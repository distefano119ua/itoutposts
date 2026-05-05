import asyncio
import json
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from config import settings
from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import PyMongoError

scheduler = AsyncIOScheduler()

MONGO_URL = settings.mongo_uri
DB_NAME = settings.db_name
COLLECTION_NAME = settings.collection_name
FALLBACK_ERROR_LOG = Path("/app/logs/mongo_fallback_errors.jsonl")

mongo_client: AsyncIOMotorClient | None = None


async def run_bash_command(command: str) -> dict[str, Any]:
    process = await asyncio.create_subprocess_shell(
        command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await process.communicate()
    return {
        'command': command,
        'returncode': process.returncode,
        'stdout': stdout.decode().strip(),
        'stderr': stderr.decode().strip()
    }


async def check_logs() -> None:
    commands = [
        "bash /app/monitor/disk_monitor.sh",
        "bash /app/monitor/ram_monitor.sh",
    ]
    for command in commands:
        result = await run_bash_command(command)
        if result['returncode'] != 0:
            error_data = {
                "service": settings.service_name,
                "command": result['command'],
                "stderror": result['stderr'],
                "stdout": result['stdout'],
                "created_at": datetime.now(timezone.utc)
            }
            await save_error_to_db(error_data)


async def save_error_to_db(error_data: dict) -> None:
    if mongo_client is None:
        raise RuntimeError("MongoDB client is not initialized.")
    db = mongo_client[DB_NAME]
    collection = db[COLLECTION_NAME]
    await collection.insert_one(error_data)


async def save_error_to_file(error_data: dict) -> None:
    FALLBACK_ERROR_LOG.parent.mkdir(parents=True, exist_ok=True)
    with FALLBACK_ERROR_LOG.open("a", encoding="utf-8") as file:
        file.write(
            json.dumps(
                error_data,
                default=str,
                ensure_ascii=False,
            )
            + "\n"
        )


async def check_mongodb_connection() -> bool:
    if mongo_client is None:
        return False
    try:
        await mongo_client.admin.command("ping")
        return True
    except PyMongoError:
        return False


@asynccontextmanager
async def lifespan(app: FastAPI):
    global mongo_client

    mongo_client = AsyncIOMotorClient(
        MONGO_URL, serverSelectionTimeoutMS=3000,
    )

    mongo_available = await check_mongodb_connection()

    if not mongo_available:
        mongo_client.close()
        mongo_client = None
        await save_error_to_file(
            {
                "service": settings.service_name,
                "type": "mongodb_connection_error",
                "message": "MongoDB is not available on startup",
                "created_at": datetime.now(timezone.utc),
            }
        )
    scheduler.add_job(
        check_logs,
        trigger="interval",
        minutes=5,
        id="check_logs_job",
        replace_existing=True,
        max_instances=1,
    )

    scheduler.start()

    yield

    scheduler.shutdown()

    if mongo_client is not None:
        mongo_client.close()

app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health_check():
    return {"status": "ok"}


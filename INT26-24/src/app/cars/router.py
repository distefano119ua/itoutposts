from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorClient

from cars.service import get_cars_from_mongodb, load_cars_csv_to_mongodb

from cars.service import (
    get_avg_price_by_company,
    get_cars_from_mongodb,
    load_cars_csv_to_mongodb,
)


router = APIRouter(prefix="/cars", tags=["cars"])


async def get_mongo_client() -> AsyncIOMotorClient:
    """
    Dependency-заглушка.

    Реальная dependency будет переопределена в main.py,
    потому что mongo_client создаётся там внутри lifespan.
    """
    raise RuntimeError("MongoDB dependency is not configured.")


@router.get("")
async def get_cars(
    mongo_client: AsyncIOMotorClient = Depends(get_mongo_client),
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    """
    Endpoint для frontend.

    GET /cars?limit=100&offset=0
    """
    try:
        return await get_cars_from_mongodb(
            mongo_client=mongo_client,
            limit=limit,
            offset=offset,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/reload")
async def reload_cars(
    mongo_client: AsyncIOMotorClient = Depends(get_mongo_client),
) -> dict[str, Any]:
    """
    Ручная перезагрузка CSV в MongoDB.

    POST /cars/reload
    """
    try:
        return await load_cars_csv_to_mongodb(mongo_client)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    

@router.get("/stats/avg-price-by-company")
async def avg_price_by_company(
    mongo_client: AsyncIOMotorClient = Depends(get_mongo_client),
    limit: int = Query(default=15, ge=1, le=50),
) -> dict[str, Any]:
    try:
        return {
            "items": await get_avg_price_by_company(
                mongo_client=mongo_client,
                limit=limit,
            )
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    

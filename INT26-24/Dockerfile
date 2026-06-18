FROM python:3.11-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash coreutils procps && \
    rm -rf /var/lib/apt/lists/*

COPY pyproject.toml uv.lock .
RUN uv sync --frozen --no-cache

ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONPATH="/app/"

COPY src/app/ /app/

#RUN chmod +x /app/monitor/disk_monitor.sh /app/monitor/ram_monitor.sh

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7000", "--reload"]
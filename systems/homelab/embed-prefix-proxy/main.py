# Harrier embedding prefix 주입 프록시.
# Hindsight OpenAI embedding provider → 이 프록시 → llama-swap /v1/embeddings.
# 쿼리 mode에서 Harrier instruct prefix를 input 앞에 붙여 전달한다.

import os
from contextlib import asynccontextmanager
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

UPSTREAM_URL = os.getenv("UPSTREAM_URL", "http://127.0.0.1:8090")
QUERY_PREFIX = os.getenv(
    "QUERY_PREFIX",
    "Instruct: Given a query, retrieve relevant passages that answer the query\nQuery: ",
)
TIMEOUT_SECONDS = float(os.getenv("TIMEOUT_SECONDS", "60"))

_client: httpx.AsyncClient | None = None


def get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(base_url=UPSTREAM_URL, timeout=TIMEOUT_SECONDS)
    return _client


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    if _client is not None:
        await _client.aclose()


app = FastAPI(lifespan=lifespan)


def prepend_prefix(value: Any) -> Any:
    if isinstance(value, str):
        return QUERY_PREFIX + value
    if isinstance(value, list):
        return [QUERY_PREFIX + v if isinstance(v, str) else v for v in value]
    return value


async def forward(path: str, body: dict) -> JSONResponse:
    try:
        resp = await get_client().post(path, json=body)
    except httpx.RequestError as exc:
        raise HTTPException(status_code=502, detail=f"upstream unreachable: {exc}")
    return JSONResponse(content=resp.json(), status_code=resp.status_code)


@app.post("/v1/embeddings")
async def embeddings_with_prefix(request: Request) -> JSONResponse:
    body = await request.json()
    if "input" in body:
        body["input"] = prepend_prefix(body["input"])
    return await forward("/v1/embeddings", body)


@app.post("/v1/embeddings/raw")
async def embeddings_raw(request: Request) -> JSONResponse:
    body = await request.json()
    return await forward("/v1/embeddings", body)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "upstream": UPSTREAM_URL}

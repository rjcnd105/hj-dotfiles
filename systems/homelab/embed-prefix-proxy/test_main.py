# embed-prefix-proxy 테스트.
# httpx MockTransport로 upstream llama-swap을 가짜로 만들고 프록시 동작 검증.

import json
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def mock_upstream(monkeypatch):
    """upstream 호출을 기록하고 고정 응답을 반환하는 가짜 클라이언트."""
    captured: dict[str, Any] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["method"] = request.method
        captured["url"] = str(request.url)
        captured["body"] = json.loads(request.content)
        return httpx.Response(
            200,
            json={
                "object": "list",
                "data": [{"object": "embedding", "index": 0, "embedding": [0.1] * 1024}],
                "model": captured["body"].get("model", "harrier"),
            },
        )

    transport = httpx.MockTransport(handler)

    import main  # noqa: WPS433 — 환경변수 고정 후 import하도록 fixture 내에서 로드

    fake = httpx.AsyncClient(base_url=main.UPSTREAM_URL, transport=transport)
    monkeypatch.setattr(main, "_client", fake)
    return main, captured


def test_health(mock_upstream):
    main, _ = mock_upstream
    client = TestClient(main.app)
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_embeddings_string_input_gets_prefix(mock_upstream):
    main, captured = mock_upstream
    client = TestClient(main.app)
    r = client.post(
        "/v1/embeddings", json={"input": "hello world", "model": "harrier"}
    )
    assert r.status_code == 200
    assert captured["body"]["input"].startswith("Instruct:")
    assert captured["body"]["input"].endswith("hello world")
    assert captured["body"]["model"] == "harrier"


def test_embeddings_list_input_each_prefixed(mock_upstream):
    main, captured = mock_upstream
    client = TestClient(main.app)
    r = client.post(
        "/v1/embeddings", json={"input": ["a", "b", "c"], "model": "harrier"}
    )
    assert r.status_code == 200
    sent = captured["body"]["input"]
    assert len(sent) == 3
    for s in sent:
        assert s.startswith("Instruct:")


def test_embeddings_raw_passthrough(mock_upstream):
    main, captured = mock_upstream
    client = TestClient(main.app)
    r = client.post(
        "/v1/embeddings/raw", json={"input": "plain text", "model": "harrier"}
    )
    assert r.status_code == 200
    assert captured["body"]["input"] == "plain text"


def test_raw_path_still_hits_upstream_v1_embeddings(mock_upstream):
    main, captured = mock_upstream
    client = TestClient(main.app)
    client.post("/v1/embeddings/raw", json={"input": "x", "model": "m"})
    assert captured["url"].endswith("/v1/embeddings")


def test_rerank_path_hits_upstream_v1_rerank(mock_upstream):
    main, captured = mock_upstream
    client = TestClient(main.app)
    r = client.post(
        "/v1/rerank",
        json={
            "model": "qwen3-reranker",
            "query": "hello",
            "documents": ["hello world"],
        },
    )
    assert r.status_code == 200
    assert captured["url"].endswith("/v1/rerank")
    assert captured["body"]["documents"] == ["hello world"]


def test_rerank_documents_are_truncated(mock_upstream, monkeypatch):
    main, captured = mock_upstream
    monkeypatch.setattr(main, "RERANK_DOCUMENT_MAX_CHARS", 8)

    client = TestClient(main.app)
    r = client.post(
        "/v1/rerank",
        json={
            "model": "qwen3-reranker",
            "query": "hello",
            "documents": ["short", "0123456789abcdef", 42],
        },
    )

    assert r.status_code == 200
    assert captured["body"]["documents"] == ["short", "01234567", 42]


def test_empty_input_field_missing_passthrough(mock_upstream):
    # input 키가 없어도 upstream이 에러 처리하도록 그대로 전달한다.
    main, captured = mock_upstream
    client = TestClient(main.app)
    r = client.post("/v1/embeddings", json={"model": "harrier"})
    assert r.status_code == 200
    assert "input" not in captured["body"]


def test_upstream_unreachable_returns_502(monkeypatch):
    import main

    def boom(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom", request=request)

    fake = httpx.AsyncClient(base_url=main.UPSTREAM_URL, transport=httpx.MockTransport(boom))
    monkeypatch.setattr(main, "_client", fake)

    client = TestClient(main.app)
    r = client.post("/v1/embeddings", json={"input": "x", "model": "m"})
    assert r.status_code == 502


def test_upstream_error_status_propagates(monkeypatch):
    import main

    def err(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, json={"error": "model load failed"})

    fake = httpx.AsyncClient(base_url=main.UPSTREAM_URL, transport=httpx.MockTransport(err))
    monkeypatch.setattr(main, "_client", fake)

    client = TestClient(main.app)
    r = client.post("/v1/embeddings", json={"input": "x", "model": "m"})
    assert r.status_code == 500
    assert r.json()["error"] == "model load failed"


def test_non_string_list_items_skipped(mock_upstream):
    # int 섞이면 그대로 둔다. llama.cpp가 에러 내든 말든.
    main, captured = mock_upstream
    client = TestClient(main.app)
    r = client.post(
        "/v1/embeddings", json={"input": ["text", 42], "model": "harrier"}
    )
    assert r.status_code == 200
    sent = captured["body"]["input"]
    assert sent[0].startswith("Instruct:")
    assert sent[1] == 42

from __future__ import annotations

from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse

SERVICE_MAP = {
    "market-data":   "http://localhost:8101",
    "ai-research":   "http://localhost:8102",
    "portfolio":     "http://localhost:8103",
    "risk":          "http://localhost:8104",
    "brokerage":     "http://localhost:8105",
    "blockchain":    "http://localhost:8106",
    "wallet":        "http://localhost:8107",
    "compliance":    "http://localhost:8108",
    "social-intel":  "http://localhost:8110",
    "reporting":     "http://localhost:8109",
}

# Path → (service key, upstream path override or None to pass through)
_ROUTES: dict[str, str] = {
    "/quotes":              SERVICE_MAP["market-data"],
    "/signal":              SERVICE_MAP["ai-research"],
    "/directional-change":  SERVICE_MAP["ai-research"],
    "/markowitz":           SERVICE_MAP["ai-research"],
    "/backtests":           SERVICE_MAP["ai-research"],
    "/rl/step":             SERVICE_MAP["ai-research"],
    "/positions":           SERVICE_MAP["portfolio"],
    "/snapshot":            SERVICE_MAP["risk"],
    "/orders":              SERVICE_MAP["brokerage"],
    "/orders/cancel":       SERVICE_MAP["brokerage"],
    "/account":             SERVICE_MAP["brokerage"],
    "/events":              SERVICE_MAP["blockchain"],
    "/alerts":              SERVICE_MAP["blockchain"],
    "/accounts":            SERVICE_MAP["wallet"],
    "/holdings":            SERVICE_MAP["wallet"],
    "/tokenized-assets":    SERVICE_MAP["wallet"],
    "/profile":             SERVICE_MAP["compliance"],
    "/notes":               SERVICE_MAP["social-intel"],
    "/reputation":          SERVICE_MAP["social-intel"],
    "/providers":           SERVICE_MAP["social-intel"],
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.client = httpx.AsyncClient(timeout=10.0)
    yield
    await app.state.client.aclose()


app = FastAPI(title="gateway-service", lifespan=lifespan)


@app.get("/health")
def health():
    return {"service": "gateway-service", "ok": True, "routes": list(_ROUTES)}


@app.get("/service-map")
def service_map():
    return SERVICE_MAP


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(path: str, request: Request) -> Response:
    route_path = f"/{path}"
    # Match longest prefix first so /orders/cancel beats /orders
    target_base = None
    for candidate in sorted(_ROUTES, key=len, reverse=True):
        if route_path == candidate or route_path.startswith(candidate + "/"):
            target_base = _ROUTES[candidate]
            break

    if target_base is None:
        return JSONResponse({"error": f"No route for /{path}"}, status_code=404)

    target_url = target_base + route_path
    body = await request.body()
    excluded = {"host", "content-length", "transfer-encoding"}
    headers = {k: v for k, v in request.headers.items() if k.lower() not in excluded}

    client: httpx.AsyncClient = request.app.state.client
    try:
        resp = await client.request(
            method=request.method,
            url=target_url,
            headers=headers,
            content=body,
            params=dict(request.query_params),
        )
        return Response(content=resp.content, status_code=resp.status_code,
                        media_type=resp.headers.get("content-type", "application/json"))
    except httpx.ConnectError:
        return JSONResponse({"error": f"Service unavailable for /{path}"}, status_code=503)

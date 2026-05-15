from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="reporting-service")


@app.get("/health")
def health():
    return {"service": "reporting-service", "ok": True}


@app.get("/client-summary")
def client_summary():
    return {
        "summary": "Hybrid wealth OS snapshot",
        "sections": ["portfolio", "risk", "signals", "on-chain events", "compliance"],
    }

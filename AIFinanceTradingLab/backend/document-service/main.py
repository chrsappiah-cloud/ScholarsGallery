from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="document-service")


@app.get("/health")
def health():
    return {"service": "document-service", "ok": True}


@app.get("/reports")
def reports():
    return {
        "reports": [
            {"id": "risk-q1", "title": "Q1 Risk Review", "storage": "ipfs://bafy-report-hash"},
            {"id": "strategy-dc", "title": "Directional Change Research", "storage": "sha256:research-version-hash"},
        ]
    }

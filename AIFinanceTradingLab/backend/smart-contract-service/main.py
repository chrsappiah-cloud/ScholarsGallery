from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="smart-contract-service")


@app.get("/health")
def health():
    return {"service": "smart-contract-service", "ok": True}


@app.get("/contracts/{address}")
def contract_detail(address: str):
    return {
        "address": address,
        "chain": "Ethereum",
        "status": "watching",
        "decoded_events": ["Transfer", "Mint", "Redemption"],
    }

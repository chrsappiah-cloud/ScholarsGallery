from __future__ import annotations

from pathlib import Path
import sys

from fastapi import FastAPI

sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import UnifiedAssetPosition  # noqa: E402

app = FastAPI(title="portfolio-service")


@app.get("/health")
def health():
    return {"service": "portfolio-service", "ok": True}


@app.get("/positions", response_model=list[UnifiedAssetPosition])
def positions():
    return [
        UnifiedAssetPosition(id="spy-core", domain="traditional", symbol="SPY", display_name="SPDR S&P 500 ETF", quantity=42, market_value_usd=22050, venue="Brokerage", risk_label="Core"),
        UnifiedAssetPosition(id="eth-wallet", domain="crypto", symbol="ETH", display_name="Ethereum", quantity=6.5, market_value_usd=19800, venue="Wallet", risk_label="Elevated"),
        UnifiedAssetPosition(id="energy-token", domain="tokenized", symbol="ENGY-RWA", display_name="Tokenized Energy Basket", quantity=120, market_value_usd=12400, venue="Smart Contract", risk_label="Structured"),
    ]

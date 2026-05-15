from __future__ import annotations

from pathlib import Path
import sys

from fastapi import FastAPI

sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import ChainAccount, TokenHolding, TokenizedAsset  # noqa: E402

app = FastAPI(title="wallet-service")

_TOKENIZED = [
    TokenizedAsset(id="rwa-energy", symbol="ENGY-RWA", display_name="Tokenized Energy Basket", asset_class="Real World Asset", contract_address="0xENGY...01", chain="Ethereum", bid_usd=103.2, ask_usd=103.6, last_price_usd=103.4, settlement_state="open", eligibility_required=True),
    TokenizedAsset(id="rwa-re", symbol="PROP-AUS", display_name="AU Commercial Property Token", asset_class="Real Estate", contract_address="0xPROP...02", chain="Base", bid_usd=212.0, ask_usd=213.5, last_price_usd=212.8, settlement_state="open", eligibility_required=True),
    TokenizedAsset(id="rwa-tbill", symbol="TBILL-3M", display_name="3-Month T-Bill Token", asset_class="Fixed Income", contract_address="0xTBIL...03", chain="Ethereum", bid_usd=99.87, ask_usd=99.91, last_price_usd=99.89, settlement_state="settled", eligibility_required=False),
]


@app.get("/health")
def health():
    return {"service": "wallet-service", "ok": True}


@app.get("/accounts", response_model=list[ChainAccount])
def accounts():
    return [
        ChainAccount(id="eth-primary", chain="Ethereum", address="0xABCD...1234", label="Primary Vault", balance_usd=19800),
        ChainAccount(id="base-watch", chain="Base", address="0x9988...F0AA", label="Watch Wallet", balance_usd=8150),
    ]


@app.get("/holdings", response_model=list[TokenHolding])
def holdings():
    return [
        TokenHolding(id="eth", contract_address="native", symbol="ETH", name="Ethereum", quantity=6.5, price_usd=3046, value_usd=19799, chain="Ethereum"),
        TokenHolding(id="usdc", contract_address="0xa0b8...", symbol="USDC", name="USD Coin", quantity=12500, price_usd=1, value_usd=12500, chain="Base"),
        TokenHolding(id="wbtc", contract_address="0x2260...", symbol="WBTC", name="Wrapped Bitcoin", quantity=0.12, price_usd=102240, value_usd=12269, chain="Ethereum"),
    ]


@app.get("/tokenized-assets", response_model=list[TokenizedAsset])
def tokenized_assets():
    return _TOKENIZED

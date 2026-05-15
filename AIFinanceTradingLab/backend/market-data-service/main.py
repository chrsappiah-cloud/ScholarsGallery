from __future__ import annotations

import os
from pathlib import Path
import sys

from dotenv import load_dotenv
from fastapi import FastAPI, Query

load_dotenv()
sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import Quote  # noqa: E402

app = FastAPI(title="market-data-service")

_API_KEY = os.getenv("ALPACA_API_KEY", "")
_API_SECRET = os.getenv("ALPACA_API_SECRET", "")
_HAS_KEYS = bool(_API_KEY and _API_SECRET)

# Crypto symbols Alpaca uses "BTC/USD" slash notation; we accept "BTC-USD" externally.
_CRYPTO_SYMBOLS = {"BTC-USD", "ETH-USD", "SOL-USD", "AVAX-USD", "BNB-USD", "DOGE-USD"}


def _to_alpaca_crypto(symbol: str) -> str:
    return symbol.replace("-USD", "/USD")


def _from_alpaca_crypto(symbol: str) -> str:
    return symbol.replace("/USD", "-USD")


def _stub_quote(symbol: str, index: int) -> Quote:
    base = {"AAPL": 212.20, "MSFT": 420.50, "NVDA": 968.0, "TSLA": 182.30,
            "BTC-USD": 102_240.0, "ETH-USD": 3_046.0}.get(symbol, 100.0 + index)
    return Quote(symbol=symbol, bid=round(base - 0.1, 2), ask=round(base + 0.1, 2), last=base)


def _live_quotes(symbols: list[str]) -> list[Quote]:
    from alpaca.data.historical import CryptoHistoricalDataClient, StockHistoricalDataClient
    from alpaca.data.requests import CryptoLatestQuoteRequest, StockLatestQuoteRequest

    stock_syms = [s for s in symbols if s not in _CRYPTO_SYMBOLS]
    crypto_syms = [s for s in symbols if s in _CRYPTO_SYMBOLS]
    results: list[Quote] = []

    if stock_syms:
        client = StockHistoricalDataClient(_API_KEY, _API_SECRET)
        resp = client.get_stock_latest_quote(StockLatestQuoteRequest(symbol_or_symbols=stock_syms))
        for sym in stock_syms:
            q = resp.get(sym)
            if q:
                mid = round((q.bid_price + q.ask_price) / 2, 4)
                results.append(Quote(symbol=sym, bid=q.bid_price, ask=q.ask_price, last=mid))

    if crypto_syms:
        client = CryptoHistoricalDataClient()
        alpaca_syms = [_to_alpaca_crypto(s) for s in crypto_syms]
        resp = client.get_crypto_latest_quote(CryptoLatestQuoteRequest(symbol_or_symbols=alpaca_syms))
        for sym, alpaca_sym in zip(crypto_syms, alpaca_syms):
            q = resp.get(alpaca_sym)
            if q:
                mid = round((q.bid_price + q.ask_price) / 2, 4)
                results.append(Quote(symbol=sym, bid=q.bid_price, ask=q.ask_price, last=mid))

    return results


@app.get("/health")
def health():
    return {"service": "market-data-service", "ok": True, "live_data": _HAS_KEYS}


@app.get("/quotes", response_model=list[Quote])
def quotes(symbols: str = Query(...)):
    requested = [s.strip().upper() for s in symbols.split(",") if s.strip()]
    if _HAS_KEYS:
        try:
            return _live_quotes(requested)
        except Exception as exc:
            # Fall back to stubs so the app stays functional during key issues.
            print(f"[market-data] Alpaca error, using stubs: {exc}")
    return [_stub_quote(sym, i) for i, sym in enumerate(requested)]

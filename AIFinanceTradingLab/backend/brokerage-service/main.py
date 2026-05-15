from __future__ import annotations

import os
from pathlib import Path
import sys
from typing import Literal

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

load_dotenv()
sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from database import get_db, init_db  # noqa: E402
from db_models import OrderRecord  # noqa: E402

from brokers import AlpacaAdapter, BrokerAdapter, IBKRAdapter
from brokers.base import OrderRequest as BrokerOrderRequest

app = FastAPI(title="brokerage-service")


@app.on_event("startup")
def startup():
    init_db()


_MODE = os.getenv("TRADING_MODE", "simulation")

_ADAPTERS: dict[str, BrokerAdapter] = {
    "alpaca": AlpacaAdapter(
        api_key=os.getenv("ALPACA_API_KEY", ""),
        api_secret=os.getenv("ALPACA_API_SECRET", ""),
        mode=_MODE,  # type: ignore[arg-type]
    ),
    "ibkr": IBKRAdapter(mode=_MODE),  # type: ignore[arg-type]
}


class OrderPayload(BaseModel):
    symbol: str
    side: Literal["buy", "sell"]
    quantity: float
    order_type: str = "market"
    limit_price: float | None = None
    mode: Literal["simulation", "paper", "live"] = "simulation"
    broker: str = "alpaca"


class CancelPayload(BaseModel):
    order_id: str
    broker: str = "alpaca"


@app.get("/health")
def health():
    return {"service": "brokerage-service", "ok": True, "brokers": list(_ADAPTERS), "mode": _MODE}


@app.post("/orders")
def place_order(payload: OrderPayload, db: Session = Depends(get_db)):
    adapter = _get_adapter(payload.broker)
    req = BrokerOrderRequest(
        symbol=payload.symbol,
        side=payload.side,
        quantity=payload.quantity,
        order_type=payload.order_type,
        limit_price=payload.limit_price,
        mode=payload.mode,
    )
    result = adapter.place_order(req)

    record = OrderRecord(
        id=result.order_id,
        broker=payload.broker,
        symbol=result.symbol,
        side=result.side,
        quantity=result.quantity,
        order_type=req.order_type,
        mode=result.status and payload.mode,
        status=result.status,
        filled_price=result.filled_price,
        submitted_at=result.submitted_at,
        message=result.message,
    )
    db.add(record)
    db.commit()

    return {
        "order_id": result.order_id,
        "symbol": result.symbol,
        "side": result.side,
        "quantity": result.quantity,
        "status": result.status,
        "filled_price": result.filled_price,
        "submitted_at": result.submitted_at.isoformat(),
        "message": result.message,
    }


@app.post("/orders/cancel")
def cancel_order(payload: CancelPayload):
    adapter = _get_adapter(payload.broker)
    success = adapter.cancel_order(payload.order_id)
    return {"cancelled": success, "order_id": payload.order_id}


@app.get("/orders")
def list_orders(broker: str = "alpaca", limit: int = 50, db: Session = Depends(get_db)):
    rows = (
        db.query(OrderRecord)
        .filter(OrderRecord.broker == broker)
        .order_by(OrderRecord.submitted_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "order_id": r.id,
            "broker": r.broker,
            "symbol": r.symbol,
            "side": r.side,
            "quantity": r.quantity,
            "order_type": r.order_type,
            "mode": r.mode,
            "status": r.status,
            "filled_price": r.filled_price,
            "submitted_at": r.submitted_at.isoformat() if r.submitted_at else None,
            "message": r.message,
        }
        for r in rows
    ]


@app.get("/account/{broker}")
def account(broker: str):
    snap = _get_adapter(broker).get_account()
    return {"broker": snap.broker, "cash": snap.cash, "portfolio_value": snap.portfolio_value,
            "buying_power": snap.buying_power, "mode": snap.mode}


@app.get("/positions/{broker}")
def positions(broker: str):
    return _get_adapter(broker).get_positions()


def _get_adapter(broker: str) -> BrokerAdapter:
    adapter = _ADAPTERS.get(broker.lower())
    if not adapter:
        raise HTTPException(status_code=404, detail=f"Unknown broker: {broker}")
    return adapter

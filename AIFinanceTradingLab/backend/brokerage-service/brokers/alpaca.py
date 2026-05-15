from __future__ import annotations

import uuid
from datetime import datetime, timezone

from .base import AccountSnapshot, BrokerAdapter, OrderRequest, OrderResult, TradingMode


class AlpacaAdapter(BrokerAdapter):
    """Alpaca Markets adapter.

    Simulation: fully stubbed, no network traffic.
    Paper/Live: delegates to alpaca-py SDK. Credentials come from env vars
    (ALPACA_API_KEY, ALPACA_API_SECRET) and are never exposed to the client.
    """

    def __init__(self, api_key: str = "", api_secret: str = "", base_url: str = "", mode: TradingMode = "simulation") -> None:
        self._api_key = api_key
        self._api_secret = api_secret
        self._mode = mode
        self._base_url = base_url or ("https://paper-api.alpaca.markets" if mode != "live" else "https://api.alpaca.markets")
        self._trading_client = None

    def _client(self):
        if self._trading_client is None and self._mode != "simulation":
            from alpaca.trading.client import TradingClient
            paper = self._mode == "paper"
            self._trading_client = TradingClient(self._api_key, self._api_secret, paper=paper)
        return self._trading_client

    @property
    def name(self) -> str:
        return "alpaca"

    def place_order(self, req: OrderRequest) -> OrderResult:
        if self._mode == "simulation":
            return OrderResult(
                order_id=str(uuid.uuid4()),
                symbol=req.symbol,
                side=req.side,
                quantity=req.quantity,
                status="filled",
                filled_price=_sim_price(req.symbol),
                message="Simulation fill — no real order submitted",
            )
        try:
            from alpaca.trading.enums import OrderSide, TimeInForce
            from alpaca.trading.requests import LimitOrderRequest, MarketOrderRequest

            side = OrderSide.BUY if req.side == "buy" else OrderSide.SELL
            if req.order_type == "limit" and req.limit_price:
                order_data = LimitOrderRequest(symbol=req.symbol, qty=req.quantity, side=side,
                                               time_in_force=TimeInForce.DAY, limit_price=req.limit_price)
            else:
                order_data = MarketOrderRequest(symbol=req.symbol, qty=req.quantity, side=side,
                                                time_in_force=TimeInForce.DAY)
            order = self._client().submit_order(order_data=order_data)
            return OrderResult(
                order_id=str(order.id),
                symbol=req.symbol,
                side=req.side,
                quantity=req.quantity,
                status=str(order.status.value),
                filled_price=float(order.filled_avg_price) if order.filled_avg_price else None,
                submitted_at=order.submitted_at or datetime.now(timezone.utc),
                message=f"Submitted to Alpaca ({self._mode})",
            )
        except Exception as exc:
            return OrderResult(
                order_id=str(uuid.uuid4()),
                symbol=req.symbol,
                side=req.side,
                quantity=req.quantity,
                status="rejected",
                filled_price=None,
                message=str(exc),
            )

    def cancel_order(self, order_id: str) -> bool:
        if self._mode == "simulation":
            return True
        try:
            self._client().cancel_order_by_id(order_id)
            return True
        except Exception:
            return False

    def get_account(self) -> AccountSnapshot:
        if self._mode == "simulation":
            return AccountSnapshot(broker="alpaca", cash=100_000.0, portfolio_value=104_200.0,
                                   buying_power=200_000.0, mode=self._mode)
        try:
            acct = self._client().get_account()
            return AccountSnapshot(
                broker="alpaca",
                cash=float(acct.cash),
                portfolio_value=float(acct.portfolio_value),
                buying_power=float(acct.buying_power),
                mode=self._mode,
            )
        except Exception:
            return AccountSnapshot(broker="alpaca", cash=0.0, portfolio_value=0.0,
                                   buying_power=0.0, mode=self._mode)

    def get_positions(self) -> list[dict]:
        if self._mode == "simulation":
            return [
                {"symbol": "AAPL", "qty": 42, "avg_entry_price": 196.40, "market_value": 8_908.80, "unrealized_pl": 504.0},
                {"symbol": "NVDA", "qty": 12, "avg_entry_price": 890.0, "market_value": 11_616.0, "unrealized_pl": 936.0},
            ]
        try:
            positions = self._client().get_all_positions()
            return [
                {
                    "symbol": p.symbol,
                    "qty": float(p.qty),
                    "avg_entry_price": float(p.avg_entry_price),
                    "market_value": float(p.market_value),
                    "unrealized_pl": float(p.unrealized_pl),
                }
                for p in positions
            ]
        except Exception:
            return []


def _sim_price(symbol: str) -> float:
    prices = {"AAPL": 212.20, "MSFT": 420.50, "NVDA": 968.00, "TSLA": 182.30,
              "BTC-USD": 102_240.0, "ETH-USD": 3_046.0}
    return prices.get(symbol.upper(), 100.0)

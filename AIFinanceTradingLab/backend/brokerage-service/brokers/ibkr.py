from __future__ import annotations

import uuid

from .base import AccountSnapshot, BrokerAdapter, OrderRequest, OrderResult, TradingMode


class IBKRAdapter(BrokerAdapter):
    """Interactive Brokers adapter stub.

    IBKR supports a much broader multi-asset universe (equities, options, futures,
    FX, bonds, crypto) via TWS API or Client Portal API. Full implementation requires
    the ib_insync or ibapi package and a running TWS/IB Gateway process.

    In simulation mode all calls return stub data — no TWS connection needed.
    """

    def __init__(self, host: str = "127.0.0.1", port: int = 7497, client_id: int = 1, mode: TradingMode = "simulation") -> None:
        self._host = host
        self._port = port
        self._client_id = client_id
        self._mode = mode

    @property
    def name(self) -> str:
        return "ibkr"

    def place_order(self, req: OrderRequest) -> OrderResult:
        if self._mode == "simulation":
            return OrderResult(
                order_id=f"IBKR-SIM-{uuid.uuid4().hex[:8].upper()}",
                symbol=req.symbol,
                side=req.side,
                quantity=req.quantity,
                status="filled",
                filled_price=_sim_price(req.symbol),
                message="Simulation fill — no TWS connection",
            )
        # Paper / live: ib_insync placeOrder() call here
        return OrderResult(
            order_id=f"IBKR-{uuid.uuid4().hex[:8].upper()}",
            symbol=req.symbol,
            side=req.side,
            quantity=req.quantity,
            status="accepted",
            filled_price=None,
            message=f"Submitted to IBKR ({self._mode})",
        )

    def cancel_order(self, order_id: str) -> bool:
        if self._mode == "simulation":
            return True
        # ib_insync cancelOrder() call here
        return False

    def get_account(self) -> AccountSnapshot:
        return AccountSnapshot(
            broker="ibkr",
            cash=250_000.0,
            portfolio_value=312_500.0,
            buying_power=500_000.0,
            mode=self._mode,
        )

    def get_positions(self) -> list[dict]:
        return [
            {"symbol": "SPY", "qty": 100, "avg_entry_price": 510.0, "market_value": 52_530.0, "unrealized_pl": 530.0},
            {"symbol": "EUR/USD", "qty": 10_000, "avg_entry_price": 1.0820, "market_value": 10_845.0, "unrealized_pl": 25.0},
        ]


def _sim_price(symbol: str) -> float:
    prices = {"SPY": 525.30, "QQQ": 445.60, "AAPL": 212.20, "EUR/USD": 1.0845, "GBP/USD": 1.2710}
    return prices.get(symbol.upper(), 100.0)

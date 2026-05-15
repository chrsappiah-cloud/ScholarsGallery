from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Literal, Optional


OrderSide = Literal["buy", "sell"]
OrderStatus = Literal["pending", "accepted", "filled", "cancelled", "rejected"]
TradingMode = Literal["simulation", "paper", "live"]


@dataclass
class OrderRequest:
    symbol: str
    side: OrderSide
    quantity: float
    order_type: str = "market"
    limit_price: Optional[float] = None
    mode: TradingMode = "simulation"


@dataclass
class OrderResult:
    order_id: str
    symbol: str
    side: OrderSide
    quantity: float
    status: OrderStatus
    filled_price: Optional[float]
    submitted_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    message: str = ""


@dataclass
class AccountSnapshot:
    broker: str
    cash: float
    portfolio_value: float
    buying_power: float
    mode: TradingMode


class BrokerAdapter(ABC):
    """Unified contract for all broker integrations. Live execution is always
    mediated server-side — credentials never reach the mobile client."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def place_order(self, req: OrderRequest) -> OrderResult: ...

    @abstractmethod
    def cancel_order(self, order_id: str) -> bool: ...

    @abstractmethod
    def get_account(self) -> AccountSnapshot: ...

    @abstractmethod
    def get_positions(self) -> list[dict]: ...

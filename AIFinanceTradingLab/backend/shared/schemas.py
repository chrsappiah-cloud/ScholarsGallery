from __future__ import annotations

from datetime import datetime, timezone
from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Quote(BaseModel):
    symbol: str
    bid: float
    ask: float
    last: float
    timestamp: datetime = Field(default_factory=utc_now)


class SignalRequest(BaseModel):
    symbol: str
    mode: Literal["simulation", "paper", "live"]
    features: Dict[str, float]


class Signal(BaseModel):
    symbol: str
    action: str
    confidence: float
    engine: str
    explanation: Optional[str] = None


class Position(BaseModel):
    symbol: str
    quantity: float
    average_price: float
    market_value: float
    unrealized_pnl: float


class RiskSnapshot(BaseModel):
    gross_exposure: float
    net_exposure: float
    max_drawdown: float
    value_at_risk95: float
    expected_shortfall95: float


class DashboardPanel(BaseModel):
    title: str
    detail: str
    caption: str


class UnifiedAssetPosition(BaseModel):
    id: str
    domain: Literal["traditional", "crypto", "tokenized"]
    symbol: str
    display_name: str
    quantity: float
    market_value_usd: float
    venue: str
    risk_label: str


class DashboardSnapshot(BaseModel):
    mode: Literal["simulation", "paper", "live"] = "simulation"
    headline: str
    subheadline: str
    panels: List[DashboardPanel]
    risk: RiskSnapshot
    top_signals: List[Signal]
    unified_positions: List[UnifiedAssetPosition]


class ChainAccount(BaseModel):
    id: str
    chain: str
    address: str
    label: Optional[str] = None
    balance_usd: float
    last_synced_at: datetime = Field(default_factory=utc_now)


class TokenHolding(BaseModel):
    id: str
    contract_address: str
    symbol: str
    name: str
    quantity: float
    price_usd: float
    value_usd: float
    chain: str


class SmartContractEvent(BaseModel):
    id: str
    chain: str
    contract_address: str
    event_name: str
    tx_hash: str
    block_number: int
    timestamp: datetime = Field(default_factory=utc_now)
    summary: str


class ComplianceProfile(BaseModel):
    kyc_status: str
    aml_risk_score: float
    jurisdiction: str
    accredited_investor: bool


class OnChainAlert(BaseModel):
    id: str
    chain: str
    severity: Literal["info", "warning", "critical"]
    title: str
    detail: str
    tx_hash: Optional[str] = None
    timestamp: datetime = Field(default_factory=utc_now)


class AnalystNote(BaseModel):
    id: str
    author_handle: str
    reputation_score: float
    symbol: str
    sentiment: Literal["bullish", "bearish", "neutral"]
    body: str
    provenance_hash: Optional[str] = None
    published_at: datetime = Field(default_factory=utc_now)
    verified_on_chain: bool = False


class ReputationScore(BaseModel):
    id: str
    handle: str
    overall_score: float
    signal_accuracy: float
    total_calls: int
    correct_calls: int
    domain: str


class TokenizedAsset(BaseModel):
    id: str
    symbol: str
    display_name: str
    asset_class: str
    contract_address: str
    chain: str
    bid_usd: Optional[float] = None
    ask_usd: Optional[float] = None
    last_price_usd: float
    settlement_state: Literal["open", "pending", "settled", "failed"]
    eligibility_required: bool


class BacktestRun(BaseModel):
    id: str
    strategy: str
    symbol: str
    start_date: str
    end_date: str
    total_return: float
    sharpe_ratio: float
    max_drawdown: float
    num_trades: int
    status: Literal["complete", "running", "failed"]

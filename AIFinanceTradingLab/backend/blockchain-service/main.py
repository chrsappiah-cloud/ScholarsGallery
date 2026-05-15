from __future__ import annotations

from pathlib import Path
import sys

from fastapi import FastAPI

sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import OnChainAlert, SmartContractEvent  # noqa: E402

app = FastAPI(title="blockchain-service")

_EVENTS = [
    SmartContractEvent(id="evt-1", chain="Ethereum", contract_address="0xVault...AA", event_name="Deposit", tx_hash="0xabc...123", block_number=21_540_110, summary="Deposit of 5.0 ETH into strategy vault"),
    SmartContractEvent(id="evt-2", chain="Base", contract_address="0xPool...BB", event_name="Swap", tx_hash="0xdef...456", block_number=14_902_000, summary="Swap 12,500 USDC → 4.1 ETH at pool price"),
    SmartContractEvent(id="evt-3", chain="Ethereum", contract_address="0xStake...CC", event_name="RewardClaimed", tx_hash="0x789...abc", block_number=21_540_050, summary="Claimed 0.08 ETH staking reward"),
]

_ALERTS = [
    OnChainAlert(id="al-1", chain="Ethereum", severity="warning", title="Unusual contract flow", detail="0xVault...AA received 3× normal deposit volume in 1 hour"),
    OnChainAlert(id="al-2", chain="Base", severity="info", title="Gas spike detected", detail="Base gas fees elevated: 42 gwei (normal < 15)"),
]


@app.get("/health")
def health():
    return {"service": "blockchain-service", "ok": True}


@app.get("/events", response_model=list[SmartContractEvent])
def events():
    return _EVENTS


@app.get("/alerts", response_model=list[OnChainAlert])
def alerts():
    return _ALERTS

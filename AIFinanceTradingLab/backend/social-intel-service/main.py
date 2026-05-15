from __future__ import annotations

from pathlib import Path
import sys
from typing import Optional

from fastapi import FastAPI, Query

sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import AnalystNote, ReputationScore  # noqa: E402

app = FastAPI(title="social-intel-service")

_NOTES = [
    AnalystNote(id="note-1", author_handle="@quant_atlas", reputation_score=0.87, symbol="ETH", sentiment="bullish", body="L2 fee compression is driving ETH accumulation by DeFi protocols. On-chain net flow from CEX to self-custody up 18% WoW.", provenance_hash="QmXf...9kLm", verified_on_chain=True),
    AnalystNote(id="note-2", author_handle="@macro_drift", reputation_score=0.74, symbol="BTC-USD", sentiment="neutral", body="BTC holding $100k range but open interest distribution suggests large positioning above $108k. Watch for liquidation cascade.", verified_on_chain=False),
    AnalystNote(id="note-3", author_handle="@onchain_lens", reputation_score=0.91, symbol="NVDA", sentiment="bullish", body="AI compute demand still compounding. Supply constraint signals in Taiwan fab data corroborated by on-chain GPU futures.", provenance_hash="QmRa...3pQw", verified_on_chain=True),
]

_SCORES = [
    ReputationScore(id="r-1", handle="@quant_atlas", overall_score=0.87, signal_accuracy=0.83, total_calls=142, correct_calls=118, domain="Crypto/DeFi"),
    ReputationScore(id="r-2", handle="@macro_drift", overall_score=0.74, signal_accuracy=0.69, total_calls=88, correct_calls=61, domain="Macro/BTC"),
    ReputationScore(id="r-3", handle="@onchain_lens", overall_score=0.91, signal_accuracy=0.89, total_calls=201, correct_calls=179, domain="Cross-asset"),
]


@app.get("/health")
def health():
    return {"service": "social-intel-service", "ok": True}


@app.get("/notes", response_model=list[AnalystNote])
def notes(symbol: Optional[str] = Query(None)):
    if symbol:
        return [n for n in _NOTES if n.symbol == symbol]
    return _NOTES


@app.get("/reputation", response_model=list[ReputationScore])
def reputation():
    return _SCORES


@app.get("/providers")
def providers():
    return {
        "providers": [
            {"id": "quant-orchid", "reputation_score": 0.92, "specialty": "Regime detection"},
            {"id": "chain-sage", "reputation_score": 0.88, "specialty": "On-chain anomaly flows"},
        ]
    }

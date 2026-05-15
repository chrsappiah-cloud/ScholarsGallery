from __future__ import annotations

from pathlib import Path
import sys

from fastapi import FastAPI

sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import RiskSnapshot  # noqa: E402

app = FastAPI(title="risk-service")


@app.get("/health")
def health():
    return {"service": "risk-service", "ok": True}


@app.get("/snapshot", response_model=RiskSnapshot)
def snapshot():
    return RiskSnapshot(
        gross_exposure=0.74,
        net_exposure=0.42,
        max_drawdown=0.061,
        value_at_risk95=0.031,
        expected_shortfall95=0.046,
    )

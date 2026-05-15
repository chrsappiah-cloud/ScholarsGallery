from __future__ import annotations

from pathlib import Path
import sys

from fastapi import FastAPI

sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import ComplianceProfile  # noqa: E402

app = FastAPI(title="compliance-service")


@app.get("/health")
def health():
    return {"service": "compliance-service", "ok": True}


@app.get("/profile", response_model=ComplianceProfile)
def profile():
    return ComplianceProfile(kyc_status="approved", aml_risk_score=0.14, jurisdiction="AU", accredited_investor=True)

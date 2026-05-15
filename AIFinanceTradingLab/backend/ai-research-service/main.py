from __future__ import annotations

from pathlib import Path
import sys

from fastapi import FastAPI
from pydantic import BaseModel

sys.path.append(str(Path(__file__).resolve().parents[1] / "shared"))
from schemas import BacktestRun, Signal, SignalRequest  # noqa: E402

from research import TradingEnv, directional_change, markowitz_weights

app = FastAPI(title="ai-research-service")
env = TradingEnv()

_BACKTESTS = [
    BacktestRun(id="bt-1", strategy="Directional Change + LSTM", symbol="NVDA", start_date="2024-01-01", end_date="2024-12-31", total_return=0.412, sharpe_ratio=1.84, max_drawdown=0.092, num_trades=143, status="complete"),
    BacktestRun(id="bt-2", strategy="Markowitz Rebalance (Monthly)", symbol="SPY/QQQ/ETH", start_date="2024-01-01", end_date="2024-12-31", total_return=0.211, sharpe_ratio=1.31, max_drawdown=0.068, num_trades=12, status="complete"),
    BacktestRun(id="bt-3", strategy="RL Agent (PPO, AlphaGo-inspired)", symbol="BTC-USD", start_date="2024-06-01", end_date="2024-12-31", total_return=0.187, sharpe_ratio=0.97, max_drawdown=0.143, num_trades=291, status="complete"),
    BacktestRun(id="bt-4", strategy="On-chain Anomaly + Mean Reversion", symbol="ETH-USD", start_date="2025-01-01", end_date="2025-04-30", total_return=0.063, sharpe_ratio=1.12, max_drawdown=0.041, num_trades=58, status="running"),
]


class DirectionalChangeRequest(BaseModel):
    prices: list[float]
    threshold: float = 0.01


class MarkowitzRequest(BaseModel):
    expected_returns: list[float]
    covariance_matrix: list[list[float]]
    risk_aversion: float = 1.0


@app.get("/health")
def health():
    return {"service": "ai-research-service", "ok": True}


@app.post("/signal", response_model=Signal)
def signal(req: SignalRequest):
    """MA-crossover + Directional Change confirmation signal (Chapter 6 pattern)."""
    ma_fast = float(req.features.get("ma_fast", 0))
    ma_slow = float(req.features.get("ma_slow", 0))
    dc_up = float(req.features.get("dc_up", 0))
    dc_down = float(req.features.get("dc_down", 0))

    if ma_fast > ma_slow and dc_up > 0:
        action, confidence = "buy", min(0.5 + (ma_fast - ma_slow) / max(ma_slow, 1) * 5 + dc_up * 0.1, 0.95)
    elif ma_fast < ma_slow and dc_down > 0:
        action, confidence = "sell", min(0.5 + (ma_slow - ma_fast) / max(ma_fast, 1) * 5 + dc_down * 0.1, 0.95)
    elif ma_fast > ma_slow:
        action, confidence = "buy", 0.52
    elif ma_fast < ma_slow:
        action, confidence = "sell", 0.52
    else:
        action, confidence = "hold", 0.50

    return Signal(
        symbol=req.symbol,
        action=action,
        confidence=round(confidence, 3),
        engine="baseline_ma_dc",
        explanation="MA-crossover trend logic confirmed by Directional Change event direction.",
    )


@app.post("/directional-change")
def directional_change_endpoint(payload: DirectionalChangeRequest):
    return {"events": directional_change(payload.prices, threshold=payload.threshold)}


@app.post("/markowitz")
def markowitz_endpoint(payload: MarkowitzRequest):
    return {
        "weights": markowitz_weights(
            payload.expected_returns,
            payload.covariance_matrix,
            risk_aversion=payload.risk_aversion,
        )
    }


@app.post("/rl/step")
def rl_step(action: int = 1):
    state, reward, terminated, truncated, info = env.step(action)
    return {
        "state": state.tolist(),
        "reward": reward,
        "terminated": terminated,
        "truncated": truncated,
        "info": info,
    }


@app.get("/backtests", response_model=list[BacktestRun])
def backtests():
    return _BACKTESTS

from __future__ import annotations

import numpy as np
import gymnasium as gym
from gymnasium import spaces


def directional_change(prices, threshold=0.01):
    if not prices:
        return []
    events = []
    last_extreme = prices[0]
    direction = None
    for i, price in enumerate(prices[1:], start=1):
        if direction in (None, "down") and price >= last_extreme * (1 + threshold):
            direction = "up"
            last_extreme = price
            events.append({"index": i, "type": "upturn", "price": price})
        elif direction in (None, "up") and price <= last_extreme * (1 - threshold):
            direction = "down"
            last_extreme = price
            events.append({"index": i, "type": "downturn", "price": price})
        else:
            if direction == "up" and price > last_extreme:
                last_extreme = price
            elif direction == "down" and price < last_extreme:
                last_extreme = price
    return events


def markowitz_weights(expected_returns, cov_matrix, risk_aversion=1.0):
    mu = np.array(expected_returns)
    cov = np.array(cov_matrix)
    inv = np.linalg.pinv(cov)
    raw = inv @ mu / max(risk_aversion, 1e-6)
    weights = np.maximum(raw, 0)
    total = weights.sum()
    return (weights / total).tolist() if total > 0 else [1.0 / len(mu)] * len(mu)


class TradingEnv(gym.Env):
    metadata = {"render_modes": []}

    def __init__(self):
        self.observation_space = spaces.Box(low=-np.inf, high=np.inf, shape=(8,), dtype=np.float32)
        self.action_space = spaces.Discrete(3)
        self.state = np.zeros(8, dtype=np.float32)

    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        self.state = np.zeros(8, dtype=np.float32)
        return self.state, {}

    def step(self, action):
        reward = float(np.random.normal(0, 0.01))
        terminated = False
        truncated = False
        info = {"risk_penalty": 0.0, "action": int(action)}
        return self.state, reward, terminated, truncated, info

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, Integer, String, Text

from database import Base


def _utc() -> datetime:
    return datetime.now(timezone.utc)


class OrderRecord(Base):
    __tablename__ = "orders"

    id = Column(String, primary_key=True)
    broker = Column(String, nullable=False)
    symbol = Column(String, nullable=False)
    side = Column(String, nullable=False)
    quantity = Column(Float, nullable=False)
    order_type = Column(String, default="market")
    mode = Column(String, nullable=False)
    status = Column(String, nullable=False)
    filled_price = Column(Float, nullable=True)
    submitted_at = Column(DateTime(timezone=True), default=_utc)
    message = Column(Text, default="")


class SignalRecord(Base):
    __tablename__ = "signals"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol = Column(String, nullable=False)
    action = Column(String, nullable=False)
    confidence = Column(Float, nullable=False)
    engine = Column(String, nullable=False)
    mode = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=_utc)

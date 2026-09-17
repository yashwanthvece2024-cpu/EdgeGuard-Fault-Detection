from typing import Literal
from pydantic import BaseModel, Field

FaultType = Literal[
    "healthy",
    "bearing_fault",
    "imbalance",
    "misalignment",
    "electrical_fault",
    "overheating",
    "unknown",
]

class Telemetry(BaseModel):
    timestamp: float
    rms_accel_g: float
    current_a: float
    temperature_c: float
    rpm: float = 0.0
    voltage_v: float = 12.0
    sample_rate_hz: float = 1000.0
    source: Literal["simulator", "serial"] = "simulator"

class FaultEvidence(BaseModel):
    vibration_score: float = 0.0
    electrical_score: float = 0.0
    thermal_score: float = 0.0
    cnn_score: float = 0.0
    ood_score: float = 0.0

class Diagnosis(BaseModel):
    fault: FaultType
    confidence: float = Field(ge=0.0, le=1.0)
    severity: Literal["normal", "warning", "critical"]
    affected_component: str
    evidence: FaultEvidence
    recommended_action: str
    rag_sources: list[str] = Field(default_factory=list)
    decision_status: Literal["confident", "uncertain", "out_of_distribution"] = "confident"

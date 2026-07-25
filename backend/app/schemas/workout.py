from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Dict, Any

class WorkoutSessionCreate(BaseModel):
    user_id: int | None = None
    session_name: Optional[str] = None
    workout_type: str = "squat"
    started_at: datetime
    ended_at: datetime
    duration_seconds: int
    target_angle_threshold: Optional[float] = None
    camera: Optional[str] = None
    min_knee_angle: float
    avg_knee_angle: float
    min_hip_angle: float
    avg_hip_angle: float
    total_reps: int
    fault_summary_json: Optional[Dict[str, Any]] = None


class WorkoutSessionResponse(BaseModel):
    id: int
    user_id: int
    session_name: Optional[str] = None
    workout_type: str
    started_at: datetime
    ended_at: datetime
    duration_seconds: int
    target_angle_threshold: Optional[float]
    camera: Optional[str]
    min_knee_angle: float
    avg_knee_angle: float
    min_hip_angle: float
    avg_hip_angle: float
    total_reps: int
    fault_summary_json: Optional[Dict[str, Any]]

    class Config:
        from_attributes = True
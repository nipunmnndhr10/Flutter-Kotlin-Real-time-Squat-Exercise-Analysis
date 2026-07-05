from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.workout import WorkoutSession
from app.schemas.workout import WorkoutSessionCreate, WorkoutSessionResponse

router = APIRouter(prefix="/workouts", tags=["Workouts"])


@router.post("/", response_model=WorkoutSessionResponse)
def save_session_summary(session: WorkoutSessionCreate, db: Session = Depends(get_db)):
    
    new_session = WorkoutSession(
        workout_type=session.workout_type,
        started_at=session.started_at,
        ended_at=session.ended_at,
        duration_seconds=session.duration_seconds,
        target_angle_threshold=session.target_angle_threshold,
        camera=session.camera,
        min_knee_angle=session.min_knee_angle,
        avg_knee_angle=session.avg_knee_angle,
        min_hip_angle=session.min_hip_angle,
        avg_hip_angle=session.avg_hip_angle,
        total_reps=session.total_reps,
        fault_summary_json=session.fault_summary_json,
        user_id=1   # TODO: Connect with real logged-in user later
    )

    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    
    return new_session
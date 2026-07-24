from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.workout import WorkoutSession
from app.schemas.workout import WorkoutSessionCreate, WorkoutSessionResponse
from app.core.security import get_current_user
from app.models.user import User

router = APIRouter(prefix="/workouts", tags=["Workouts"])


@router.get("/", response_model=list[WorkoutSessionResponse])
def get_user_workouts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Fetch all workout sessions for the authenticated user."""
    return (
        db.query(WorkoutSession)
        .filter(WorkoutSession.user_id == current_user.id)
        .order_by(WorkoutSession.created_at.desc())
        .all()
    )


@router.post("/", response_model=WorkoutSessionResponse)
def save_session_summary(
    session: WorkoutSessionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    new_session = WorkoutSession(
        user_id=current_user.id,
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
        form_score=session.form_score,
        fault_summary_json=session.fault_summary_json,
    )

    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    
    return new_session


@router.delete("/{session_id}")
def delete_workout_session(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete a specific workout session for the authenticated user."""
    session = (
        db.query(WorkoutSession)
        .filter(WorkoutSession.id == session_id, WorkoutSession.user_id == current_user.id)
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Workout session not found")
    
    db.delete(session)
    db.commit()
    return {"detail": "Workout session deleted successfully"}
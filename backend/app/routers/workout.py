from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.workout import WorkoutSession
from app.schemas.workout import WorkoutSessionCreate, WorkoutSessionResponse
from app.core.security import get_current_user
from app.models.user import User

from app.models.notification import Notification

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
        session_name=session.session_name,
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
    )

    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    # Automatically trigger in-app notification for recorded session
    notif = Notification(
        user_id=current_user.id,
        title="Workout Recorded!",
        body=f"Great set! You completed {session.total_reps} reps in {session.duration_seconds}s.",
        notification_type="workout",
        is_read=False,
    )
    db.add(notif)
    db.commit()

    return new_session


@router.delete("/{workout_id}")
def delete_workout_session(
    workout_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(WorkoutSession).filter(
        WorkoutSession.id == workout_id,
        WorkoutSession.user_id == current_user.id
    ).first()

    if not session:
        raise HTTPException(status_code=404, detail="Workout session not found")

    db.delete(session)
    db.commit()

    return {"message": "Workout session deleted successfully"}

class WorkoutSessionRename(BaseModel):
    session_name: str

@router.patch("/{workout_id}/name", response_model=WorkoutSessionResponse)
def rename_workout_session(
    workout_id: int,
    rename_data: WorkoutSessionRename,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(WorkoutSession).filter(
        WorkoutSession.id == workout_id,
        WorkoutSession.user_id == current_user.id
    ).first()

    if not session:
        raise HTTPException(status_code=404, detail="Workout session not found")

    session.session_name = rename_data.session_name
    db.commit()
    db.refresh(session)
    
    return session
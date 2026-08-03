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


def calculate_form_score(reps: int, fault_json: dict | None) -> int | None:
    if not reps or reps <= 0:
        return None
    if not fault_json:
        return 100
    weights = {
        'knee_valgus': 2.5, 'knee_cave': 2.5, 'left_knee_cave': 2.5, 'right_knee_cave': 2.5,
        'chest_up': 2.2, 'lean_forward': 2.2, 'go_deeper': 1.5, 'shallow_depth': 1.5, 'too_low': 1.0,
    }
    pts = 0.0
    for k, v in fault_json.items():
        if isinstance(v, (int, float)) and v > 0:
            w = weights.get(str(k).lower(), 1.5)
            eff = v * 0.5 if v <= 2 else float(v)
            pts += eff * w
    penalty = (pts / reps) * 15
    return max(0, min(100, round(100 - penalty)))


@router.post("/", response_model=WorkoutSessionResponse)
def save_session_summary(
    session: WorkoutSessionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if session.total_reps and session.total_reps > 0:
        computed_score = calculate_form_score(session.total_reps, session.fault_summary_json)
        final_score = session.form_score if session.form_score is not None else computed_score
    else:
        final_score = None

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
        form_score=final_score,
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
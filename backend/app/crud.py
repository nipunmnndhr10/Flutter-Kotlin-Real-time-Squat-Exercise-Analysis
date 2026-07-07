from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from app import models, schemas, auth
from typing import List, Optional

# User CRUD
def get_user_by_email(db: Session, email: str) -> Optional[models.User]:
    return db.query(models.User).filter(models.User.email == email).first()

def get_user_by_id(db: Session, user_id: int) -> Optional[models.User]:
    return db.query(models.User).filter(models.User.user_id == user_id).first()

def create_user(db: Session, user: schemas.UserCreate) -> models.User:
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(
        name=user.name,
        email=user.email,
        password_hash=hashed_password
    )
    db.add(db_user)
    try:
        db.commit()
        db.refresh(db_user)
        return db_user
    except IntegrityError:
        db.rollback()
        raise ValueError("Email already registered")

# Workout CRUD
def create_workout(db: Session, workout: schemas.WorkoutCreate) -> models.WorkoutSession:
    user = get_user_by_id(db, workout.user_id)
    if not user:
        raise ValueError(f"User with id {workout.user_id} not found")
    
    db_workout = models.WorkoutSession(
        user_id=workout.user_id,
        squat_type=workout.squat_type,
        total_reps=workout.total_reps,
        form_score=workout.form_score,
        faults=workout.faults  # NEW: Save faults
    )
    db.add(db_workout)
    db.commit()
    db.refresh(db_workout)
    return db_workout

def get_user_workouts(db: Session, user_id: int, limit: int = 100) -> List[models.WorkoutSession]:
    return db.query(models.WorkoutSession)\
        .filter(models.WorkoutSession.user_id == user_id)\
        .order_by(models.WorkoutSession.created_at.desc())\
        .limit(limit)\
        .all()

def get_workout_by_id(db: Session, session_id: int) -> Optional[models.WorkoutSession]:
    return db.query(models.WorkoutSession)\
        .filter(models.WorkoutSession.session_id == session_id)\
        .first()
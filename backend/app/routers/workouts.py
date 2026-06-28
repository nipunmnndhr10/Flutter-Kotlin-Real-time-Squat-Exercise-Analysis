from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from app import schemas, crud
from app.database import get_db

router = APIRouter(prefix="/api/workout", tags=["Workouts"])

@router.post("/save", response_model=schemas.WorkoutResponse)
def save_workout(workout: schemas.WorkoutCreate, db: Session = Depends(get_db)):
    try:
        db_workout = crud.create_workout(db, workout)
        return db_workout
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": str(e)}
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": f"Failed to save workout: {str(e)}"}
        )

@router.get("/history/{user_id}", response_model=List[schemas.WorkoutResponse])
def get_workout_history(user_id: int, db: Session = Depends(get_db)):
    user = crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": f"User with id {user_id} not found"}
        )
    
    workouts = crud.get_user_workouts(db, user_id)
    return workouts

@router.get("/history/{user_id}/stats", response_model=Dict[str, Any])
def get_workout_stats(user_id: int, db: Session = Depends(get_db)):
    workouts = crud.get_user_workouts(db, user_id)
    
    if not workouts:
        return {
            "total_workouts": 0,
            "total_reps": 0,
            "average_form_score": None,
            "most_common_squat_type": None
        }
    
    total_workouts = len(workouts)
    total_reps = sum(w.total_reps for w in workouts)
    
    form_scores = [w.form_score for w in workouts if w.form_score is not None]
    avg_form_score = sum(form_scores) / len(form_scores) if form_scores else None
    
    squat_types = {}
    for w in workouts:
        squat_types[w.squat_type] = squat_types.get(w.squat_type, 0) + 1
    most_common = max(squat_types, key=squat_types.get) if squat_types else None
    
    return {
        "total_workouts": total_workouts,
        "total_reps": total_reps,
        "average_form_score": avg_form_score,
        "most_common_squat_type": most_common
    }
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

# Auth Schemas
class UserCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=8)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class LoginResponse(BaseModel):
    user_id: int
    name: str
    email: str
    token: str

# Workout Schemas
class WorkoutCreate(BaseModel):
    user_id: int
    squat_type: str = Field(..., min_length=1, max_length=50)
    total_reps: int = Field(..., ge=1)
    form_score: Optional[float] = Field(None, ge=0, le=100)

class WorkoutResponse(BaseModel):
    session_id: int
    user_id: int
    squat_type: str
    total_reps: int
    form_score: Optional[float]
    created_at: datetime
    
    class Config:
        from_attributes = True
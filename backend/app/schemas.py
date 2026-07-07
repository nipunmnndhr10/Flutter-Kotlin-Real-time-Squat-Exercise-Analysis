from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional, Dict

# ============================================================================
# AUTHENTICATION SCHEMAS
# ============================================================================

# Schema for user registration (signup)
class UserCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)      # Full name, 2-50 characters
    email: EmailStr                                          # Valid email format
    password: str = Field(..., min_length=8)                # Password, minimum 8 characters

# Schema for user login
class UserLogin(BaseModel):
    email: EmailStr                                          # User email for login
    password: str                                            # User password

# Schema for login response (returns user data + JWT token)
class LoginResponse(BaseModel):
    user_id: int                                             # Unique user identifier
    name: str                                                # User's full name
    email: str                                               # User's email
    token: str                                               # JWT authentication token

# ============================================================================
# WORKOUT SCHEMAS
# ============================================================================

# Schema for creating/saving a new workout
class WorkoutCreate(BaseModel):
    user_id: int = Field(..., description="ID of the user performing the workout")       # User ID
    squat_type: str = Field(..., min_length=1, max_length=50, description="Type of squat")  # Squat type
    total_reps: int = Field(..., ge=1, description="Total number of reps completed")      # Total reps, must be >= 1
    form_score: Optional[float] = Field(None, ge=0, le=100, description="Form score 0-100")   # Form score (optional)
    
    # New field: faults - dictionary of fault types and their occurrence counts
    faults: Optional[Dict[str, int]] = Field(
        None, 
        description="Fault types and their counts e.g. {'LEAN_FORWARD': 3, 'TOO_LOW': 2}"
    )

# Schema for workout response (retrieving workout data)
class WorkoutResponse(BaseModel):
    session_id: int                                          # Unique workout session ID
    user_id: int                                             # User ID who performed the workout
    squat_type: str                                          # Type of squat performed
    total_reps: int                                          # Total reps completed
    form_score: Optional[float]                              # Form score (0-100), optional
    faults: Optional[Dict[str, int]] = None                 # Fault counts dictionary
    created_at: datetime                                     # Timestamp when workout was saved
    
    class Config:
        from_attributes = True                               # Allows conversion from SQLAlchemy models
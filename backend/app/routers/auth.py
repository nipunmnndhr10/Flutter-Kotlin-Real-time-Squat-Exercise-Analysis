from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Dict, Any
from app import schemas, crud, auth
from app.database import get_db

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.post("/signup", response_model=Dict[str, Any])
def signup(user: schemas.UserCreate, db: Session = Depends(get_db)):
    try:
        db_user = crud.create_user(db, user)
        return {
            "message": "User registered successfully",
            "userId": db_user.user_id,
            "name": db_user.name,
            "email": db_user.email
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": str(e)}
        )

@router.post("/login", response_model=schemas.LoginResponse)
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, user.email)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "Invalid email or password"}
        )
    
    if not auth.verify_password(user.password, db_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "Invalid email or password"}
        )
    
    token_data = {"sub": str(db_user.user_id), "email": db_user.email}
    token = auth.create_access_token(token_data)
    
    return schemas.LoginResponse(
        user_id=db_user.user_id,
        name=db_user.name,
        email=db_user.email,
        token=token
    )
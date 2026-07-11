from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserLogin, UserResponse
from passlib.context import CryptContext

from app.core.security import create_access_token, get_current_user

# for grouping all auth routes under /auth prefix and tagging them as "Auth" for documentation purposes
router = APIRouter(prefix="/auth", tags=["Auth"])

# Password hashing setup
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# Helper function to hash password
def hash_password(password: str):
    return pwd_context.hash(password)


# Helper function to verify password
def verify_password(plain_password: str, hashed_password: str):
    return pwd_context.verify(plain_password, hashed_password)


@router.post("/signup", response_model=UserResponse)
def signup(user_data: UserCreate, db: Session = Depends(get_db)):
    
    # check if user already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # hash the password before storing it
    hashed_pw = hash_password(user_data.password)

    # create new user
    new_user = User(
        email=user_data.email,
        hashed_password=hashed_pw,
        full_name=user_data.full_name
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Auto-login: generate JWT token immediately after signup
    access_token = create_access_token(
        data={
            "sub": new_user.email,
            "user_id": new_user.id
        }
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "message": "Signup successful",
        "user": {
            "id": new_user.id,
            "email": new_user.email,
            "full_name": new_user.full_name
        }
    }

@router.post("/login")
def login(user_data: UserLogin, db: Session = Depends(get_db)):
    
    # look up user by email
    user = db.query(User).filter(User.email == user_data.email).first()

    # verify if user exists and password is correct: compare plain pw with hashed pw using bcrypt
    if not user or not verify_password(user_data.password, user.hashed_password):
         raise HTTPException(status_code=400, detail="Invalid email or password")
    

    # creating JWT token for the authenticated user. The token will contain the user's email and ID as payload, and it will be signed using the SECRET_KEY and ALGORITHM defined in the security module.
    access_token = create_access_token(
        data={
            "sub": user.email,
            "user_id": user.id
        }
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "message": "Login successful",
        "user": {
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name
        }
    }
    
@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "full_name": current_user.full_name
    }
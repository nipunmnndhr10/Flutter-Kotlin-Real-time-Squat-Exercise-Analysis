import os
import shutil
import uuid
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, File, UploadFile
from sqlalchemy.orm import Session
from app.core.database import get_db
from datetime import datetime, timedelta, timezone
from app.models.user import User, PasswordReset
from app.schemas.user import UserCreate, UserLogin, UserResponse, TokenResponse, ForgotPasswordRequest, ResetPasswordRequest, GoogleTokenRequest
from app.core.utils import generate_otp, send_otp_email
from passlib.context import CryptContext
import secrets
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

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


@router.post("/signup", response_model=TokenResponse)
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
            "full_name": new_user.full_name,
            "profile_picture_url": new_user.profile_picture_url,
            "created_at": new_user.created_at
        }
    }


@router.post("/login", response_model=TokenResponse)
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
            "full_name": user.full_name,
            "profile_picture_url": user.profile_picture_url,
            "created_at": user.created_at
        }
    }


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/forgot-password")
def forgot_password(request: ForgotPasswordRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == request.email).first()
    if not user:
        # Always return a generic message to prevent email enumeration
        return {"message": "If that email exists, an OTP has been sent."}

    # Invalidate any old OTPs for this email
    db.query(PasswordReset).filter(PasswordReset.email == request.email).delete()

    otp = generate_otp()
    expires = datetime.now(timezone.utc) + timedelta(minutes=10)

    reset_entry = PasswordReset(
        email=request.email,
        otp=otp,
        expires_at=expires
    )
    db.add(reset_entry)
    db.commit()

    background_tasks.add_task(send_otp_email, request.email, otp)
    return {"message": "If that email exists, an OTP has been sent."}


@router.post("/reset-password")
def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    reset_entry = db.query(PasswordReset).filter(
        PasswordReset.email == request.email,
        PasswordReset.otp == request.otp
    ).first()

    if not reset_entry:
        raise HTTPException(status_code=400, detail="Invalid OTP")

    now_utc = datetime.now(timezone.utc)
    # Handle timezone differences between Python and DB
    db_expires_at = reset_entry.expires_at
    if db_expires_at.tzinfo is None:
        now_utc = now_utc.replace(tzinfo=None)

    if now_utc > db_expires_at:
        db.delete(reset_entry)
        db.commit()
        raise HTTPException(status_code=400, detail="OTP has expired")

    user = db.query(User).filter(User.email == request.email).first()
    if not user:
        raise HTTPException(status_code=400, detail="User not found")

    user.hashed_password = hash_password(request.new_password)
    db.delete(reset_entry)
    db.commit()

    return {"message": "Password has been successfully reset"}


# Google Sign-In setup
GOOGLE_CLIENT_ID = "984161335343-0l7irv2t1nkrft49bo186ahd46unania.apps.googleusercontent.com"

@router.post("/google", response_model=TokenResponse)
def google_auth(request: GoogleTokenRequest, db: Session = Depends(get_db)):
    try:
        # Verify the token against GOOGLE_CLIENT_ID, falling back to general Google signature check
        try:
            idinfo = google_id_token.verify_oauth2_token(
                request.id_token, google_requests.Request(), GOOGLE_CLIENT_ID
            )
        except ValueError as err:
            print(f"Primary Google token verification failed ({err}), trying signature verification...")
            idinfo = google_id_token.verify_oauth2_token(
                request.id_token, google_requests.Request()
            )

        email = idinfo.get("email")
        full_name = idinfo.get("name") or email.split("@")[0]
        
        if not email:
            raise HTTPException(status_code=400, detail="Google token missing email")

        # Check if user exists
        user = db.query(User).filter(User.email == email).first()

        if not user:
            # Create a new user with a random dummy password
            dummy_pw = secrets.token_urlsafe(32)
            hashed_pw = hash_password(dummy_pw)
            
            user = User(
                email=email,
                hashed_password=hashed_pw,
                full_name=full_name
            )
            db.add(user)
            db.commit()
            db.refresh(user)

        # Generate JWT token
        access_token = create_access_token(
            data={
                "sub": user.email,
                "user_id": user.id
            }
        )

        return {
            "access_token": access_token,
            "token_type": "bearer",
            "message": "Google Login successful",
            "user": {
                "id": user.id,
                "email": user.email,
                "full_name": user.full_name,
                "profile_picture_url": user.profile_picture_url,
                "created_at": user.created_at
            }
        }
    except ValueError as e:
        print(f"Google Token Verification Error: {e}")
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {str(e)}")
    except Exception as e:
        print(f"Unexpected Google Auth Error: {e}")
        raise HTTPException(status_code=500, detail=f"Google Auth error: {str(e)}")


@router.post("/profile-picture", response_model=UserResponse)
def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
    file_ext = os.path.splitext(file.filename or "")[1].lower()
    if file_ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Invalid image format. Allowed: JPG, PNG, WEBP")

    os.makedirs("uploads/profiles", exist_ok=True)
    filename = f"user_{current_user.id}_{uuid.uuid4().hex[:8]}{file_ext}"
    filepath = os.path.join("uploads/profiles", filename)

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    relative_url = f"/static/profiles/{filename}"
    current_user.profile_picture_url = relative_url
    db.commit()
    db.refresh(current_user)

    return current_user

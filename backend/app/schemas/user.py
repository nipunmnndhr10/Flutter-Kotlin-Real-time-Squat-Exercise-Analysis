from pydantic import BaseModel, EmailStr

# For Signup request
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None

# For Login request
class UserLogin(BaseModel):
    email: EmailStr
    password: str

# User object inside auth responses
class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str | None = None

    class Config:
        from_attributes = True

# Auth response: login and signup both return token + user
class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    message: str
    user: UserResponse

# For Forgot Password request
class ForgotPasswordRequest(BaseModel):
    email: EmailStr

# For Reset Password request
class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str
    new_password: str

# For Google Sign-In request
class GoogleTokenRequest(BaseModel):
    id_token: str

from pydantic import BaseModel, EmailStr

# For Signup
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None

# For Login
class UserLogin(BaseModel):
    email: EmailStr
    password: str

# Simple response
class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str | None

    class Config:
        from_attributes = True
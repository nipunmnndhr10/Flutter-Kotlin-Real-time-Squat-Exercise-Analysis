from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from app.database import engine, Base  # ← Removed get_db (not needed here)
from app.routers import auth, workouts
import os
from dotenv import load_dotenv

load_dotenv()

# Create database tables (synchronous)
Base.metadata.create_all(bind=engine)
print("✅ Database tables created successfully!")

app = FastAPI(
    title="Squat App API",
    description="API for squat form correction mobile app",
    version="1.0.0"
)

# CORS Configuration
allowed_origins = [origin.strip() for origin in os.getenv("ALLOWED_ORIGINS", "").split(",") if origin.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins or ["http://localhost:3000", "http://localhost:8080", "http://10.0.2.2:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Exception handler
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    errors = {}
    for error in exc.errors():
        field = error.get("loc", [])[-1] if error.get("loc") else "unknown"
        errors[field] = error.get("msg", "Invalid input")
    return JSONResponse(status_code=400, content={"errors": errors})

# Root endpoints
@app.get("/")
async def root():
    return {"message": "Squat App API is running", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

# Include routers
app.include_router(auth.router)
app.include_router(workouts.router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )
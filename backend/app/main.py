from app.core.database import Base, engine
from app.routers import workout, auth
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Capstone Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(workout.router)

@app.get("/")
async def root():
   return {"message":"Fast API is running!"}



import os
from app.core.database import Base, engine
from app.routers import workout, auth, notification
from app.models.user import User
from app.models.workout import WorkoutSession
from app.models.notification import Notification
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqladmin import Admin, ModelView

# Ensure uploads directory exists
os.makedirs("uploads/profiles", exist_ok=True)

# Create database tables automatically from SQLAlchemy models
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Capstone Backend")

# Setup Web Admin Portal at /admin
admin = Admin(app, engine, title="SquatMate Admin Portal")

class UserAdmin(ModelView, model=User):
    column_list = [User.id, User.email, User.full_name, User.created_at, User.is_active]
    column_searchable_list = [User.email, User.full_name]
    icon = "fa-solid fa-user"

class WorkoutAdmin(ModelView, model=WorkoutSession):
    column_list = [WorkoutSession.id, WorkoutSession.user_id, WorkoutSession.total_reps, WorkoutSession.duration_seconds, WorkoutSession.created_at]
    icon = "fa-solid fa-person-running"

class NotificationAdmin(ModelView, model=Notification):
    column_list = [Notification.id, Notification.user_id, Notification.title, Notification.is_read, Notification.created_at]
    icon = "fa-solid fa-bell"

admin.add_view(UserAdmin)
admin.add_view(WorkoutAdmin)
admin.add_view(NotificationAdmin)

# Serve uploaded static files
app.mount("/static", StaticFiles(directory="uploads"), name="static")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(workout.router)
app.include_router(notification.router)

@app.get("/")
async def root():
   return {"message":"Fast API is running!"}

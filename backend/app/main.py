import os
from typing import Any
from app.core.database import Base, engine
from app.routers import workout, auth, notification
from app.models.user import User
from app.models.workout import WorkoutSession
from app.models.notification import Notification
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqladmin import Admin, ModelView
from sqladmin.authentication import AuthenticationBackend
from starlette.requests import Request
from app.core.security import SECRET_KEY
from app.core.database import Base, engine, SessionLocal
from app.routers.auth import verify_password

# Ensure uploads directory exists
os.makedirs("uploads/profiles", exist_ok=True)

from sqlalchemy import text

# Create database tables automatically from SQLAlchemy models
Base.metadata.create_all(bind=engine)

import json

# Auto-migrate missing columns directly on startup
try:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE workout_sessions ADD COLUMN IF NOT EXISTS form_score INTEGER DEFAULT 100;"))
except Exception as e:
    print(f"Startup schema migration check: {e}")

# Recalculate form_score for existing historical records in database
def recalculate_existing_form_scores():
    try:
        db = SessionLocal()
        sessions = db.query(WorkoutSession).all()
        weights = {
            'knee_valgus': 2.5, 'knee_cave': 2.5, 'left_knee_cave': 2.5, 'right_knee_cave': 2.5,
            'chest_up': 2.2, 'lean_forward': 2.2, 'go_deeper': 1.5, 'shallow_depth': 1.5, 'too_low': 1.0,
        }
        for s in sessions:
            f_json = s.fault_summary_json
            if isinstance(f_json, str):
                try:
                    f_json = json.loads(f_json)
                except Exception:
                    f_json = {}
            reps = s.total_reps or 0
            if reps > 0 and f_json and isinstance(f_json, dict) and any(v > 0 for v in f_json.values() if isinstance(v, (int, float))):
                pts = 0.0
                for k, v in f_json.items():
                    if isinstance(v, (int, float)) and v > 0:
                        w = weights.get(str(k).lower(), 1.5)
                        eff = v * 0.5 if v <= 2 else float(v)
                        pts += eff * w
                penalty = (pts / reps) * 15
                s.form_score = max(0, min(100, round(100 - penalty)))
            else:
                s.form_score = 100
        db.commit()
        db.close()
    except Exception as e:
        print(f"Form score recalculation note: {e}")

recalculate_existing_form_scores()

app = FastAPI(title="Capstone Backend")


class AdminAuth(AuthenticationBackend):
    async def login(self, request: Request) -> bool:
        form = await request.form()
        username = form.get("username")
        password = form.get("password")

        if not username or not password:
            return False

        # Authenticate strictly using environment-configured admin credentials
        admin_user = os.getenv("ADMIN_USERNAME", "admin@squatmate.com")
        admin_pass = os.getenv("ADMIN_PASSWORD", "AdminSecurePassword123!")

        if username == admin_user and password == admin_pass:
            request.session.update({"token": "admin_session_token", "user": username})
            return True

        return False

    async def logout(self, request: Request) -> bool:
        request.session.clear()
        return True

    async def authenticate(self, request: Request) -> bool:
        token = request.session.get("token")
        if not token:
            return False
        return True


authentication_backend = AdminAuth(secret_key=SECRET_KEY)

# Setup Web Admin Portal at /admin with authentication
admin = Admin(app, engine, title="SquatMate Admin Portal", authentication_backend=authentication_backend)


class UserAdmin(ModelView, model=User):
    column_list = [User.id, User.email, User.full_name, User.is_active, User.created_at]
    column_searchable_list = [User.email, User.full_name]
    form_excluded_columns = ["workouts", "notifications", "hashed_password"]
    icon = "fa-solid fa-user"


from sqlalchemy.event import listens_for

@listens_for(WorkoutSession, 'before_insert')
@listens_for(WorkoutSession, 'before_update')
def auto_calculate_workout_form_score(mapper, connection, target):
    weights = {
        'knee_valgus': 2.5, 'knee_cave': 2.5, 'left_knee_cave': 2.5, 'right_knee_cave': 2.5,
        'chest_up': 2.2, 'lean_forward': 2.2, 'go_deeper': 1.5, 'shallow_depth': 1.5, 'too_low': 1.0,
    }
    f_json = target.fault_summary_json
    if isinstance(f_json, str):
        try:
            f_json = json.loads(f_json)
        except Exception:
            f_json = {}
    reps = target.total_reps or 0
    if reps > 0 and f_json and isinstance(f_json, dict) and any(v > 0 for v in f_json.values() if isinstance(v, (int, float))):
        pts = 0.0
        for k, v in f_json.items():
            if isinstance(v, (int, float)) and v > 0:
                w = weights.get(str(k).lower(), 1.5)
                eff = v * 0.5 if v <= 2 else float(v)
                pts += eff * w
        penalty = (pts / reps) * 15
        target.form_score = max(0, min(100, round(100 - penalty)))
    else:
        target.form_score = 100


class WorkoutAdmin(ModelView, model=WorkoutSession):
    column_list = [
        WorkoutSession.id,
        WorkoutSession.user_id,
        WorkoutSession.session_name,
        WorkoutSession.total_reps,
        WorkoutSession.form_score,
        WorkoutSession.duration_seconds,
        WorkoutSession.fault_summary_json,
        WorkoutSession.created_at,
    ]
    column_labels = {
        "fault_summary_json": "Fault Summary",
        "session_name": "Session Name",
        "duration_seconds": "Duration (sec)",
        "total_reps": "Total Reps",
        "form_score": "Form Score (%)",
    }
    column_formatters = {
        WorkoutSession.fault_summary_json: lambda m, a: (
            ", ".join([f"{k.replace('_', ' ').title()}: {v}" for k, v in (m.fault_summary_json or {}).items() if v > 0])
            if (m.fault_summary_json and any(v > 0 for v in (m.fault_summary_json or {}).values()))
            else "Clean Form (No Faults)"
        )
    }
    column_searchable_list = [WorkoutSession.session_name]
    icon = "fa-solid fa-person-running"

    async def on_model_change(self, data: dict, model: Any, is_created: bool, request: Request) -> None:
        reps = data.get("total_reps") or (model.total_reps if model else 0) or 0
        f_json = data.get("fault_summary_json") or (model.fault_summary_json if model else None)
        if isinstance(f_json, str):
            try:
                f_json = json.loads(f_json)
            except Exception:
                f_json = {}
        if reps > 0 and f_json and isinstance(f_json, dict) and any(v > 0 for v in f_json.values() if isinstance(v, (int, float))):
            weights = {
                'knee_valgus': 2.5, 'knee_cave': 2.5, 'left_knee_cave': 2.5, 'right_knee_cave': 2.5,
                'chest_up': 2.2, 'lean_forward': 2.2, 'go_deeper': 1.5, 'shallow_depth': 1.5, 'too_low': 1.0,
            }
            pts = 0.0
            for k, v in f_json.items():
                if isinstance(v, (int, float)) and v > 0:
                    w = weights.get(str(k).lower(), 1.5)
                    eff = v * 0.5 if v <= 2 else float(v)
                    pts += eff * w
            penalty = (pts / reps) * 15
            data["form_score"] = max(0, min(100, round(100 - penalty)))
        else:
            data["form_score"] = 100


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

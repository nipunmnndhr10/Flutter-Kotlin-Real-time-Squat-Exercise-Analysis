import random
from datetime import datetime, timedelta, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.database import SQLALCHEMY_DATABASE_URL
from app.models.workout import WorkoutSession
from app.models.notification import Notification
from app.models.user import User

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"options": "-c timezone=Asia/Kathmandu"}
)
SessionLocal = sessionmaker(bind=engine)

SESSION_NAMES = [
    "Side-View Depth Session",
    "Morning Squat Routine",
    "Strength & Depth Focus",
    "Evening Leg Session",
    "Form & Alignment Test",
    "Hypertrophy Squats",
    "Power Squat Workout",
]

# Real faults detected by SquatMate engine:
FAULT_PRESETS = [
    {},  # Clean form
    {},
    {"go_deeper": 1},
    {"chest_up": 1},
    {"too_low": 1},
    {"go_deeper": 1, "chest_up": 1},
]

def seed_data(user_id: int = 3, target_total_squats: int = 120, days_span: int = 6):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = db.query(User).first()
            if not user:
                print("No user found in database!")
                return
            user_id = user.id

        # 1. Clear existing workout sessions and notifications for this user to get a clean dataset
        print(f"Clearing old sessions and notifications for User ID {user_id}...")
        db.query(WorkoutSession).filter(WorkoutSession.user_id == user_id).delete()
        db.query(Notification).filter(Notification.user_id == user_id).delete()
        db.commit()

        print(f"Seeding {target_total_squats} TOTAL SQUATS across {days_span} days for User ID {user_id}...")

        nepal_tz = timezone(timedelta(hours=5, minutes=45))
        now = datetime.now(nepal_tz)
        start_time = now - timedelta(days=days_span)

        # Distribute 120 squats into ~10 sessions across 6 days (~12 reps per session)
        session_reps_list = [12, 10, 15, 12, 14, 10, 12, 15, 10, 10]  # Sum = 120 squats
        num_sessions = len(session_reps_list)
        interval_seconds = (days_span * 24 * 3600) / num_sessions

        new_sessions = []
        new_notifications = []

        for i, reps in enumerate(session_reps_list):
            session_time = start_time + timedelta(seconds=i * interval_seconds + random.randint(-600, 600))
            duration = random.randint(45, 90)
            ended_time = session_time + timedelta(seconds=duration)

            avg_knee = round(random.uniform(92.0, 108.0), 1)
            min_knee = round(avg_knee - random.uniform(15.0, 22.0), 1)
            avg_hip = round(random.uniform(85.0, 102.0), 1)
            min_hip = round(avg_hip - random.uniform(12.0, 18.0), 1)
            session_name = random.choice(SESSION_NAMES)

            session = WorkoutSession(
                user_id=user_id,
                session_name=session_name,
                started_at=session_time,
                ended_at=ended_time,
                duration_seconds=duration,
                target_angle_threshold=90.0,
                camera="front",  # Front camera (side view alignment)
                min_knee_angle=min_knee,
                avg_knee_angle=avg_knee,
                min_hip_angle=min_hip,
                avg_hip_angle=avg_hip,
                total_reps=reps,
                fault_summary_json=random.choice(FAULT_PRESETS),
                created_at=session_time,
            )
            new_sessions.append(session)

            # Create unread notification for testing
            notification = Notification(
                user_id=user_id,
                title="Workout Recorded!",
                body=f"Session '{session_name}' saved with {reps} reps.",
                notification_type="workout",
                is_read=False,
                created_at=ended_time,
            )
            new_notifications.append(notification)

        db.bulk_save_objects(new_sessions)
        db.bulk_save_objects(new_notifications)
        db.commit()
        print(f"Successfully seeded exactly {sum(session_reps_list)} total squats across {num_sessions} sessions for User ID {user_id}!")

    except Exception as e:
        db.rollback()
        print(f"Error seeding data: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_data(user_id=3, target_total_squats=120, days_span=6)

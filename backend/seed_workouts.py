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
    "High-Volume Squats",
    "Evening Leg Session",
    "Form & Alignment Test",
    "Hypertrophy Squats",
    "Power Squat Workout",
    "Endurance Squat Set",
]

# Real faults detected by SquatMate engine:
# - go_deeper (shallow squat depth)
# - chest_up (excessive forward torso lean)
# - too_low (excessive squat depth)
FAULT_PRESETS = [
    {},  # Perfect Form (Clean - No faults)
    {},
    {},
    {"go_deeper": 1},
    {"go_deeper": 2},
    {"chest_up": 1},
    {"too_low": 1},
    {"go_deeper": 1, "chest_up": 1},
]

def seed_data(user_id: int = 3, count: int = 120, days_span: int = 6):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = db.query(User).first()
            if not user:
                print("No user found in database!")
                return
            user_id = user.id

        print(f"Seeding {count} authentic workout sessions AND notifications for User ID {user_id} across {days_span} days...")

        nepal_tz = timezone(timedelta(hours=5, minutes=45))
        now = datetime.now(nepal_tz)
        start_time = now - timedelta(days=days_span)
        interval_seconds = (days_span * 24 * 3600) / count

        new_sessions = []
        new_notifications = []

        for i in range(count):
            session_time = start_time + timedelta(seconds=i * interval_seconds + random.randint(-300, 300))
            duration = random.randint(45, 180)
            ended_time = session_time + timedelta(seconds=duration)

            reps = random.randint(10, 30)
            avg_knee = round(random.uniform(88.0, 112.0), 1)
            min_knee = round(avg_knee - random.uniform(15.0, 25.0), 1)
            avg_hip = round(random.uniform(82.0, 105.0), 1)
            min_hip = round(avg_hip - random.uniform(12.0, 22.0), 1)
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

            # Create corresponding notification for this workout
            notification = Notification(
                user_id=user_id,
                title="Workout Recorded!",
                body=f"Session '{session_name}' saved with {reps} reps.",
                notification_type="workout",
                is_read=True if i < count - 3 else False,  # Keep last 3 unread
                created_at=ended_time,
            )
            new_notifications.append(notification)

        db.bulk_save_objects(new_sessions)
        db.bulk_save_objects(new_notifications)
        db.commit()
        print(f"Successfully seeded {count} workout sessions AND {count} notifications for User ID {user_id} into database!")

    except Exception as e:
        db.rollback()
        print(f"Error seeding data: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_data(user_id=3, count=120, days_span=6)

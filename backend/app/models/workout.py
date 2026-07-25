from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

class WorkoutSession(Base):
   __tablename__ = "workout_sessions"

   id = Column(Integer, primary_key=True, index=True)
   user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
   session_name = Column(String, nullable=True)
   
   started_at = Column(DateTime(timezone=True), nullable=False)
   ended_at = Column(DateTime(timezone=True), nullable=False)
   duration_seconds = Column(Integer, default=0)
   
   target_angle_threshold = Column(Float, nullable=True)
   camera = Column(String, nullable=True)

   min_knee_angle = Column(Float)
   avg_knee_angle = Column(Float)
   min_hip_angle = Column(Float)
   avg_hip_angle = Column(Float)
   
   total_reps = Column(Integer, default=0)
   fault_summary_json = Column(JSON, nullable=True)       # Store faults as JSON

   created_at = Column(DateTime(timezone=True), server_default=func.now())

   # Relationship with user: An SQL Alchemy relationship that tells SQLAlchemy that a WorkoutSession belongs to a User.
   user = relationship("User", back_populates="workouts")

   def __str__(self):
       return f"Workout #{self.id} ({self.session_name or 'Squat Session'} - {self.total_reps or 0} reps)"

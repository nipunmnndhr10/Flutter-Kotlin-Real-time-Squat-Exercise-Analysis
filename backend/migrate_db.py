import os
from sqlalchemy import text
from app.core.database import engine

def migrate():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE workout_sessions ADD COLUMN session_name VARCHAR;"))
            conn.commit()
            print("Successfully added session_name column to workout_sessions table.")
        except Exception as e:
            if "already exists" in str(e).lower() or "duplicate column name" in str(e).lower():
                print("Column session_name already exists.")
            else:
                print(f"Error: {e}")

if __name__ == "__main__":
    migrate()

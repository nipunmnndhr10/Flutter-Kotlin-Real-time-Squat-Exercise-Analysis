import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from dotenv import load_dotenv

load_dotenv()


# The URL_DATABASE variable contains the connection string that specifies the database type (postgresql), username (nipunmnndhr), password (nipun101), host (localhost), port (5432), and database name (capstone_db) for connecting to the PostgreSQL database.
# URL_DATABASE = 'postgresql://nipunmnndhr:nipun101@localhost:5432/capstone_db'

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")


# connects python app to PostgreSQL database using SQLAlchemy, create_engine is a function that creates a new SQLAlchemy engine instance, which is the starting point for any SQLAlchemy application. It represents the core interface to the database and provides a source of database connections. 
engine = create_engine(SQLALCHEMY_DATABASE_URL)


# session here is a temporary workspace where you talk to the db
# sessionmaker is a factory for creating new Session objects, which are used to interact with the database. The sessionmaker function takes several parameters to configure the behavior of the sessions it creates:
# autocommit=False: This means that changes made in a session will not be automatically committed to the database. You will need to explicitly call session.commit() to save changes.
# autoflush=False: This means that changes made in a session will not be automatically flushed to the database. You will need to explicitly call session.flush() to send changes to the database before they are committed.
# bind=engine: This specifies the database engine that the sessions will use to connect to the database.
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# foundation for all your database tables (models). It provides a base class that your model classes will inherit from. When you define a model class that inherits from Base, SQLAlchemy will automatically create the corresponding database table based on the attributes defined in the model class.
# Without it: SQLAlchemy cannot map Python classes → database tables
Base = declarative_base()


# This function will be used in our routes
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
"""Phase 0 check: can Python reach PostgreSQL using the details in .env?"""
import os

from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, text

load_dotenv()  # copies the values from .env into environment variables

# URL.create builds the connection address safely, even if the password has symbols like @ or #
url = URL.create(
    "postgresql+psycopg",  # database type + driver
    username=os.getenv("PG_USER"),
    password=os.getenv("PG_PASSWORD"),
    host=os.getenv("PG_HOST"),
    port=int(os.getenv("PG_PORT", "5432")),
    database="postgres",  # built-in database; our "olist" one doesn't exist yet
)
engine = create_engine(url)

with engine.connect() as conn:
    print("Connected!", conn.execute(text("SELECT version()")).scalar())

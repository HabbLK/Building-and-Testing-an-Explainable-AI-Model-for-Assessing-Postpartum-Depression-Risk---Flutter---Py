"""
MongoDB access layer for the PPD app backend.

Uses a dedicated database (MONGO_DB_NAME, default "motherwell_ppd") on the
shared cluster given in .env — never touches any other database on that
server. Credentials are read from .env (see .env.example); do not commit
.env to version control.
"""

import os
from pathlib import Path

from dotenv import load_dotenv
from pymongo import ASCENDING, MongoClient

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

MONGO_URI = os.environ["MONGO_URI"]
DB_NAME = os.environ.get("MONGO_DB_NAME", "motherwell_ppd")

_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=8000)
db = _client[DB_NAME]

users = db["users"]
sessions = db["sessions"]
assessments = db["assessments"]

users.create_index([("email", ASCENDING)], unique=True)
assessments.create_index([("user_id", ASCENDING), ("timestamp", ASCENDING)])
sessions.create_index([("token", ASCENDING)], unique=True)


def ping():
    _client.admin.command("ping")
    return True

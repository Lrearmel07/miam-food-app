"""Réglages de l'API, lus dans les variables d'environnement."""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[2]

APP_NAME = os.getenv("APP_NAME", "Miam API")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    f"sqlite:///{BASE_DIR / 'food.db'}",
)

SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-a-changer-en-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_MINUTES = int(os.getenv("ACCESS_TOKEN_MINUTES", "1440"))

SEED_DATA = os.getenv("SEED_DATA", "1") == "1"

CORS_ORIGINS = os.getenv("CORS_ORIGINS", 
    ",".join([
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:8081",
        "http://127.0.0.1:8081",
        "http://localhost:8082",
        "http://127.0.0.1:8082",
        "http://localhost:8083",
        "http://127.0.0.1:8083",]))


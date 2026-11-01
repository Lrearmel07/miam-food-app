"""Point d'entrée de l'API Miam."""

import logging
from contextlib import asynccontextmanager

from fastapi import APIRouter, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.api import admin, auth, catalog, chat, courier, orders, partner, reviews
from app.api import uploads
from app.core.config import APP_NAME, APP_VERSION, CORS_ORIGINS, SEED_DATA
from app.db.migrate import ensure_schema
from app.db.seed import seed_database
from app.db.session import Base, SessionLocal, engine
from app.services.restaurants import backfill_restaurant_locations
from app.services.tracking import backfill_tracking
from fastapi.staticfiles import StaticFiles
from pathlib import Path

logger = logging.getLogger("miam")


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    ensure_schema()
    if SEED_DATA:
        seed_database()
    db = SessionLocal()
    try:
        backfill_restaurant_locations(db)
        backfill_tracking(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title=APP_NAME,
    version=APP_VERSION,
    description="API de livraison de repas : clients, livreurs, partenaires et admin.",
    lifespan=lifespan,
)

origins = [origin.strip() for origin in CORS_ORIGINS.split(",") if origin.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_error_handler(request: Request, exc: SQLAlchemyError):
    logger.exception("Erreur base de données sur %s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Erreur base de données, veuillez réessayer."},
    )


@app.exception_handler(Exception)
async def unhandled_error_handler(request: Request, exc: Exception):
    logger.exception("Erreur inattendue sur %s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Erreur interne du serveur."},
    )


@app.get("/health", tags=["Santé"])
def health():
    return {"status": "ok", "app": APP_NAME, "version": APP_VERSION}


@app.get("/", tags=["Santé"])
def root():
    return {"message": "Bienvenue sur l'API Miam", "docs": "/docs"}


api = APIRouter(prefix="/api/v1")
api.include_router(auth.router)
api.include_router(catalog.router)
api.include_router(orders.router)
api.include_router(courier.router)
api.include_router(partner.router)
api.include_router(admin.router)
api.include_router(chat.router)
api.include_router(reviews.router)
api.include_router(uploads.router)
app.include_router(api)

BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")


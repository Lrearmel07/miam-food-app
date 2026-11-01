"""Migrations légères pour les bases SQLite existantes."""

from sqlalchemy import inspect, text

from app.db.session import engine


def ensure_schema() -> None:
    """Ajoute les colonnes manquantes sans supprimer les données existantes."""
    inspector = inspect(engine)
    if "restaurants" not in inspector.get_table_names():
        return

    existing = {column["name"] for column in inspector.get_columns("restaurants")}
    additions = []
    if "latitude" not in existing:
        additions.append("ADD COLUMN latitude FLOAT")
    if "longitude" not in existing:
        additions.append("ADD COLUMN longitude FLOAT")
    if not additions:
        return

    with engine.begin() as connection:
        for addition in additions:
            connection.execute(text(f"ALTER TABLE restaurants {addition}"))

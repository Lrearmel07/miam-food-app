"""Helpers de localisation pour les restaurants."""

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models import Restaurant
from app.services.geo import restaurant_coordinates


def refresh_restaurant_location(restaurant: Restaurant) -> None:
    latitude, longitude = restaurant_coordinates(
        restaurant.name, restaurant.address
    )
    restaurant.latitude = round(latitude, 6)
    restaurant.longitude = round(longitude, 6)


def backfill_restaurant_locations(db: Session) -> None:
    restaurants = (
        db.query(Restaurant)
        .filter(
            or_(
                Restaurant.latitude.is_(None),
                Restaurant.longitude.is_(None),
            )
        )
        .all()
    )
    for restaurant in restaurants:
        refresh_restaurant_location(restaurant)
    if restaurants:
        db.commit()


def apply_restaurant_payload(restaurant: Restaurant, data: dict) -> None:
    data = dict(data)
    latitude = data.pop("latitude", None)
    longitude = data.pop("longitude", None)
    coordinates_provided = latitude is not None and longitude is not None
    address_changed = (
        "address" in data
        and (data["address"] or "").strip().lower()
        != (restaurant.address or "").strip().lower()
    )

    for field, value in data.items():
        setattr(restaurant, field, value)

    if coordinates_provided:
        restaurant.latitude = round(latitude, 6)
        restaurant.longitude = round(longitude, 6)
    elif (
        address_changed
        or restaurant.latitude is None
        or restaurant.longitude is None
    ):
        refresh_restaurant_location(restaurant)

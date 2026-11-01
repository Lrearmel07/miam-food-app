"""Catalogue public : restaurants, menus, produits et cuisines."""

import json

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session, selectinload

from app.db.session import get_db
from app.models import Product, Restaurant
from app.schemas import ProductRead, RestaurantRead
from app.services.geo import distance_km, restaurant_point
from app.schemas import ImageRead 
from app.models import RestaurantImage, ProductImage  

router = APIRouter(tags=["Catalogue"])


def _origin(
    latitude: float | None, longitude: float | None
) -> tuple[float, float] | None:
    if (latitude is None) != (longitude is None):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Latitude et longitude doivent être fournies ensemble.",
        )
    if latitude is None or longitude is None:
        return None
    return latitude, longitude


def _parse_zones(zones):
    if not zones:
        return []
    if isinstance(zones, list):
        return zones
    if isinstance(zones, str):
        try:
            data = json.loads(zones)
            if isinstance(data, list):
                return data
        except Exception:
            pass
    return []


def _restaurant_read(
    restaurant: Restaurant,
    origin: tuple[float, float] | None,
) -> RestaurantRead:
    latitude, longitude = restaurant_point(restaurant)
    zones = _parse_zones(getattr(restaurant, "delivery_zones", None))
    data = {
        "id": restaurant.id,
        "name": restaurant.name,
        "description": restaurant.description or "",
        "cuisine": restaurant.cuisine or "International",
        "emoji": getattr(restaurant, "emoji", "") or "",
        "image_url": getattr(restaurant, "image_url", None),
        "cover_image_url": getattr(restaurant, "cover_image_url", None),
        "color": restaurant.color or "#FF7A45",
        "rating": float(getattr(restaurant, "rating", 4.5) or 4.5),
        "review_count": int(getattr(restaurant, "review_count", 0) or 0),
        "delivery_fee": float(restaurant.delivery_fee or 0),
        "min_order": float(restaurant.min_order or 0),
        "eta_min": int(restaurant.eta_min or 25),
        "address": restaurant.address or "",
        "latitude": round(latitude, 6),
        "longitude": round(longitude, 6),
        "distance_km": None,
        "is_open": bool(restaurant.is_open),
        "opening_hours": getattr(restaurant, "opening_hours", None),
        "delivery_zones": zones,
        "promo_text": getattr(restaurant, "promo_text", None),
        "promo_badge": getattr(restaurant, "promo_badge", None),
        "owner_id": restaurant.owner_id,
        "product_count": int(getattr(restaurant, "product_count", 0) or 0),
    }
    if origin is not None:
        data["distance_km"] = round(distance_km(origin, (latitude, longitude)), 2)
    try:
        return RestaurantRead.model_validate(data)
    except Exception:
        return RestaurantRead.model_validate(data)


@router.get("/restaurants", response_model=list[RestaurantRead])
def list_restaurants(
    q: str | None = Query(default=None, max_length=80),
    cuisine: str | None = Query(default=None, max_length=60),
    latitude: float | None = Query(default=None, ge=-90, le=90),
    longitude: float | None = Query(default=None, ge=-180, le=180),
    db: Session = Depends(get_db),
):
    query = db.query(Restaurant).options(selectinload(Restaurant.products))
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(Restaurant.name.ilike(like), Restaurant.description.ilike(like))
        )
    if cuisine:
        query = query.filter(Restaurant.cuisine == cuisine)

    origin = _origin(latitude, longitude)
    items = [_restaurant_read(restaurant, origin) for restaurant in query.all()]
    if origin is not None:
        items.sort(
            key=lambda item: (
                item.distance_km or 0.0,
                -item.rating,
                item.name,
            )
        )
    else:
        items.sort(key=lambda item: (-item.rating, item.name))
    return items


@router.get("/restaurants/{restaurant_id}", response_model=RestaurantRead)
def get_restaurant(
    restaurant_id: int,
    latitude: float | None = Query(default=None, ge=-90, le=90),
    longitude: float | None = Query(default=None, ge=-180, le=180),
    db: Session = Depends(get_db),
):
    restaurant = (
        db.query(Restaurant)
        .options(selectinload(Restaurant.products))
        .filter(Restaurant.id == restaurant_id)
        .first()
    )
    if restaurant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant introuvable",
        )
    return _restaurant_read(restaurant, _origin(latitude, longitude))


@router.get("/restaurants/{restaurant_id}/menu", response_model=list[ProductRead])
def get_menu(
    restaurant_id: int,
    include_unavailable: bool = False,
    db: Session = Depends(get_db),
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant introuvable",
        )
    query = db.query(Product).filter(Product.restaurant_id == restaurant_id)
    if not include_unavailable:
        query = query.filter(Product.is_available.is_(True))
    return query.order_by(Product.category, Product.name).all()
@router.get("/restaurants/{restaurant_id}/gallery", response_model=list[ImageRead])
def get_public_restaurant_gallery(
    restaurant_id: int,
    db: Session = Depends(get_db),
):
    return (
        db.query(RestaurantImage)
        .filter(RestaurantImage.restaurant_id == restaurant_id)
        .order_by(RestaurantImage.sort_order, RestaurantImage.id)
        .all()
    )


@router.get("/products", response_model=list[ProductRead])
def list_products(
    restaurant_id: int | None = None,
    q: str | None = Query(default=None, max_length=80),
    db: Session = Depends(get_db),
):
    query = db.query(Product).filter(Product.is_available.is_(True))
    if restaurant_id is not None:
        query = query.filter(Product.restaurant_id == restaurant_id)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(Product.name.ilike(like), Product.description.ilike(like))
        )
    return query.order_by(Product.name).limit(100).all()


@router.get("/cuisines", response_model=list[str])
def list_cuisines(db: Session = Depends(get_db)):
    rows = db.query(Restaurant.cuisine).distinct().order_by(Restaurant.cuisine).all()
    return [row[0] for row in rows]
@router.get("/restaurants/{restaurant_id}/gallery", response_model=list[ImageRead])
def get_public_restaurant_gallery(
    restaurant_id: int,
    db: Session = Depends(get_db),
):
    return (
        db.query(RestaurantImage)
        .filter(RestaurantImage.restaurant_id == restaurant_id)
        .order_by(RestaurantImage.sort_order, RestaurantImage.id)
        .all()
    )


@router.get("/products/{product_id}/gallery", response_model=list[ImageRead])
def get_public_product_gallery(
    product_id: int,
    db: Session = Depends(get_db),
):
    return (
        db.query(ProductImage)
        .filter(ProductImage.product_id == product_id)
        .order_by(ProductImage.sort_order, ProductImage.id)
        .all()
    )

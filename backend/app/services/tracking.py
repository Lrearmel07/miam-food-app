"""Suivi cartographique : coordonnées de démonstration et sérialisation."""

from __future__ import annotations

import math
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models import Order, OrderStatus, OrderTracking, Restaurant
from app.services.geo import (
    delivery_point,
    distance_km,
    point_along,
    restaurant_point,
)
from app.schemas import (
    OrderTrackingRead,
    TrackingCourierRead,
    TrackingPlaceRead,
)


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def ensure_tracking(db: Session, order: Order) -> OrderTracking:
    tracking = (
        db.query(OrderTracking)
        .filter(OrderTracking.order_id == order.id)
        .first()
    )
    if tracking is not None:
        return tracking

    restaurant = order.restaurant or db.get(Restaurant, order.restaurant_id)
    start = restaurant_point(restaurant)
    end = delivery_point(order.address)
    courier_point: tuple[float, float] | None = None
    if order.courier_id is not None:
        if order.status in (
            OrderStatus.shipping.value,
            OrderStatus.delivered.value,
        ):
            courier_point = (
                end
                if order.status == OrderStatus.delivered.value
                else point_along(start, end, 0.35)
            )

    tracking = OrderTracking(
        order_id=order.id,
        restaurant_lat=start[0],
        restaurant_lng=start[1],
        delivery_lat=end[0],
        delivery_lng=end[1],
        courier_lat=courier_point[0] if courier_point else None,
        courier_lng=courier_point[1] if courier_point else None,
        courier_updated_at=_now() if courier_point else None,
    )
    db.add(tracking)
    db.flush()
    return tracking


def update_courier_location(
    db: Session,
    order: Order,
    latitude: float,
    longitude: float,
) -> OrderTracking:
    tracking = ensure_tracking(db, order)
    tracking.courier_lat = latitude
    tracking.courier_lng = longitude
    tracking.courier_updated_at = _now()
    db.commit()
    db.refresh(tracking)
    return tracking


def backfill_tracking(db: Session) -> None:
    existing = {row[0] for row in db.query(OrderTracking.order_id).all()}
    orders = db.query(Order).all()
    changed = False
    for order in orders:
        if order.id in existing:
            continue
        ensure_tracking(db, order)
        changed = True
    if changed:
        db.commit()


def build_tracking_read(
    db: Session,
    order: Order,
) -> OrderTrackingRead:
    tracking = ensure_tracking(db, order)
    db.commit()
    db.refresh(tracking)

    restaurant = order.restaurant or db.get(Restaurant, order.restaurant_id)
    restaurant_place = TrackingPlaceRead(
        name=restaurant.name,
        address=restaurant.address,
        latitude=tracking.restaurant_lat,
        longitude=tracking.restaurant_lng,
    )
    delivery_place = TrackingPlaceRead(
        name="Adresse de livraison",
        address=order.address,
        latitude=tracking.delivery_lat,
        longitude=tracking.delivery_lng,
    )

    courier = None
    if order.courier is not None:
        courier = TrackingCourierRead(
            id=order.courier.id,
            full_name=order.courier.full_name,
            phone=order.courier.phone,
            latitude=tracking.courier_lat,
            longitude=tracking.courier_lng,
            updated_at=tracking.courier_updated_at,
        )

    destination = (tracking.delivery_lat, tracking.delivery_lng)
    if tracking.courier_lat is not None and tracking.courier_lng is not None:
        origin = (tracking.courier_lat, tracking.courier_lng)
    else:
        origin = (tracking.restaurant_lat, tracking.restaurant_lng)

    if order.status in (OrderStatus.delivered.value, OrderStatus.cancelled.value):
        remaining = 0.0
    else:
        remaining = distance_km(origin, destination)

    eta = 0 if remaining == 0 else max(1, math.ceil(remaining / 0.3))
    return OrderTrackingRead(
        order_id=order.id,
        status=OrderStatus(order.status),
        restaurant=restaurant_place,
        delivery=delivery_place,
        courier=courier,
        distance_remaining_km=round(remaining, 2),
        eta_minutes=eta,
        updated_at=tracking.updated_at or tracking.courier_updated_at or _now(),
    )

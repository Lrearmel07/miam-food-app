"""Espace livreur : courses disponibles, acceptation, livraison, statistiques."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.orders import _get_order, _with_relations
from app.core.deps import require_courier
from app.db.session import get_db
from app.models import Order, OrderStatus, User
from app.schemas import OrderRead, OrderTrackingRead, TrackingLocationIn
from app.services.tracking import (
    build_tracking_read,
    ensure_tracking,
    update_courier_location,
)

router = APIRouter(prefix="/courier", tags=["Livreur"])


@router.get("/available", response_model=list[OrderRead])
def available_orders(
    user: User = Depends(require_courier),
    db: Session = Depends(get_db),
):
    return (
        _with_relations(db)
        .filter(
            Order.status == OrderStatus.ready.value,
            Order.courier_id.is_(None),
        )
        .order_by(Order.updated_at.asc())
        .limit(50)
        .all()
    )


@router.get("/orders", response_model=list[OrderRead])
def my_orders(
    user: User = Depends(require_courier),
    db: Session = Depends(get_db),
):
    return (
        _with_relations(db)
        .filter(Order.courier_id == user.id)
        .order_by(Order.updated_at.desc())
        .limit(100)
        .all()
    )


@router.post("/orders/{order_id}/accept", response_model=OrderRead)
def accept_order(
    order_id: int,
    user: User = Depends(require_courier),
    db: Session = Depends(get_db),
):
    order = _get_order(db, order_id)
    if order.status != OrderStatus.ready.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cette course n'est plus disponible",
        )
    if order.courier_id is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cette course a déjà été prise",
        )

    order.courier_id = user.id
    order.status = OrderStatus.shipping.value
    db.flush()
    tracking = ensure_tracking(db, order)
    tracking.courier_lat = tracking.restaurant_lat
    tracking.courier_lng = tracking.restaurant_lng
    tracking.courier_updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(order)
    return _get_order(db, order.id)


@router.post("/orders/{order_id}/deliver", response_model=OrderRead)
def deliver_order(
    order_id: int,
    user: User = Depends(require_courier),
    db: Session = Depends(get_db),
):
    order = _get_order(db, order_id)
    if order.courier_id != user.id:
        raise HTTPException(status_code=403, detail="Cette course n'est pas la vôtre")
    if order.status != OrderStatus.shipping.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La course n'est pas en livraison",
        )

    order.status = OrderStatus.delivered.value
    db.flush()
    tracking = ensure_tracking(db, order)
    tracking.courier_lat = tracking.delivery_lat
    tracking.courier_lng = tracking.delivery_lng
    tracking.courier_updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(order)
    return _get_order(db, order.id)


@router.patch("/orders/{order_id}/location", response_model=OrderTrackingRead)
def update_location(
    order_id: int,
    payload: TrackingLocationIn,
    user: User = Depends(require_courier),
    db: Session = Depends(get_db),
):
    order = _get_order(db, order_id)
    if order.courier_id != user.id:
        raise HTTPException(status_code=403, detail="Cette course n'est pas la vôtre")
    if order.status != OrderStatus.shipping.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La course n'est pas en livraison",
        )

    update_courier_location(
        db,
        order,
        payload.latitude,
        payload.longitude,
    )
    return build_tracking_read(db, order)


@router.get("/stats")
def courier_stats(
    user: User = Depends(require_courier),
    db: Session = Depends(get_db),
):
    available = (
        db.query(func.count(Order.id))
        .filter(
            Order.status == OrderStatus.ready.value,
            Order.courier_id.is_(None),
        )
        .scalar()
        or 0
    )
    active = (
        db.query(func.count(Order.id))
        .filter(
            Order.courier_id == user.id,
            Order.status == OrderStatus.shipping.value,
        )
        .scalar()
        or 0
    )
    delivered = (
        db.query(func.count(Order.id))
        .filter(
            Order.courier_id == user.id,
            Order.status == OrderStatus.delivered.value,
        )
        .scalar()
        or 0
    )
    earnings = (
        db.query(func.coalesce(func.sum(Order.delivery_fee), 0.0))
        .filter(
            Order.courier_id == user.id,
            Order.status == OrderStatus.delivered.value,
        )
        .scalar()
        or 0.0
    )
    return {
        "available": int(available),
        "active": int(active),
        "delivered": int(delivered),
        "earnings": round(float(earnings), 2),
    }

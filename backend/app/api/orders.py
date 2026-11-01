"""Commandes client/partenaire/livreur."""

import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.deps import (
    get_current_user,
    require_courier,
    require_roles,
)
from app.db.session import get_db
from app.models import Order, OrderItem, OrderStatus, OrderTracking, Product, Restaurant, Role, User
from app.schemas import OrderCreate, OrderRead, OrderStatusUpdate

router = APIRouter(prefix="/orders", tags=["Commandes"])


def _parse_zones(zones: str | None):
    if not zones:
        return []
    try:
        data = json.loads(zones)
        if isinstance(data, list):
            return data
    except Exception:
        pass
    return []


def _zone_fee(restaurant: Restaurant, address: str) -> float:
    address_l = address.lower()
    for zone in _parse_zones(restaurant.delivery_zones):
        zname = str(zone.get("zone", "")).lower()
        fee = zone.get("fee")
        if zname and zname in address_l and fee is not None:
            try:
                return float(fee)
            except Exception:
                pass
    return float(restaurant.delivery_fee)


def _is_open_now(restaurant: Restaurant) -> bool:
    if not restaurant.is_open:
        return False
    hours = restaurant.opening_hours or ""
    if not hours:
        return True
    # Accept formats like "09:00 - 22:00" or "9h-22h"; if parse fails keep open
    try:
        import re

        m = re.findall(r"(\d{1,2})[:hH]?(\d{2})?", hours)
        if len(m) >= 2:
            h1 = int(m[0][0])
            mi1 = int(m[0][1]) if m[0][1] else 0
            h2 = int(m[1][0])
            mi2 = int(m[1][1]) if m[1][1] else 0
            now = datetime.now()
            start = now.replace(hour=h1, minute=mi1, second=0, microsecond=0)
            end = now.replace(hour=h2, minute=mi2, second=0, microsecond=0)
            if end < start:
                # overnight simple check
                return now >= start or now <= end
            return start <= now <= end
    except Exception:
        pass
    return True


@router.post("", response_model=OrderRead, status_code=status.HTTP_201_CREATED)
def create_order(
    payload: OrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != Role.client.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls les clients peuvent passer une commande.",
        )

    restaurant = db.get(Restaurant, payload.restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="Restaurant introuvable.")
    if not _is_open_now(restaurant):
        raise HTTPException(
            status_code=409,
            detail="Ce restaurant est fermé pour le moment.",
        )

    product_ids = [item.product_id for item in payload.items]
    products = (
        db.query(Product)
        .filter(Product.id.in_(product_ids), Product.restaurant_id == restaurant.id)
        .all()
    )
    product_map = {product.id: product for product in products}

    subtotal = 0.0
    order_items: list[OrderItem] = []
    for item in payload.items:
        product = product_map.get(item.product_id)
        if product is None or not product.is_available:
            raise HTTPException(status_code=400, detail="Produit indisponible.")
        unit_price = product.price
        subtotal += unit_price * item.quantity
        order_items.append(
            OrderItem(
                product_id=product.id,
                name=product.name,
                unit_price=unit_price,
                quantity=item.quantity,
                emoji=product.emoji or "",
            )
        )

    if subtotal < restaurant.min_order:
        raise HTTPException(
            status_code=400,
            detail=f"Montant minimum : {int(restaurant.min_order)} FCFA.",
        )

    delivery_fee = _zone_fee(restaurant, payload.address)
    total = subtotal + delivery_fee

    order = Order(
        client_id=current_user.id,
        restaurant_id=restaurant.id,
        status=OrderStatus.pending.value,
        subtotal=subtotal,
        delivery_fee=delivery_fee,
        total=total,
        address=payload.address,
        notes=payload.notes,
    )
    db.add(order)
    db.flush()
    for order_item in order_items:
        order_item.order_id = order.id
        db.add(order_item)

    tracking = OrderTracking(
        order_id=order.id,
        restaurant_lat=restaurant.latitude or 0.0,
        restaurant_lng=restaurant.longitude or 0.0,
        delivery_lat=0.0,
        delivery_lng=0.0,
    )
    db.add(tracking)
    db.commit()

    order = (
        db.query(Order)
        .options(
            joinedload(Order.client),
            joinedload(Order.courier),
            joinedload(Order.restaurant),
            selectinload(Order.items),
        )
        .filter(Order.id == order.id)
        .first()
    )
    return order


@router.get("", response_model=list[OrderRead])
def list_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = (
        db.query(Order)
        .options(
            joinedload(Order.client),
            joinedload(Order.courier),
            joinedload(Order.restaurant),
            selectinload(Order.items),
        )
        .order_by(Order.created_at.desc())
    )
    if current_user.role == Role.client.value:
        query = query.filter(Order.client_id == current_user.id)
    elif current_user.role == Role.courier.value:
        query = query.filter(
            (Order.courier_id == current_user.id)
            | (Order.status.in_([OrderStatus.ready.value, OrderStatus.accepted.value]))
        )
    elif current_user.role == Role.partner.value:
        restaurant_ids = [r.id for r in current_user.restaurants]
        if not restaurant_ids:
            return []
        query = query.filter(Order.restaurant_id.in_(restaurant_ids))
    else:
        pass
    return query.all()


@router.get("/{order_id}", response_model=OrderRead)
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = (
        db.query(Order)
        .options(
            joinedload(Order.client),
            joinedload(Order.courier),
            joinedload(Order.restaurant),
            selectinload(Order.items),
        )
        .filter(Order.id == order_id)
        .first()
    )
    if order is None:
        raise HTTPException(status_code=404, detail="Commande introuvable.")

    if current_user.role == Role.client.value and order.client_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé.")
    if current_user.role == Role.courier.value and order.courier_id not in (
        None,
        current_user.id,
    ):
        restaurant_ids = [r.id for r in current_user.restaurants] if hasattr(current_user, "restaurants") else []
        if order.restaurant_id not in restaurant_ids and order.courier_id != current_user.id and order.status not in (
            OrderStatus.ready.value,
            OrderStatus.accepted.value,
        ):
            raise HTTPException(status_code=403, detail="Accès refusé.")
    if current_user.role == Role.partner.value:
        restaurant_ids = [r.id for r in current_user.restaurants]
        if order.restaurant_id not in restaurant_ids:
            raise HTTPException(status_code=403, detail="Accès refusé.")

    return order


@router.patch("/{order_id}/status", response_model=OrderRead)
def update_status(
    order_id: int,
    payload: OrderStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = (
        db.query(Order)
        .options(
            joinedload(Order.client),
            joinedload(Order.courier),
            joinedload(Order.restaurant),
            selectinload(Order.items),
        )
        .filter(Order.id == order_id)
        .first()
    )
    if order is None:
        raise HTTPException(status_code=404, detail="Commande introuvable.")

    new_status = payload.status.value

    if current_user.role == Role.partner.value:
        restaurant_ids = [r.id for r in current_user.restaurants]
        if order.restaurant_id not in restaurant_ids:
            raise HTTPException(status_code=403, detail="Accès refusé.")
        allowed = {OrderStatus.accepted.value, OrderStatus.preparing.value, OrderStatus.ready.value, OrderStatus.cancelled.value}
        if new_status not in allowed:
            raise HTTPException(status_code=400, detail="Transition non autorisée.")
    elif current_user.role == Role.courier.value:
        if new_status == OrderStatus.shipping.value:
            if order.courier_id is not None and order.courier_id != current_user.id:
                raise HTTPException(status_code=409, detail="Commande déjà prise en charge.")
            order.courier_id = current_user.id
        elif new_status == OrderStatus.delivered.value:
            if order.courier_id != current_user.id:
                raise HTTPException(status_code=403, detail="Seul le livreur assigné peut valider la livraison.")
        else:
            raise HTTPException(status_code=400, detail="Transition non autorisée.")
    elif current_user.role == Role.admin.value:
        pass
    elif current_user.role == Role.client.value and new_status == OrderStatus.cancelled.value:
        if order.status not in (OrderStatus.pending.value, OrderStatus.accepted.value):
            raise HTTPException(status_code=400, detail="Cette commande ne peut plus être annulée.")
        if order.client_id != current_user.id:
            raise HTTPException(status_code=403, detail="Accès refusé.")
    else:
        raise HTTPException(status_code=403, detail="Accès refusé.")

    order.status = new_status
    db.commit()
    db.refresh(order)
    return order


def _with_relations(db: Session):
    return (
        db.query(Order)
        .options(
            joinedload(Order.client),
            joinedload(Order.courier),
            joinedload(Order.restaurant),
            selectinload(Order.items),
        )
    )


def _get_order(db: Session, order_id: int):
    order = _with_relations(db).filter(Order.id == order_id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="Commande introuvable.")
    return order

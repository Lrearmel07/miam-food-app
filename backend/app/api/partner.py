"""Espace partenaire : restaurant, menu, commandes et statistiques."""

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.deps import require_partner
from app.db.session import get_db
from app.models import Order, OrderStatus, Product, ProductImage, Restaurant, RestaurantImage, Role, User
from app.services.restaurants import apply_restaurant_payload
from app.schemas import (
    GalleryReorderIn,
    ImageCreate,
    ImageRead,
    OrderRead,
    OrderStatusUpdate,
    ProductCreate,
    ProductRead,
    ProductUpdate,
    RestaurantRead,
    RestaurantUpdate,
)

router = APIRouter(prefix="/partner", tags=["Partenaire"])

TRANSITIONS = {
    OrderStatus.pending.value: {OrderStatus.accepted.value, OrderStatus.cancelled.value},
    OrderStatus.accepted.value: {OrderStatus.preparing.value, OrderStatus.cancelled.value},
    OrderStatus.preparing.value: {OrderStatus.ready.value, OrderStatus.cancelled.value},
    OrderStatus.ready.value: {OrderStatus.cancelled.value},
}


def my_restaurant(db: Session, user: User) -> Restaurant:
    restaurant = (
        db.query(Restaurant)
        .options(selectinload(Restaurant.products))
        .filter(Restaurant.owner_id == user.id)
        .order_by(Restaurant.id)
        .first()
    )
    if restaurant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aucun restaurant associé à ce compte",
        )
    return restaurant


def _partner_orders(db: Session):
    return db.query(Order).options(
        joinedload(Order.restaurant),
        joinedload(Order.client),
        joinedload(Order.courier),
        selectinload(Order.items),
    )


@router.get("/restaurant", response_model=RestaurantRead)
def get_my_restaurant(
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    return my_restaurant(db, user)


@router.patch("/restaurant", response_model=RestaurantRead)
def update_my_restaurant(
    payload: RestaurantUpdate,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    data = payload.model_dump(exclude_unset=True)
    data.pop("owner_id", None)
    apply_restaurant_payload(restaurant, data)
    db.commit()
    db.refresh(restaurant)
    return restaurant


@router.get("/orders", response_model=list[OrderRead])
def partner_orders(
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    return (
        _partner_orders(db)
        .filter(Order.restaurant_id == restaurant.id)
        .order_by(Order.created_at.desc())
        .limit(100)
        .all()
    )


@router.patch("/orders/{order_id}/status", response_model=OrderRead)
def update_order_status(
    order_id: int,
    payload: OrderStatusUpdate,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    order = _partner_orders(db).filter(Order.id == order_id).first()
    if order is None or order.restaurant_id != restaurant.id:
        raise HTTPException(status_code=404, detail="Commande introuvable")

    target = payload.status.value
    allowed = TRANSITIONS.get(order.status, set())
    if target not in allowed:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Transition impossible : {order.status} → {target}",
        )

    order.status = target
    db.commit()
    db.refresh(order)
    return order


@router.get("/products", response_model=list[ProductRead])
def partner_products(
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    return (
        db.query(Product)
        .filter(Product.restaurant_id == restaurant.id)
        .order_by(Product.category, Product.name)
        .all()
    )


@router.post("/products", response_model=ProductRead, status_code=201)
def create_product(
    payload: ProductCreate,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    product = Product(restaurant_id=restaurant.id, **payload.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.patch("/products/{product_id}", response_model=ProductRead)
def update_product(
    product_id: int,
    payload: ProductUpdate,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    product = db.get(Product, product_id)
    if product is None or product.restaurant_id != restaurant.id:
        raise HTTPException(status_code=404, detail="Produit introuvable")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(product, field, value)
    db.commit()
    db.refresh(product)
    return product


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(
    product_id: int,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    product = db.get(Product, product_id)
    if product is None or product.restaurant_id != restaurant.id:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    db.delete(product)
    db.commit()


@router.get("/stats")
def partner_stats(
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    base = db.query(Order).filter(Order.restaurant_id == restaurant.id)
    orders_today = (
        base.filter(func.date(Order.created_at) == date.today().isoformat())
        .with_entities(func.count(Order.id))
        .scalar()
        or 0
    )
    pending = base.filter(
        Order.status.in_(
            [
                OrderStatus.pending.value,
                OrderStatus.accepted.value,
                OrderStatus.preparing.value,
            ]
        )
    ).count()
    revenue = (
        base.filter(Order.status == OrderStatus.delivered.value)
        .with_entities(func.coalesce(func.sum(Order.total), 0.0))
        .scalar()
        or 0.0
    )
    products = (
        db.query(Product)
        .filter(Product.restaurant_id == restaurant.id)
        .count()
    )
    return {
        "restaurant_name": restaurant.name,
        "is_open": restaurant.is_open,
        "rating": restaurant.rating,
        "orders_today": int(orders_today),
        "pending": int(pending),
        "products": int(products),
        "revenue": round(float(revenue), 2),
    }


# Galerie restaurant
@router.get("/restaurant/gallery", response_model=list[ImageRead])
def get_restaurant_gallery(
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    return (
        db.query(RestaurantImage)
        .filter(RestaurantImage.restaurant_id == restaurant.id)
        .order_by(RestaurantImage.sort_order, RestaurantImage.id)
        .all()
    )


@router.post("/restaurant/gallery", response_model=ImageRead, status_code=201)
def add_restaurant_image(
    payload:ImageCreate,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    max_order = (
        db.query(func.coalesce(func.max(RestaurantImage.sort_order), -1))
        .filter(RestaurantImage.restaurant_id == restaurant.id)
        .scalar()
    )
    img = RestaurantImage(restaurant_id=restaurant.id, image_url=payload.image_url, sort_order=(max_order or -1) + 1)
    db.add(img)
    db.commit()
    db.refresh(img)
    return img


@router.delete("/restaurant/gallery/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_restaurant_image(
    image_id: int,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    img = db.get(RestaurantImage, image_id)
    if img is None or img.restaurant_id != restaurant.id:
        raise HTTPException(status_code=404, detail="Image introuvable")
    db.delete(img)
    db.commit()


@router.post("/restaurant/gallery/reorder", response_model=list[ImageRead])
def reorder_restaurant_gallery(
    payload: GalleryReorderIn,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    images = (
        db.query(RestaurantImage)
        .filter(
            RestaurantImage.restaurant_id == restaurant.id,
            RestaurantImage.id.in_(payload.items),
        )
        .all()
    )
    by_id = {img.id: img for img in images}
    for idx, img_id in enumerate(payload.items):
        img = by_id.get(img_id)
        if img:
            img.sort_order = idx
    db.commit()
    return (
        db.query(RestaurantImage)
        .filter(RestaurantImage.restaurant_id == restaurant.id)
        .order_by(RestaurantImage.sort_order, RestaurantImage.id)
        .all()
    )


# Galerie produits
@router.get("/products/{product_id}/gallery", response_model=list[ImageRead])
def get_product_gallery(
    product_id: int,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    product = db.get(Product, product_id)
    if product is None or product.restaurant_id != restaurant.id:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    return (
        db.query(ProductImage)
        .filter(ProductImage.product_id == product.id)
        .order_by(ProductImage.sort_order, ProductImage.id)
        .all()
    )


@router.post("/products/{product_id}/gallery", response_model=ImageRead, status_code=201)
def add_product_image(
    product_id: int,
    payload:ImageCreate,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    product = db.get(Product, product_id)
    if product is None or product.restaurant_id != restaurant.id:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    max_order = (
        db.query(func.coalesce(func.max(ProductImage.sort_order), -1))
        .filter(ProductImage.product_id == product.id)
        .scalar()
    )
    img = ProductImage(product_id=product.id, image_url=payload.image_url, sort_order=(max_order or -1) + 1)
    db.add(img)
    db.commit()
    db.refresh(img)
    return img


@router.delete("/products/gallery/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product_image(
    image_id: int,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    restaurant = my_restaurant(db, user)
    img = db.get(ProductImage, image_id)
    if img is None:
        raise HTTPException(status_code=404, detail="Image introuvable")
    product = db.get(Product, img.product_id)
    if product is None or product.restaurant_id != restaurant.id:
        raise HTTPException(status_code=404, detail="Image introuvable")
    db.delete(img)
    db.commit()


@router.post("/products/gallery/reorder", response_model=list[ImageRead])
def reorder_product_gallery(
    payload: GalleryReorderIn,
    user: User = Depends(require_partner),
    db: Session = Depends(get_db),
):
    images = db.query(ProductImage).filter(ProductImage.id.in_(payload.items)).all()
    if not images:
        return []
    restaurant = my_restaurant(db, user)
    product_ids = {img.product_id for img in images}
    products = db.query(Product).filter(Product.id.in_(product_ids)).all()
    owned = {p.id for p in products if p.restaurant_id == restaurant.id}
    for img in images:
        if img.product_id not in owned:
            raise HTTPException(status_code=403, detail="Accès refusé")
    by_id = {img.id: img for img in images}
    for idx, img_id in enumerate(payload.items):
        img = by_id.get(img_id)
        if img:
            img.sort_order = idx
    db.commit()
    # return reordered for first product? just return all reordered in payload order grouped
    result = []
    for img_id in payload.items:
        img = by_id.get(img_id)
        if img:
            result.append(img)
    return result

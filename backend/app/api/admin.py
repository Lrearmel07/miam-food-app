"""Espace administrateur : supervision globale de la plateforme."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.deps import require_admin
from app.core.security import hash_password
from app.db.session import get_db
from app.models import Order, OrderStatus, Product, ProductImage, Restaurant, RestaurantImage, Role, User
from app.services.restaurants import (
    apply_restaurant_payload,
    refresh_restaurant_location,
)
from app.schemas import (
    GalleryReorderIn,
    ImageCreate,
    ImageRead,
    OrderRead,
    OrderStatusUpdate,
    PartnerCreate,
    ProductCreate,
    ProductRead,
    ProductUpdate,
    RestaurantCreate,
    RestaurantRead,
    RestaurantUpdate,
    UserActiveUpdate,
    UserRead,
)

router = APIRouter(prefix="/admin", tags=["Administrateur"])


def _admin_orders(db: Session):
    return db.query(Order).options(
        joinedload(Order.restaurant),
        joinedload(Order.client),
        joinedload(Order.courier),
        selectinload(Order.items),
    )


@router.get("/stats")
def admin_stats(
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    counts = {
        role: db.query(User).filter(User.role == role.value).count()
        for role in Role
    }
    orders = db.query(Order)
    revenue = (
        orders.filter(Order.status == OrderStatus.delivered.value)
        .with_entities(func.coalesce(func.sum(Order.total), 0.0))
        .scalar()
        or 0.0
    )
    pending = orders.filter(
        Order.status.in_(
            [
                OrderStatus.pending.value,
                OrderStatus.accepted.value,
                OrderStatus.preparing.value,
                OrderStatus.ready.value,
            ]
        )
    ).count()
    return {
        "users": sum(counts.values()),
        "clients": counts[Role.client],
        "couriers": counts[Role.courier],
        "partners": counts[Role.partner],
        "admins": counts[Role.admin],
        "restaurants": db.query(Restaurant).count(),
        "orders": orders.count(),
        "pending_orders": int(pending),
        "revenue": round(float(revenue), 2),
    }


@router.get("/users", response_model=list[UserRead])
def list_users(
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(User).order_by(User.created_at.desc()).all()


@router.patch("/users/{user_id}/active", response_model=UserRead)
def set_user_active(
    user_id: int,
    payload: UserActiveUpdate,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if target.id == user.id and not payload.is_active:
        raise HTTPException(
            status_code=400,
            detail="Impossible de désactiver son propre compte",
        )
    target.is_active = payload.is_active
    db.commit()
    db.refresh(target)
    return target


@router.get("/restaurants", response_model=list[RestaurantRead])
def list_restaurants(
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(Restaurant)
        .options(selectinload(Restaurant.products))
        .order_by(Restaurant.name)
        .all()
    )


@router.post("/restaurants", response_model=RestaurantRead, status_code=201)
def create_restaurant(
    payload: RestaurantCreate,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    data = payload.model_dump()
    latitude = data.pop("latitude", None)
    longitude = data.pop("longitude", None)
    restaurant = Restaurant(**data)
    if latitude is not None and longitude is not None:
        restaurant.latitude = round(latitude, 6)
        restaurant.longitude = round(longitude, 6)
    else:
        refresh_restaurant_location(restaurant)
    db.add(restaurant)
    db.commit()
    db.refresh(restaurant)
    return restaurant


@router.patch("/restaurants/{restaurant_id}", response_model=RestaurantRead)
def update_restaurant(
    restaurant_id: int,
    payload: RestaurantUpdate,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="Restaurant introuvable")
    apply_restaurant_payload(
        restaurant, payload.model_dump(exclude_unset=True)
    )
    db.commit()
    db.refresh(restaurant)
    return restaurant


@router.get("/orders", response_model=list[OrderRead])
def list_orders(
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return _admin_orders(db).order_by(Order.created_at.desc()).limit(300).all()


@router.patch("/orders/{order_id}/status", response_model=OrderRead)
def force_order_status(
    order_id: int,
    payload: OrderStatusUpdate,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    order = _admin_orders(db).filter(Order.id == order_id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="Commande introuvable")
    order.status = payload.status.value
    db.commit()
    db.refresh(order)
    return order


@router.post("/partners", response_model=UserRead, status_code=201)
def create_partner(
    payload: PartnerCreate,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    email = payload.email.strip().lower()
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=409, detail="Cet email est déjà utilisé")

    partner = User(
        email=email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name.strip(),
        phone=payload.phone,
        role=Role.partner.value,
    )
    db.add(partner)
    db.flush()

    restaurant = Restaurant(
        name=payload.restaurant_name.strip(),
        cuisine=payload.cuisine,
        owner_id=partner.id,
        is_open=False,
        description="Nouveau partenaire en attente de validation.",
    )
    refresh_restaurant_location(restaurant)
    db.add(restaurant)
    db.commit()
    db.refresh(partner)
    return partner


# Galerie restaurants (admin)
@router.get("/restaurants/{restaurant_id}/gallery", response_model=list[ImageRead])
def admin_restaurant_gallery(
    restaurant_id: int,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="Restaurant introuvable")
    return (
        db.query(RestaurantImage)
        .filter(RestaurantImage.restaurant_id == restaurant.id)
        .order_by(RestaurantImage.sort_order, RestaurantImage.id)
        .all()
    )


@router.post("/restaurants/{restaurant_id}/gallery", response_model=ImageRead, status_code=201)
def admin_add_restaurant_image(
    restaurant_id: int,
    payload:ImageCreate,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="Restaurant introuvable")
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


@router.delete("/restaurants/gallery/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_restaurant_image(
    image_id: int,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    img = db.get(RestaurantImage, image_id)
    if img is None:
        raise HTTPException(status_code=404, detail="Image introuvable")
    db.delete(img)
    db.commit()


@router.post("/restaurants/gallery/reorder", response_model=list[ImageRead])
def admin_reorder_restaurant_gallery(
    payload: GalleryReorderIn,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    images = db.query(RestaurantImage).filter(RestaurantImage.id.in_(payload.items)).all()
    by_id = {img.id: img for img in images}
    for idx, img_id in enumerate(payload.items):
        img = by_id.get(img_id)
        if img:
            img.sort_order = idx
    db.commit()
    result = []
    for img_id in payload.items:
        img = by_id.get(img_id)
        if img:
            result.append(img)
    return result


# Galerie produits (admin)
@router.get("/products/{product_id}/gallery", response_model=list[ImageRead])
def admin_product_gallery(
    product_id: int,
    payload:ImageCreate,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    return (
        db.query(ProductImage)
        .filter(ProductImage.product_id == product.id)
        .order_by(ProductImage.sort_order, ProductImage.id)
        .all()
    )


@router.post("/products/{product_id}/gallery", response_model=ImageRead, status_code=201)
def admin_add_product_image(
    product_id: int,
    image_url: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    product = db.get(Product, product_id)
    if product is None:
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
def admin_delete_product_image(
    image_id: int,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    img = db.get(ProductImage, image_id)
    if img is None:
        raise HTTPException(status_code=404, detail="Image introuvable")
    db.delete(img)
    db.commit()


@router.post("/products/gallery/reorder", response_model=list[ImageRead])
def admin_reorder_product_gallery(
    payload: GalleryReorderIn,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    images = db.query(ProductImage).filter(ProductImage.id.in_(payload.items)).all()
    by_id = {img.id: img for img in images}
    for idx, img_id in enumerate(payload.items):
        img = by_id.get(img_id)
        if img:
            img.sort_order = idx
    db.commit()
    result = []
    for img_id in payload.items:
        img = by_id.get(img_id)
        if img:
            result.append(img)
    return result

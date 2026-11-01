"""Modèles SQLAlchemy : utilisateurs, restaurants, produits et commandes."""

from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Role(str, Enum):
    client = "client"
    courier = "courier"
    partner = "partner"
    admin = "admin"


class OrderStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    preparing = "preparing"
    ready = "ready"
    shipping = "shipping"
    delivered = "delivered"
    cancelled = "cancelled"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    role: Mapped[str] = mapped_column(String(20), default=Role.client.value, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    restaurants: Mapped[list["Restaurant"]] = relationship(
        back_populates="owner", foreign_keys="Restaurant.owner_id"
    )
    client_orders: Mapped[list["Order"]] = relationship(
        back_populates="client", foreign_keys="Order.client_id"
    )
    courier_orders: Mapped[list["Order"]] = relationship(
        back_populates="courier", foreign_keys="Order.courier_id"
    )
    reviews: Mapped[list["Review"]] = relationship(back_populates="user")
    avatar_url: Mapped[str | None] = mapped_column(String, nullable=True) 


class Restaurant(Base):
    __tablename__ = "restaurants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    cuisine: Mapped[str] = mapped_column(String(60), index=True)
    emoji: Mapped[str] = mapped_column(String(16), default="")
    image_url: Mapped[str | None] = mapped_column(String(600), nullable=True)
    cover_image_url: Mapped[str | None] = mapped_column(String(600), nullable=True)
    color: Mapped[str] = mapped_column(String(9), default="#FF7A45")
    rating: Mapped[float] = mapped_column(Float, default=4.5)
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    delivery_fee: Mapped[float] = mapped_column(Float, default=1500.0)
    min_order: Mapped[float] = mapped_column(Float, default=5000.0)
    eta_min: Mapped[int] = mapped_column(Integer, default=25)
    address: Mapped[str] = mapped_column(String(255), default="")
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_open: Mapped[bool] = mapped_column(Boolean, default=True)
    opening_hours: Mapped[str | None] = mapped_column(Text, nullable=True)
    delivery_zones: Mapped[str | None] = mapped_column(Text, nullable=True)
    promo_text: Mapped[str | None] = mapped_column(String(200), nullable=True)
    promo_badge: Mapped[str | None] = mapped_column(String(80), nullable=True)
    owner_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    owner: Mapped[User | None] = relationship(
        back_populates="restaurants", foreign_keys=[owner_id]
    )
    products: Mapped[list["Product"]] = relationship(
        back_populates="restaurant", cascade="all, delete-orphan"
    )
    images: Mapped[list["RestaurantImage"]] = relationship(
        back_populates="restaurant", cascade="all, delete-orphan", order_by="RestaurantImage.sort_order"
    )
    orders: Mapped[list["Order"]] = relationship(back_populates="restaurant")
    reviews: Mapped[list["Review"]] = relationship(
        back_populates="restaurant", cascade="all, delete-orphan"
    )

    @property
    def product_count(self) -> int:
        return len(self.products)


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id"), index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    price: Mapped[float] = mapped_column(Float)
    category: Mapped[str] = mapped_column(String(60), default="Plats")
    emoji: Mapped[str] = mapped_column(String(16), default="")
    image_url: Mapped[str | None] = mapped_column(String(600), nullable=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    prep_time: Mapped[int] = mapped_column(Integer, default=15)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    restaurant: Mapped[Restaurant] = relationship(back_populates="products")
    images: Mapped[list["ProductImage"]] = relationship(
        back_populates="product", cascade="all, delete-orphan", order_by="ProductImage.sort_order"
    )


class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id"), index=True
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    restaurant: Mapped[Restaurant] = relationship(back_populates="reviews")
    user: Mapped[User] = relationship(back_populates="reviews")


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id"), index=True
    )
    courier_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True, index=True
    )
    status: Mapped[str] = mapped_column(
        String(20), default=OrderStatus.pending.value, index=True
    )
    subtotal: Mapped[float] = mapped_column(Float, default=0.0)
    delivery_fee: Mapped[float] = mapped_column(Float, default=0.0)
    total: Mapped[float] = mapped_column(Float, default=0.0)
    address: Mapped[str] = mapped_column(String(255))
    notes: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    client: Mapped[User] = relationship(
        back_populates="client_orders", foreign_keys=[client_id]
    )
    courier: Mapped[User | None] = relationship(
        back_populates="courier_orders", foreign_keys=[courier_id]
    )
    restaurant: Mapped[Restaurant] = relationship(back_populates="orders")
    items: Mapped[list["OrderItem"]] = relationship(
        back_populates="order", cascade="all, delete-orphan"
    )
    tracking: Mapped["OrderTracking | None"] = relationship(
        back_populates="order", cascade="all, delete-orphan", uselist=False
    )


class OrderTracking(Base):
    __tablename__ = "order_tracking"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("orders.id"), unique=True, index=True
    )
    restaurant_lat: Mapped[float] = mapped_column(Float)
    restaurant_lng: Mapped[float] = mapped_column(Float)
    delivery_lat: Mapped[float] = mapped_column(Float)
    delivery_lng: Mapped[float] = mapped_column(Float)
    courier_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    courier_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    courier_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    order: Mapped[Order] = relationship(back_populates="tracking")



class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), index=True)
    product_id: Mapped[int | None] = mapped_column(ForeignKey("products.id"), nullable=True)
    name: Mapped[str] = mapped_column(String(120))
    unit_price: Mapped[float] = mapped_column(Float)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    emoji: Mapped[str] = mapped_column(String(16), default="")

    order: Mapped[Order] = relationship(back_populates="items")


class RestaurantImage(Base):
    __tablename__ = "restaurant_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id"), index=True
    )
    image_url: Mapped[str] = mapped_column(String(600))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    restaurant: Mapped[Restaurant] = relationship(back_populates="images")


class ProductImage(Base):
    __tablename__ = "product_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"), index=True)
    image_url: Mapped[str] = mapped_column(String(600))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    product: Mapped[Product] = relationship(back_populates="images")

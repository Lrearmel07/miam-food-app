"""Schémas Pydantic : validation des entrées et forme des réponses JSON."""

from datetime import datetime

from typing import Any
from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator

from app.models import OrderStatus, Role


class UserBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    phone: str | None = None


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    full_name: str
    phone: str | None = None
    avatar_url: str | None = None 
    role: Role
    is_active: bool
    created_at: datetime


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    full_name: str = Field(min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=30)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead


class RestaurantBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    emoji: str
    color: str
    address: str


class DeliveryZoneRead(BaseModel):
    model_config = ConfigDict(extra="ignore")

    zone: str
    fee: float


class RestaurantRead(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    name: str
    description: str
    cuisine: str
    emoji: str
    image_url: str | None = None
    cover_image_url: str | None = None
    color: str
    rating: float
    review_count: int = 0
    delivery_fee: float
    min_order: float
    eta_min: int
    address: str
    latitude: float | None = None
    longitude: float | None = None
    distance_km: float | None = None
    is_open: bool
    opening_hours: str | None = None
    delivery_zones: Any = []

    @model_validator(mode="before")
    @classmethod
    def _parse_zones(cls, values):
        if isinstance(values, dict):
            v = values.get("delivery_zones")
            if isinstance(v, str):
                import json
                try:
                    parsed = json.loads(v)
                    if isinstance(parsed, list):
                        values["delivery_zones"] = parsed
                    else:
                        values["delivery_zones"] = []
                except Exception:
                    values["delivery_zones"] = []
        return values
    promo_text: str | None = None
    promo_badge: str | None = None
    owner_id: int | None = None
    product_count: int = 0


class RestaurantCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str = ""
    cuisine: str = "International"
    emoji: str = ""
    image_url: str | None = None
    cover_image_url: str | None = None
    color: str = "#FF7A45"
    rating: float = 4.5
    review_count: int = 0
    delivery_fee: float = 1500.0
    min_order: float = 5000.0
    eta_min: int = 25
    address: str = ""
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    is_open: bool = True
    opening_hours: str | None = None
    delivery_zones: list[DeliveryZoneRead] = []
    promo_text: str | None = None
    promo_badge: str | None = None
    owner_id: int | None = None

    @model_validator(mode="after")
    def _validate_coordinates(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError(
                "Latitude et longitude doivent être fournies ensemble."
            )
        return self


class RestaurantUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    cuisine: str | None = None
    emoji: str | None = None
    image_url: str | None = None
    cover_image_url: str | None = None
    color: str | None = None
    rating: float | None = None
    review_count: int | None = None
    delivery_fee: float | None = None
    min_order: float | None = None
    eta_min: int | None = None
    address: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    is_open: bool | None = None
    opening_hours: str | None = None
    delivery_zones: list[DeliveryZoneRead] = []
    promo_text: str | None = None
    promo_badge: str | None = None
    owner_id: int | None = None

    @model_validator(mode="after")
    def _validate_coordinates(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError(
                "Latitude et longitude doivent être fournies ensemble."
            )
        return self


class ProductRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    restaurant_id: int
    name: str
    description: str
    price: float
    category: str
    emoji: str
    image_url: str | None = None
    is_available: bool
    prep_time: int


class ProductCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str = ""
    price: float = Field(gt=0)
    category: str = "Plats"
    emoji: str = ""
    image_url: str | None = None
    is_available: bool = True
    prep_time: int = Field(default=15, ge=1, le=180)


class ProductUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    price: float | None = Field(default=None, gt=0)
    category: str | None = None
    emoji: str | None = None
    image_url: str | None = None
    is_available: bool | None = None
    prep_time: int | None = Field(default=None, ge=1, le=180)


class ReviewAuthor(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str


class ReviewRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    rating: int
    comment: str
    created_at: datetime
    author: ReviewAuthor


class ReviewCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


class OrderItemIn(BaseModel):
    product_id: int
    quantity: int = Field(default=1, ge=1, le=20)


class OrderCreate(BaseModel):
    restaurant_id: int
    items: list[OrderItemIn] = Field(min_length=1)
    address: str = Field(min_length=5, max_length=255)
    notes: str = Field(default="", max_length=500)


class OrderItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int | None
    name: str
    unit_price: float
    quantity: int
    emoji: str


class OrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    status: OrderStatus
    subtotal: float
    delivery_fee: float
    total: float
    address: str
    notes: str
    created_at: datetime
    updated_at: datetime
    restaurant: RestaurantBrief
    client: UserBrief
    courier: UserBrief | None = None
    items: list[OrderItemRead]


class OrderStatusUpdate(BaseModel):
    status: OrderStatus


class TrackingLocationIn(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class TrackingPlaceRead(BaseModel):
    name: str
    address: str
    latitude: float
    longitude: float


class TrackingCourierRead(BaseModel):
    id: int
    full_name: str
    phone: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    updated_at: datetime | None = None


class OrderTrackingRead(BaseModel):
    order_id: int
    status: OrderStatus
    restaurant: TrackingPlaceRead
    delivery: TrackingPlaceRead
    courier: TrackingCourierRead | None = None
    distance_remaining_km: float
    eta_minutes: int
    updated_at: datetime


class UserActiveUpdate(BaseModel):
    is_active: bool


class PartnerCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    full_name: str = Field(min_length=2, max_length=120)
    phone: str | None = None
    restaurant_name: str = Field(min_length=2, max_length=120)
    cuisine: str = "International"


class ChatMessageIn(BaseModel):
    message: str = Field(min_length=1, max_length=500)
    context: dict | None = None


class ChatSuggestion(BaseModel):
    label: str


class ChatMessageOut(BaseModel):
    reply: str
    suggestions: list[str] = []


class ImageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    image_url: str
    sort_order: int
    created_at: datetime


class GalleryReorderIn(BaseModel):
    items: list[int] = Field(min_length=1)

class ImageCreate(BaseModel):
    image_url: str = Field(min_length=1, max_length=500)

class UserUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    avatar_url: str | None = None
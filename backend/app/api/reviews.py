"""Avis clients sur les restaurants."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models import Order, OrderStatus, Restaurant, Review, User
from app.schemas import ReviewCreate, ReviewRead

router = APIRouter(prefix="/restaurants", tags=["Avis"])


@router.get("/{restaurant_id}/reviews", response_model=list[ReviewRead])
def list_reviews(restaurant_id: int, db: Session = Depends(get_db)):
    restaurant = db.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant introuvable.")

    reviews = (
        db.query(Review)
        .options(joinedload(Review.user))
        .filter(Review.restaurant_id == restaurant_id)
        .order_by(Review.created_at.desc())
        .all()
    )
    result = []
    for r in reviews:
        result.append(
            ReviewRead(
                id=r.id,
                rating=r.rating,
                comment=r.comment,
                created_at=r.created_at,
                author={"id": r.user.id, "full_name": r.user.full_name},
            )
        )
    return result


@router.post("/{restaurant_id}/reviews", response_model=ReviewRead, status_code=201)
def create_review(
    restaurant_id: int,
    payload: ReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    restaurant = db.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant introuvable.")

    delivered = (
        db.query(Order)
        .filter(
            Order.client_id == current_user.id,
            Order.restaurant_id == restaurant_id,
            Order.status == OrderStatus.delivered.value,
        )
        .first()
    )
    if not delivered:
        raise HTTPException(
            status_code=403,
            detail="Vous ne pouvez laisser un avis qu'après une commande livrée.",
        )

    existing = (
        db.query(Review)
        .filter(Review.user_id == current_user.id, Review.restaurant_id == restaurant_id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Vous avez déjà laissé un avis pour ce restaurant.")

    review = Review(
        restaurant_id=restaurant_id,
        user_id=current_user.id,
        rating=payload.rating,
        comment=payload.comment.strip(),
    )
    db.add(review)
    db.flush()

    stats = (
        db.query(func.avg(Review.rating), func.count(Review.id))
        .filter(Review.restaurant_id == restaurant_id)
        .first()
    )
    avg = float(stats[0] or 0)
    count = int(stats[1] or 0)
    restaurant.rating = round(avg, 1)
    restaurant.review_count = count
    db.commit()
    db.refresh(review)
    return ReviewRead(
        id=review.id,
        rating=review.rating,
        comment=review.comment,
        created_at=review.created_at,
        author={"id": current_user.id, "full_name": current_user.full_name},
    )

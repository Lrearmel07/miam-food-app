"""Chatbot Miam pour aider les clients."""

from __future__ import annotations

import re
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models import Order, Product, Restaurant, User
from app.schemas import ChatMessageIn, ChatMessageOut

router = APIRouter(prefix="/chat", tags=["Chatbot"])


def _normalize(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^\w\sàâäéèêëîïôöùûüç']", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


@router.post("/message", response_model=ChatMessageOut)
def chat_message(
    payload: ChatMessageIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Message vide.")

    norm = _normalize(message)
    hour = datetime.now().hour
    greeting = "Bonjour" if hour < 18 else "Bonsoir"

    restaurants = db.query(Restaurant).all()
    product_count = db.query(func.count(Product.id)).scalar() or 0
    open_count = sum(1 for r in restaurants if r.is_open)

    orders = (
        db.query(Order)
        .filter(Order.client_id == current_user.id)
        .order_by(Order.created_at.desc())
        .limit(3)
        .all()
    )
    active_orders = [
        o for o in orders if o.status in ("pending", "preparing", "shipping", "accepted", "ready")
    ]

    if any(word in norm for word in ["bonjour", "bonsoir", "salut", "hey"]):
        return ChatMessageOut(
            reply=(
                f"{greeting} {current_user.full_name.split(' ')[0]} ! Je suis **MiamBot**.\n\n"
                "Je peux t'aider pour : restaurants, menu, commande, suivi ou délais."
            ),
            suggestions=[
                "Voir les restaurants proches",
                "Quels plats sont populaires ?",
                "Comment suivre ma commande ?",
                "Quels sont les délais de livraison ?",
            ],
        )

    if any(word in norm for word in ["restaurant", "resto", "proche", "autour", "plateau", "cocody", "yopougon", "treichville"]):
        if not restaurants:
            return ChatMessageOut(reply="Aucun restaurant disponible pour le moment.", suggestions=["Revenir à l'accueil"])
        names = ", ".join(r.name for r in restaurants[:5])
        return ChatMessageOut(
            reply=f"Nous avons **{len(restaurants)} restaurant(s)** à Abidjan dont **{open_count} ouvert(s)**.\n\n{names}\n\nActive **Me localiser** pour trier par distance.",
            suggestions=["Voir les plats du jour", "Me localiser", "Passer une commande"],
        )

    if any(word in norm for word in ["menu", "plat", "manger", "repas", "bissap", "attieke", "alloco", "thieboudienne", "mafe", "yassa"]):
        return ChatMessageOut(
            reply=f"Notre carte compte **{product_count} plat(s)**.\n\nAttiéké poisson braisé, Poulet braisé alloco, Thiéboudienne, Mafé de bœuf, Yassa poulet, Brochettes, Alloco, Jus de bissap, Jus de gingembre, Dégué/Thiakry.\n\nClique sur un plat pour voir sa fiche détaillée.",
            suggestions=["Voir Chez Mama", "Voir Maquis du Plateau", "Trouver des boissons"],
        )

    if any(word in norm for word in ["commander", "panier", "ajouter", "valider"]):
        return ChatMessageOut(
            reply="1) Choisis un restaurant\n2) Ajoute tes plats\n3) Ouvre le panier et valide\n4) Indique ton adresse et confirme\n\nUn panier ne peut contenir que des plats du même restaurant.",
            suggestions=["Ouvrir mon panier", "Choisir un restaurant"],
        )

    if any(word in norm for word in ["suivre", "suivi", "livreur", "arrive", "en livraison"]):
        if active_orders:
            o = active_orders[0]
            return ChatMessageOut(reply=f"Commande **#{o.id}** en statut **{o.status}**.\n\nOnglet **Commandes > Suivre** pour voir la carte en temps réel.", suggestions=["Suivre ma commande", "Mes commandes"])
        if orders:
            o = orders[0]
            return ChatMessageOut(reply=f"Dernière commande **#{o.id}** : **{o.status}**.\n\nDès qu'elle passe en livraison, le bouton Suivre apparaît.", suggestions=["Mes commandes"])
        return ChatMessageOut(reply="Tu n'as pas encore de commande.", suggestions=["Voir les restaurants"])

    if any(word in norm for word in ["delai", "temps", "frais", "minutes"]):
        return ChatMessageOut(reply="Délai estimé : **20 à 35 minutes**.\n\nFrais de livraison et minimum varient par restaurant et s'affichent avant validation.", suggestions=["Me localiser", "Voir les restaurants proches"])

    if any(word in norm for word in ["merci"]):
        return ChatMessageOut(reply="De rien ! Bon appétit 😊", suggestions=["Commander à nouveau"])

    return ChatMessageOut(
        reply="Dis-moi ce dont tu as besoin : restaurants, menu, commande ou suivi.",
        suggestions=["Voir les restaurants proches", "Comment passer commande ?", "Comment suivre ma commande ?"],
    )

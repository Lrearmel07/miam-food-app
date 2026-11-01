"""Données de démonstration pour Miam (Abidjan)."""

import json
from datetime import datetime, timedelta

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import Order, OrderItem, OrderStatus, OrderTracking, Product, Restaurant, Role, Review, User


def seed_database() -> None:
    db = SessionLocal()
    try:
        if db.query(User).count():
            return

        def user(email: str, name: str, role: str, phone: str | None = None) -> User:
            u = User(
                email=email,
                password_hash=hash_password("demo1234"),
                full_name=name,
                phone=phone,
                role=role,
                is_active=True,
            )
            db.add(u)
            db.flush()
            return u

        admin = user("admin@miam.app", "Awa Koné", Role.admin.value, "+225 07 00 00 00 01")
        partner = user("partner@miam.app", "Mama Adjoua", Role.partner.value, "+225 07 00 00 00 02")
        courier = user("courier@miam.app", "Karim Diallo", Role.courier.value, "+225 07 00 00 00 03")
        client = user("client@miam.app", "Aminata Touré", Role.client.value, "+225 07 00 00 00 04")
        client2 = user("amina@miam.app", "Amina Bakayoko", Role.client.value, "+225 07 00 00 00 05")
        db.flush()

        zones = [
            {"zone": "Plateau", "fee": 1000},
            {"zone": "Cocody", "fee": 1000},
            {"zone": "Riviera Palmeraie", "fee": 1200},
            {"zone": "Zone 4", "fee": 1200},
            {"zone": "Angré", "fee": 1300},
            {"zone": "Treichville", "fee": 1300},
            {"zone": "Yopougon", "fee": 1500},
        ]
        zones_json = json.dumps(zones, ensure_ascii=False)

        restaurants = [
            Restaurant(
                name="Chez Mama",
                description="Cuisine ivoirienne généreuse : attiéké, poisson braisé, sauces maison.",
                cuisine="Ivoirien",
                emoji="",
                image_url="https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=80&auto=format",
                cover_image_url="https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?w=1600&q=80&auto=format",
                color="#FF7A45",
                rating=4.9,
                review_count=0,
                delivery_fee=1000,
                min_order=5000,
                eta_min=25,
                address="Rue L88, Cocody Angré, Abidjan",
                latitude=5.3965,
                longitude=-3.9675,
                is_open=True,
                opening_hours="09:00 - 22:00",
                delivery_zones=zones_json,
                promo_text="Attiéké + poisson braisé dès 7500 FCFA",
                promo_badge="-10% COCO",
                owner_id=partner.id,
            ),
            Restaurant(
                name="Maquis du Plateau",
                description="Le maquis de référence. Grillades, brochettes, alloco et ambiance ivoirienne.",
                cuisine="Grillades",
                emoji="",
                image_url="https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=80&auto=format&fit=crop",
                cover_image_url="https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1600&q=80&auto=format&fit=crop",
                color="#B91C1C",
                rating=4.9,
                review_count=0,
                delivery_fee=1000,
                min_order=4000,
                eta_min=20,
                address="Boulevard de la République, Plateau, Abidjan",
                latitude=5.3200,
                longitude=-4.0200,
                is_open=True,
                opening_hours="11:00 - 23:00",
                delivery_zones=zones_json,
                promo_text="Brochettes + alloco à partager",
                promo_badge="POPULAIRE",
                owner_id=partner.id,
            ),
            Restaurant(
                name="Baobab & Saveurs",
                description="Saveurs d'Afrique de l'Ouest : thiéboudienne, mafé, yassa.",
                cuisine="Ouest-africain",
                emoji="",
                image_url="https://images.unsplash.com/photo-1547592180-85f173990554?w=1200&q=80&auto=format",
                cover_image_url="https://images.unsplash.com/photo-1512058564366-18510be2db19?w=1600&q=80&auto=format",
                color="#22C55E",
                rating=4.8,
                review_count=0,
                delivery_fee=1000,
                min_order=5000,
                eta_min=25,
                address="Avenue Chardy, Cocody, Abidjan",
                latitude=5.3010,
                longitude=-3.9950,
                is_open=True,
                opening_hours="09:00 - 21:00",
                delivery_zones=zones_json,
                promo_text="Thiéboudienne maison tous les jours",
                promo_badge="MAISON",
                owner_id=partner.id,
            ),
            Restaurant(
                name="Green Bowl",
                description="Bowls frais, légumes locaux, jus naturels. Rapide et sain.",
                cuisine="Healthy local",
                emoji="",
                image_url="https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=80&auto=format",
                cover_image_url="https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=1600&q=80&auto=format",
                color="#14B8A6",
                rating=4.7,
                review_count=0,
                delivery_fee=1000,
                min_order=4000,
                eta_min=18,
                address="Riviera 3, Cocody, Abidjan",
                latitude=5.3470,
                longitude=-3.9530,
                is_open=True,
                opening_hours="08:00 - 20:00",
                delivery_zones=zones_json,
                promo_text="Bowl frais - Idéal midi",
                promo_badge="SAIN",
                owner_id=partner.id,
            ),
            Restaurant(
                name="Sweet Abidjan",
                description="Douceurs ivoiriennes : dégué, thiakry, beignets, jus frais.",
                cuisine="Desserts",
                emoji="",
                image_url="https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=1200&q=80&auto=format",
                cover_image_url="https://images.unsplash.com/photo-1488477181946-6428a0291777?w=1600&q=80&auto=format",
                color="#F59E0B",
                rating=4.9,
                review_count=0,
                delivery_fee=800,
                min_order=2000,
                eta_min=15,
                address="Boulevard Lagunaire, Marcory Zone 4, Abidjan",
                latitude=5.2930,
                longitude=-4.0100,
                is_open=True,
                opening_hours="10:00 - 22:00",
                delivery_zones=zones_json,
                promo_text="Jus de bissap glacé bien frais",
                promo_badge="GLACÉ",
                owner_id=partner.id,
            ),
        ]
        for r in restaurants:
            db.add(r)
        db.flush()

        def prod(restaurant: Restaurant, name: str, desc: str, price: float, cat: str, img: str, prep: int = 15):
            p = Product(
                restaurant_id=restaurant.id,
                name=name,
                description=desc,
                price=price,
                category=cat,
                emoji="",
                image_url=img,
                is_available=True,
                prep_time=prep,
            )
            db.add(p)
            return p

        imgs = {
            "attieke": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80&auto=format",
            "poisson": "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800&q=80&auto=format",
            "poulet": "https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=800&q=80&auto=format",
            "alloco": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800&q=80&auto=format",
            "brochette": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800&q=80&auto=format",
            "thiebou": "https://images.unsplash.com/photo-1547592180-85f173990554?w=800&q=80&auto=format",
            "mafe": "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800&q=80&auto=format",
            "yassa": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800&q=80&auto=format",
            "bowl": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80&auto=format",
            "bissap": "https://images.unsplash.com/photo-1546554137-f86b9593a222?w=800&q=80&auto=format",
            "gingembre": "https://images.unsplash.com/photo-1546554137-f86b9593a222?w=800&q=80&auto=format",
            "degue": "https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800&q=80&auto=format",
        }

        chez = restaurants[0]
        maquis = restaurants[1]
        baobab = restaurants[2]
        green = restaurants[3]
        sweet = restaurants[4]

        prod(chez, "Attiéké poisson braisé", "Attiéké, poisson braisé, tomates, oignons et piment.", 7500, "Plats", imgs["attieke"], 20)
        prod(chez, "Poulet braisé alloco", "Poulet mariné, alloco doré et sauce piment maison.", 8500, "Plats", imgs["poulet"], 25)
        prod(chez, "Sauce claire de poisson", "Poisson frais, tomate, aubergine et riz parfumé.", 7000, "Plats", imgs["poisson"], 25)
        prod(chez, "Jus de bissap", "Hibiscus frais, gingembre et menthe.", 1500, "Boissons", imgs["bissap"], 5)
        prod(chez, "Beignets de banane", "Banane douce, farine et sucre vanillé.", 2000, "Desserts", imgs["degue"], 10)

        prod(maquis, "Poisson braisé entier", "Poisson entier braisé, attiéké et sauce tomate pimentée.", 9000, "Grillades", imgs["poisson"], 25)
        prod(maquis, "Poulet braisé piment", "Poulet mariné au piment, alloco et oignons grillés.", 8000, "Grillades", imgs["poulet"], 25)
        prod(maquis, "Brochettes de bœuf", "Brochettes marinées, sauce arachide et alloco.", 5000, "Grillades", imgs["brochette"], 15)
        prod(maquis, "Alloco", "Bananes plantains dorées et sauce piment.", 2500, "Accompagnements", imgs["alloco"], 10)
        prod(maquis, "Jus de gingembre", "Gingembre frais, citron et sucre de canne.", 1500, "Boissons", imgs["gingembre"], 5)

        prod(baobab, "Thiéboudienne", "Riz au poisson, légumes et sauce tomate au tamarin.", 8500, "Plats", imgs["thiebou"], 30)
        prod(baobab, "Mafé de bœuf", "Bœuf fondant, sauce arachide et riz parfumé.", 8000, "Plats", imgs["mafe"], 30)
        prod(baobab, "Yassa poulet", "Poulet, oignons citronnés et riz basmati.", 7500, "Plats", imgs["yassa"], 25)
        prod(baobab, "Jus de bissap", "Hibiscus, gingembre et menthe fraîche.", 1500, "Boissons", imgs["bissap"], 5)
        prod(baobab, "Thiakry", "Semoule de mil, lait caillé et vanille.", 2500, "Desserts", imgs["degue"], 10)

        prod(green, "Bowl Attiéké Végé", "Attiéké, avocat, tomate, concombre et citron.", 6500, "Plats", imgs["bowl"], 10)
        prod(green, "Bowl Poulet Grillé", "Poulet grillé, quinoa, légumes frais et vinaigrette.", 7500, "Plats", imgs["bowl"], 12)
        prod(green, "Salade Coco Fraîche", "Salade, noix de coco, ananas et citron vert.", 5500, "Plats", imgs["bowl"], 8)
        prod(green, "Jus de gingembre", "Gingembre frais, citron et menthe.", 1500, "Boissons", imgs["gingembre"], 5)
        prod(green, "Jus de bissap", "Hibiscus glacé maison.", 1500, "Boissons", imgs["bissap"], 5)

        prod(sweet, "Dégué", "Semoule de mil fermentée, yaourt sucré et vanille.", 2000, "Desserts", imgs["degue"], 5)
        prod(sweet, "Thiakry", "Semoule de mil, lait caillé doux et muscade.", 2000, "Desserts", imgs["degue"], 5)
        prod(sweet, "Beignets", "Beignets dorés, croustillants et moelleux.", 1500, "Desserts", imgs["degue"], 10)
        prod(sweet, "Jus de bissap glacé", "Hibiscus, gingembre, menthe bien frais.", 1500, "Boissons", imgs["bissap"], 5)
        prod(sweet, "Jus de mangue", "Mangue fraîche pressée.", 1500, "Boissons", imgs["bissap"], 5)

        db.flush()

        def getp(r, name):
            return db.query(Product).filter(Product.restaurant_id == r.id, Product.name == name).first()

        reviews = [
            Review(restaurant_id=chez.id, user_id=client.id, rating=5, comment="Attiéké poisson braisé parfait, très généreux !"),
            Review(restaurant_id=chez.id, user_id=client2.id, rating=5, comment="Sauces maison excellentes, livraison rapide."),
            Review(restaurant_id=maquis.id, user_id=client.id, rating=5, comment="Meilleur maquis du Plateau, brochettes top."),
            Review(restaurant_id=maquis.id, user_id=client2.id, rating=4, comment="Alloco croustillant, ambiance garantie."),
            Review(restaurant_id=baobab.id, user_id=client.id, rating=5, comment="Thiéboudienne authentique comme à Dakar."),
            Review(restaurant_id=green.id, user_id=client2.id, rating=4, comment="Bowl frais et léger, parfait midi."),
            Review(restaurant_id=sweet.id, user_id=client.id, rating=5, comment="Bissap glacé délicieux, dégué onctueux."),
        ]
        for rv in reviews:
            db.add(rv)
        db.flush()

        for r in restaurants:
            stats = db.query(__import__('sqlalchemy').func.avg(Review.rating), __import__('sqlalchemy').func.count(Review.id)).filter(Review.restaurant_id == r.id).first()
            if stats and stats[0]:
                r.rating = round(float(stats[0]), 1)
                r.review_count = int(stats[1] or 0)

        db.commit()
    finally:
        db.close()

"""Tests de bout en bout de l'API Miam."""

import uuid

from tests.conftest import auth, login


def _new_client(client) -> tuple[str, dict]:
    email = f"test-{uuid.uuid4().hex[:8]}@miam.app"
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "secret123",
            "full_name": "Client Test",
            "phone": "+225 07 11 22 33 44",
        },
    )
    assert response.status_code == 201, response.text
    data = response.json()
    return data["access_token"], data["user"]


def _menu(client, restaurant_id: int) -> list[dict]:
    response = client.get(f"/api/v1/restaurants/{restaurant_id}/menu")
    assert response.status_code == 200, response.text
    return response.json()


def _restaurant_id(client, name: str) -> int:
    response = client.get("/api/v1/restaurants")
    assert response.status_code == 200
    return next(item["id"] for item in response.json() if item["name"] == name)


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_login_me_and_bad_password(client, tokens):
    for role in ("admin", "partner", "courier", "client"):
        response = client.get("/api/v1/auth/me", headers=auth(tokens[role]))
        assert response.status_code == 200, response.text
        assert response.json()["role"] == role

    bad = client.post(
        "/api/v1/auth/login",
        json={"email": "client@miam.app", "password": "mauvais"},
    )
    assert bad.status_code == 401

    anonymous = client.get("/api/v1/auth/me")
    assert anonymous.status_code == 401

    invalid = client.get("/api/v1/auth/me", headers=auth("fake.token.here"))
    assert invalid.status_code == 401


def test_register_and_duplicate_email(client):
    token, user = _new_client(client)
    assert user["role"] == "client"
    me = client.get("/api/v1/auth/me", headers=auth(token))
    assert me.status_code == 200
    assert me.json()["email"] == user["email"]

    duplicate = client.post(
        "/api/v1/auth/register",
        json={
            "email": user["email"],
            "password": "secret123",
            "full_name": "Doublon",
        },
    )
    assert duplicate.status_code == 409


def test_catalog(client):
    restaurants = client.get("/api/v1/restaurants").json()
    assert len(restaurants) == 5
    assert all("product_count" in item for item in restaurants)
    assert all(item["product_count"] > 0 for item in restaurants)

    search = client.get("/api/v1/restaurants", params={"q": "baobab"}).json()
    assert len(search) == 1
    assert search[0]["name"] == "Baobab & Saveurs"

    cuisines = client.get("/api/v1/cuisines").json()
    assert "Ivoirien" in cuisines and "Ouest-africain" in cuisines

    baobab_id = search[0]["id"]
    menu = _menu(client, baobab_id)
    assert len(menu) == 5
    assert all(item["restaurant_id"] == baobab_id for item in menu)

    missing = client.get("/api/v1/restaurants/9999")
    assert missing.status_code == 404
    missing_menu = client.get("/api/v1/restaurants/9999/menu")
    assert missing_menu.status_code == 404


def test_restaurants_are_sorted_by_distance(client):
    nearby = client.get(
        "/api/v1/restaurants",
        params={"latitude": 5.3200, "longitude": -4.0200},
    )
    assert nearby.status_code == 200, nearby.text
    restaurants = nearby.json()
    assert len(restaurants) == 5
    assert all(item["latitude"] is not None for item in restaurants)
    assert all(item["longitude"] is not None for item in restaurants)
    assert restaurants[0]["name"] == "Maquis du Plateau"
    assert restaurants[0]["distance_km"] == 0
    distances = [item["distance_km"] for item in restaurants]
    assert distances == sorted(distances)

    partial = client.get(
        "/api/v1/restaurants", params={"latitude": 5.3200}
    )
    assert partial.status_code == 422

    detail = client.get(
        f"/api/v1/restaurants/{restaurants[0]['id']}",
        params={"latitude": 5.3200, "longitude": -4.0200},
    )
    assert detail.status_code == 200
    assert detail.json()["distance_km"] == 0


def test_client_order_and_cancel(client):
    token, _ = _new_client(client)
    green_id = _restaurant_id(client, "Green Bowl")
    menu = _menu(client, green_id)
    bowl = next(item for item in menu if item["name"] == "Bol attiéké avocat")
    smoothie = next(
        item for item in menu if item["name"] == "Smoothie mangue-gingembre"
    )

    response = client.post(
        "/api/v1/orders",
        headers=auth(token),
        json={
            "restaurant_id": green_id,
            "items": [
                {"product_id": bowl["id"], "quantity": 1},
                {"product_id": smoothie["id"], "quantity": 1},
            ],
            "address": "Riviera Palmeraie, Cocody, Abidjan",
            "notes": "Sans glaçons",
        },
    )
    assert response.status_code == 201, response.text
    order = response.json()
    assert order["status"] == "pending"
    assert order["subtotal"] == 10000.0
    assert order["delivery_fee"] == 1000.0
    assert order["total"] == 11000.0
    assert len(order["items"]) == 2
    assert order["client"]["full_name"] == "Client Test"

    mine = client.get("/api/v1/orders", headers=auth(token)).json()
    assert any(item["id"] == order["id"] for item in mine)

    cancel = client.post(f"/api/v1/orders/{order['id']}/cancel", headers=auth(token))
    assert cancel.status_code == 200
    assert cancel.json()["status"] == "cancelled"

    again = client.post(f"/api/v1/orders/{order['id']}/cancel", headers=auth(token))
    assert again.status_code == 409


def test_order_validation(client):
    token, _ = _new_client(client)
    maquis_id = _restaurant_id(client, "Maquis du Plateau")
    mama_id = _restaurant_id(client, "Chez Mama")
    maquis_menu = _menu(client, maquis_id)
    alloco = next(item for item in maquis_menu if item["name"] == "Alloco")
    too_small = client.post(
        "/api/v1/orders",
        headers=auth(token),
        json={
            "restaurant_id": maquis_id,
            "items": [{"product_id": alloco["id"], "quantity": 1}],
            "address": "Plateau, Abidjan",
        },
    )
    assert too_small.status_code == 400
    assert "Minimum" in too_small.json()["detail"]

    wrong_restaurant = client.post(
        "/api/v1/orders",
        headers=auth(token),
        json={
            "restaurant_id": mama_id,
            "items": [{"product_id": alloco["id"], "quantity": 1}],
            "address": "Cocody Angré, Abidjan",
        },
    )
    assert wrong_restaurant.status_code == 400

    empty_items = client.post(
        "/api/v1/orders",
        headers=auth(token),
        json={
            "restaurant_id": mama_id,
            "items": [],
            "address": "Cocody Angré, Abidjan",
        },
    )
    assert empty_items.status_code == 422


def test_role_guards(client, tokens):
    forbidden = client.post(
        "/api/v1/orders",
        headers=auth(tokens["courier"]),
        json={
            "restaurant_id": 1,
            "items": [{"product_id": 1, "quantity": 1}],
            "address": "Plateau, Abidjan",
        },
    )
    assert forbidden.status_code == 403

    admin_denied = client.get("/api/v1/admin/stats", headers=auth(tokens["client"]))
    assert admin_denied.status_code == 403

    partner_denied = client.get(
        "/api/v1/courier/available", headers=auth(tokens["partner"])
    )
    assert partner_denied.status_code == 403


def test_full_order_lifecycle(client, tokens):
    client_token, _ = _new_client(client)
    mama_id = _restaurant_id(client, "Chez Mama")
    menu = _menu(client, mama_id)
    attieke = next(
        item for item in menu if item["name"] == "Attiéké poisson braisé"
    )

    created = client.post(
        "/api/v1/orders",
        headers=auth(client_token),
        json={
            "restaurant_id": mama_id,
            "items": [{"product_id": attieke["id"], "quantity": 1}],
            "address": "Riviera Palmeraie, Cocody, Abidjan",
        },
    )
    assert created.status_code == 201, created.text
    order_id = created.json()["id"]

    partner_orders = client.get(
        "/api/v1/orders", headers=auth(tokens["partner"])
    ).json()
    assert any(item["id"] == order_id for item in partner_orders)

    tracking = client.get(
        f"/api/v1/orders/{order_id}/tracking",
        headers=auth(client_token),
    )
    assert tracking.status_code == 200, tracking.text
    initial_tracking = tracking.json()
    assert initial_tracking["status"] == "pending"
    assert initial_tracking["restaurant"]["latitude"] != 0
    assert initial_tracking["delivery"]["latitude"] != 0
    assert initial_tracking["courier"] is None
    assert initial_tracking["distance_remaining_km"] > 0

    partner_tracking = client.get(
        f"/api/v1/orders/{order_id}/tracking",
        headers=auth(tokens["partner"]),
    )
    assert partner_tracking.status_code == 200

    other_token, _ = _new_client(client)
    denied_tracking = client.get(
        f"/api/v1/orders/{order_id}/tracking",
        headers=auth(other_token),
    )
    assert denied_tracking.status_code == 403

    for target in ("accepted", "preparing", "ready"):
        updated = client.patch(
            f"/api/v1/partner/orders/{order_id}/status",
            headers=auth(tokens["partner"]),
            json={"status": target},
        )
        assert updated.status_code == 200, updated.text
        assert updated.json()["status"] == target

    invalid = client.patch(
        f"/api/v1/partner/orders/{order_id}/status",
        headers=auth(tokens["partner"]),
        json={"status": "preparing"},
    )
    assert invalid.status_code == 409

    available = client.get(
        "/api/v1/courier/available", headers=auth(tokens["courier"])
    ).json()
    assert any(item["id"] == order_id for item in available)

    accepted = client.post(
        f"/api/v1/courier/orders/{order_id}/accept",
        headers=auth(tokens["courier"]),
    )
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["status"] == "shipping"
    assert accepted.json()["courier"]["full_name"] == "Karim Diallo"

    shipping_tracking = client.get(
        f"/api/v1/orders/{order_id}/tracking",
        headers=auth(client_token),
    )
    assert shipping_tracking.status_code == 200
    shipping_body = shipping_tracking.json()
    assert shipping_body["courier"]["full_name"] == "Karim Diallo"
    assert shipping_body["courier"]["latitude"] is not None
    assert shipping_body["courier"]["longitude"] is not None

    moved = client.patch(
        f"/api/v1/courier/orders/{order_id}/location",
        headers=auth(tokens["courier"]),
        json={"latitude": 5.3650, "longitude": -3.9450},
    )
    assert moved.status_code == 200, moved.text
    assert moved.json()["courier"]["latitude"] == 5.3650
    assert moved.json()["courier"]["longitude"] == -3.9450
    assert moved.json()["distance_remaining_km"] < shipping_body["distance_remaining_km"]

    partner_location = client.patch(
        f"/api/v1/courier/orders/{order_id}/location",
        headers=auth(tokens["partner"]),
        json={"latitude": 5.3650, "longitude": -3.9450},
    )
    assert partner_location.status_code == 403

    bad_location = client.patch(
        f"/api/v1/courier/orders/{order_id}/location",
        headers=auth(tokens["courier"]),
        json={"latitude": 123, "longitude": -4.02},
    )
    assert bad_location.status_code == 422

    second_accept = client.post(
        f"/api/v1/courier/orders/{order_id}/accept",
        headers=auth(tokens["courier"]),
    )
    assert second_accept.status_code == 409

    delivered = client.post(
        f"/api/v1/courier/orders/{order_id}/deliver",
        headers=auth(tokens["courier"]),
    )
    assert delivered.status_code == 200, delivered.text
    assert delivered.json()["status"] == "delivered"

    final_tracking = client.get(
        f"/api/v1/orders/{order_id}/tracking",
        headers=auth(client_token),
    )
    assert final_tracking.status_code == 200
    final_body = final_tracking.json()
    assert final_body["status"] == "delivered"
    assert final_body["distance_remaining_km"] == 0
    assert final_body["courier"]["latitude"] == final_body["delivery"]["latitude"]
    assert final_body["courier"]["longitude"] == final_body["delivery"]["longitude"]

    stats = client.get("/api/v1/courier/stats", headers=auth(tokens["courier"]))
    assert stats.status_code == 200
    assert stats.json()["delivered"] >= 1
    assert stats.json()["earnings"] >= 1.99


def test_partner_dashboard_and_products(client, tokens):
    restaurant = client.get(
        "/api/v1/partner/restaurant", headers=auth(tokens["partner"])
    )
    assert restaurant.status_code == 200
    assert restaurant.json()["name"] == "Chez Mama"

    stats = client.get("/api/v1/partner/stats", headers=auth(tokens["partner"]))
    assert stats.status_code == 200
    assert set(stats.json()) >= {
        "orders_today",
        "pending",
        "products",
        "revenue",
        "rating",
    }

    created = client.post(
        "/api/v1/partner/products",
        headers=auth(tokens["partner"]),
        json={
            "name": "Plat Test",
            "description": "Créé par pytest",
            "price": 9500.0,
            "category": "Plats",
            "emoji": "🍲",
        },
    )
    assert created.status_code == 201, created.text
    product_id = created.json()["id"]

    updated = client.patch(
        f"/api/v1/partner/products/{product_id}",
        headers=auth(tokens["partner"]),
        json={"price": 11000.0, "is_available": False},
    )
    assert updated.status_code == 200
    assert updated.json()["price"] == 11000.0
    assert updated.json()["is_available"] is False

    public_menu = _menu(client, restaurant.json()["id"])
    assert all(item["id"] != product_id for item in public_menu)

    deleted = client.delete(
        f"/api/v1/partner/products/{product_id}",
        headers=auth(tokens["partner"]),
    )
    assert deleted.status_code == 204


def test_admin_supervision(client, tokens):
    stats = client.get("/api/v1/admin/stats", headers=auth(tokens["admin"]))
    assert stats.status_code == 200
    body = stats.json()
    assert body["restaurants"] == 5
    assert body["clients"] >= 2
    assert body["couriers"] >= 2

    users = client.get("/api/v1/admin/users", headers=auth(tokens["admin"]))
    assert users.status_code == 200
    assert len(users.json()) >= 8

    email = f"partner-{uuid.uuid4().hex[:8]}@miam.app"
    created = client.post(
        "/api/v1/admin/partners",
        headers=auth(tokens["admin"]),
        json={
            "email": email,
            "password": "secret123",
            "full_name": "Nouveau Partenaire",
            "restaurant_name": "Table Test",
            "cuisine": "Fusion",
        },
    )
    assert created.status_code == 201, created.text
    partner_id = created.json()["id"]

    duplicate = client.post(
        "/api/v1/admin/partners",
        headers=auth(tokens["admin"]),
        json={
            "email": email,
            "password": "secret123",
            "full_name": "Doublon",
            "restaurant_name": "Table Bis",
        },
    )
    assert duplicate.status_code == 409

    partner_token = login(client, email, "secret123")
    restaurant = client.get(
        "/api/v1/partner/restaurant", headers=auth(partner_token)
    )
    assert restaurant.status_code == 200
    assert restaurant.json()["name"] == "Table Test"
    assert restaurant.json()["latitude"] is not None
    assert restaurant.json()["longitude"] is not None

    disabled = client.patch(
        f"/api/v1/admin/users/{partner_id}/active",
        headers=auth(tokens["admin"]),
        json={"is_active": False},
    )
    assert disabled.status_code == 200
    assert disabled.json()["is_active"] is False

    blocked_login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "secret123"},
    )
    assert blocked_login.status_code == 403

    enabled = client.patch(
        f"/api/v1/admin/users/{partner_id}/active",
        headers=auth(tokens["admin"]),
        json={"is_active": True},
    )
    assert enabled.status_code == 200

    orders = client.get("/api/v1/admin/orders", headers=auth(tokens["admin"]))
    assert orders.status_code == 200
    assert len(orders.json()) >= 5

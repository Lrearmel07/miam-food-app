"""Coordonnées et calculs de distance pour les lieux Miam."""

from __future__ import annotations

import hashlib
import math

from app.models import Restaurant

RESTAURANT_LOCATIONS: dict[str, tuple[float, float]] = {
    "rue l88, cocody angré, abidjan": (5.3965, -3.9675),
    "boulevard lagunaire, plateau, abidjan": (5.3200, -4.0200),
    "rue du canal, zone 4, marcory, abidjan": (5.3010, -3.9950),
    "riviera 3, cocody, abidjan": (5.3470, -3.9530),
    "avenue 21, treichville, abidjan": (5.2930, -4.0100),
}

DELIVERY_LOCATIONS: dict[str, tuple[float, float]] = {
    "riviera palmeraie, cocody, abidjan": (5.3590, -3.9380),
    "zone 4, marcory, abidjan": (5.2980, -3.9950),
    "angré 8e tranche, cocody, abidjan": (5.4010, -3.9650),
    "treichville, abidjan": (5.2920, -4.0090),
    "yopougon niangon, abidjan": (5.3380, -4.0810),
    "10 rue du test, cocody, abidjan": (5.3500, -3.9800),
    "22 avenue du cycle, cocody, abidjan": (5.3450, -3.9900),
}


def _fallback_point(seed: str) -> tuple[float, float]:
    digest = hashlib.sha1(seed.encode("utf-8")).digest()
    lat_offset = (int.from_bytes(digest[:4], "big") % 2001 - 1000) / 100000
    lng_offset = (int.from_bytes(digest[4:8], "big") % 2001 - 1000) / 100000
    return round(5.3167 + lat_offset, 6), round(-4.0333 + lng_offset, 6)


def restaurant_coordinates(name: str, address: str | None) -> tuple[float, float]:
    safe_address = (address or "").strip()
    key = safe_address.lower()
    if key in RESTAURANT_LOCATIONS:
        return RESTAURANT_LOCATIONS[key]
    return _fallback_point(f"{name}|{safe_address}")


def restaurant_point(restaurant: Restaurant) -> tuple[float, float]:
    if restaurant.latitude is not None and restaurant.longitude is not None:
        return restaurant.latitude, restaurant.longitude
    return restaurant_coordinates(restaurant.name, restaurant.address)


def delivery_point(address: str) -> tuple[float, float]:
    key = address.strip().lower()
    if key in DELIVERY_LOCATIONS:
        return DELIVERY_LOCATIONS[key]
    return _fallback_point(address)


def point_along(
    start: tuple[float, float],
    end: tuple[float, float],
    fraction: float,
) -> tuple[float, float]:
    ratio = max(0.0, min(1.0, fraction))
    return (
        round(start[0] + (end[0] - start[0]) * ratio, 6),
        round(start[1] + (end[1] - start[1]) * ratio, 6),
    )


def distance_km(
    start: tuple[float, float],
    end: tuple[float, float],
) -> float:
    radius = 6371.0
    lat1, lng1 = map(math.radians, start)
    lat2, lng2 = map(math.radians, end)
    delta_lat = lat2 - lat1
    delta_lng = lng2 - lng1
    value = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lng / 2) ** 2
    )
    return radius * 2 * math.asin(math.sqrt(value))

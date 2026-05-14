"""Helpers for inventory HTTP responses (field naming differs across services/clients)."""


def inventory_check_is_available(payload):
    """True if inventory check JSON says stock is available.

    inventory-service uses ``available``; some callers/tests use ``is_available``.
    """
    if not isinstance(payload, dict):
        return False
    if payload.get("is_available") is True:
        return True
    if payload.get("available") is True:
        return True
    return False

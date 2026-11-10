"""Wysyłka wiadomości e-mail."""
import logging

from azure.communication.email import EmailClient

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger("jewelrunner.email")


def _unavailable() -> AppError:
    return AppError(503, "email_unavailable", "Nie udało się wysłać wiadomości. Spróbuj ponownie później.")


def _send_acs(to: str, subject: str, body: str) -> None:
    settings = get_settings()
    if not settings.acs_connection_string or not settings.email_sender:
        logger.error("Brak ACS_CONNECTION_STRING lub EMAIL_SENDER")
        raise _unavailable()
    message = {
        "senderAddress": settings.email_sender,
        "recipients": {"to": [{"address": to}]},
        "content": {"subject": subject, "plainText": body},
    }
    try:
        # Usługa przyjmuje wiadomość od razu, a dostarcza ją w tle; nie czekamy na doręczenie.
        EmailClient.from_connection_string(settings.acs_connection_string).begin_send(message)
    except Exception as exc:
        # Np. limit domeny zarządzanej (10 wiadomości na godzinę). Treść wiadomości zawiera token, więc jej nie logujemy.
        logger.error("Wysyłka e-maila nie powiodła się: %s", type(exc).__name__)
        raise _unavailable() from exc


def send_email(to: str, subject: str, body: str) -> None:
    settings = get_settings()
    if settings.email_backend == "acs":
        _send_acs(to, subject, body)
        return
    if settings.email_backend == "console" and settings.environment == "development":
        logger.warning("E-mail do %s | %s\n%s", to, subject, body)
        return
    raise _unavailable()

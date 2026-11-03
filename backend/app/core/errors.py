"""Wspólny format błędów API: {"error": {"code", "message", "details"}}."""
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import OperationalError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import get_settings

logger = logging.getLogger("jewelrunner")

HTTP_CODES = {
    401: "unauthorized",
    403: "forbidden",
    404: "not_found",
    405: "method_not_allowed",
}


class AppError(Exception):
    """Błąd biznesowy z kodem, na podstawie którego portal pokazuje komunikat."""

    def __init__(self, status_code: int, code: str, message: str, details: object = None):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def error_response(status_code: int, code: str, message: str, details: object = None) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"error": {"code": code, "message": message, "details": details}},
    )


async def catch_unhandled(request: Request, call_next):
    """Działa wewnątrz CORS, więc portal może odczytać także odpowiedź 500."""
    try:
        return await call_next(request)
    except Exception:
        logger.exception("Nieobsłużony błąd: %s %s", request.method, request.url.path)
        return error_response(500, "internal_error", "Wystąpił błąd serwera. Spróbuj ponownie później.")


SAFE_METHODS = {"GET", "HEAD", "OPTIONS"}


async def check_origin(request: Request, call_next):
    """Cookie sesji jest wysyłane automatycznie, więc inna strona nie może wywoływać zmian w imieniu gracza."""
    origin = request.headers.get("origin")
    if request.method not in SAFE_METHODS and origin and origin not in get_settings().cors_origin_list:
        return error_response(403, "forbidden", "Niedozwolone źródło żądania.")
    return await call_next(request)


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def handle_app_error(_: Request, exc: AppError) -> JSONResponse:
        return error_response(exc.status_code, exc.code, exc.message, exc.details)

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        return error_response(exc.status_code, HTTP_CODES.get(exc.status_code, "http_error"), str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        # Bez pola "input", żeby odpowiedź nie odsyłała haseł z formularzy.
        fields = [
            {"field": ".".join(str(part) for part in error["loc"][1:]), "message": error["msg"]}
            for error in exc.errors()
        ]
        return error_response(422, "validation_error", "Niepoprawne dane.", fields)

    @app.exception_handler(OperationalError)
    async def handle_database_error(request: Request, exc: OperationalError) -> JSONResponse:
        logger.error("Baza danych niedostępna: %s %s: %s", request.method, request.url.path, type(exc.orig).__name__)
        return error_response(503, "database_unavailable", "Serwis jest chwilowo niedostępny.")

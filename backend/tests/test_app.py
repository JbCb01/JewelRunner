from fastapi.testclient import TestClient
from pydantic import BaseModel

from app.core.errors import AppError
from app.main import create_app

ORIGIN = "http://localhost:5173"


class Body(BaseModel):
    password: str
    age: int


def build_client() -> TestClient:
    app = create_app()

    @app.get("/test/boom")
    def boom():
        raise RuntimeError("tajny szczegół")

    @app.get("/test/business")
    def business():
        raise AppError(409, "email_taken", "Adres jest już zarejestrowany.", {"field": "email"})

    @app.post("/test/body")
    def body(_: Body):
        return {}

    return TestClient(app)


client = build_client()


def test_unknown_path_uses_common_error_format():
    response = client.get("/api/brak")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_wrong_method_uses_common_error_format():
    assert client.delete("/api/health").json()["error"]["code"] == "method_not_allowed"


def test_business_error():
    response = client.get("/test/business")
    assert response.status_code == 409
    assert response.json() == {
        "error": {"code": "email_taken", "message": "Adres jest już zarejestrowany.", "details": {"field": "email"}}
    }


def test_validation_error_lists_fields_and_hides_input():
    response = client.post("/test/body", json={"password": "SekretneHaslo1", "age": "x"})
    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert error["details"][0]["field"] == "age"
    assert "SekretneHaslo1" not in response.text


def test_unhandled_error_hides_details_and_keeps_cors_header():
    response = client.get("/test/boom", headers={"Origin": ORIGIN})
    assert response.status_code == 500
    assert response.json()["error"]["code"] == "internal_error"
    assert "tajny" not in response.text
    assert response.headers["access-control-allow-origin"] == ORIGIN


def test_cors_allows_portal_with_cookies():
    response = client.options(
        "/api/health", headers={"Origin": ORIGIN, "Access-Control-Request-Method": "GET"}
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == ORIGIN
    assert response.headers["access-control-allow-credentials"] == "true"


def test_cors_rejects_other_origin():
    response = client.options(
        "/api/health", headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "GET"}
    )
    assert "access-control-allow-origin" not in response.headers


def test_health_returns_503_when_database_is_unavailable():
    response = client.get("/api/health")
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "database_unavailable"


def test_login_rejects_too_long_password_before_database():
    response = client.post("/api/auth/login", json={"email": "a@example.com", "password": "x" * 129})
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_cross_site_post_is_rejected_before_handling():
    response = client.post(
        "/api/auth/logout", headers={"Origin": "https://evil.example"}
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "forbidden"


def test_openapi_is_available():
    assert client.get("/api/openapi.json").status_code == 200




def test_portal_is_served_with_spa_fallback(tmp_path, monkeypatch):
    from app.core.config import get_settings

    (tmp_path / "index.html").write_text("<h1>portal</h1>", encoding="utf-8")
    (tmp_path / "assets").mkdir()
    (tmp_path / "assets" / "app.js").write_text("console.log(1)", encoding="utf-8")
    (tmp_path.parent / "tajny.txt").write_text("sekret", encoding="utf-8")
    monkeypatch.setenv("PORTAL_DIST", str(tmp_path))
    get_settings.cache_clear()
    try:
        portal = TestClient(create_app())
        assert "portal" in portal.get("/").text
        assert "portal" in portal.get("/wyzwania/1").text
        assert portal.get("/assets/app.js").text == "console.log(1)"
        assert "sekret" not in portal.get("/..%2Ftajny.txt").text
        response = portal.get("/api/nie-ma")
        assert response.status_code == 404
        assert response.json()["error"]["code"] == "not_found"
        assert portal.get("/api/health").status_code == 503
    finally:
        get_settings.cache_clear()

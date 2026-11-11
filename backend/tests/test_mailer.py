import pytest

from app.core.config import get_settings
from app.core.errors import AppError
from app.services import mailer


@pytest.fixture
def acs(monkeypatch):
    monkeypatch.setenv("EMAIL_BACKEND", "acs")
    monkeypatch.setenv("ACS_CONNECTION_STRING", "endpoint=https://test.communication.azure.com/;accesskey=eA==")
    monkeypatch.setenv("EMAIL_SENDER", "DoNotReply@test.azurecomm.net")
    get_settings.cache_clear()
    yield monkeypatch
    get_settings.cache_clear()


class FakeClient:
    sent: list = []
    error: Exception | None = None

    @classmethod
    def from_connection_string(cls, conn_str):
        assert conn_str.startswith("endpoint=")
        return cls()

    def begin_send(self, message):
        if FakeClient.error:
            raise FakeClient.error
        FakeClient.sent.append(message)


@pytest.fixture
def fake_client(monkeypatch):
    FakeClient.sent = []
    FakeClient.error = None
    monkeypatch.setattr(mailer, "EmailClient", FakeClient)
    return FakeClient


def test_acs_sends_plain_text_message(acs, fake_client):
    mailer.send_email("gracz@example.com", "Temat", "Treść z linkiem")
    assert fake_client.sent == [
        {
            "senderAddress": "DoNotReply@test.azurecomm.net",
            "recipients": {"to": [{"address": "gracz@example.com"}]},
            "content": {"subject": "Temat", "plainText": "Treść z linkiem"},
        }
    ]


def test_acs_failure_becomes_503_without_leaking_details(acs, fake_client, caplog):
    fake_client.error = RuntimeError("tajny token w treści")
    with pytest.raises(AppError) as error:
        mailer.send_email("gracz@example.com", "Temat", "token=abc")
    assert error.value.status_code == 503 and error.value.code == "email_unavailable"
    assert "token" not in caplog.text


def test_acs_without_configuration_is_503(acs, fake_client):
    acs.setenv("EMAIL_SENDER", "")
    get_settings.cache_clear()
    with pytest.raises(AppError):
        mailer.send_email("gracz@example.com", "Temat", "Treść")
    assert fake_client.sent == []


def test_console_works_only_in_development(monkeypatch):
    monkeypatch.setenv("EMAIL_BACKEND", "console")
    monkeypatch.setenv("ENVIRONMENT", "production")
    get_settings.cache_clear()
    try:
        with pytest.raises(AppError):
            mailer.send_email("gracz@example.com", "Temat", "Treść")
    finally:
        get_settings.cache_clear()

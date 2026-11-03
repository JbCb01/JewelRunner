from functools import lru_cache
from typing import Literal

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str
    cors_origins: str = "http://localhost:5173"
    environment: str = "development"
    session_ttl_hours: int = 168
    portal_url: str = "http://localhost:5173"
    # Folder ze zbudowanym portalem. Po ustawieniu API i portal działają pod jednym adresem.
    portal_dist: str = ""
    email_backend: Literal["console", "none", "acs"] = "none"
    # Azure Communication Services: connection string i adres nadawcy z domeny zarządzanej
    acs_connection_string: str = ""
    email_sender: str = ""
    session_cookie_samesite: Literal["lax", "strict", "none"] = "lax"

    @field_validator("cors_origins")
    @classmethod
    def reject_wildcard(cls, value: str) -> str:
        if "*" in value:
            raise ValueError("CORS_ORIGINS nie może zawierać '*', bo API używa cookies")
        return value

    @property
    def session_cookie_secure(self) -> bool:
        return self.environment != "development"

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

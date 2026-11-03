"""Modele ORM odwzorowują tabele z migracji. Schemat zmieniamy tylko migracjami Alembica."""
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Text, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.types import DateTime


class Base(DeclarativeBase):
    pass


class Gracz(Base):
    __tablename__ = "gracz"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    nazwa_uzytkownika: Mapped[str] = mapped_column(Text)
    email: Mapped[str] = mapped_column(Text)
    skrot_hasla: Mapped[str] = mapped_column(Text)
    status_konta: Mapped[str] = mapped_column(Text, server_default="aktywne")
    liczba_nieudanych_logowan: Mapped[int] = mapped_column(server_default="0")
    zablokowany_do: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    data_ostatniego_logowania: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    data_modyfikacji: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))


class SesjaLogowania(Base):
    __tablename__ = "sesja_logowania"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    gracz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gracz.id"))
    skrot_tokenu: Mapped[str] = mapped_column(Text)
    urzadzenie: Mapped[str] = mapped_column(Text)
    data_wygasniecia: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    data_uniewaznienia: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class StatystykiGracza(Base):
    __tablename__ = "statystyki_gracza"

    gracz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gracz.id"), primary_key=True)
    laczny_czas_gry_s: Mapped[int] = mapped_column(BigInteger, server_default="0")
    liczba_ukonczonych_poziomow: Mapped[int] = mapped_column(server_default="0")
    liczba_pokonanych_wrogow: Mapped[int] = mapped_column(server_default="0")
    liczba_porazek: Mapped[int] = mapped_column(server_default="0")
    najdluzsze_combo: Mapped[int] = mapped_column(server_default="0")


class PortfelGracza(Base):
    __tablename__ = "portfel_gracza"

    gracz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gracz.id"), primary_key=True)


class ElementPersonalizacji(Base):
    __tablename__ = "element_personalizacji"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    typ: Mapped[str] = mapped_column(Text)
    nazwa: Mapped[str] = mapped_column(Text)
    czy_domyslny: Mapped[bool] = mapped_column()


class PosiadanyElement(Base):
    __tablename__ = "posiadany_element"

    gracz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gracz.id"), primary_key=True)
    element_id: Mapped[int] = mapped_column(ForeignKey("element_personalizacji.id"), primary_key=True)


class WygladPostaci(Base):
    __tablename__ = "wyglad_postaci"

    gracz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gracz.id"), primary_key=True)
    skorka_id: Mapped[int] = mapped_column(ForeignKey("element_personalizacji.id"))
    kolor_id: Mapped[int] = mapped_column(ForeignKey("element_personalizacji.id"))


class TokenZmianyEmaila(Base):
    __tablename__ = "token_zmiany_emaila"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    gracz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gracz.id"))
    nowy_email: Mapped[str] = mapped_column(Text)
    skrot_wartosci: Mapped[str] = mapped_column(Text)
    data_waznosci: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    czy_uzyty: Mapped[bool] = mapped_column(server_default="false")



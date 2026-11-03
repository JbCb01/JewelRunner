from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse

from app.core.errors import AppError


def register_portal(app: FastAPI, dist: Path) -> None:
    """Serwuje zbudowany portal. Musi być dodane po routerach API."""
    root = dist.resolve()
    index = root / "index.html"
    if not index.is_file():
        raise RuntimeError(f"Brak zbudowanego portalu w {root}")

    @app.get("/{path:path}", include_in_schema=False)
    def serve_portal(path: str) -> FileResponse:
        if path == "api" or path.startswith("api/"):
            raise AppError(404, "not_found", "Not Found")
        candidate = (root / path).resolve()
        if candidate.is_relative_to(root) and candidate.is_file():
            return FileResponse(candidate)
        # Adresy portalu, np. /wyzwania/1, obsługuje router po stronie przeglądarki.
        return FileResponse(index)

"""Buduje jewelrunner.zip do wdrożenia: backend i zbudowany portal. Uruchamiać z folderu backend."""
import shutil
import subprocess
import zipfile
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
PORTAL = BACKEND.parent / "portal"
OUTPUT = BACKEND.parent / "jewelrunner.zip"
INCLUDE = ["app", "alembic", "db", "scripts", "deploy", "alembic.ini", "requirements.txt"]
# Dane przykładowe zawierają konta ze znanym hasłem, więc nie trafiają na serwer.
EXCLUDE_NAMES = {"__pycache__", "002_dane_przykladowe.sql", "seed_dev.py", "AZURE.md", "provision.sh", "email.sh", "build_package.py"}


def files(path: Path):
    if path.is_file():
        yield path
        return
    for item in sorted(path.rglob("*")):
        if item.is_file() and not EXCLUDE_NAMES.intersection(item.relative_to(BACKEND).parts):
            yield item


def main() -> None:
    subprocess.run([shutil.which("npm"), "run", "build"], cwd=PORTAL, check=True)
    with zipfile.ZipFile(OUTPUT, "w", zipfile.ZIP_DEFLATED) as package:
        for name in INCLUDE:
            for item in files(BACKEND / name):
                package.write(item, item.relative_to(BACKEND).as_posix())
        for item in sorted((PORTAL / "dist").rglob("*")):
            if item.is_file():
                package.write(item, "portal_dist/" + item.relative_to(PORTAL / "dist").as_posix())
    print(f"Gotowe: {OUTPUT}")


if __name__ == "__main__":
    main()

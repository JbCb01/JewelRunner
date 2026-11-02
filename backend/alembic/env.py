from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine

from app.core.config import get_settings

if context.config.config_file_name:
    fileConfig(context.config.config_file_name)

engine = create_engine(get_settings().database_url)

with engine.connect() as connection:
    context.configure(connection=connection)
    with context.begin_transaction():
        context.run_migrations()

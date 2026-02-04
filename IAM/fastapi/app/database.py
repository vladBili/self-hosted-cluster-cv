from typing import Annotated, TypeAlias
from fastapi import Depends
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

DATABASE_URL = "postgresql://fastapi_user:fastapi_password@postgres.postgres.svc.cluster.local:5432/postgres"

engine = create_engine(DATABASE_URL)

# SQLAlchemy
def get_session():
    with Session(engine) as session:
        yield session

# FastAPI
SessionDep: TypeAlias = Annotated[Session, Depends(get_session)]




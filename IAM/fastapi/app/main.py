from fastapi import FastAPI
from sqlalchemy import select
from app.database import SessionDep
from app.models import Test

app = FastAPI()

@app.get("/")
def read_all(session: SessionDep):
    stmt = select(Test)
    users = session.execute(stmt).scalars().all()
    return users
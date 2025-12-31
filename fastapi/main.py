from fastapi import FastAPI
from datetime import datetime
import uvicorn
import os
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

app = FastAPI(
    title="Docker API AWS",
    description="API con healthcheck",
    version="1.0.0"
)

# Configuración de base de datos
DB_HOST = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT = os.getenv("POSTGRES_PORT", "5432")
DB_NAME = os.getenv("POSTGRES_DB", "postgres")
DB_USER = os.getenv("POSTGRES_USER", "postgres")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"


def get_db_engine():
    """Crea y retorna una instancia del engine de SQLAlchemy"""
    return create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=5, max_overflow=10)



@app.get("/")
async def root():
    """Endpoint principal"""
    return {
        "message": "Bienvenido a Docker API AWS",
        "status": "running"
    }


@app.get("/health")
async def healthcheck():
    """Endpoint de healthcheck para verificar el estado de la aplicación"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "docker-api-aws",
        "version": "1.0.0",
        "app": "fastapi"
    }


@app.get("/health/db")
async def db_healthcheck():
    """Endpoint de healthcheck para verificar la conexión a la base de datos PostgreSQL"""
    db_status = {
        "database": "postgresql",
        "host": DB_HOST,
        "port": DB_PORT,
        "database_name": DB_NAME,
        "timestamp": datetime.now().isoformat()
    }

    try:
        engine = get_db_engine()
        with engine.connect() as connection:
            # Ejecutar una consulta simple para verificar la conexión
            result = connection.execute(text("SELECT version()"))
            version = result.scalar()

            # Verificar si la base de datos está respondiendo
            connection.execute(text("SELECT 1"))

            db_status.update({
                "status": "healthy",
                "connected": True,
                "postgres_version": version,
                "message": "Conexión a base de datos exitosa"
            })
            return db_status

    except OperationalError as e:
        db_status.update({
            "status": "unhealthy",
            "connected": False,
            "error": str(e),
            "message": "Error al conectar con la base de datos"
        })
        return db_status
    except Exception as e:
        db_status.update({
            "status": "unhealthy",
            "connected": False,
            "error": str(e),
            "message": "Error inesperado al verificar la base de datos"
        })
        return db_status



if __name__ == '__main__':
    uvicorn.run(app, host="0.0.0.0", port=3000)

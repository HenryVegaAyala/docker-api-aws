from fastapi import FastAPI
from datetime import datetime
import uvicorn

app = FastAPI(
    title="Docker API AWS",
    description="API con healthcheck",
    version="1.0.0"
)


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
        "version": "1.0.0"
    }


if __name__ == '__main__':
    uvicorn.run(app, host="0.0.0.0", port=8000)

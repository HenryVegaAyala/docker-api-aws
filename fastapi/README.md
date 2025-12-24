# Docker API AWS

API FastAPI con healthcheck para despliegue en AWS.

## Características

- ✅ Endpoint de healthcheck (`/health`)
- ✅ API REST con FastAPI
- ✅ Dockerizado
- ✅ Listo para AWS

## Endpoints

### GET /
Endpoint principal de bienvenida.

**Respuesta:**
```json
{
  "message": "Bienvenido a Docker API AWS",
  "status": "running"
}
```

### GET /health
Endpoint de healthcheck para verificar el estado de la aplicación.

**Respuesta:**
```json
{
  "status": "healthy",
  "timestamp": "2025-12-23T10:30:00",
  "service": "docker-api-aws",
  "version": "1.0.0"
}
```

## Instalación y Ejecución

### Local (sin Docker)

1. Instalar dependencias:
```bash
pip install -r requirements.txt
```

2. Ejecutar la aplicación:
```bash
python main.py
```

La aplicación estará disponible en: `http://localhost:8000`

### Con Docker

1. Construir la imagen:
```bash
docker build -t docker-api-aws .
```

2. Ejecutar el contenedor:
```bash
docker run -d -p 8000:8000 --name api-container docker-api-aws
```

3. Verificar el healthcheck:
```bash
docker ps
```

4. Probar la API:
```bash
curl http://localhost:8000/health
```

## Documentación API

FastAPI genera documentación automática:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Despliegue en AWS

Este proyecto está listo para ser desplegado en:
- AWS ECS (Elastic Container Service)
- AWS EKS (Elastic Kubernetes Service)
- AWS App Runner
- AWS Elastic Beanstalk

El healthcheck en `/health` puede ser utilizado por AWS Load Balancer para verificar la salud de los contenedores.


# Docker API AWS - Node.js

API desarrollada con Express.js que incluye healthcheck para despliegue en AWS usando Docker.

## Características

- ✅ API REST con Express.js
- ✅ Endpoint de healthcheck
- ✅ Dockerfile optimizado con Alpine Linux
- ✅ Configuración lista para producción
- ✅ Healthcheck automático en contenedor

## Requisitos

- Node.js 20+
- Docker (opcional)

## Instalación

### Instalación local

```bash
# Instalar dependencias
npm install

# Ejecutar en modo desarrollo
npm run dev

# Ejecutar en modo producción
npm start
```

### Instalación con Docker

```bash
# Construir la imagen
docker build -t docker-api-aws-nodejs .

# Ejecutar el contenedor
docker run -p 8000:8000 docker-api-aws-nodejs
```

## Endpoints

### GET /

Endpoint principal de la API.

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
  "timestamp": "2025-12-23T10:00:00.000Z",
  "service": "docker-api-aws",
  "version": "1.0.0"
}
```

## Pruebas

### Local

```bash
# Endpoint principal
curl http://localhost:8000/

# Healthcheck
curl http://localhost:8000/health
```

### Docker

```bash
# Endpoint principal
curl http://localhost:8000/

# Healthcheck
curl http://localhost:8000/health

# Ver logs del contenedor
docker logs <container-id>

# Ver el estado del healthcheck
docker inspect --format='{{.State.Health.Status}}' <container-id>
```

## Variables de entorno

- `PORT`: Puerto en el que se ejecuta la aplicación (por defecto: 8000)

## Estructura del proyecto

```
nodejs/
├── index.js           # Aplicación Express
├── package.json       # Dependencias de Node.js
├── Dockerfile         # Definición de la imagen Docker
├── .dockerignore      # Archivos excluidos de la imagen
└── README.md          # Documentación
```

## Despliegue en AWS

Esta aplicación está lista para ser desplegada en:
- AWS ECS (Elastic Container Service)
- AWS Fargate
- AWS EC2 con Docker

El healthcheck configurado en el Dockerfile permite a AWS verificar automáticamente el estado del contenedor.


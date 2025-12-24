const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware para parsear JSON
app.use(express.json());

/**
 * Endpoint principal
 */
app.get('/', (req, res) => {
  res.json({
    message: 'Bienvenido a Docker API AWS',
    status: 'running'
  });
});

/**
 * Endpoint de healthcheck para verificar el estado de la aplicación
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'docker-api-aws',
    version: '1.0.0',
    app: 'nodejs'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor corriendo en http://0.0.0.0:${PORT}`);
  console.log(`📋 API: Docker API AWS v1.0.0`);
  console.log(`✅ Healthcheck disponible en /health`);
});


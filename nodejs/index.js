const express = require('express');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3000;

// Configuración de base de datos
const DB_HOST = process.env.POSTGRES_HOST || 'localhost';
const DB_PORT = process.env.POSTGRES_PORT || '5432';
const DB_NAME = process.env.POSTGRES_DB || 'postgres';
const DB_USER = process.env.POSTGRES_USER || 'postgres';
const DB_PASSWORD = process.env.POSTGRES_PASSWORD || 'postgres';

// Pool de conexiones a PostgreSQL
const pool = new Pool({
  host: DB_HOST,
  port: DB_PORT,
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASSWORD,
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

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

/**
 * Endpoint de healthcheck para verificar la conexión a la base de datos PostgreSQL
 */
app.get('/health/db', async (req, res) => {
  const dbStatus = {
    database: 'postgresql',
    host: DB_HOST,
    port: DB_PORT,
    database_name: DB_NAME,
    timestamp: new Date().toISOString()
  };

  let client;
  try {
    // Obtener un cliente del pool
    client = await pool.connect();

    // Ejecutar una consulta simple para verificar la conexión
    const versionResult = await client.query('SELECT version()');
    const version = versionResult.rows[0].version;

    // Verificar si la base de datos está respondiendo
    await client.query('SELECT 1');

    dbStatus.status = 'healthy';
    dbStatus.connected = true;
    dbStatus.postgres_version = version;
    dbStatus.message = 'Conexión a base de datos exitosa';

    res.json(dbStatus);
  } catch (error) {
    dbStatus.status = 'unhealthy';
    dbStatus.connected = false;
    dbStatus.error = error.message;

    if (error.code) {
      dbStatus.error_code = error.code;
    }

    if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
      dbStatus.message = 'Error al conectar con la base de datos';
    } else {
      dbStatus.message = 'Error inesperado al verificar la base de datos';
    }

    res.json(dbStatus);
  } finally {
    // Liberar el cliente de vuelta al pool
    if (client) {
      client.release();
    }
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor corriendo en http://0.0.0.0:${PORT}`);
  console.log(`📋 API: Docker API AWS v1.0.0`);
  console.log(`✅ Healthcheck disponible en /health`);
});


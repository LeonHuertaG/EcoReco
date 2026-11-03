const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth.routes');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Rutas API
app.use('/api/auth', authRoutes);

// Ruta de prueba de salud de la API
app.get('/api/health', (req, res) => {
  res.json({ ok: true, mensaje: 'API EcoReco activa y respondiendo' });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor ejecutándose en http://0.0.0.0:${PORT}`);
});
const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '1234',
  database: process.env.DB_NAME || 'eco_reco',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});


pool.getConnection()
  .then(connection => {
    console.log('Conexión exitosa a MySQL (eco_reco)');
    connection.release();
  })
  .catch(err => {
    console.error('Error de conexión a la Base de Datos:', err.message);
  });

module.exports = pool;
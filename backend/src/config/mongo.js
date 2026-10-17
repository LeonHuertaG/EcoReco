
const mongoose = require('mongoose');

let connecting;

async function connectMongo({ autoIndex = process.env.NODE_ENV !== 'production' } = {}) {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (connecting) return connecting;

  const uri = process.env.MONGODB_URI;

  if (!uri) {
    throw new Error(
      'Falta configurar MONGODB_URI en backend/.env.'
    );
  }

  connecting = mongoose.connect(uri, {
    dbName: process.env.MONGODB_DB || 'ecoreco',
    serverSelectionTimeoutMS: 15000,
    autoIndex,
  })
    .then(({ connection }) => {
      console.log(`MongoDB conectado: ${connection.name}`);
      return connection;
    })
    .catch(error => {
      connecting = null;
      throw error;
    });

  return connecting;
}

async function disconnectMongo() {
  await mongoose.disconnect();
  connecting = null;
}

module.exports = {
  mongoose,
  connectMongo,
  disconnectMongo,
};

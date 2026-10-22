
require('dotenv').config();

const { randomBytes, scrypt } = require('node:crypto');
const { promisify } = require('node:util');

const {
  connectMongo,
  disconnectMongo,
} = require('../src/config/mongo');

const models = require('../src/models');

const derive = promisify(scrypt);

async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');

  const hash = (
    await derive(password, salt, 64)
  ).toString('hex');

  return `scrypt:${salt}:${hash}`;
}

async function seedRoles() {
  const roles = [
    {
      codigo: 1,
      nombre: 'Administrador',
      descripcion: 'Acceso total al sistema.',
    },
    {
      codigo: 2,
      nombre: 'Operaciones',
      descripcion: 'Gestión comercial, agenda y rutas.',
    },
    {
      codigo: 3,
      nombre: 'Chofer / Cobrador',
      descripcion: 'Atención de paradas, cobros y cortes.',
    },
    {
      codigo: 4,
      nombre: 'Cliente',
      descripcion: 'Consulta y seguimiento de servicios.',
    },
  ];

  for (const role of roles) {
    await models.Role.updateOne(
      { codigo: role.codigo },
      {
        $setOnInsert: {
          ...role,
          activo: true,
        },
      },
      { upsert: true }
    );
  }
}

async function seedCatalogs() {
  const shifts = [
    {
      nombre: 'Matutino',
      horaInicio: '08:00',
      horaFin: '14:00',
      descripcion: 'Turno matutino.',
    },
    {
      nombre: 'Vespertino',
      horaInicio: '14:00',
      horaFin: '20:00',
      descripcion: 'Turno vespertino.',
    },
  ];

  const methods = [
    {
      nombre: 'Efectivo',
      descripcion: 'Pago en efectivo.',
    },
    {
      nombre: 'Transferencia',
      descripcion: 'Transferencia bancaria.',
    },
    {
      nombre: 'Tarjeta',
      descripcion: 'Pago con tarjeta.',
    },
  ];

  for (const shift of shifts) {
    await models.Shift.updateOne(
      { nombre: shift.nombre },
      {
        $setOnInsert: {
          ...shift,
          activo: true,
        },
      },
      { upsert: true }
    );
  }

  for (const method of methods) {
    await models.PaymentMethod.updateOne(
      { nombre: method.nombre },
      {
        $setOnInsert: {
          ...method,
          activo: true,
        },
      },
      { upsert: true }
    );
  }
}

async function seedAdministrator() {
  const username = (
    process.env.ADMIN_USERNAME || ''
  ).trim();

  const password = process.env.ADMIN_PASSWORD || '';

  if (!username || password.length < 8) {
    throw new Error(
      'Configura ADMIN_USERNAME y ADMIN_PASSWORD ' +
      '(mínimo 8 caracteres) en backend/.env.'
    );
  }

  const usernameNormalizado = username.toLowerCase();

  const existing = await models.User.findOne({
    usuarioNormalizado: usernameNormalizado,
  });

  if (existing) {
    console.log(
      `La cuenta administradora "${username}" ya existe; no se modificó.`
    );
    return;
  }

  const role = await models.Role.findOne({
    codigo: 1,
    activo: true,
  });

  const email = (
    process.env.ADMIN_EMAIL || ''
  ).trim().toLowerCase() || null;

  await models.User.create({
    rolId: role._id,
    usuario: username,
    usuarioNormalizado: usernameNormalizado,
    nombre: (
      process.env.ADMIN_NAME ||
      'Administrador EcoReco'
    ).trim(),
    correo: email,
    correoNormalizado: email,
    passwordHash: await hashPassword(password),
    activo: true,
  });

  console.log(`Cuenta administradora creada: ${username}`);
}

async function createCollectionsAndIndexes() {
  for (const Model of Object.values(models)) {
    try {
      await Model.createCollection();
    } catch (error) {
      if (
        error.code !== 48 &&
        error.codeName !== 'NamespaceExists'
      ) {
        throw error;
      }
    }

    await Model.createIndexes();
  }
}

async function main() {
  await connectMongo();

  await createCollectionsAndIndexes();
  await seedRoles();
  await seedCatalogs();
  await seedAdministrator();

  console.log(
    'Base de datos EcoReco inicializada correctamente.'
  );
}

main()
  .catch(error => {
    console.error(
      'No se pudo inicializar MongoDB:',
      error.message
    );

    process.exitCode = 1;
  })
  .finally(async () => {
    await disconnectMongo();
  });

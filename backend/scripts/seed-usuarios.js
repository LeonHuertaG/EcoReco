require('dotenv').config();

const { randomBytes, scrypt } = require('node:crypto');
const { promisify } = require('node:util');

const { connectMongo, disconnectMongo } = require('../src/config/mongo');
const models = require('../src/models');

const derive = promisify(scrypt);

async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = (await derive(password, salt, 64)).toString('hex');
  return `scrypt:${salt}:${hash}`;
}

async function main() {
  await connectMongo();

  const passwordHash = await hashPassword('EcoReco123');

  const usuariosPrueba = [
    {
      codigoRol: 1,
      usuario: 'admin1',
      nombre: 'Administrador General',
      correo: 'admin@ecoreco.com',
    },
    {
      codigoRol: 2,
      usuario: 'vendedor1',
      nombre: 'Martín Vendedor',
      correo: 'martinv@gmail.com',
    },
    {
      codigoRol: 3,
      usuario: 'cobrador1',
      nombre: 'Josepe Cobrador',
      correo: 'josepec@gmail.com',
    },
    {
      codigoRol: 4,
      usuario: 'cliente1',
      nombre: 'Erick Cliente',
      correo: 'erickcl@gmail.com',
    },
  ];

  for (const item of usuariosPrueba) {
    const rol = await models.Role.findOne({ codigo: item.codigoRol, activo: true });
    if (!rol) {
      throw new Error(`No existe el rol con codigo ${item.codigoRol}. Corre primero init-mongodb.js`);
    }

    const userDoc = await models.User.findOneAndUpdate(
      { usuarioNormalizado: item.usuario.toLowerCase() },
      {
        $set: {
          rolId: rol._id,
          usuario: item.usuario,
          usuarioNormalizado: item.usuario.toLowerCase(),
          nombre: item.nombre,
          correo: item.correo.toLowerCase(),
          correoNormalizado: item.correo.toLowerCase(),
          passwordHash,
          activo: true,
        },
      },
      { upsert: true, new: true }
    );

    // Si es Chofer/Cobrador (rol 3), le creamos su perfil en 'choferes'
    if (item.codigoRol === 3) {
      await models.Driver.findOneAndUpdate(
        { cuentaId: userDoc._id },
        {
          $set: {
            cuentaId: userDoc._id,
            nombre: item.nombre,
            telefono: '4770001234',
            numeroLicencia: 'LIC-GTO-2024-9872',
            vencimientoLicencia: '2028-12-31',
            fechaIngreso: '2024-01-15',
            activo: true,
          },
        },
        { upsert: true }
      );
    }

    // Si es Cliente (rol 4), le creamos su perfil en 'clientes'
    if (item.codigoRol === 4) {
      await models.Client.findOneAndUpdate(
        { cuentaId: userDoc._id },
        {
          $set: {
            cuentaId: userDoc._id,
            nombre: item.nombre,
            telefono: '4721234567',
            correo: item.correo.toLowerCase(),
            razonSocial: 'Hospital Médica San José S.A. de C.V.',
            rfc: 'EKU9003173C9',
            direccion: 'Pedro Moreno #110, Centro, León, Gto.',
            codigoPostal: '37000',
            activo: true,
          },
        },
        { upsert: true }
      );
    }

    console.log(`✅ Listo: ${item.usuario} (Rol ${item.codigoRol})`);
  }

  console.log('\n🎉 Todos los usuarios creados con contraseña: EcoReco123');
}

main()
  .catch((err) => {
    console.error('❌ Error:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await disconnectMongo();
  });
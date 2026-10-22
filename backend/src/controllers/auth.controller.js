
const {
  scrypt,
  timingSafeEqual,
} = require('node:crypto');

const { promisify } = require('node:util');

const { User } = require('../models');
const { createSession } = require('../middleware/session');

const derive = promisify(scrypt);

async function verifyPassword(password, storedHash) {
  if (typeof storedHash !== 'string') {
    return false;
  }

  const parts = storedHash.split(':');

  if (parts.length !== 3 || parts[0] !== 'scrypt') {
    return false;
  }

  const [, salt, hash] = parts;

  if (
    !/^[a-f0-9]{32}$/.test(salt) ||
    !/^[a-f0-9]{128}$/.test(hash)
  ) {
    return false;
  }

  const calculated = await derive(password, salt, 64);
  const expected = Buffer.from(hash, 'hex');

  return timingSafeEqual(calculated, expected);
}

exports.login = async (req, res, next) => {
  const usuario = req.body?.usuario;
  const pass = req.body?.pass;

  if (
    typeof usuario !== 'string' ||
    !usuario.trim() ||
    usuario.length > 255 ||
    typeof pass !== 'string' ||
    !pass ||
    pass.length > 1024
  ) {
    return res.status(400).json({
      ok: false,
      mensaje: 'Credenciales inválidas.',
    });
  }

  try {
    const identifier = usuario.trim().toLowerCase();

    const account = await User.findOne({
      $or: [
        { usuarioNormalizado: identifier },
        { correoNormalizado: identifier },
      ],
    })
      .select('+passwordHash')
      .populate('rolId');

    if (
      !account ||
      !account.activo ||
      !account.rolId ||
      !account.rolId.activo
    ) {
      return res.status(401).json({
        ok: false,
        mensaje: 'Usuario o contraseña incorrectos.',
      });
    }

    const valid = await verifyPassword(
      pass,
      account.passwordHash
    );

    if (!valid) {
      return res.status(401).json({
        ok: false,
        mensaje: 'Usuario o contraseña incorrectos.',
      });
    }

    const user = {
      pk_usuario: account._id.toString(),
      fk_rol: Number(account.rolId.codigo),
      usuario: account.usuario,
      nombre: account.nombre,
      correo: account.correo || '',
      estado: 1,
    };

    const token = await createSession(account._id);

    return res.json({
      ok: true,
      mensaje: 'Inicio de sesión exitoso',
      usuario: user,
      token,
    });
  } catch (error) {
    return next(error);
  }
};

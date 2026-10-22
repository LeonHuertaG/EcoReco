
const {
  randomBytes,
  createHash,
} = require('node:crypto');

const { Session, User } = require('../models');

const DURATION = 8 * 60 * 60 * 1000;

function hashToken(token) {
  return createHash('sha256')
    .update(token)
    .digest('hex');
}

async function createSession(userId) {
  const token = randomBytes(32).toString('hex');

  await Session.create({
    tokenHash: hashToken(token),
    userId,
    expiresAt: new Date(Date.now() + DURATION),
  });

  return token;
}

function authorize(requiredRole) {
  return async (req, res, next) => {
    const match = req.get('authorization')
      ?.match(/^Bearer ([a-f0-9]{64})$/i);

    if (!match) {
      return res.status(401).json({
        mensaje: 'Inicia sesión nuevamente.',
      });
    }

    const token = match[1].toLowerCase();

    try {
      const session = await Session.findOne({
        tokenHash: hashToken(token),
        expiresAt: { $gt: new Date() },
      });

      if (!session) {
        return res.status(401).json({
          mensaje: 'La sesión expiró. Inicia sesión nuevamente.',
        });
      }

      const account = await User.findById(session.userId)
        .populate('rolId');

      if (
        !account ||
        !account.activo ||
        !account.rolId ||
        !account.rolId.activo
      ) {
        await Session.deleteOne({ _id: session._id });

        return res.status(401).json({
          mensaje: 'La cuenta ya no está disponible.',
        });
      }

      const role = Number(account.rolId.codigo);

      if (requiredRole && role !== requiredRole) {
        return res.status(403).json({
          mensaje: 'Acceso denegado.',
        });
      }

      req.user = {
        pk_usuario: account._id.toString(),
        fk_rol: role,
        usuario: account.usuario,
        nombre: account.nombre,
        correo: account.correo || '',
        estado: 1,
      };

      req.token = token;
      req.sessionId = session._id;

      return next();
    } catch (error) {
      return next(error);
    }
  };
}

async function endSession(req, res, next) {
  try {
    await Session.deleteOne({
      tokenHash: hashToken(req.token),
    });

    return res.sendStatus(204);
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  createSession,
  authorize,
  endSession,
};

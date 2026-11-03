const db = require('../config/db');

exports.login = async (req, res) => {
  const { usuario, pass } = req.body;

  if (!usuario || !pass) {
    return res.status(400).json({
      ok: false,
      mensaje: 'El usuario y la contraseña son obligatorios'
    });
  }

  try {
    // Ejecutamos tu Stored Procedure de MySQL
    const [rows] = await db.query('CALL sp_login(?, ?)', [usuario, pass]);
    const resultados = rows[0];

    if (!resultados || resultados.length === 0) {
      return res.status(401).json({
        ok: false,
        mensaje: 'Usuario o contraseña incorrectos'
      });
    }

    const usuarioLogueado = resultados[0];

    return res.status(200).json({
      ok: true,
      mensaje: 'Inicio de sesión exitoso',
      usuario: {
        pk_usuario: usuarioLogueado.pk_usuario,
        fk_rol: usuarioLogueado.fk_rol,
        usuario: usuarioLogueado.usuario || usuario,
        nombre: usuarioLogueado.nombre,
        correo: usuarioLogueado.correo,
        estado: usuarioLogueado.estado ?? 1
      }
    });

  } catch (error) {
    console.error('Error en sp_login:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error interno del servidor al autenticar'
    });
  }
};
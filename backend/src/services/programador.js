const { generate, today } = require("./operacion-agenda");
const { User } = require("../models");

function startScheduler(metrics) {
  const configuredUser = process.env.GENERACION_USUARIO_ID;

  if (!configuredUser) return;

  const userId = configuredUser.trim();
  const horizon = Number(process.env.GENERACION_HORIZONTE_DIAS ?? 30);

  if (
    !/^[a-f\d]{24}$/i.test(userId) ||
    !Number.isInteger(horizon) ||
    horizon < 1 ||
    horizon > 91
  ) {
    throw new Error(
      "Configuración inválida de generación automática de visitas.",
    );
  }

  let running = false;

  async function run() {
    if (running) return;

    running = true;

    try {
      const actor = await User.findById(userId).populate("rolId");

      if (
        !actor ||
        !actor.activo ||
        !actor.rolId ||
        !actor.rolId.activo ||
        ![1, 2].includes(Number(actor.rolId.codigo))
      ) {
        throw new Error(
          "El usuario de generación automática no está activo o no tiene permisos.",
        );
      }

      const start = today();

      const end = new Date(`${start}T00:00:00.000Z`);
      end.setUTCDate(end.getUTCDate() + horizon - 1);

      const finish = end.toISOString().slice(0, 10);

      const result = await generate(actor._id.toString(), {
        desde: start,
        hasta: finish,
      });

      metrics.ultima_generacion = {
        fecha: new Date().toISOString(),
        estado: "correcta",
        creadas: result.creadas,
      };

      console.log(
        `Generación automática ${start}: ${result.creadas} visitas nuevas.`,
      );
    } catch (error) {
      metrics.ultima_generacion = {
        fecha: new Date().toISOString(),
        estado: "error",
      };

      console.error("Error al generar visitas automáticamente:", error.message);
    } finally {
      running = false;
    }
  }

  void run();

  setInterval(run, 60 * 60 * 1000).unref();
}

module.exports = { startScheduler };

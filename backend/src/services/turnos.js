const { Shift } = require("../models");

const activeShifts = {
  $or: [{ activo: true }, { activo: { $exists: false }, estado: 1 }],
};

function shiftHours(shift) {
  const horaInicio = String(
    shift?.horaInicio ?? shift?.hora_inicio ?? "",
  ).slice(0, 5);
  const horaFin = String(shift?.horaFin ?? shift?.hora_fin ?? "").slice(0, 5);
  const clock = /^([01]\d|2[0-3]):[0-5]\d$/;

  return clock.test(horaInicio) && clock.test(horaFin) && horaInicio < horaFin
    ? { horaInicio, horaFin }
    : null;
}

async function listShifts(session = null) {
  const rows = await Shift.find(activeShifts).session(session).lean();
  return rows
    .flatMap((row) => {
      const hours = shiftHours(row);
      return hours ? [{ ...row, ...hours }] : [];
    })
    .sort((a, b) => a.horaInicio.localeCompare(b.horaInicio));
}

module.exports = { activeShifts, shiftHours, listShifts };

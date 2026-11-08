const mongoose = require("mongoose");
const models = require("../models");
const { activeShifts, shiftHours, listShifts } = require("./turnos");
const { RequestError, date } = require("./chofer-domain");

const localDate = new Intl.DateTimeFormat("sv-SE", {
  timeZone: "America/Mexico_City",
});

function today() {
  return localDate.format(new Date());
}

function objectId(value, label = "Identificador") {
  if (typeof value !== "string" || !/^[a-f\d]{24}$/i.test(value)) {
    throw new RequestError(`${label} inválido.`);
  }

  return new mongoose.Types.ObjectId(value);
}

function dayNumber(value) {
  const [year, month, day] = value.split("-").map(Number);
  return Math.floor(Date.UTC(year, month - 1, day) / 86400000);
}

function fromNumber(value) {
  return new Date(value * 86400000).toISOString().slice(0, 10);
}

function occurrence(start, day, frequency) {
  const difference = dayNumber(day) - dayNumber(start);

  if (difference < 0) return false;

  if (frequency === "Semanal") return difference % 7 === 0;
  if (frequency === "Quincenal") return difference % 14 === 0;

  if (frequency === "Mensual") {
    const [year, month] = day.split("-").map(Number);
    const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();

    return Number(day.slice(-2)) === Math.min(lastDay, Number(start.slice(-2)));
  }

  return false;
}

// Conserva la hora operativa de Ciudad de México.
function wallClockDate(day, time) {
  const normalized = String(time || "00:00").slice(0, 5);
  return new Date(`${day}T${normalized}:00.000Z`);
}

function formatWallClock(value) {
  if (!value) return null;
  return value.toISOString().slice(0, 19);
}

async function withAgendaLock(day, work) {
  const session = await mongoose.startSession();
  let result;

  try {
    await session.withTransaction(async () => {
      await models.PlanningLock.findOneAndUpdate(
        { _id: `agenda:${day}` },
        { $inc: { version: 1 } },
        { upsert: true, new: true, session },
      );

      result = await work(session);
    });

    return result;
  } finally {
    await session.endSession();
  }
}

async function writeAudit(userId, resource, resourceId, action, session) {
  if (typeof userId !== "string" || !/^[a-f\d]{24}$/i.test(userId)) {
    return;
  }

  const event = {
    usuarioId: new mongoose.Types.ObjectId(userId),
    recurso: resource,
    recursoId: String(resourceId),
    accion: action,
    fecha: new Date(),
  };

  if (session) {
    await models.Audit.create([event], { session });
  } else {
    await models.Audit.create(event);
  }
}

// ==========================================
// CREAR VISITA
// ==========================================

async function createVisit(contract, day, userId, session = null) {
  const query = models.Collection.findOne({
    contratoId: contract._id,
    $or: [{ fechaOriginalClave: day }, { fechaClave: day, activo: true }],
  });

  if (session) query.session(session);

  if (await query) return null;

  const document = {
    clienteId: contract.clienteId._id || contract.clienteId,
    contratoId: contract._id,
    folio: `REC-${contract._id.toString()}-${day.replaceAll("-", "")}`,
    fecha: wallClockDate(day, contract.horaServicio),
    fechaClave: day,
    fechaOriginalClave: day,
    respuestaCliente: "pendiente",
    publicada: false,
    activo: true,
    servicio: { estado: "pendiente" },
  };

  let created;

  if (session) {
    [created] = await models.Collection.create([document], { session });
  } else {
    try {
      created = await models.Collection.create(document);
    } catch (error) {
      if (error.code === 11000) return null;
      throw error;
    }
  }

  await writeAudit(userId, "recolecciones", created._id, "programar", session);

  return created._id.toString();
}

// ==========================================
// PROGRAMACIÓN MANUAL
// ==========================================

async function schedule(userId, body) {
  const day = date(body.fecha);
  const contractId = objectId(body.fk_contrato, "Contrato");

  if (day < today()) {
    throw new RequestError("Selecciona hoy o una fecha futura.");
  }

  try {
    return await withAgendaLock(day, async (session) => {
      const contract = await models.Contract.findOne({
        _id: contractId,
        activo: true,
        fechaInicio: { $lte: day },
        fechaFin: { $gte: day },
        horaServicio: { $type: "string", $ne: "" },
      })
        .populate({
          path: "clienteId",
          match: { activo: true },
        })
        .session(session);

      if (!contract || !contract.clienteId) {
        throw new RequestError(
          "Se requiere un contrato vigente, un cliente activo y un horario.",
          409,
        );
      }

      const visit = await createVisit(contract, day, userId, session);

      if (!visit) {
        throw new RequestError(
          "El contrato ya tiene una visita para esa fecha.",
          409,
        );
      }

      return { id: visit };
    });
  } catch (error) {
    if (error.code === 11000) {
      throw new RequestError(
        "El contrato ya tiene una visita para esa fecha.",
        409,
      );
    }

    throw error;
  }
}

// ==========================================
// GENERACIÓN AUTOMÁTICA
// ==========================================

async function generate(userId, body) {
  const start = date(body.desde);
  const end = date(body.hasta);

  if (
    start < today() ||
    start > end ||
    dayNumber(end) - dayNumber(start) > 90
  ) {
    throw new RequestError("Selecciona un periodo futuro de hasta 91 días.");
  }

  const contracts = await models.Contract.find({
    activo: true,
    fechaInicio: { $lte: end },
    fechaFin: { $gte: start },
    horaServicio: { $type: "string", $ne: "" },
  })
    .populate({
      path: "clienteId",
      match: { activo: true },
    })
    .sort({ _id: 1 });

  let created = 0;

  for (const contract of contracts) {
    if (!contract.clienteId) continue;

    const first = Math.max(dayNumber(start), dayNumber(contract.fechaInicio));

    const last = Math.min(dayNumber(end), dayNumber(contract.fechaFin));

    for (let n = first; n <= last; n++) {
      const day = fromNumber(n);

      if (!occurrence(contract.fechaInicio, day, contract.frecuencia)) {
        continue;
      }

      if (await createVisit(contract, day, userId)) {
        created++;
      }
    }
  }

  return { creadas: created };
}

// ==========================================
// OPCIONES DE AGENDA
// ==========================================

async function catalogOptions() {
  const [routes, drivers, shifts, contracts] = await Promise.all([
    models.Route.find({ activo: true }).sort({ nombre: 1 }).lean(),

    models.Driver.find({ activo: true }).sort({ nombre: 1 }).lean(),

    listShifts(),

    models.Contract.find({ activo: true })
      .populate({ path: "clienteId", select: "nombre" })
      .sort({ folio: 1 })
      .lean(),
  ]);

  return {
    rutas: routes.map((item) => ({
      id: item._id.toString(),
      nombre: item.nombre,
    })),

    choferes: drivers.map((item) => ({
      id: item._id.toString(),
      nombre: item.nombre,
    })),

    turnos: shifts.map((item) => ({
      id: item._id.toString(),
      nombre: item.nombre,
    })),

    contratos: contracts
      .filter((item) => item.clienteId && item.clienteId.activo !== false)
      .map((item) => ({
        id: item._id.toString(),
        nombre: `${item.folio} · ${item.clienteId.nombre}`,
      })),
  };
}

// ==========================================
// CONVERTIR VISITA PARA FLUTTER
// ==========================================

function mapVisit(item) {
  return {
    id: item._id.toString(),
    folio: item.folio,
    cliente: item.clienteId?.nombre || "Cliente no disponible",
    contrato: item.contratoId?.folio ?? null,
    fecha: formatWallClock(item.fecha),

    activo: item.activo === false ? 0 : 1,
    respuesta_cliente: item.respuestaCliente || "pendiente",
    publicada: item.publicada ? 1 : 0,

    fk_ruta: item.rutaId?._id?.toString() || item.rutaId?.toString() || null,

    fk_chofer:
      item.choferId?._id?.toString() || item.choferId?.toString() || null,

    fk_turno: item.turnoId?._id?.toString() || item.turnoId?.toString() || null,

    orden_parada: item.orden ?? null,

    ruta: item.rutaId?.nombre || null,
    chofer: item.choferId?.nombre || null,
    turno: item.turnoId?.nombre || null,

    servicio: item.servicio?.estado || "pendiente",
  };
}

// ==========================================
// CONSULTAR AGENDA
// ==========================================

async function agenda(day) {
  const items = await models.Collection.find(day ? { fechaClave: day } : {})
    .populate({ path: "clienteId", select: "nombre" })
    .populate({ path: "contratoId", select: "folio" })
    .populate({ path: "rutaId", select: "nombre" })
    .populate({ path: "choferId", select: "nombre" })
    .populate({ path: "turnoId", select: "nombre" })
    .sort({ fecha: -1, _id: -1 })
    .lean();

  const open = (item) =>
    item.activo !== false &&
    ["pendiente", "en_curso"].includes(item.servicio?.estado || "pendiente");
  items.sort((a, b) => Number(open(b)) - Number(open(a)));

  return {
    fecha: day ?? null,
    hoy: today(),
    items: items.map(mapVisit),
    ...(await catalogOptions()),
  };
}

function clockOf(value) {
  return `${String(value.getUTCHours()).padStart(2, "0")}:${String(value.getUTCMinutes()).padStart(2, "0")}`;
}

// ==========================================
// ASIGNACIÓN DE RUTAS Y CHOFERES
// ==========================================

async function assign(userId, body) {
  const day = date(body.fecha);

  const routeId = objectId(body.fk_ruta, "Ruta");
  const driverId = objectId(body.fk_chofer, "Chofer");
  const shiftId = objectId(body.fk_turno, "Turno");

  if (
    day < today() ||
    typeof body.publicar !== "boolean" ||
    !Array.isArray(body.paradas) ||
    !body.paradas.length ||
    body.paradas.length > 100
  ) {
    throw new RequestError(
      "Selecciona hasta 100 paradas para una fecha vigente.",
    );
  }

  const ids = body.paradas.map((value, index) =>
    objectId(value, `Parada ${index + 1}`),
  );

  if (new Set(ids.map(String)).size !== ids.length) {
    throw new RequestError("Hay paradas repetidas.");
  }

  return withAgendaLock(day, async (session) => {
    const [driver, shift, route] = await Promise.all([
      models.Driver.findOne({
        _id: driverId,
        activo: true,
      })
        .populate({
          path: "cuentaId",
          populate: { path: "rolId" },
        })
        .session(session),

      models.Shift.findOne({
        _id: shiftId,
        ...activeShifts,
      })
        .session(session)
        .lean(),

      models.Route.findOne({
        _id: routeId,
        activo: true,
      }).session(session),
    ]);

    const account = driver?.cuentaId;
    const hours = shiftHours(shift);

    if (
      !driver ||
      !account ||
      !account.activo ||
      !account.rolId ||
      !account.rolId.activo ||
      Number(account.rolId.codigo) !== 3 ||
      !driver.vencimientoLicencia ||
      driver.vencimientoLicencia < day ||
      !hours ||
      !route
    ) {
      throw new RequestError(
        "Verifica ruta, turno y licencia vigente del chofer.",
        409,
      );
    }

    const visits = await models.Collection.find({
      _id: { $in: ids },
      fechaClave: day,
      activo: true,
    })
      .session(session)
      .lean();

    if (visits.length !== ids.length) {
      throw new RequestError(
        "Hay paradas que no existen, no están activas o pertenecen a otra fecha.",
        409,
      );
    }

    const invalid = visits.some((visit) => {
      const serviceState = visit.servicio?.estado || "pendiente";

      const alreadyAssigned =
        visit.rutaId &&
        (String(visit.rutaId) !== String(routeId) ||
          String(visit.turnoId) !== String(shiftId) ||
          String(visit.choferId) !== String(driverId));

      const time = clockOf(visit.fecha);

      return (
        serviceState !== "pendiente" ||
        alreadyAssigned ||
        time < hours.horaInicio ||
        time >= hours.horaFin
      );
    });

    if (invalid) {
      throw new RequestError(
        "Hay una parada ya iniciada, asignada a otro grupo o fuera del horario del turno.",
        409,
      );
    }

    // Comprobar conflictos de chofer y ruta.
    const others = await models.Collection.find({
      fechaClave: day,
      activo: true,
      _id: { $nin: ids },
      $or: [{ choferId: driverId }, { rutaId: routeId, turnoId: shiftId }],
    })
      .populate({
        path: "turnoId",
        select: "horaInicio horaFin hora_inicio hora_fin",
      })
      .session(session)
      .lean();

    const conflict = others.some((other) => {
      const otherShiftId = other.turnoId?._id || other.turnoId;

      const sameGroup =
        String(other.rutaId) === String(routeId) &&
        String(otherShiftId) === String(shiftId) &&
        String(other.choferId) === String(driverId);

      if (sameGroup) return false;

      const sameRouteSlot =
        String(other.rutaId) === String(routeId) &&
        String(otherShiftId) === String(shiftId) &&
        String(other.choferId) !== String(driverId);

      const otherHours = shiftHours(other.turnoId);
      const overlaps =
        otherHours &&
        otherHours.horaInicio < hours.horaFin &&
        otherHours.horaFin > hours.horaInicio;

      return (
        sameRouteSlot ||
        (String(other.choferId) === String(driverId) && overlaps)
      );
    });

    if (conflict) {
      throw new RequestError(
        "El chofer o la ruta ya tienen una asignación incompatible.",
        409,
      );
    }

    const tail = await models.Collection.find({
      fechaClave: day,
      rutaId: routeId,
      turnoId: shiftId,
      choferId: driverId,
      activo: true,
      _id: { $nin: ids },
    })
      .sort({ orden: -1 })
      .select("orden")
      .session(session)
      .lean();

    let nextOrder = (tail[0]?.orden || 0) + 1;

    for (const visitId of ids) {
      await models.Collection.updateOne(
        { _id: visitId },
        {
          $set: {
            rutaId: routeId,
            choferId: driverId,
            turnoId: shiftId,
            orden: nextOrder++,
            publicada: body.publicar,
          },
        },
        { session },
      );

      await writeAudit(
        userId,
        "recolecciones",
        visitId,
        body.publicar ? "publicar" : "guardar_borrador",
        session,
      );
    }

    return { asignadas: ids.length };
  });
}

// ==========================================
// DESASIGNAR PARADA
// ==========================================

async function unassign(userId, visitValue) {
  const visitId = objectId(visitValue, "Parada");

  const initial =
    await models.Collection.findById(visitId).select("fechaClave");

  if (!initial) {
    throw new RequestError("La parada no se puede desasignar.", 409);
  }

  return withAgendaLock(initial.fechaClave, async (session) => {
    const visit = await models.Collection.findOne({
      _id: visitId,
      activo: true,
      fechaClave: { $gte: today() },
    }).session(session);

    if (!visit || (visit.servicio?.estado || "pendiente") !== "pendiente") {
      throw new RequestError("La parada no se puede desasignar.", 409);
    }

    visit.rutaId = null;
    visit.choferId = null;
    visit.turnoId = null;
    visit.orden = null;

    await visit.save({ session });

    await writeAudit(userId, "recolecciones", visitId, "desasignar", session);

    return { id: visitId.toString() };
  });
}

// ==========================================
// VISITAS DEL CLIENTE
// ==========================================

function mapCustomerVisit(item) {
  return {
    ...mapVisit(item),
    frecuencia: item.contratoId?.frecuencia || null,
  };
}

async function customerVisits(userValue) {
  const userId = objectId(userValue, "Usuario");

  const client = await models.Client.findOne({
    cuentaId: userId,
    activo: true,
  }).select("_id");

  if (!client) {
    return { fecha: today(), items: [] };
  }

  const currentDay = today();

  const populate = [
    { path: "clienteId", select: "nombre" },
    { path: "contratoId", select: "frecuencia" },
    { path: "rutaId", select: "nombre" },
    { path: "choferId", select: "nombre" },
    { path: "turnoId", select: "nombre" },
  ];

  const upcoming = await models.Collection.find({
    clienteId: client._id,
    fechaClave: { $gte: currentDay },
  })
    .populate(populate)
    .sort({ fechaClave: 1, fecha: 1, _id: -1 })
    .lean();

  const past = await models.Collection.find({
    clienteId: client._id,
    fechaClave: { $lt: currentDay },
  })
    .populate(populate)
    .sort({ fechaClave: -1, fecha: -1, _id: -1 })
    .lean();

  return {
    fecha: currentDay,
    items: [...upcoming, ...past].map(mapCustomerVisit),
  };
}

// ==========================================
// ACCIONES DEL CLIENTE
// ==========================================

async function customerAction(userValue, visitValue, body) {
  const userId = objectId(userValue, "Usuario");
  const visitId = objectId(visitValue, "Visita");

  const action = body.accion;

  if (!["confirmar", "cancelar", "reprogramar"].includes(action)) {
    throw new RequestError("Acción inválida.");
  }

  const newDay = action === "reprogramar" ? date(body.fecha) : null;

  return withAgendaLock(newDay || today(), async (session) => {
    const client = await models.Client.findOne({
      cuentaId: userId,
      activo: true,
    })
      .select("_id")
      .session(session);

    if (!client) {
      throw new RequestError("Visita no encontrada.", 404);
    }

    const visit = await models.Collection.findOne({
      _id: visitId,
      clienteId: client._id,
    }).session(session);

    if (!visit) {
      throw new RequestError("Visita no encontrada.", 404);
    }

    const contract = await models.Contract.findById(visit.contratoId).session(
      session,
    );

    const serviceState = visit.servicio?.estado || "pendiente";

    const recovering =
      action === "reprogramar" &&
      visit.respuestaCliente === "cancelada" &&
      contract?.frecuencia === "Mensual" &&
      newDay.slice(0, 7) === visit.fechaClave.slice(0, 7);

    if (
      serviceState !== "pendiente" ||
      (!recovering && (!visit.activo || visit.fechaClave < today()))
    ) {
      throw new RequestError("La visita ya no admite este cambio.", 409);
    }

    if (action === "reprogramar") {
      if (
        !contract?.activo ||
        newDay === visit.fechaClave ||
        newDay < today() ||
        newDay < contract.fechaInicio ||
        newDay > contract.fechaFin
      ) {
        throw new RequestError(
          "Selecciona una nueva fecha dentro de la vigencia del contrato.",
        );
      }

      const duplicate = await models.Collection.exists({
        contratoId: visit.contratoId,
        fechaClave: newDay,
        activo: true,
        _id: { $ne: visitId },
      }).session(session);

      if (duplicate) {
        throw new RequestError("Ya existe una visita para ese día.", 409);
      }

      const visitTime = clockOf(visit.fecha);

      const [shifts, eligibleDrivers] = await Promise.all([
        listShifts(session),

        models.Driver.find({
          activo: true,
          vencimientoLicencia: { $gte: newDay },
        })
          .populate({
            path: "cuentaId",
            populate: { path: "rolId" },
          })
          .session(session),
      ]);

      const availableDriver = eligibleDrivers.some(
        (driver) =>
          driver.cuentaId?.activo === true &&
          driver.cuentaId?.rolId?.activo === true &&
          Number(driver.cuentaId.rolId.codigo) === 3,
      );

      const availableShift = shifts.some(
        (shift) => shift.horaInicio <= visitTime && visitTime < shift.horaFin,
      );
      if (!availableShift || !availableDriver) {
        throw new RequestError(
          "No hay un turno y chofer habilitados para esa fecha y hora.",
          409,
        );
      }

      visit.fechaClave = newDay;
      visit.fecha = wallClockDate(newDay, visitTime);
      visit.activo = true;
      visit.respuestaCliente = "reprogramada";

      visit.rutaId = null;
      visit.choferId = null;
      visit.turnoId = null;
      visit.orden = null;
    } else if (action === "cancelar") {
      visit.activo = false;
      visit.respuestaCliente = "cancelada";

      visit.rutaId = null;
      visit.choferId = null;
      visit.turnoId = null;
      visit.orden = null;
    } else {
      visit.respuestaCliente = "confirmada";
    }

    await visit.save({ session });

    await writeAudit(
      userId.toString(),
      "recolecciones",
      visitId,
      action,
      session,
    );

    return { id: visitId.toString() };
  });
}

module.exports = {
  today,
  agenda,
  assign,
  unassign,
  generate,
  schedule,
  customerVisits,
  customerAction,
  occurrence,
};

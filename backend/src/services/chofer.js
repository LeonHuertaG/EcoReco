
const mongoose = require('mongoose');

const {
  Driver,
  Collection,
  Contract,
  Waste,
  Sale,
  Payment,
  Manifest,
  PaymentMethod,
  Cut,
  Audit,
  PlanningLock,
} = require('../models');

const {
  RequestError,
  decimal,
  amount,
  text,
  image,
  key,
  calculate,
} = require('./chofer-domain');

const Oid = mongoose.Types.ObjectId;
const activeCatalogEntry = {
  $or: [{ activo: true }, { activo: { $exists: false }, estado: 1 }],
};

function wasteUnit(waste) {
  return waste.unidadMedida || waste.unidad_medida || 'unidad';
}

// ========================================
// FECHAS
// ========================================

const formatter = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'America/Mexico_City',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hourCycle: 'h23',
});

const dayFormatter = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'America/Mexico_City',
});

const today = () => dayFormatter.format(new Date());

function now() {
  return localTime(new Date());
}

function localTime(value) {
  if (!value) return null;

  const p = Object.fromEntries(
    formatter.formatToParts(new Date(value))
      .filter(x => x.type !== 'literal')
      .map(x => [x.type, x.value])
  );

  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}:${p.second}`;
}

function dayRange(day) {
  function start(value) {
    const probe = new Date(`${value}T12:00:00Z`);

    const p = Object.fromEntries(
      formatter.formatToParts(probe)
        .filter(x => x.type !== 'literal')
        .map(x => [x.type, x.value])
    );

    const asUtc = Date.UTC(
      +p.year,
      +p.month - 1,
      +p.day,
      +p.hour,
      +p.minute,
      +p.second
    );

    return new Date(
      Date.parse(`${value}T00:00:00Z`) -
      (asUtc - probe.getTime())
    );
  }

  const next = new Date(`${day}T00:00:00Z`);
  next.setUTCDate(next.getUTCDate() + 1);

  return {
    $gte: start(day),
    $lt: start(next.toISOString().slice(0, 10)),
  };
}

// ========================================
// IDENTIFICADORES Y DECIMALES
// ========================================

function oid(value, label = 'Identificador') {
  if (
    typeof value !== 'string' ||
    !/^[a-f\d]{24}$/i.test(value)
  ) {
    throw new RequestError(`${label} inválido.`);
  }

  return new Oid(value);
}

function ref(value) {
  return value ? String(value._id || value) : null;
}

function dec(value) {
  return value == null ? '0.00' : value.toString();
}

function cents(value) {
  return decimal(dec(value), 'Importe', true);
}

function dec128(value) {
  return mongoose.Types.Decimal128.fromString(
    amount(value)
  );
}

function clockForStop(stop) {
  // La agenda almacena la hora programada
  // como una fecha UTC de pared.
  return stop.fecha.toISOString().slice(0, 19);
}

// ========================================
// BITÁCORA
// ========================================

async function audit(
  session,
  user,
  resource,
  resourceId,
  action
) {
  await Audit.create([{
    usuarioId: oid(user, 'Usuario'),
    recurso: resource,
    recursoId: String(resourceId),
    accion: action,
    fecha: new Date(),
  }], { session });
}

// ========================================
// TRANSACCIONES
// ========================================

async function transaction(user, work, extraLocks = []) {
  const locks = [
    ...new Set([
      `chofer:${user}`,
      ...extraLocks,
    ]),
  ].sort();

  for (const lock of locks) {
    await PlanningLock.updateOne(
      { _id: lock },
      { $setOnInsert: { version: 0 } },
      { upsert: true }
    );
  }

  const session = await mongoose.startSession();

  let result;

  try {
    await session.withTransaction(async () => {
      for (const lock of locks) {
        await PlanningLock.updateOne(
          { _id: lock },
          { $inc: { version: 1 } },
          { session }
        );
      }

      result = await work(session);
    });

    return result;
  } finally {
    await session.endSession();
  }
}

// ========================================
// CHOFER AUTENTICADO
// ========================================

async function driverFor(user, session = null) {
  const query = Driver.findOne({
    cuentaId: oid(user, 'Usuario'),
    activo: true,
  });

  if (session) query.session(session);

  const driver = await query.select('_id nombre');

  if (!driver) {
    throw new RequestError(
      'Chofer no disponible.',
      403
    );
  }

  return driver;
}

// ========================================
// CONSULTAR PARADA AUTORIZADA
// ========================================

async function getStop(session, user, stopId) {
  const driver = await driverFor(user, session);

  const query = Collection.findOne({
    _id: oid(stopId, 'Parada'),
    choferId: driver._id,
  })
    .populate('clienteId', 'nombre direccion telefono')
    .populate('rutaId', 'nombre')
    .populate('turnoId', 'nombre horaInicio')
    .populate('choferId', 'nombre');

  if (session) query.session(session);

  const stop = await query;

  const status = stop?.servicio?.estado || 'pendiente';

  if (
    !stop ||
    (!stop.activo && status === 'pendiente') ||
    (!stop.publicada && status === 'pendiente') ||
    !stop.clienteId ||
    !stop.rutaId ||
    !stop.turnoId ||
    !stop.choferId
  ) {
    throw new RequestError(
      'Parada no encontrada.',
      404
    );
  }

  return stop;
}

// ========================================
// FORMATO PARA FLUTTER
// ========================================

function stopRow(stop) {
  const service = stop.servicio || {};

  return {
    pk_recoleccion: ref(stop),
    folio: stop.folio,

    fk_cliente: ref(stop.clienteId),
    fk_contrato: ref(stop.contratoId),
    fk_turno: ref(stop.turnoId),
    fk_ruta: ref(stop.rutaId),

    fecha: clockForStop(stop),
    observaciones: stop.observaciones ?? null,
    orden_parada: stop.orden ?? null,

    cliente: stop.clienteId?.nombre || '',
    direccion: stop.clienteId?.direccion || '',
    telefono: stop.clienteId?.telefono || null,

    ruta: stop.rutaId?.nombre || '',
    turno: stop.turnoId?.nombre || '',

    estado: service.estado || 'pendiente',

    fk_venta: ref(service.ventaId),
    fk_manifiesto: ref(service.manifiestoId),

    motivo: service.motivo ?? null,
    insumos: service.insumos ?? null,

    llegada: localTime(service.llegada),
    cierre: localTime(service.cierre),

    tiene_foto: service.foto?.length ? 1 : 0,
    tiene_firma: service.firma?.length ? 1 : 0,
  };
}

function stopSort(a, b) {
  const shift = (
    a.turnoId?.horaInicio || ''
  ).localeCompare(
    b.turnoId?.horaInicio || ''
  );

  return shift ||
    (ref(a.rutaId) || '').localeCompare(ref(b.rutaId) || '') ||
    (a.orden ?? Infinity) - (b.orden ?? Infinity) ||
    a.fecha.getTime() - b.fecha.getTime();
}

// ========================================
// PARADAS DEL DÍA
// ========================================

async function list(user, day) {
  const driver = await driverFor(user);

  const filters = day ? {
    fechaClave: day,
    $or: [
      { activo: true, publicada: true },
      { 'servicio.estado': { $in: ['en_curso', 'completada', 'fallida'] } },
    ],
  } : {
    activo: true,
    publicada: true,
    $or: [
      { 'servicio.estado': { $in: ['pendiente', 'en_curso'] } },
      { 'servicio.estado': { $exists: false } },
    ],
  };

  const stops = await Collection.find({ choferId: driver._id, ...filters })
    .populate('clienteId', 'nombre direccion telefono')
    .populate('rutaId', 'nombre')
    .populate('turnoId', 'nombre horaInicio')
    .lean();

  const assignments = day ? [] : await Collection.find({
    choferId: driver._id,
    turnoId: { $ne: null },
    fechaClave: { $lte: today() },
    $or: [{ publicada: true }, { 'servicio.estado': { $in: ['en_curso', 'completada', 'fallida'] } }],
  }).select('fechaClave turnoId').populate('turnoId', 'nombre').lean();
  const cashShifts = new Map();
  for (const item of assignments) {
    if (!item.turnoId) continue;
    const id = ref(item.turnoId);
    for (const date of [item.fechaClave, today()]) {
      cashShifts.set(`${date}:${id}`, { id, fecha: date, nombre: item.turnoId.nombre });
    }
  }

  return {
    fecha: day ?? today(),
    paradas: stops.sort((a, b) => (a.fechaClave ?? '').localeCompare(b.fechaClave ?? '') ||
      stopSort(a, b)).map(stopRow),
    cajas: [...cashShifts.values()].sort((a, b) => b.fecha.localeCompare(a.fecha)),
  };
}

// ========================================
// PAGOS Y SALDOS
// ========================================

async function totalPaid(saleIds) {
  if (!saleIds.length) return new Map();

  const payments = await Payment.find({
    ventaId: { $in: saleIds },
  })
    .select('ventaId importe')
    .lean();

  const totals = new Map();

  for (const payment of payments) {
    const id = ref(payment.ventaId);

    totals.set(
      id,
      (totals.get(id) || 0n) + cents(payment.importe)
    );
  }

  return totals;
}

// ========================================
// COTIZACIONES
// ========================================

function quoteResponse(quote) {
  return {
    subtotal: amount(quote.subtotal),
    iva: amount(quote.iva),
    total: amount(quote.total),

    conceptos: quote.lines.map(line => ({
      concepto: line.concept,
      subtotal: amount(line.total),
    })),
  };
}

function absenceQuote(contract) {
  if (
    !contract ||
    !contract.cargoVisitaFallida ||
    cents(contract.cargoVisitaFallida) === 0n
  ) {
    return null;
  }

  const quote = calculate({
    monto: dec(contract.cargoVisitaFallida),
    iva_porcentaje: dec(contract.ivaPorcentaje),
  }, 0n, 0n);

  quote.lines[0].concept = 'Visita fallida';

  return quote;
}

// ========================================
// DETALLE DE PARADA
// ========================================

async function detail(user, stopId) {
  const stop = await getStop(null, user, stopId);

  const [contract, sales] = await Promise.all([
    Contract.findById(stop.contratoId).lean(),

    Sale.find({
      clienteId: stop.clienteId._id,
      activo: true,
    })
      .sort({ fecha: 1, _id: 1 })
        .lean(),
  ]);

  const paid = await totalPaid(
    sales.map(x => x._id)
  );

  const visible = sales.filter(sale =>
    ref(sale.recoleccionId) === ref(stop) ||
    cents(sale.total) > (paid.get(ref(sale)) || 0n)
  );

  const current = sales.find(sale =>
    ref(sale) === ref(stop.servicio?.ventaId)
  );

  const payments = current
    ? await Payment.find({
        ventaId: current._id,
      })
        .populate('metodoPagoId', 'nombre')
        .sort({ fecha: 1, _id: 1 })
        .lean()
    : [];

  const wastes = await Waste.find({
    _id: {
      $in: (stop.residuos || [])
        .map(x => x.desechoId),
    },
  })
    .select('nombre')
    .lean();

  const names = new Map(
    wastes.map(w => [ref(w), w.nombre])
  );

  const fee = absenceQuote(contract);

  return {
    ...stopRow(stop),

    es_hoy: stop.fechaClave === today(),
    fecha_operable: stop.fechaClave <= today(),

    residuos: (stop.residuos || [])
      .filter(x => x.activo !== false)
      .map(x => ({
        nombre:
          names.get(ref(x.desechoId)) || 'Residuo',

        cantidad: dec(x.cantidad),
        peso: dec(x.peso),
        observaciones: x.observaciones ?? null,
      })),

    ventas: visible.map(sale => ({
      pk_venta: ref(sale),
      fk_recoleccion: ref(sale.recoleccionId),

      folio: sale.folio,
      fecha: localTime(sale.fecha),

      subtotal: dec(sale.subtotal),
      iva: dec(sale.iva),
      total: dec(sale.total),

      saldo: amount(
        cents(sale.total) -
        (paid.get(ref(sale)) || 0n)
      ),
    })),

    conceptos: (current?.conceptos || [])
      .map(x => ({
        concepto: x.concepto,
        cantidad: dec(x.cantidad),
        precio_unitario: dec(x.precioUnitario),
        subtotal: dec(x.subtotal),
      })),

    pagos: payments.map(p => ({
      importe: dec(p.importe),
      metodo: p.metodoPagoId?.nombre || '',
      fecha: localTime(p.fecha),
    })),

    cargo_ausencia:
      fee ? amount(fee.total) : null,
  };
}

// ========================================
// INICIAR PARADA
// ========================================

function requireStarted(stop) {
  if (stop.servicio?.estado !== 'en_curso') {
    throw new RequestError(
      'Primero inicia la parada.',
      409
    );
  }
}

async function start(user, stopId) {
  return transaction(user, async session => {
    const stop = await getStop(session, user, stopId);

    const state =
      stop.servicio?.estado || 'pendiente';

    if (state !== 'pendiente') {
      return { estado: state };
    }

    if (stop.fechaClave > today()) {
      throw new RequestError(
        'Solo puedes iniciar paradas de hoy o de fechas anteriores.',
        409
      );
    }

    stop.set('servicio.estado', 'en_curso');
    stop.set('servicio.usuarioId', oid(user));
    stop.set('servicio.llegada', new Date());

    await stop.save({ session });

    await audit(
      session,
      user,
      'recolecciones',
      stop._id,
      'registrar_llegada'
    );

    return { estado: 'en_curso' };
  });
}

// ========================================
// VALIDAR CONTRATO
// ========================================

async function contractFor(stop, session) {
  const query = Contract.findOne({
    _id: stop.contratoId,

    clienteId: stop.clienteId._id,

    fechaInicio: {
      $lte: stop.fechaClave,
    },

    fechaFin: {
      $gte: stop.fechaClave,
    },
  });

  if (session) query.session(session);

  const contract = await query.lean();

  if (!contract) {
    throw new RequestError(
      'La parada requiere un contrato vigente del cliente.',
      409
    );
  }

  return contract;
}

// ========================================
// CALCULAR SERVICIO Y RESIDUOS
// ========================================

async function serviceData(stop, input, session) {
  if (
    !Array.isArray(input) ||
    !input.length ||
    input.length > 50
  ) {
    throw new RequestError(
      'Captura entre 1 y 50 tipos de residuos.'
    );
  }

  const items = input.map(item => ({
    wasteId: oid(item?.fk_desecho, 'Residuo'),

    quantity: decimal(
      item?.cantidad,
      'Cantidad'
    ),

    weight: decimal(
      item?.peso,
      'Peso'
    ),

    notes: text(
      item?.observaciones,
      'Observaciones del residuo',
      255,
      false
    ),
  }));

  const ids = items.map(x => ref(x.wasteId));

  if (new Set(ids).size !== ids.length) {
    throw new RequestError(
      'Agrupa los residuos del mismo tipo.'
    );
  }

  const wastesQ = Waste.find({
    _id: { $in: items.map(x => x.wasteId) },
    ...activeCatalogEntry,
  }).select('nombre unidadMedida unidad_medida');

  if (session) wastesQ.session(session);

  const wastes = await wastesQ.lean();

  if (wastes.length !== items.length) {
    throw new RequestError(
      'Un residuo ya no está disponible.',
      409
    );
  }

  const wasteMap = new Map(
    wastes.map(x => [ref(x), x])
  );

  const contract = await contractFor(
    stop,
    session
  );

  // Calcular kilos acumulados del mes.
  const first = `${stop.fechaClave.slice(0, 7)}-01`;

  const end = new Date(
    `${first}T00:00:00Z`
  );

  end.setUTCMonth(end.getUTCMonth() + 1);

  const previousQ = Collection.find({
    contratoId: stop.contratoId,

    _id: {
      $ne: stop._id,
    },

    fechaClave: {
      $gte: first,
      $lt: end.toISOString().slice(0, 10),
    },

    'servicio.estado': 'completada',
  }).select('residuos');

  if (session) previousQ.session(session);

  const previous = await previousQ.lean();

  const priorKg = previous.reduce(
    (sum, collection) =>
      sum + (collection.residuos ?? [])
        .filter(x => x.activo !== false)
        .reduce(
          (weight, item) =>
            weight + cents(item.peso),
          0n
        ),
    0n
  );

  const currentKg = items.reduce(
    (sum, item) => sum + item.weight,
    0n
  );

  const quote = calculate({
    monto: contract.cuotaPorVisita == null ? null : dec(contract.cuotaPorVisita),

    iva_porcentaje:
      contract.ivaPorcentaje == null ? null : dec(contract.ivaPorcentaje),

    kilos_mensuales:
      contract.kilosMensuales == null
        ? null
        : dec(contract.kilosMensuales),

    tarifa_excedente:
      contract.tarifaExcedente == null
        ? null
        : dec(contract.tarifaExcedente),
  }, priorKg, currentKg);

  return {
    items: items.map(x => ({
      ...x,
      waste: wasteMap.get(ref(x.wasteId)),
    })),

    quote,
  };
}

// ========================================
// GENERAR VENTA
// ========================================

async function saveSale(
  session,
  user,
  stop,
  quote,
  notes
) {
  const [sale] = await Sale.create([{
    clienteId: stop.clienteId._id,
    usuarioId: oid(user),
    recoleccionId: stop._id,

    folio: `V-${ref(stop)}`,
    fecha: new Date(),

    subtotal: dec128(quote.subtotal),
    iva: dec128(quote.iva),
    total: dec128(quote.total),

    observaciones: notes,

    conceptos: quote.lines.map(line => ({
      concepto: line.concept,
      cantidad: dec128(line.quantity),
      precioUnitario: dec128(line.rate),
      subtotal: dec128(line.total),
    })),

    activo: true,
  }], { session });

  await audit(
    session,
    user,
    'ventas',
    sale._id,
    'emitir'
  );

  return sale._id;
}

// ========================================
// REGISTRAR VISITA FALLIDA
// ========================================

async function fail(user, stopId, body) {
  const reason = text(
    body?.motivo,
    'Motivo',
    255
  );

  const photo = image(
    body?.foto,
    'Foto'
  );

  return transaction(user, async session => {
    const stop = await getStop(
      session,
      user,
      stopId
    );

    if (stop.servicio?.estado === 'fallida') {
      return { estado: 'fallida' };
    }

    requireStarted(stop);

    const policy = await contractFor(
      stop,
      session
    );

    const quote = absenceQuote(policy);

    let saleId = null;

    if (quote) {
      const previous = await Sale.exists({
        recoleccionId: stop._id,
      }).session(session);

      if (previous) {
        throw new RequestError(
          'La parada ya tiene una venta.',
          409
        );
      }

      saleId = await saveSale(
        session,
        user,
        stop,
        quote,
        reason
      );

      stop.total = dec128(quote.total);
    }

    stop.set('servicio.estado', 'fallida');
    stop.set('servicio.motivo', reason);
    stop.set('servicio.foto', photo);
    stop.set('servicio.cierre', new Date());
    stop.set('servicio.usuarioId', oid(user));
    stop.set('servicio.ventaId', saleId);

    await stop.save({ session });

    await audit(
      session,
      user,
      'recolecciones',
      stop._id,
      'registrar_ausencia'
    );

    return { estado: 'fallida' };
  });
}

// ========================================
// COTIZAR RECOLECCIÓN
// ========================================

async function preview(user, stopId, body) {
  const stop = await getStop(
    null,
    user,
    stopId
  );

  requireStarted(stop);

  const { quote } = await serviceData(
    stop,
    body?.residuos,
    null
  );

  return quoteResponse(quote);
}

// ========================================
// COMPLETAR RECOLECCIÓN
// ========================================

async function complete(user, stopId, body) {
  const notes = text(
    body?.observaciones,
    'Observaciones',
    255,
    false
  );

  const supplies = text(
    body?.insumos,
    'Insumos',
    255,
    false
  );

  const origin = text(body?.origen, 'Origen', 255, false);
  const destination = text(body?.destino, 'Destino', 255, false);

  const signature = image(
    body?.firma,
    'Firma'
  );

  const photo = image(
    body?.foto,
    'Foto',
    true
  );

  const accepted = decimal(
    body?.total_confirmado,
    'Total confirmado',
    true
  );

  const preflight = await getStop(
    null,
    user,
    stopId
  );

  return transaction(
    user,
    async session => {
      const stop = await getStop(
        session,
        user,
        stopId
      );

      // Evitar duplicar registros por reintentos.
      if (stop.servicio?.estado === 'completada') {
        return {
          fk_venta: ref(stop.servicio.ventaId),
          fk_manifiesto: ref(
            stop.servicio.manifiestoId
          ),
        };
      }

      requireStarted(stop);

      const hasSale = await Sale.exists({
        recoleccionId: stop._id,
      }).session(session);

      const hasManifest = await Manifest.exists({
        recoleccionId: stop._id,
      }).session(session);

      if (
        hasSale ||
        hasManifest ||
        stop.residuos?.length
      ) {
        throw new RequestError(
          'Esta parada ya contiene registros previos.',
          409
        );
      }

      const { items, quote } = await serviceData(
        stop,
        body?.residuos,
        session
      );

      if (accepted !== quote.total) {
        throw new RequestError(
          'El importe cambió. Vuelve a calcular y recaba la firma.',
          409
        );
      }

      const saleId = await saveSale(
        session,
        user,
        stop,
        quote,
        notes
      );

      const [manifest] = await Manifest.create([{
        recoleccionId: stop._id,
        clienteId: stop.clienteId._id,
        choferId: stop.choferId._id,

        folio: `M-${ref(stop)}`,
        fechaEmision: new Date(),

        origen: origin ?? (stop.clienteId.direccion || stop.clienteId.nombre),
        destino: destination,
        observaciones: notes,

        clienteNombre: stop.clienteId.nombre,
        choferNombre: stop.choferId.nombre,

        residuos: items.map(item => ({
          desechoId: item.wasteId,
          cantidad: dec128(item.quantity),
          peso: dec128(item.weight),
          unidadMedida: wasteUnit(item.waste),
          descripcion: item.waste.nombre,
        })),

        activo: true,
      }], { session });

      stop.residuos = items.map(item => ({
        desechoId: item.wasteId,
        cantidad: dec128(item.quantity),
        peso: dec128(item.weight),
        observaciones: item.notes,
        activo: true,
      }));

      stop.total = dec128(quote.total);
      stop.observaciones = notes;

      stop.set('servicio.estado', 'completada');
      stop.set('servicio.cierre', new Date());
      stop.set('servicio.firma', signature);
      stop.set('servicio.foto', photo);
      stop.set('servicio.usuarioId', oid(user));
      stop.set('servicio.insumos', supplies);
      stop.set('servicio.ventaId', saleId);
      stop.set('servicio.manifiestoId', manifest._id);

      await stop.save({ session });

      await audit(
        session,
        user,
        'recolecciones',
        stop._id,
        'completar'
      );

      await audit(
        session,
        user,
        'manifiestos',
        manifest._id,
        'emitir'
      );

      return {
        fk_venta: ref(saleId),
        fk_manifiesto: ref(manifest),
      };
    },
    [
      `contrato:${ref(preflight.contratoId)}`,
    ]
  );
}

// ========================================
// VALIDAR CAJA ABIERTA
// ========================================

async function requireOpen(
  session,
  user,
  shift,
  day
) {
  const closed = await Cut.exists({
    usuarioId: oid(user),
    turnoId: oid(String(shift), 'Turno'),
    jornada: day,
  }).session(session);

  if (closed) {
    throw new RequestError(
      'El turno ya tiene un corte registrado.',
      409
    );
  }
}

// ========================================
// REGISTRAR PAGO
// ========================================

async function pay(user, stopId, body) {
  const saleId = oid(
    body?.fk_venta,
    'Venta'
  );

  const methodId = oid(
    body?.fk_metodo_pago,
    'Método de pago'
  );

  const value = decimal(
    body?.importe,
    'Importe'
  );

  const operation = key(body?.clave);

  return transaction(
    user,
    async session => {
      const stop = await getStop(
        session,
        user,
        stopId
      );

      const sale = await Sale.findOne({
        _id: saleId,
        clienteId: stop.clienteId._id,
        activo: true,
      }).session(session);

      if (!sale) {
        throw new RequestError(
          'Venta no encontrada.',
          404
        );
      }

      const prior = await Payment.findOne({
        usuarioId: oid(user),
        clave: operation,
      }).session(session);

      if (prior) {
        if (
          ref(prior.ventaId) !== ref(sale) ||
          ref(prior.metodoPagoId) !== ref(methodId) ||
          cents(prior.importe) !== value
        ) {
          throw new RequestError(
            'La clave de operación ya se usó con otros datos.',
            409
          );
        }

        return { pk_pago: ref(prior) };
      }

      const day = today();

      if (stop.fechaClave > day) {
        throw new RequestError(
          'El cobro requiere una parada de hoy o de fechas anteriores.',
          409
        );
      }

      await requireOpen(
        session,
        user,
        stop.turnoId._id,
        day
      );

      const method = await PaymentMethod.exists({
        _id: methodId,
        ...activeCatalogEntry,
      }).session(session);

      if (!method) {
        throw new RequestError(
          'Método de pago no disponible.'
        );
      }

      const payments = await Payment.find({
        ventaId: saleId,
      })
        .select('importe')
        .session(session)
        .lean();

      const paid = payments.reduce(
        (sum, p) =>
          sum + cents(p.importe),
        0n
      );

      if (value > cents(sale.total) - paid) {
        throw new RequestError(
          'El importe supera el saldo pendiente.',
          409
        );
      }

      const [payment] = await Payment.create([{
        ventaId: saleId,
        usuarioId: oid(user),
        turnoId: stop.turnoId._id,
        metodoPagoId: methodId,

        importe: dec128(value),
        fecha: new Date(),
        clave: operation,
      }], { session });

      if (!sale.metodoPagoId) {
        sale.metodoPagoId = methodId;
        await sale.save({ session });
      }

      await audit(
        session,
        user,
        'pagos',
        payment._id,
        'registrar'
      );

      return {
        pk_pago: ref(payment),
      };
    },
    [
      `venta:${ref(saleId)}`,
    ]
  );
}

// ========================================
// CONSULTAR MANIFIESTO
// ========================================

async function manifest(user, stopId) {
  const stop = await getStop(
    null,
    user,
    stopId
  );

  if (!stop.servicio?.manifiestoId) {
    throw new RequestError(
      'Manifiesto no encontrado.',
      404
    );
  }

  const doc = await Manifest.findOne({
    _id: stop.servicio.manifiestoId,
    recoleccionId: stop._id,
    activo: true,
  }).lean();

  if (!doc) {
    throw new RequestError(
      'Manifiesto no encontrado.',
      404
    );
  }

  return {
    folio: doc.folio,
    tiene_firma: Boolean(stop.servicio?.firma?.length),
    origen: doc.origen,
    destino: doc.destino,
    observaciones: doc.observaciones,

    cliente: doc.clienteNombre,
    chofer: doc.choferNombre,

    fecha_emision: localTime(
      doc.fechaEmision
    ),

    fecha_entrega: localTime(
      doc.entrega?.fecha
    ),

    residuos: (doc.residuos || []).map(item => ({
      descripcion: item.descripcion,
      cantidad: dec(item.cantidad),
      peso: dec(item.peso),
      unidad_medida: item.unidadMedida,
    })),
  };
}

// ========================================
// ENTREGAR MANIFIESTO
// ========================================

async function deliver(user, stopId) {
  return transaction(user, async session => {
    const stop = await getStop(
      session,
      user,
      stopId
    );

    if (!stop.servicio?.manifiestoId) {
      throw new RequestError(
        'Manifiesto no encontrado.',
        404
      );
    }

    const doc = await Manifest.findOne({
      _id: stop.servicio.manifiestoId,
      recoleccionId: stop._id,
      activo: true,
    }).session(session);

    if (!doc) {
      throw new RequestError(
        'Manifiesto no encontrado.',
        404
      );
    }

    if (!doc.entrega) {
      doc.entrega = {
        usuarioId: oid(user),
        fecha: new Date(),
      };

      await doc.save({ session });

      await audit(
        session,
        user,
        'manifiestos',
        doc._id,
        'entregar'
      );
    }

    return {
      fk_manifiesto: ref(doc),
    };
  });
}

// ========================================
// HISTORIAL DE MANIFIESTOS
// ========================================

async function manifests(user, day, folio) {
  const driver = await driverFor(user);

  const query = {
    choferId: driver._id,
    activo: true,
  };

  if (folio) {
    query.folio = folio;
  } else if (day) {
    query.fechaEmision = dayRange(day);
  }

  const rows = await Manifest.find(query)
    .sort({
      fechaEmision: -1,
      _id: -1,
    })
    .lean();

  return {
    manifiestos: rows.map(doc => ({
      folio: doc.folio,
      fk_recoleccion: ref(doc.recoleccionId),
      cliente: doc.clienteNombre,
      fecha: localTime(doc.fechaEmision),
    })),
  };
}

// ========================================
// FOTOGRAFÍAS Y FIRMAS
// ========================================

async function evidence(user, stopId, type) {
  if (!['foto', 'firma'].includes(type)) {
    throw new RequestError(
      'Evidencia no encontrada.',
      404
    );
  }

  const stop = await getStop(
    null,
    user,
    stopId
  );

  const bytes = stop.servicio?.[type];

  if (!bytes?.length) {
    throw new RequestError(
      'Evidencia no encontrada.',
      404
    );
  }

  return Buffer.from(bytes);
}

// ========================================
// CATÁLOGOS DEL CHOFER
// ========================================

async function catalog() {
  const [wastes, methods] = await Promise.all([
    Waste.find(activeCatalogEntry)
      .select('nombre unidadMedida unidad_medida')
      .sort({ nombre: 1 })
      .lean(),

    PaymentMethod.find(activeCatalogEntry)
      .select('nombre')
      .sort({ nombre: 1 })
      .lean(),
  ]);

  return {
    residuos: wastes.map(x => ({
      id: ref(x),
      nombre: x.nombre,
      unidad_medida: wasteUnit(x),
    })),

    metodos: methods.map(x => ({
      id: ref(x),
      nombre: x.nombre,
    })),
  };
}

// ========================================
// HISTORIAL DE VISITAS AL CLIENTE
// ========================================

async function clientVisits(user, stopId) {
  const stop = await getStop(
    null,
    user,
    stopId
  );

  const driver = await driverFor(user);

  const rows = await Collection.find({
    choferId: driver._id,
    clienteId: stop.clienteId._id,

    'servicio.estado': {
      $in: ['completada', 'fallida'],
    },
  })
    .populate('clienteId', 'nombre direccion telefono')
    .populate('rutaId', 'nombre')
    .populate('turnoId', 'nombre horaInicio')
    .sort({
      fecha: -1,
      _id: -1,
    })
    .limit(50)
    .lean();

  return {
    paradas: rows.map(stopRow),
  };
}

// ========================================
// HISTORIAL DE VENTAS
// ========================================

async function history(user, day, client = '') {
  const userId = oid(
    user,
    'Usuario'
  );

  const sales = await Sale.find({
    usuarioId: userId,
    activo: true,
    ...(day ? { fecha: dayRange(day) } : {}),
  })
    .populate('clienteId', 'nombre')
    .sort({
      fecha: -1,
      _id: -1,
    })
    .lean();

  const chosen = sales.filter(sale =>
    (sale.clienteId?.nombre || '')
      .toLocaleLowerCase('es')
      .includes(
        client.toLocaleLowerCase('es')
      )
  );

  const paid = await totalPaid(
    chosen.map(x => x._id)
  );

  return {
    ventas: chosen.map(sale => ({
      folio: sale.folio,
      fk_recoleccion: ref(sale.recoleccionId),

      cliente:
        sale.clienteId?.nombre || '',

      total: dec(sale.total),
      fecha: localTime(sale.fecha),

      saldo: amount(
        cents(sale.total) -
        (paid.get(ref(sale)) || 0n)
      ),
    })),
  };
}

// ========================================
// EXPORTACIONES
// ========================================

module.exports = {
  list,
  detail,
  start,
  fail,
  preview,
  complete,
  pay,
  manifest,
  deliver,
  manifests,
  evidence,
  catalog,
  history,
  clientVisits,

  // Utilidades para chofer-caja.js
  transaction,
  getStop,
  requireOpen,
  today,
  now,
  audit,
};

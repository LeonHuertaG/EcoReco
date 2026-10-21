
const mongoose = require('mongoose');

const {
  Client,
  Contract,
  Sale,
  Payment,
  Manifest,
  Banner,
  Collection,
  Audit,
} = require('../models');

const { RequestError, money } = require('./chofer-domain');

const zone = 'America/Mexico_City';

const zonedFormatter = new Intl.DateTimeFormat('en-GB', {
  timeZone: zone,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hourCycle: 'h23',
});

// ========================================
// FECHAS Y ZONA HORARIA
// ========================================

function zoneParts(value) {
  return Object.fromEntries(
    zonedFormatter.formatToParts(new Date(value))
      .filter(part => part.type !== 'literal')
      .map(part => [part.type, part.value])
  );
}

function localDate(value) {
  if (!value) return null;

  const p = zoneParts(value);

  return `${p.year}-${p.month}-${p.day}`;
}

function localTimestamp(value) {
  if (!value) return null;

  const p = zoneParts(value);

  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}:${p.second}`;
}

function utcStartOfLocalDay(day) {
  const sample = new Date(`${day}T12:00:00.000Z`);

  const p = zoneParts(sample);

  const localAsUTC = Date.UTC(
    Number(p.year),
    Number(p.month) - 1,
    Number(p.day),
    Number(p.hour),
    Number(p.minute),
    Number(p.second)
  );

  const offset = localAsUTC - sample.getTime();

  return new Date(
    Date.parse(`${day}T00:00:00.000Z`) - offset
  );
}

function dayRange(day) {
  const next = new Date(`${day}T00:00:00.000Z`);
  next.setUTCDate(next.getUTCDate() + 1);

  return {
    start: utcStartOfLocalDay(day),
    end: utcStartOfLocalDay(
      next.toISOString().slice(0, 10)
    ),
  };
}

// ========================================
// DINERO Y DECIMAL128
// ========================================

function toCents(value) {
  const raw = value == null
    ? '0'
    : value.toString();

  const match = /^(-?)(\d+)(?:\.(\d{1,2}))?$/.exec(raw);

  if (!match) {
    throw new Error(
      `Valor monetario inválido: ${raw}`
    );
  }

  const cents =
    BigInt(match[2]) * 100n +
    BigInt((match[3] || '').padEnd(2, '0'));

  return match[1] === '-' ? -cents : cents;
}

function asMoney(value) {
  return money(toCents(value));
}

// ========================================
// OBJECTID
// ========================================

function asObjectId(value) {
  if (
    typeof value !== 'string' ||
    !/^[a-f\d]{24}$/i.test(value)
  ) {
    throw new RequestError(
      'Identificador inválido.',
      400
    );
  }

  return new mongoose.Types.ObjectId(value);
}

// ========================================
// CLIENTE AUTENTICADO
// ========================================

async function customer(userId) {
  return Client.findOne({
    cuentaId: asObjectId(userId),
    activo: true,
  })
    .select('nombre direccion correo telefono')
    .lean();
}

// ========================================
// PAGOS Y SALDOS DE VENTAS
// ========================================

async function paymentTotals(sales) {
  if (sales.length === 0) {
    return new Map();
  }

  const grouped = await Payment.aggregate([
    {
      $match: {
        ventaId: {
          $in: sales.map(sale => sale._id),
        },
      },
    },
    {
      $group: {
        _id: '$ventaId',
        pagado: {
          $sum: '$importe',
        },
      },
    },
  ]);

  return new Map(
    grouped.map(row => [
      row._id.toString(),
      toCents(row.pagado),
    ])
  );
}

// ========================================
// ESTADO DE CUENTA DEL CLIENTE
// ========================================

async function customerAccount(userId) {
  const [client, notices] = await Promise.all([
    customer(userId),

    Banner.find({
      activo: true,
    })
      .sort({ _id: -1 })
      .limit(10)
      .select('titulo descripcion -_id')
      .lean(),
  ]);

  const result = {
    clientes: client
      ? [
          {
            nombre: client.nombre,
            direccion: client.direccion,
            correo: client.correo || null,
            telefono: client.telefono || null,
          },
        ]
      : [],

    contratos: [],
    ventas: [],
    manifiestos: [],

    avisos: notices.map(notice => ({
      titulo: notice.titulo,
      descripcion: notice.descripcion,
    })),
  };

  if (!client) {
    return result;
  }

  const [contracts, sales, manifests] = await Promise.all([
    Contract.find({
      clienteId: client._id,
    })
      .sort({ _id: -1 })
      .lean(),

    Sale.find({
      clienteId: client._id,
      activo: true,
    })
      .sort({ _id: -1 })
      .lean(),

    Manifest.find({
      clienteId: client._id,
      activo: true,
    })
      .sort({ _id: -1 })
      .select('folio fechaEmision')
      .lean(),
  ]);

  const paid = await paymentTotals(sales);

  // Contratos
  result.contratos = contracts.map(contract => ({
    folio: contract.folio,
    inicio: contract.fechaInicio,
    fin: contract.fechaFin,
    frecuencia: contract.frecuencia,
    monto: asMoney(contract.cuotaPorVisita),
    estado: contract.activo === false ? 0 : 1,
  }));

  // Ventas y saldos pendientes
  result.ventas = sales.map(sale => ({
    folio: sale.folio,
    fecha: localDate(sale.fecha),
    total: asMoney(sale.total),

    saldo: money(
      toCents(sale.total) -
      (paid.get(sale._id.toString()) || 0n)
    ),
  }));

  // Manifiestos
  result.manifiestos = manifests.map(manifest => ({
    id: manifest._id.toString(),
    folio: manifest.folio,
    fecha: localDate(manifest.fechaEmision),
  }));

  return result;
}

// ========================================
// DETALLE DEL MANIFIESTO
// ========================================

async function customerManifest(userId, manifestId) {
  const client = await customer(userId);

  if (!client) {
    throw new RequestError(
      'Manifiesto no encontrado.',
      404
    );
  }

  const manifest = await Manifest.findOne({
    _id: asObjectId(manifestId),
    clienteId: client._id,
    activo: true,
  })
    .populate('residuos.desechoId', 'nombre')
    .lean();

  if (!manifest) {
    throw new RequestError(
      'Manifiesto no encontrado.',
      404
    );
  }

  return {
    folio: manifest.folio,
    origen: manifest.origen,
    destino: manifest.destino,

    chofer: manifest.choferNombre,
    cliente: manifest.clienteNombre || client.nombre,

    observaciones: manifest.observaciones || null,

    emision: localTimestamp(
      manifest.fechaEmision
    ),

    entrega: localTimestamp(
      manifest.entrega?.fecha
    ),

    items: (manifest.residuos || []).map(item => ({
      descripcion:
        item.descripcion ||
        item.desechoId?.nombre ||
        'Residuo',

      cantidad: item.cantidad?.toString() || '0',
      peso: item.peso?.toString() || '0',
    })),
  };
}

// ========================================
// REPORTES ADMINISTRATIVOS
// ========================================

async function reports(day, metrics = {}) {
  const { start, end } = dayRange(day);

  const range = {
    $gte: start,
    $lt: end,
  };

  const [sales, collections, events] = await Promise.all([
    // Ventas del día
    Sale.find({
      fecha: range,
    })
      .populate('clienteId', 'nombre')
      .sort({ _id: -1 })
      .lean(),

    // Recolecciones fallidas
    Collection.find({
      'servicio.estado': 'fallida',
      'servicio.cierre': range,
    })
      .populate('clienteId', 'nombre')
      .sort({
        'servicio.cierre': -1,
        _id: -1,
      })
      .lean(),

    // Bitácora
    Audit.find({
      fecha: range,
    })
      .populate('usuarioId', 'usuario')
      .sort({ _id: -1 })
      .limit(100)
      .lean(),
  ]);

  const paid = await paymentTotals(sales);

  return {
    fecha: day,

    ventas: sales.map(sale => ({
      folio: sale.folio,
      cliente:
        sale.clienteId?.nombre ||
        'Cliente no disponible',

      total: asMoney(sale.total),

      saldo: money(
        toCents(sale.total) -
        (paid.get(sale._id.toString()) || 0n)
      ),
    })),

    incidencias: collections.map(stop => ({
      folio: stop.folio,

      cliente:
        stop.clienteId?.nombre ||
        'Cliente no disponible',

      motivo:
        stop.servicio?.motivo ||
        'Sin motivo registrado',
    })),

    eventos: events.map(event => ({
      recurso: event.recurso,
      recurso_id: event.recursoId,
      accion: event.accion,

      usuario:
        event.usuarioId?.usuario ||
        'Usuario no disponible',

      hora:
        localTimestamp(event.fecha)?.slice(11, 16) ||
        '--:--',
    })),

    servidor: {
      solicitudes: metrics.solicitudes || 0,
      errores: metrics.errores || 0,

      latencia_ms: Math.round(
        (metrics.total_ms || 0) /
        Math.max(1, metrics.solicitudes || 0)
      ),

      uptime_s: Math.floor(process.uptime()),

      ultima_generacion:
        metrics.ultima_generacion || null,
    },
  };
}

module.exports = {
  customerAccount,
  customerManifest,
  reports,
};

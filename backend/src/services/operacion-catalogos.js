
const { randomBytes, scrypt } = require('node:crypto');
const { promisify } = require('node:util');
const mongoose = require('mongoose');

const models = require('../models');
const { today } = require('./operacion-agenda');
const { activeShifts, shiftHours, listShifts } = require('./turnos');
const { embeddedNeighborhoodId } = require('./embedded-neighborhood');
const {
  RequestError,
  date,
  text,
  decimal,
  amount,
} = require('./chofer-domain');

const derive = promisify(scrypt);

const frequencies = ['Semanal', 'Quincenal', 'Mensual'];
const accounts = {
  cuentas_cliente: 4,
  cuentas_chofer: 3,
};

const activeFilter = {
  $or: [{ activo: true }, { activo: { $exists: false }, estado: 1 }],
};

const field = (
  key,
  label,
  type = 'text',
  required = true,
  max = 120,
  db = key
) => ({ key, label, type, required, max, db });

const ref = (
  key,
  label,
  source,
  required = true,
  db = key
) => ({
  ...field(key, label, 'ref', required, 120, db),
  source,
});

const name = field('nombre', 'Nombre');
const description = field(
  'descripcion',
  'Descripción',
  'text',
  false,
  255
);

// ==========================================
// DEFINICIÓN DE CATÁLOGOS
// ==========================================

const catalogs = {
  usuarios: {
    model: models.User,
    pk: 'pk_usuario',
    label: 'Usuarios',
    created: 'fechaCreacion',
    fields: [
      ref('fk_rol', 'Rol', 'roles', true, 'rolId'),
      field('usuario', 'Usuario'),
      field('nombre', 'Nombre', 'text', true, 255),
      field('correo', 'Correo', 'email', false),
      field(
        'pass',
        'Contraseña',
        'password',
        false,
        120,
        'passwordHash'
      ),
    ],
  },

  roles: {
    model: models.Role,
    pk: 'pk_rol',
    label: 'Roles',
    fields: [name, description],
  },

  clientes: {
    model: models.Client,
    pk: 'pk_cliente',
    label: 'Clientes',
    commercial: true,
    created: 'fechaRegistro',
    fields: [
      ref(
        'fk_usuario',
        'Cuenta del cliente',
        'cuentas_cliente',
        false,
        'cuentaId'
      ),
      name,
      field('telefono', 'Teléfono', 'phone', false, 10),
      field('correo', 'Correo', 'email', false),
      ref(
        'fk_actividad_comercial',
        'Actividad comercial',
        'actividades_comerciales',
        false,
        'actividadComercialId'
      ),
      field('razon_social', 'Razón social', 'text', false, 255, 'razonSocial'),
      field('rfc', 'RFC', 'text', false, 13),
      field('direccion', 'Dirección', 'text', true, 255),
      ref(
        'fk_colonia',
        'Colonia',
        'colonias',
        false,
        'coloniaId'
      ),
      field(
        'codigo_postal',
        'Código postal',
        'text',
        false,
        10,
        'codigoPostal'
      ),
    ],
  },

  contratos: {
    model: models.Contract,
    pk: 'pk_contrato',
    label: 'Contratos',
    title: 'folio',
    commercial: true,
    fields: [
      ref('fk_cliente', 'Cliente', 'clientes', true, 'clienteId'),
      field('folio', 'Folio', 'text', true, 50),
      field(
        'fecha_inicio',
        'Inicio de vigencia',
        'date',
        true,
        10,
        'fechaInicio'
      ),
      field(
        'fecha_fin',
        'Fin de vigencia',
        'date',
        true,
        10,
        'fechaFin'
      ),
      field(
        'frecuencia_recoleccion',
        'Frecuencia',
        'frequency',
        true,
        30,
        'frecuencia'
      ),
      ref('fk_turno', 'Turno de recolección', 'turnos_contrato', false, 'turnoId'),
      field(
        'monto',
        'Cuota por visita',
        'decimal',
        true,
        20,
        'cuotaPorVisita'
      ),
      field(
        'iva_porcentaje',
        'IVA (%)',
        'decimal',
        true,
        20,
        'ivaPorcentaje'
      ),
      field(
        'cargo_visita_fallida',
        'Cargo por visita fallida',
        'decimal',
        false,
        20,
        'cargoVisitaFallida'
      ),
      field(
        'kilos_mensuales',
        'Kilos incluidos al mes',
        'decimal',
        false,
        20,
        'kilosMensuales'
      ),
      field(
        'tarifa_excedente',
        'Tarifa por kilo excedente',
        'decimal',
        false,
        20,
        'tarifaExcedente'
      ),
      description,
    ],
  },

  rutas: {
    model: models.Route,
    pk: 'pk_ruta',
    label: 'Rutas',
    commercial: true,
    fields: [
      name,
      ref('fk_sector', 'Sector', 'sectores', false, 'sectorId'),
      description,
    ],
  },

  choferes: {
    model: models.Driver,
    pk: 'pk_chofer',
    label: 'Choferes',
    fields: [
      ref(
        'fk_usuario',
        'Cuenta del chofer',
        'cuentas_chofer',
        true,
        'cuentaId'
      ),
      name,
      field('telefono', 'Teléfono', 'text', false, 10),
      field(
        'numero_licencia',
        'Número de licencia',
        'text',
        true,
        50,
        'numeroLicencia'
      ),
      field(
        'vencimiento_licencia',
        'Vencimiento de licencia',
        'date',
        true,
        10,
        'vencimientoLicencia'
      ),
      field(
        'fecha_ingreso',
        'Fecha de ingreso',
        'date',
        true,
        10,
        'fechaIngreso'
      ),
    ],
  },

  turnos: {
    model: models.Shift,
    pk: 'pk_turno',
    label: 'Turnos',
    fields: [
      name,
      field('hora_inicio', 'Hora de inicio', 'time', true, 8, 'horaInicio'),
      field('hora_fin', 'Hora de fin', 'time', true, 8, 'horaFin'),
      description,
    ],
  },

  sectores: {
    model: models.Sector,
    pk: 'pk_sector',
    label: 'Sectores',
    fields: [name, description],
  },

  colonias: {
    model: models.Neighborhood,
    pk: 'pk_colonias',
    label: 'Colonias',
    fields: [
      name,
      ref('fk_sector', 'Sector', 'sectores', false, 'sectorId'),
      field('municipio', 'Municipio'),
      field('ciudad', 'Ciudad'),
      field(
        'estado_republica',
        'Estado',
        'text',
        true,
        120,
        'estado'
      ),
      field(
        'codigo_postal',
        'Código postal',
        'text',
        true,
        10,
        'codigoPostal'
      ),
    ],
  },

  actividades_comerciales: {
    model: models.CommercialActivity,
    pk: 'pk_actividad_comercial',
    label: 'Actividades comerciales',
    fields: [name, description],
  },

  desechos: {
    model: models.Waste,
    pk: 'pk_desecho',
    label: 'Residuos',
    fields: [
      name,
      field('tipo', 'Tipo'),
      field(
        'unidad_medida',
        'Unidad de medida',
        'text',
        true,
        50,
        'unidadMedida'
      ),
      field('precio', 'Precio', 'decimal'),
      description,
    ],
  },

  metodos_pago: {
    model: models.PaymentMethod,
    pk: 'pk_metodo_pago',
    label: 'Métodos de pago',
    fields: [name, description],
  },

  banners: {
    model: models.Banner,
    pk: 'pk_banner',
    label: 'Avisos',
    title: 'titulo',
    fields: [
      field('titulo', 'Título'),
      field('descripcion', 'Descripción', 'text', true, 255),
    ],
  },
};

// ==========================================
// VALIDAR ACCESO A CATÁLOGOS
// ==========================================

function definition(resource, role) {
  const config = Object.hasOwn(catalogs, resource)
    ? catalogs[resource]
    : null;

  if (!config || (role !== 1 && !config.commercial)) {
    throw new RequestError('Catálogo no disponible.', 404);
  }

  return config;
}

// ==========================================
// MENÚ DE CATÁLOGOS
// ==========================================

function menu(role) {
  return {
    items: Object.entries(catalogs)
      .filter(([key, config]) => !['roles', 'banners'].includes(key) &&
        (role === 1 || config.commercial))
      .map(([key, config]) => ({
        key,
        label: config.label,
      })),
  };
}

// ==========================================
// VALIDACIÓN DE OBJECTID
// ==========================================

function objectId(value, label = 'Identificador') {
  if (
    typeof value !== 'string' ||
    !/^[a-f\d]{24}$/i.test(value)
  ) {
    throw new RequestError(`${label} inválido.`);
  }

  return new mongoose.Types.ObjectId(value);
}

function neighborhoodLabel(row) {
  const postalCode = row.codigoPostal ?? row.codigo_postal;
  return postalCode ? `${row.nombre} (CP ${postalCode})` : row.nombre;
}

async function neighborhoodOptions() {
  const [sectors, standalone] = await Promise.all([
    models.Sector.find(activeFilter).select('colonias').lean(),
    models.Neighborhood.find().lean(),
  ]);
  const options = new Map();

  for (const sector of sectors) {
    const colonies = Array.isArray(sector.colonias) ? sector.colonias : [];
    for (const [index, colony] of colonies.entries()) {
      if (!colony?.nombre || (colony.activo ?? (colony.estado !== 0)) === false) {
        continue;
      }

      const id = embeddedNeighborhoodId(sector._id, colony, index).toString();
      options.set(id, { id, nombre: neighborhoodLabel(colony) });
    }
  }

  for (const row of standalone) {
    const id = row._id.toString();
    if (row.activo ?? (row.estado === 1)) {
      options.set(id, { id, nombre: neighborhoodLabel(row) });
    } else {
      options.delete(id);
    }
  }

  return [...options.values()].sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
}

async function catalogRole(code) {
  return models.Role.findOne({ codigo: code, ...activeFilter }).select('_id');
}

// ==========================================
// OPCIONES PARA SELECTORES
// ==========================================

async function options(_conn, source) {
  if (source === 'roles') {
    const rows = await models.Role.find(activeFilter)
      .sort({ codigo: 1 })
      .lean();

    return rows.map(row => ({
      id: row.codigo,
      nombre: row.nombre,
    }));
  }

  if (Object.hasOwn(accounts, source)) {
    const role = await catalogRole(accounts[source]);
    if (!role) return [];

    const [rows, assigned] = await Promise.all([
      models.User.find({ rolId: role._id, ...activeFilter })
        .select('usuario nombre').sort({ nombre: 1 }).lean(),
      source === 'cuentas_cliente' ? models.Client.distinct('cuentaId') : [],
    ]);
    const assignedIds = new Set(assigned.filter(Boolean).map(String));

    return rows.map(row => ({
      id: row._id.toString(),
      nombre: `${row.nombre} · ${row.usuario}`,
      ...(assignedIds.has(row._id.toString()) ? { asignada: true } : {}),
    }));
  }

  if (source === 'colonias') return neighborhoodOptions();

  if (source === 'turnos_contrato') {
    return (await listShifts()).map(shift => ({
      id: shift._id.toString(),
      nombre: `${shift.nombre} (${shift.horaInicio}–${shift.horaFin})`,
    }));
  }

  const config = catalogs[source];
  if (!config) return [];

  const sortField = config.title || 'nombre';

  const rows = await config.model.find(activeFilter)
    .sort({ [sortField]: 1 })
    .limit(500)
    .lean();

  return rows.map(row => ({
    id: row._id.toString(),
    nombre: row[sortField] || row.nombre || '',
  }));
}

// ==========================================
// NORMALIZAR Y VALIDAR VALORES
// ==========================================

function normalizeInput(item, value) {
  if (
    (value == null || value === '') &&
    !item.required
  ) {
    return null;
  }

  switch (item.type) {
    case 'ref': {
      if (item.source === 'roles') {
        const code = Number(value);

        if (!Number.isInteger(code) || code < 1) {
          throw new RequestError(`${item.label} inválido.`);
        }

        return code;
      }

      return objectId(value, item.label);
    }

    case 'decimal': {
      const cents = decimal(value, item.label, true);

      return mongoose.Types.Decimal128.fromString(
        amount(cents)
      );
    }

    case 'date':
      return date(value);

    case 'time':
      if (
        typeof value !== 'string' ||
        !/^([01]\d|2[0-3]):[0-5]\d(?::00)?$/.test(value)
      ) {
        throw new RequestError(
          `${item.label} requiere formato HH:MM.`
        );
      }

      return value.slice(0, 5);

    case 'frequency':
      if (!frequencies.includes(value)) {
        throw new RequestError(
          'Selecciona una frecuencia válida.'
        );
      }

      return value;

    case 'email':
      if (
        typeof value !== 'string' ||
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())
      ) {
        throw new RequestError('Correo inválido.');
      }

      return text(value, item.label, item.max).toLowerCase();

    case 'phone':
      if (typeof value !== 'string' || !/^\d{10}$/.test(value)) {
        throw new RequestError('El teléfono debe tener 10 dígitos.');
      }
      return value;

    case 'password':
      return text(value, item.label, item.max, item.required);

    default:
      return text(value, item.label, item.max, item.required);
  }
}

// ==========================================
// RESOLVER REFERENCIAS
// ==========================================

async function resolveReference(item, value) {
  if (value == null) return null;
  if (item.source === 'turnos_contrato') return value;

  let resolved = null;
  if (item.source === 'roles') {
    resolved = (await catalogRole(value))?._id;
  } else if (Object.hasOwn(accounts, item.source)) {
    const role = await catalogRole(accounts[item.source]);
    if (role) {
      resolved = (await models.User.exists({
        _id: value,
        rolId: role._id,
        ...activeFilter,
      }))?._id;
    }
  } else if (item.source === 'colonias') {
    const neighborhoods = await neighborhoodOptions();
    if (neighborhoods.some(option => option.id === value.toString())) {
      resolved = value;
    }
  } else {
    const target = catalogs[item.source];
    resolved = (await target?.model.exists({
      _id: value,
      ...activeFilter,
    }))?._id;
  }

  if (!resolved) {
    throw new RequestError(`${item.label} no está disponible.`, 409);
  }

  return resolved;
}

// ==========================================
// CONSTRUIR DOCUMENTO
// ==========================================

async function buildValues(resource, config, body, existingId) {
  const values = {};

  for (const item of config.fields) {
    const raw = normalizeInput(item, body[item.key]);

    if (item.type === 'password') {
      if (raw == null) {
        if (!existingId) {
          throw new RequestError('Captura una contraseña.');
        }

        continue;
      }

      if (raw !== body.confirmar_pass) {
        throw new RequestError('Las contraseñas no coinciden.');
      }

      if (raw.length < 8) {
        throw new RequestError(
          'La contraseña requiere al menos ocho caracteres.'
        );
      }

      const salt = randomBytes(16).toString('hex');

      const hash = (
        await derive(raw, salt, 64)
      ).toString('hex');

      values[item.db] = `scrypt:${salt}:${hash}`;

      continue;
    }

    if (item.type === 'ref') {
      values[item.db] = await resolveReference(item, raw);
    } else {
      values[item.db] = raw;
    }
  }

  if (resource === 'usuarios') {
    values.usuarioNormalizado = values.usuario.toLowerCase();

    values.correoNormalizado = values.correo
      ? values.correo.toLowerCase()
      : null;
  }

  return values;
}

// ==========================================
// VALIDAR CAMPOS ÚNICOS
// ==========================================

async function validateUnique(resource, values, existingId) {
  const Model = catalogs[resource].model;

  const checks = {
    usuarios: [
      ['usuarioNormalizado', values.usuarioNormalizado, 'Usuario'],
      ['correoNormalizado', values.correoNormalizado, 'Correo'],
    ],

    contratos: [
      ['folio', values.folio, 'Folio'],
    ],

    choferes: [
      ['cuentaId', values.cuentaId, 'Cuenta del chofer'],
    ],

    clientes: [
      ['cuentaId', values.cuentaId, 'Cuenta del cliente'],
    ],
  };

  for (const [key, value, label] of checks[resource] || []) {
    if (value == null) continue;

    const filter = { [key]: value };

    if (existingId) {
      filter._id = { $ne: existingId };
    }

    if (await Model.exists(filter)) {
      throw new RequestError(
        `El campo ${label} ya está en uso.`,
        409
      );
    }
  }
}

// ==========================================
// BITÁCORA
// ==========================================

async function audit(user, resource, resourceId, action) {
  // Compatibilidad temporal con llamadas anteriores:
  // audit(conn, user, resource, id, action).

  if (arguments.length === 5) {
    [, user, resource, resourceId, action] = arguments;
  }

  if (
    typeof user !== 'string' ||
    !/^[a-f\d]{24}$/i.test(user)
  ) {
    return;
  }

  await models.Audit.create({
    usuarioId: new mongoose.Types.ObjectId(user),
    recurso: resource,
    recursoId: String(resourceId),
    accion: action,
    fecha: new Date(),
  });
}

// ==========================================
// LISTAR REGISTROS
// ==========================================

async function list(resource, role, page = 1) {
  const config = definition(resource, role);
  const offset = (page - 1) * 50;

  const query = config.model.find()
    .sort({ activo: -1, _id: -1 })
    .skip(offset)
    .limit(51);

  for (const item of config.fields.filter(
    field => field.source === 'roles'
  )) {
    query.populate({
      path: item.db,
      select: 'codigo nombre folio titulo usuario',
    });
  }

  const documents = await query.lean();

  const items = documents.slice(0, 50).map(document => {
    const result = {
      id: document._id.toString(),
      estado: (document.activo ?? document.estado !== 0) ? 1 : 0,
    };

    for (const item of config.fields) {
      if (item.type === 'password') continue;

      const value = document[item.db];

      if (item.type === 'ref') {
        result[item.key] = value == null
          ? null
          : item.source === 'roles'
            ? value.codigo
            : value.toString();
      } else if (item.type === 'decimal') {
        result[item.key] = value == null
          ? null
          : value.toString();
      } else if (item.type === 'date') {
        result[item.key] = value == null
          ? null
          : String(value).slice(0, 10);
      } else {
        result[item.key] = value == null ? null : value;
      }
    }

    return result;
  });

  const selectors = {};

  for (const item of config.fields.filter(
    field => field.source
  )) {
    selectors[item.source] = await options(null, item.source);
  }

  const fieldMetadata = ({ key, label, type, required, max, source }) => ({
    key, label, type, required, max, ...(source ? { source } : {}),
  });
  const clientFields = catalogs.clientes.fields.filter(item =>
    !['fk_usuario', 'nombre', 'correo'].includes(item.key)
  );
  if (resource === 'usuarios') {
    for (const item of clientFields.filter(item => item.source)) {
      selectors[item.source] = await options(null, item.source);
    }
  }

  return {
    items,
    more: documents.length > 50,

    fields: config.fields.map(fieldMetadata),
    ...(resource === 'usuarios' ? { campos_cliente: clientFields.map(fieldMetadata) } : {}),

    selectors,
    title: config.title || 'nombre',
    label: config.label,
    frequencies,
    ...(resource === 'contratos' ? { fecha_actual: today() } : {}),
  };
}

// ==========================================
// CREAR Y EDITAR REGISTROS
// ==========================================

function requireWritable(resource) {
  if (['roles', 'banners'].includes(resource)) {
    throw new RequestError('Este catálogo es de solo lectura.', 403);
  }
}

async function createClientAndAccount(user, client, account, returnAccount) {
  await validateUnique('usuarios', account, null);
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(async () => {
      const [createdUser] = await models.User.create([account], { session });
      const [createdClient] = await models.Client.create([
        { ...client, cuentaId: createdUser._id },
      ], { session });
      await models.Audit.create([
        { usuarioId: user.pk_usuario, recurso: 'clientes',
          recursoId: String(createdClient._id), accion: 'guardar' },
        { usuarioId: user.pk_usuario, recurso: 'usuarios',
          recursoId: String(createdUser._id), accion: 'guardar' },
      ], { session, ordered: true });
      return { id: String(returnAccount ? createdUser._id : createdClient._id) };
    });
  } finally {
    await session.endSession();
  }
}

async function save(user, resource, resourceId, body) {
  requireWritable(resource);
  body ??= {};
  const config = definition(resource, user.fk_rol);

  const existingId = resourceId
    ? objectId(resourceId)
    : null;

  const values = await buildValues(
    resource,
    config,
    body || {},
    existingId
  );

  // Evitar que el administrador cambie su propio rol.
  if (
    resource === 'usuarios' &&
    existingId &&
    existingId.toString() === String(user.pk_usuario)
  ) {
    const current = await models.User.findById(existingId)
      .select('rolId');

    if (current && !current.rolId.equals(values.rolId)) {
      throw new RequestError(
        'Tu cuenta debe conservar el rol de administrador.',
        409
      );
    }
  }

  // Validaciones específicas de contratos.
  if (resource === 'contratos') {
    const current = existingId
      ? await models.Contract.findById(existingId)
        .select('clienteId fechaInicio turnoId horaServicio').lean()
      : null;

    if (existingId && !current) {
      throw new RequestError('Registro no encontrado.', 404);
    }

    if (values.fechaInicio < today() && values.fechaInicio !== current?.fechaInicio) {
      throw new RequestError('El inicio de vigencia no puede ser anterior a hoy.');
    }

    if (!values.turnoId && (!current || current.turnoId)) {
      throw new RequestError('Selecciona un turno de recolección.');
    }

    if (values.turnoId && String(values.turnoId) !== String(current?.turnoId)) {
      const shift = await models.Shift.findOne({
        _id: values.turnoId,
        ...activeShifts,
      }).lean();
      const hours = shiftHours(shift);
      if (!hours) throw new RequestError('El turno ya no está disponible.', 409);
      values.horaServicio = hours.horaInicio;
    } else {
      values.horaServicio = current?.horaServicio ?? null;
    }

    if (
      values.fechaFin < values.fechaInicio ||
      Number(values.ivaPorcentaje.toString()) > 100 ||
      (
        values.kilosMensuales != null &&
        values.tarifaExcedente == null
      )
    ) {
      throw new RequestError(
        'Revisa la vigencia, el porcentaje de IVA y la tarifa de excedente.'
      );
    }

    if (
      current && !current.clienteId.equals(values.clienteId) &&
      await models.Collection.exists({ contratoId: existingId })
    ) {
      throw new RequestError(
        'El contrato ya tiene visitas. Conserva el cliente original.',
        409
      );
    }
  }

  // Validación de turnos.
  if (
    resource === 'turnos' &&
    values.horaInicio >= values.horaFin
  ) {
    throw new RequestError(
      'La hora de fin debe ser posterior a la de inicio.'
    );
  }

  await validateUnique(resource, values, existingId);

  let saved;

  try {
    if (!existingId && resource === 'clientes' && !values.cuentaId) {
      const account = await buildValues('usuarios', catalogs.usuarios, {
        fk_rol: 4, usuario: body.usuario_cliente, pass: body.pass_cliente,
        confirmar_pass: body.confirmar_pass_cliente,
        nombre: values.nombre, correo: values.correo,
      }, null);
      return await createClientAndAccount(user, values, account, false);
    }

    if (!existingId && resource === 'usuarios' && Number(body.fk_rol) === 4) {
      const client = await buildValues('clientes', catalogs.clientes, {
        ...body, fk_usuario: null,
      }, null);
      return await createClientAndAccount(user, client, values, true);
    }

    if (existingId) {
      saved = await config.model.findByIdAndUpdate(
        existingId,
        { $set: values },
        {
          new: true,
          runValidators: true,
        }
      );

      if (!saved) {
        throw new RequestError('Registro no encontrado.', 404);
      }
    } else {
      saved = await config.model.create({
        ...values,
        activo: true,
        ...(config.created
          ? { [config.created]: new Date() }
          : {}),
      });
    }
  } catch (error) {
    if (error.code === 11000) {
      throw new RequestError(
        'Ya existe un registro con esos datos únicos.',
        409
      );
    }

    if (error.name === 'ValidationError') {
      throw new RequestError(error.message, 400);
    }

    throw error;
  }

  await audit(
    user.pk_usuario,
    resource,
    saved._id,
    'guardar'
  );

  return {
    id: saved._id.toString(),
  };
}

// ==========================================
// ACTIVAR / DESACTIVAR REGISTROS
// ==========================================

async function setActive(user, resource, resourceId, active) {
  requireWritable(resource);
  const config = definition(resource, user.fk_rol);
  const id = objectId(resourceId);

  if (typeof active !== 'boolean') {
    throw new RequestError('Estado inválido.');
  }

  const record = await config.model.findById(id);

  if (!record) {
    throw new RequestError('Registro no encontrado.', 404);
  }

  if (
    !active &&
    resource === 'usuarios' &&
    id.toString() === String(user.pk_usuario)
  ) {
    throw new RequestError(
      'No puedes desactivar tu propia cuenta.',
      409
    );
  }

  if (
    !active &&
    resource === 'roles' &&
    record.codigo === 1
  ) {
    throw new RequestError(
      'El rol de administración debe permanecer activo.',
      409
    );
  }

  record.activo = active;
  await record.save();

  // Al desactivar un usuario, invalidar sus sesiones.
  if (!active && resource === 'usuarios') {
    await models.Session.deleteMany({
      userId: id,
    });
  }

  // Al desactivar un rol, invalidar las sesiones de sus usuarios.
  if (!active && resource === 'roles') {
    const users = await models.User.find({
      rolId: id,
    }).select('_id').lean();

    await models.Session.deleteMany({
      userId: {
        $in: users.map(user => user._id),
      },
    });
  }

  await audit(
    user.pk_usuario,
    resource,
    id,
    active ? 'activar' : 'desactivar'
  );

  return {
    id: id.toString(),
  };
}

module.exports = {
  audit,
  menu,
  options,
  list,
  save,
  setActive,
};

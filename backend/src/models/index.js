
const mongoose = require('mongoose');

const { Schema } = mongoose;
const ObjectId = Schema.Types.ObjectId;
const Decimal = Schema.Types.Decimal128;

const options = {
  timestamps: true,
  versionKey: false,
  minimize: false,
};

function defineModel(name, schema, collection) {
  return mongoose.models[name] ||
    mongoose.model(name, schema, collection);
}

// ==========================================
// ROLES
// ==========================================

const roleSchema = new Schema({
  codigo: {
    type: Number,
    required: true,
    unique: true,
  },
  nombre: {
    type: String,
    required: true,
    trim: true,
  },
  descripcion: {
    type: String,
    default: '',
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

// ==========================================
// USUARIOS
// ==========================================

const userSchema = new Schema({
  rolId: {
    type: ObjectId,
    ref: 'Role',
    required: true,
  },
  usuario: {
    type: String,
    required: true,
    trim: true,
  },
  usuarioNormalizado: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
    unique: true,
  },
  nombre: {
    type: String,
    required: true,
    trim: true,
    maxlength: 255,
  },
  correo: {
    type: String,
    default: null,
    trim: true,
    lowercase: true,
  },
  correoNormalizado: {
    type: String,
    default: null,
    trim: true,
    lowercase: true,
  },
  passwordHash: {
    type: String,
    required: true,
    select: false,
  },
  activo: {
    type: Boolean,
    default: true,
  },
  fechaCreacion: {
    type: Date,
    default: Date.now,
  },
}, options);

userSchema.index(
  { correoNormalizado: 1 },
  {
    unique: true,
    partialFilterExpression: {
      correoNormalizado: { $type: 'string' },
    },
  }
);

userSchema.index({ rolId: 1, activo: 1 });

// ==========================================
// CLIENTES
// ==========================================

const clientSchema = new Schema({
  cuentaId: {
    type: ObjectId,
    ref: 'User',
    default: null,
  },
  nombre: {
    type: String,
    required: true,
    trim: true,
    maxlength: 120,
  },
  telefono: {
    type: String,
    default: null,
  },
  correo: {
    type: String,
    default: null,
    lowercase: true,
  },
  actividadComercialId: {
    type: ObjectId,
    ref: 'CommercialActivity',
    default: null,
  },
  razonSocial: {
    type: String,
    default: null,
  },
  rfc: {
    type: String,
    default: null,
    uppercase: true,
  },
  direccion: {
    type: String,
    required: true,
  },
  coloniaId: {
    type: ObjectId,
    ref: 'Neighborhood',
    default: null,
  },
  codigoPostal: {
    type: String,
    default: null,
  },
  fechaRegistro: {
    type: Date,
    default: Date.now,
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

clientSchema.index(
  { cuentaId: 1 },
  {
    unique: true,
    partialFilterExpression: {
      cuentaId: { $type: 'objectId' },
    },
  }
);

clientSchema.index({
  nombre: 'text',
  razonSocial: 'text',
  rfc: 'text',
});

// ==========================================
// CONTRATOS
// ==========================================

const contractSchema = new Schema({
  clienteId: {
    type: ObjectId,
    ref: 'Client',
    required: true,
  },
  folio: {
    type: String,
    required: true,
    unique: true,
  },
  fechaInicio: {
    type: String,
    required: true,
  },
  fechaFin: {
    type: String,
    required: true,
  },
  frecuencia: {
    type: String,
    enum: ['Semanal', 'Quincenal', 'Mensual'],
    required: true,
  },
  turnoId: {
    type: ObjectId,
    ref: 'Shift',
    default: null,
  },
  horaServicio: {
    type: String,
    default: null,
  },
  cuotaPorVisita: {
    type: Decimal,
    required: true,
  },
  ivaPorcentaje: {
    type: Decimal,
    required: true,
  },
  cargoVisitaFallida: {
    type: Decimal,
    default: null,
  },
  kilosMensuales: {
    type: Decimal,
    default: null,
  },
  tarifaExcedente: {
    type: Decimal,
    default: null,
  },
  descripcion: {
    type: String,
    default: '',
  },
  activo: {
    type: Boolean,
    default: true,
  },
  fechaCreacion: {
    type: Date,
    default: Date.now,
  },
}, options);

contractSchema.index({
  clienteId: 1,
  activo: 1,
  fechaInicio: 1,
  fechaFin: 1,
});

// ==========================================
// CHOFERES
// ==========================================

const driverSchema = new Schema({
  cuentaId: {
    type: ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  nombre: {
    type: String,
    required: true,
  },
  telefono: String,
  numeroLicencia: {
    type: String,
    required: true,
  },
  vencimientoLicencia: {
    type: String,
    required: true,
  },
  fechaIngreso: {
    type: String,
    required: true,
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

// ==========================================
// CATÁLOGOS
// ==========================================

const routeSchema = new Schema({
  nombre: {
    type: String,
    required: true,
  },
  sectorId: {
    type: ObjectId,
    ref: 'Sector',
    default: null,
  },
  descripcion: {
    type: String,
    default: '',
  },
  fechaCreacion: {
    type: Date,
    default: Date.now,
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

const shiftSchema = new Schema({
  nombre: {
    type: String,
    required: true,
    unique: true,
  },
  horaInicio: {
    type: String,
    required: true,
  },
  horaFin: {
    type: String,
    required: true,
  },
  descripcion: {
    type: String,
    default: '',
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

const sectorSchema = new Schema({
  nombre: {
    type: String,
    required: true,
    unique: true,
  },
  descripcion: {
    type: String,
    default: '',
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

const neighborhoodSchema = new Schema({
  nombre: {
    type: String,
    required: true,
  },
  sectorId: {
    type: ObjectId,
    ref: 'Sector',
    default: null,
  },
  municipio: String,
  ciudad: String,
  estado: String,
  codigoPostal: String,
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

neighborhoodSchema.index({
  nombre: 1,
  codigoPostal: 1,
});

const activitySchema = new Schema({
  nombre: {
    type: String,
    required: true,
    unique: true,
  },
  descripcion: {
    type: String,
    default: '',
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

const wasteSchema = new Schema({
  nombre: {
    type: String,
    required: true,
    unique: true,
  },
  tipo: {
    type: String,
    required: true,
  },
  unidadMedida: {
    type: String,
    required: true,
  },
  precio: {
    type: Decimal,
    required: true,
  },
  descripcion: {
    type: String,
    default: '',
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

const paymentMethodSchema = new Schema({
  nombre: {
    type: String,
    required: true,
    unique: true,
  },
  descripcion: {
    type: String,
    default: '',
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

const bannerSchema = new Schema({
  titulo: {
    type: String,
    required: true,
    maxlength: 120,
  },
  descripcion: {
    type: String,
    required: true,
    maxlength: 255,
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

// ==========================================
// SUBDOCUMENTOS DE RECOLECCIONES
// ==========================================

const wasteItemSchema = new Schema({
  desechoId: {
    type: ObjectId,
    ref: 'Waste',
    required: true,
  },
  cantidad: {
    type: Decimal,
    required: true,
  },
  peso: {
    type: Decimal,
    required: true,
  },
  observaciones: {
    type: String,
    default: null,
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, { _id: false });

const driverServiceSchema = new Schema({
  estado: {
    type: String,
    enum: [
      'pendiente',
      'en_curso',
      'completada',
      'fallida',
    ],
    default: 'pendiente',
  },
  usuarioId: {
    type: ObjectId,
    ref: 'User',
    default: null,
  },
  llegada: {
    type: Date,
    default: null,
  },
  cierre: {
    type: Date,
    default: null,
  },
  motivo: {
    type: String,
    default: null,
  },
  insumos: {
    type: String,
    default: null,
  },
  foto: {
    type: Buffer,
    default: null,
  },
  firma: {
    type: Buffer,
    default: null,
  },
  ventaId: {
    type: ObjectId,
    ref: 'Sale',
    default: null,
  },
  manifiestoId: {
    type: ObjectId,
    ref: 'Manifest',
    default: null,
  },
}, { _id: false });

// ==========================================
// RECOLECCIONES
// ==========================================

const collectionSchema = new Schema({
  clienteId: {
    type: ObjectId,
    ref: 'Client',
    required: true,
  },
  contratoId: {
    type: ObjectId,
    ref: 'Contract',
    required: true,
  },
  rutaId: {
    type: ObjectId,
    ref: 'Route',
    default: null,
  },
  choferId: {
    type: ObjectId,
    ref: 'Driver',
    default: null,
  },
  turnoId: {
    type: ObjectId,
    ref: 'Shift',
    default: null,
  },
  folio: {
    type: String,
    required: true,
    unique: true,
  },
  fecha: {
    type: Date,
    required: true,
  },
  fechaClave: {
    type: String,
    required: true,
  },
  observaciones: {
    type: String,
    default: null,
  },
  orden: {
    type: Number,
    default: null,
  },
  total: {
    type: Decimal,
    default: null,
  },
  respuestaCliente: {
    type: String,
    enum: [
      'pendiente',
      'confirmada',
      'reprogramada',
      'cancelada',
    ],
    default: 'pendiente',
  },
  publicada: {
    type: Boolean,
    default: false,
  },
  activo: {
    type: Boolean,
    default: true,
  },
  servicio: {
    type: driverServiceSchema,
    default: () => ({}),
  },
  residuos: {
    type: [wasteItemSchema],
    default: [],
  },
  fechaOriginalClave: {
  type: String,
  required: true,
},
}, options);

// Impide generar dos veces la misma visita original.
collectionSchema.index(
  { contratoId: 1, fechaOriginalClave: 1 },
  { unique: true }
);

// Impide dos visitas activas del mismo contrato en una fecha.
collectionSchema.index(
  { contratoId: 1, fechaClave: 1 },
  {
    unique: true,
    partialFilterExpression: { activo: true },
  }
);

collectionSchema.index({
  choferId: 1,
  fecha: 1,
  turnoId: 1,
});

collectionSchema.index({
  rutaId: 1,
  turnoId: 1,
  fecha: 1,
});

collectionSchema.index({
  clienteId: 1,
  fecha: -1,
});

// ==========================================
// VENTAS
// ==========================================

const saleLineSchema = new Schema({
  concepto: {
    type: String,
    required: true,
  },
  cantidad: {
    type: Decimal,
    required: true,
  },
  precioUnitario: {
    type: Decimal,
    required: true,
  },
  subtotal: {
    type: Decimal,
    required: true,
  },
}, { _id: false });

const saleSchema = new Schema({
  clienteId: {
    type: ObjectId,
    ref: 'Client',
    required: true,
  },
  usuarioId: {
    type: ObjectId,
    ref: 'User',
    required: true,
  },
  recoleccionId: {
    type: ObjectId,
    ref: 'Collection',
    required: true,
    unique: true,
  },
  metodoPagoId: {
    type: ObjectId,
    ref: 'PaymentMethod',
    default: null,
  },
  folio: {
    type: String,
    required: true,
    unique: true,
  },
  fecha: {
    type: Date,
    required: true,
  },
  subtotal: {
    type: Decimal,
    required: true,
  },
  iva: {
    type: Decimal,
    required: true,
  },
  total: {
    type: Decimal,
    required: true,
  },
  observaciones: {
    type: String,
    default: null,
  },
  conceptos: {
    type: [saleLineSchema],
    default: [],
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

saleSchema.index({ clienteId: 1, fecha: -1 });

// ==========================================
// PAGOS
// ==========================================

const paymentSchema = new Schema({
  ventaId: {
    type: ObjectId,
    ref: 'Sale',
    required: true,
  },
  usuarioId: {
    type: ObjectId,
    ref: 'User',
    required: true,
  },
  turnoId: {
    type: ObjectId,
    ref: 'Shift',
    required: true,
  },
  metodoPagoId: {
    type: ObjectId,
    ref: 'PaymentMethod',
    required: true,
  },
  importe: {
    type: Decimal,
    required: true,
  },
  fecha: {
    type: Date,
    required: true,
  },
  clave: {
    type: String,
    required: true,
  },
}, options);

paymentSchema.index(
  { usuarioId: 1, clave: 1 },
  { unique: true }
);

paymentSchema.index({ ventaId: 1, fecha: 1 });
paymentSchema.index({ usuarioId: 1, turnoId: 1, fecha: 1 });

// ==========================================
// MANIFIESTOS
// ==========================================

const manifestItemSchema = new Schema({
  desechoId: {
    type: ObjectId,
    ref: 'Waste',
    default: null,
  },
  cantidad: {
    type: Decimal,
    required: true,
  },
  peso: {
    type: Decimal,
    required: true,
  },
  unidadMedida: {
    type: String,
    required: true,
  },
  descripcion: {
    type: String,
    required: true,
  },
}, { _id: false });

const deliverySchema = new Schema({
  usuarioId: {
    type: ObjectId,
    ref: 'User',
    required: true,
  },
  fecha: {
    type: Date,
    required: true,
  },
}, { _id: false });

const manifestSchema = new Schema({
  recoleccionId: {
    type: ObjectId,
    ref: 'Collection',
    required: true,
    unique: true,
  },
  clienteId: {
    type: ObjectId,
    ref: 'Client',
    required: true,
  },
  choferId: {
    type: ObjectId,
    ref: 'Driver',
    required: true,
  },
  folio: {
    type: String,
    required: true,
    unique: true,
  },
  fechaEmision: {
    type: Date,
    required: true,
  },
  origen: {
    type: String,
    required: true,
  },
  destino: {
    type: String,
    default: null,
  },
  observaciones: {
    type: String,
    default: null,
  },
  clienteNombre: {
    type: String,
    required: true,
  },
  choferNombre: {
    type: String,
    required: true,
  },
  residuos: {
    type: [manifestItemSchema],
    default: [],
  },
  entrega: {
    type: deliverySchema,
    default: null,
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

manifestSchema.index({
  clienteId: 1,
  fechaEmision: -1,
});

// ==========================================
// VIÁTICOS
// ==========================================

const expenseDetailSchema = new Schema({
  concepto: {
    type: String,
    required: true,
  },
  cantidad: {
    type: Decimal,
    required: true,
  },
  importe: {
    type: Decimal,
    required: true,
  },
  fecha: {
    type: Date,
    required: true,
  },
}, { _id: false });

const expenseSchema = new Schema({
  choferId: {
    type: ObjectId,
    ref: 'Driver',
    required: true,
  },
  rutaId: {
    type: ObjectId,
    ref: 'Route',
    default: null,
  },
  usuarioId: {
    type: ObjectId,
    ref: 'User',
    required: true,
  },
  turnoId: {
    type: ObjectId,
    ref: 'Shift',
    required: true,
  },
  recoleccionId: {
    type: ObjectId,
    ref: 'Collection',
    default: null,
  },
  jornada: String,
  fecha: {
    type: Date,
    required: true,
  },
  importe: {
    type: Decimal,
    required: true,
  },
  concepto: {
    type: String,
    required: true,
  },
  clave: {
    type: String,
    required: true,
  },
  detalles: {
    type: [expenseDetailSchema],
    default: [],
  },
  activo: {
    type: Boolean,
    default: true,
  },
}, options);

expenseSchema.index(
  { usuarioId: 1, clave: 1 },
  { unique: true }
);

expenseSchema.index({
  usuarioId: 1,
  turnoId: 1,
  fecha: 1,
});

// ==========================================
// CORTES
// ==========================================

const cutMovementSchema = new Schema({
  pagoId: {
    type: ObjectId,
    ref: 'Payment',
    default: null,
  },
  ventaId: {
    type: ObjectId,
    ref: 'Sale',
    required: true,
  },
  metodoPagoId: {
    type: ObjectId,
    ref: 'PaymentMethod',
    required: true,
  },
  concepto: {
    type: String,
    required: true,
  },
  importe: {
    type: Decimal,
    required: true,
  },
  fecha: {
    type: Date,
    required: true,
  },
}, { _id: false });

const cutSchema = new Schema({
  usuarioId: {
    type: ObjectId,
    ref: 'User',
    required: true,
  },
  turnoId: {
    type: ObjectId,
    ref: 'Shift',
    required: true,
  },
  jornada: {
    type: String,
    required: true,
  },
  fechaInicio: {
    type: Date,
    required: true,
  },
  fechaFin: {
    type: Date,
    required: true,
  },
  fondoInicial: {
    type: Decimal,
    required: true,
  },
  totalCobros: {
    type: Decimal,
    required: true,
  },
  totalViaticos: {
    type: Decimal,
    required: true,
  },
  efectivoFinal: {
    type: Decimal,
    required: true,
  },
  observaciones: {
    type: String,
    default: null,
  },
  efectivoEsperado: {
    type: Decimal,
    required: true,
  },
  efectivoCobrado: Decimal,
  efectivoContado: {
    type: Decimal,
    default: null,
  },
  diferencia: {
    type: Decimal,
    default: null,
  },
  revisorId: {
    type: ObjectId,
    ref: 'User',
    default: null,
  },
  fechaRevision: {
    type: Date,
    default: null,
  },
  notaRevision: {
    type: String,
    default: null,
  },
  movimientos: {
    type: [cutMovementSchema],
    default: [],
  },
}, options);

cutSchema.index(
  { usuarioId: 1, turnoId: 1, jornada: 1 },
  { unique: true }
);

cutSchema.index({ jornada: 1, revisorId: 1 });

// ==========================================
// BITÁCORA
// ==========================================

const auditSchema = new Schema({
  usuarioId: {
    type: ObjectId,
    ref: 'User',
    required: true,
  },
  recurso: {
    type: String,
    required: true,
    maxlength: 60,
  },
  recursoId: {
    type: String,
    required: true,
  },
  accion: {
    type: String,
    required: true,
    maxlength: 40,
  },
  fecha: {
    type: Date,
    default: Date.now,
  },
}, { versionKey: false });

auditSchema.index({
  recurso: 1,
  recursoId: 1,
  fecha: -1,
});

auditSchema.index({ fecha: -1 });

const planningLockSchema = new Schema({
  _id: {
    type: String,
    required: true,
  },
  version: {
    type: Number,
    default: 0,
  },
}, {
  versionKey: false,
});

const sessionSchema = new Schema({
  tokenHash: {
    type: String,
    required: true,
    unique: true,
  },
  userId: {
    type: ObjectId,
    ref: 'User',
    required: true,
  },
  expiresAt: {
    type: Date,
    required: true,
  },
}, {
  timestamps: true,
  versionKey: false,
});

// Elimina automáticamente las sesiones vencidas.
sessionSchema.index(
  { expiresAt: 1 },
  { expireAfterSeconds: 0 }
);

sessionSchema.index({ userId: 1, expiresAt: 1 });

// ==========================================
// EXPORTAR MODELOS
// ==========================================

module.exports = {
  Role: defineModel('Role', roleSchema, 'roles'),
  User: defineModel('User', userSchema, 'usuarios'),
  Client: defineModel('Client', clientSchema, 'clientes'),
  Contract: defineModel('Contract', contractSchema, 'contratos'),
  Driver: defineModel('Driver', driverSchema, 'choferes'),
  Route: defineModel('Route', routeSchema, 'rutas'),
  Shift: defineModel('Shift', shiftSchema, 'turnos'),
  Sector: defineModel('Sector', sectorSchema, 'sectores'),
  Neighborhood: defineModel('Neighborhood', neighborhoodSchema, 'colonias'),
  CommercialActivity: defineModel(
    'CommercialActivity',
    activitySchema,
    'actividades_comerciales'
  ),
  Waste: defineModel('Waste', wasteSchema, 'desechos'),
  PaymentMethod: defineModel(
    'PaymentMethod',
    paymentMethodSchema,
    'metodos_pago'
  ),
  Banner: defineModel('Banner', bannerSchema, 'banners'),
  Collection: defineModel('Collection', collectionSchema, 'recolecciones'),
  Sale: defineModel('Sale', saleSchema, 'ventas'),
  Payment: defineModel('Payment', paymentSchema, 'pagos'),
  Manifest: defineModel('Manifest', manifestSchema, 'manifiestos'),
  Expense: defineModel('Expense', expenseSchema, 'viaticos'),
  Cut: defineModel('Cut', cutSchema, 'cortes'),
  Audit: defineModel('Audit', auditSchema, 'bitacora_operacion'),
  Session: defineModel('Session', sessionSchema, 'sesiones'),
  PlanningLock: defineModel(
  'PlanningLock',
  planningLockSchema,
  'bloqueos_agenda'
),
};

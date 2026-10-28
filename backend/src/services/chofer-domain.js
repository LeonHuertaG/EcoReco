class RequestError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function decimal(value, label, allowZero = false) {
  if (!['string', 'number'].includes(typeof value) ||
      !/^\d{1,8}(?:\.\d{1,2})?$/.test(String(value))) {
    throw new RequestError(`${label} debe tener hasta dos decimales.`);
  }
  const [units, fraction = ''] = String(value).split('.');
  const cents = BigInt(units) * 100n + BigInt(fraction.padEnd(2, '0'));
  if (!allowZero && cents === 0n) throw new RequestError(`${label} debe ser mayor que cero.`);
  return cents;
}

function money(cents) {
  const abs = cents < 0n ? -cents : cents;
  return `${cents < 0n ? '-' : ''}${abs / 100n}.${String(abs % 100n).padStart(2, '0')}`;
}

function amount(cents) {
  if (cents > 9999999999n || cents < -9999999999n) {
    throw new RequestError('El importe excede el límite admitido.');
  }
  return money(cents);
}

function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      Number.isNaN(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value ||
      value < '1000-01-01' || value > '9999-12-30') {
    throw new RequestError('Fecha inválida. Usa AAAA-MM-DD.');
  }
  return value;
}

function text(value, label, max, required = true) {
  if (value == null && !required) return null;
  if (typeof value !== 'string' || value.trim().length > max || (required && !value.trim())) {
    throw new RequestError(`${label} debe contener ${required ? 'entre 1 y' : 'hasta'} ${max} caracteres.`);
  }
  return value.trim() || null;
}

function id(value) {
  if (!['string', 'number'].includes(typeof value) ||
      !/^[1-9]\d{0,9}$/.test(String(value)) || Number(value) > 2147483647) {
    throw new RequestError('Identificador inválido.');
  }
  return Number(value);
}

function key(value) {
  if (typeof value !== 'string' ||
      !/^[a-f\d]{8}-[a-f\d]{4}-4[a-f\d]{3}-[89ab][a-f\d]{3}-[a-f\d]{12}$/i.test(value)) {
    throw new RequestError('Identificador de operación inválido.');
  }
  return value.toLowerCase();
}

function image(value, label, optional = false) {
  if (value == null && optional) return null;
  if (typeof value !== 'string' || value.length > 2800000 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
    throw new RequestError(`${label} debe ser una imagen de hasta 2 MB.`);
  }
  const bytes = Buffer.from(value, 'base64');
  if (bytes.length > 2097152 || !imageType(bytes)) {
    throw new RequestError(`${label} debe ser una imagen PNG o JPEG de hasta 2 MB.`);
  }
  return bytes;
}

function imageType(bytes) {
  if (bytes.subarray(0, 8).toString('hex') === '89504e470d0a1a0a') return 'image/png';
  if (bytes.subarray(0, 3).toString('hex') === 'ffd8ff') return 'image/jpeg';
  return null;
}

function calculate(contract, previousKg, currentKg) {
  if (contract.monto == null || contract.iva_porcentaje == null) {
    throw new RequestError('El contrato requiere cuota por visita y porcentaje de IVA.', 409);
  }
  const base = decimal(contract.monto, 'Cuota', true);
  const lines = [{ concept: 'Servicio de recolección', quantity: 100n, rate: base, total: base }];
  if (contract.kilos_mensuales != null) {
    const quota = decimal(contract.kilos_mensuales, 'Cuota en kilos', true);
    const above = kg => kg > quota ? kg - quota : 0n;
    const excess = above(previousKg + currentKg) - above(previousKg);
    if (excess > 0n) {
      const rate = decimal(contract.tarifa_excedente, 'Tarifa por kilo excedente', true);
      lines.push({ concept: 'Kilos excedentes', quantity: excess, rate,
        total: (excess * rate + 50n) / 100n });
    }
  }
  const subtotal = lines.reduce((sum, line) => sum + line.total, 0n);
  const percentage = decimal(contract.iva_porcentaje, 'IVA', true);
  if (percentage > 10000n) throw new RequestError('El IVA del contrato supera 100%.');
  const iva = (subtotal * percentage + 5000n) / 10000n;
  return { lines, subtotal, iva, total: subtotal + iva };
}

module.exports = { RequestError, decimal, money, amount, date, text, id, key, image, imageType, calculate };

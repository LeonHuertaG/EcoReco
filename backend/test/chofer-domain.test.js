const { test } = require('node:test');
const assert = require('node:assert/strict');
const { calculate, decimal, money } = require('../src/services/chofer-domain');

const contract = {
  monto: '100.00',
  kilos_mensuales: '10.00',
  tarifa_excedente: '20.00',
  iva_porcentaje: '16.00'
};

test('cobra solo el excedente nuevo del mes', () => {
  const first = calculate(contract, 0n, 750n);
  const second = calculate(contract, 750n, 750n);
  const third = calculate(contract, 1500n, 200n);
  assert.deepEqual([first.total, second.total, third.total].map(money), ['116.00', '232.00', '162.40']);
  assert.equal(second.lines[1].quantity, 500n);
  assert.equal(third.lines[1].quantity, 200n);
});

test('redondea importes e IVA a centavos exactos', () => {
  const quote = calculate({ ...contract, monto: '0.05', tarifa_excedente: '1.50', iva_porcentaje: '10.00' }, 1000n, 1n);
  assert.equal(quote.lines[1].total, 2n);
  assert.equal(quote.iva, 1n);
  assert.equal(quote.total, 8n);
});

test('valida importes y requiere IVA explícito', () => {
  assert.equal(decimal('12.30', 'Pago'), 1230n);
  for (const value of ['12.301', '1e2', '-1', 0, null]) {
    assert.throws(() => decimal(value, 'Pago'));
  }
  assert.throws(() => calculate({ ...contract, iva_porcentaje: null }, 0n, 0n), /IVA/);
});

const test = require('node:test');
const assert = require('node:assert/strict');

require('../scripts/utils/capacity.js');
const formatCapacity = global.NigateFormatCapacity;

test('uses the next binary unit at each capacity threshold', () => {
  assert.equal(formatCapacity(1024 ** 3), '1.00 GB');
  assert.equal(formatCapacity(1024 ** 4 - 1), '1024.00 GB');
  assert.equal(formatCapacity(1024 ** 4), '1.00 TB');
  assert.equal(formatCapacity(1.5 * 1024 ** 4), '1.50 TB');
  assert.equal(formatCapacity(1024 ** 5), '1.00 PB');
});

test('handles zero, fractional bytes, and invalid values safely', () => {
  assert.equal(formatCapacity(0), '0 B');
  assert.equal(formatCapacity(1.9), '1 B');
  assert.equal(formatCapacity(Number.NaN), '0 B');
  assert.equal(formatCapacity(Number.POSITIVE_INFINITY), '0 B');
});

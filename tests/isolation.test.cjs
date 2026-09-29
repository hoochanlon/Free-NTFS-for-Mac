const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { promisify } = require('node:util');
const { execFile } = require('node:child_process');

test('the test process cannot spawn any host commands', () => {
  assert.throws(() => spawnSync('/usr/bin/true'), error => error.code === 'ERR_ACCESS_DENIED');
});

test('custom promisify paths also cannot reach host commands', async () => {
  await assert.rejects(async () => promisify(execFile)('/usr/bin/true'), error => error.code === 'ERR_ACCESS_DENIED');
});

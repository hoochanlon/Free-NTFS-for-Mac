const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { verifyFileWrites } = require('../scripts/ntfs-manager/write-verifier');
const identity = () => ({ uid: process.getuid(), gid: process.getgid() });

async function fixture(fn) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'nigate-unit-'));
  await fs.writeFile(path.join(root, 'existing-user-file.txt'), 'must survive');
  try { await fn(root); }
  finally { await fs.rm(root, { recursive: true, force: true }); }
}

async function intact(root) {
  assert.deepEqual(await fs.readdir(root), ['existing-user-file.txt']);
  assert.equal(await fs.readFile(path.join(root, 'existing-user-file.txt'), 'utf8'), 'must survive');
}

test('runs the real create/seek/truncate/append/fsync/rename/delete probe and cleans up', async () => {
  await fixture(async root => {
    await verifyFileWrites(root, identity());
    await intact(root);
  });
});

test('rejects another owner and removes only its generated fixtures', async () => {
  await fixture(async root => {
    await assert.rejects(verifyFileWrites(root, { ...identity(), uid: identity().uid + 1 }), /归属不匹配/);
    await intact(root);
  });
});

test('cleans up if rename fails after all content writes', async () => {
  await fixture(async root => {
    const rename = test.mock.method(fs, 'rename', async () => { throw new Error('simulated rename failure'); });
    try { await assert.rejects(verifyFileWrites(root, identity()), /simulated rename failure/); }
    finally { rename.mock.restore(); }
    await intact(root);
  });
});

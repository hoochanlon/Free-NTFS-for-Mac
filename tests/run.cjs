// Load tests in one process so Node's permission model can deny every child
// process. A broken mock must never reach the host's sudo/diskutil/mount.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
assert.ok(process.permission, 'Run tests through pnpm test (permission guard required)');
assert.equal(process.permission.has('child'), false, 'Child processes must be forbidden');
// Node also disables fsync under the permission model. The filesystem-only
// probe suite runs separately on os.tmpdir fixtures; it imports no disk tools.
for (const file of fs.readdirSync(__dirname).filter(name => name.endsWith('.test.cjs') && name !== 'write-verifier.test.cjs').sort()) {
  require(path.join(__dirname, file));
}

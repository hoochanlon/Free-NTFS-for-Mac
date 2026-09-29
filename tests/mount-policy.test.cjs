const test = require('node:test');
const assert = require('node:assert/strict');
const { currentMountIdentity, buildHibernationRemovalArgs, buildMountArgs } = require('../scripts/ntfs-manager/mount-policy');

const source = (uid, gid, euid = uid, egid = gid) => ({
  getuid: () => uid, getgid: () => gid, geteuid: () => euid, getegid: () => egid,
});
const device = { disk: 'disk999999s3', devicePath: '/dev/disk999999s3', volume: '/Volumes/数据 (USB disk)', volumeName: '数据 (USB disk)' };

test('resolves the initiating user anew for each mount', () => {
  assert.deepEqual(currentMountIdentity(source(501, 20)), { uid: 501, gid: 20 });
  assert.deepEqual(currentMountIdentity(source(502, 80)), { uid: 502, gid: 80 });
});

test('rejects root, elevated, unavailable and malformed identities', () => {
  for (const input of [source(0, 0), source(501, 20, 0), source(501, 20, 501, 0), source(-1, 20), source(501, NaN), source(1.5, 20), source(2 ** 32 - 1, 20), {}]) {
    assert.throws(() => currentMountIdentity(input));
  }
});

test('keeps paths as separate argv and uses the validated safe option group', () => {
  const args = buildMountArgs('/opt/homebrew/bin/ntfs-3g', device, { uid: 502, gid: 80 });
  assert.deepEqual(args, ['/opt/homebrew/bin/ntfs-3g', '-olocal', '-oallow_other', '-oauto_xattr', '-ovolname=数据 (USB disk)', '-onoatime', '-onorecover', '-ouid=502', '-ogid=80', '/dev/disk999999s3', '/Volumes/数据 (USB disk)']);
  assert.ok(!args.some(arg => arg.includes('remove_hiberfile') || arg === '-orecover'));
});

test('rejects device mismatch, path traversal and injected mount options', () => {
  for (const patch of [{ disk: 'disk999999s30' }, { devicePath: '/dev/disk999999s3;id' }, { volume: '/' }, { volume: '/Volumes/../Users' }, { volume: '/Volumes/folder/subdir' }, { volumeName: 'DATA,remove_hiberfile' }, { volumeName: 'DATA\nnext' }]) {
    assert.throws(() => buildMountArgs('/opt/homebrew/bin/ntfs-3g', { ...device, ...patch }, { uid: 501, gid: 20 }));
  }
});

test('builds the hibernation removal retry only from the safe normal argv', () => {
  const normal = buildMountArgs('/opt/homebrew/bin/ntfs-3g', device, { uid: 501, gid: 20 });
  const recovery = buildHibernationRemovalArgs(normal);
  assert.ok(!recovery.includes('-onorecover'));
  assert.ok(recovery.includes('-oremove_hiberfile'));
  assert.deepEqual(recovery.slice(-2), [device.devicePath, device.volume]);
  assert.throws(() => buildHibernationRemovalArgs(recovery));
  assert.throws(() => buildHibernationRemovalArgs(normal.filter(arg => arg !== '-onorecover')));
});

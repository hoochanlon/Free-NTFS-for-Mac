const test = require('node:test');
const assert = require('node:assert/strict');
const { parseMountTable, assertDeviceIdentity, assertMountState, waitForMountState } = require('../scripts/ntfs-manager/mount-state');
const device = { disk: 'disk999999s3', devicePath: '/dev/disk999999s3', volume: '/Volumes/Work on USB (数据)', volumeName: 'Work on USB (数据)', volumeUuid: 'AAA-BBB' };
const info = { DeviceNode: device.devicePath, FilesystemType: 'ntfs', VolumeUUID: 'AAA-BBB', DiskUUID: 'CCC-DDD', Size: 12000, MountPoint: device.volume, WritableMedia: true, WritableVolume: true };
const rw = () => ({ info: { ...info }, entry: { devicePath: device.devicePath, volume: device.volume, options: 'macfuse, local', isFuse: true, isReadOnly: false } });
const ro = () => ({ info: { ...info, WritableVolume: false }, entry: { ...rw().entry, isFuse: false, isReadOnly: true } });
const unmounted = () => ({ info: { ...info, MountPoint: undefined, WritableVolume: undefined } });

test('parses exact device identifiers and volume names with spaces, parentheses and on', () => {
  const parsed = parseMountTable('/dev/disk999999s3 on /Volumes/Work on USB (数据) (macfuse, local, noatime)\n/dev/disk999999s30 on /Volumes/other (ntfs, read-only)\nmap auto_home on /System/Volumes/Data/home (autofs, automounted)');
  assert.equal(parsed.length, 2);
  assert.equal(parsed[0].volume, device.volume);
  assert.equal(parsed[0].isFuse, true);
  assert.equal(parsed[1].devicePath, '/dev/disk999999s30');
  assert.equal(parsed[1].isReadOnly, true);
});

test('a volume name containing fuse cannot masquerade as a FUSE backend', () => {
  assert.equal(parseMountTable('/dev/disk999999s3 on /Volumes/macfuse (ntfs, local)')[0].isFuse, false);
});

test('accepts verified RW, explicit RO and unmounted states', () => {
  assertMountState(rw(), device, info, 'readWrite');
  assertMountState(ro(), device, info, 'readOnly');
  assertMountState(unmounted(), device, info, 'unmounted');
});

test('rejects wrong UUID, changed partition size, non-NTFS and wrong device', () => {
  for (const patch of [{ VolumeUUID: 'OTHER' }, { DiskUUID: 'OTHER' }, { Size: 13000 }, { FilesystemType: 'apfs' }, { DeviceNode: '/dev/disk999999s30' }]) {
    assert.throws(() => assertDeviceIdentity({ ...info, ...patch }, device, info));
  }
  assert.throws(() => assertDeviceIdentity({ ...info, VolumeUUID: undefined, DiskUUID: undefined }, { ...device, volumeUuid: undefined }));
});

test('compares partition Size rather than filesystem TotalSize', () => {
  assertDeviceIdentity({ ...info, TotalSize: 11900 }, device, { ...info, TotalSize: 12000 });
});

test('fails closed on read-only flags, unknown writable state and wrong mount point', () => {
  for (const patch of [{ WritableVolume: false }, { WritableVolume: undefined }, { WritableMedia: false }, { MountPoint: '/Volumes/elsewhere' }]) {
    assert.throws(() => assertMountState({ ...rw(), info: { ...info, ...patch } }, device, info, 'readWrite'));
  }
  for (const patch of [{ isReadOnly: true }, { isFuse: false }, { devicePath: '/dev/disk999999s30' }, { volume: '/Volumes/elsewhere' }]) {
    assert.throws(() => assertMountState({ ...rw(), entry: { ...rw().entry, ...patch } }, device, info, 'readWrite'));
  }
  assert.throws(() => assertMountState(rw(), device, info, 'readOnly'));
  assert.throws(() => assertMountState(rw(), device, info, 'unmounted'));
});

test('waits for two consecutive valid observations after transient failures', async () => {
  const snapshots = [unmounted(), rw(), ro(), rw(), rw()];
  let calls = 0;
  const actual = await waitForMountState(device, info, 'readWrite', { intervalMs: 0, timeoutMs: 500, read: async () => snapshots[calls++] });
  assert.equal(calls, 5);
  assert.deepEqual(actual, rw());
});

test('retains the specific failure when state does not settle', async () => {
  await assert.rejects(waitForMountState(device, info, 'readWrite', { intervalMs: 0, timeoutMs: 3, read: async () => ro() }), /读写挂载/);
});


test('passes the remaining deadline to each system query', async () => {
  const budgets = [];
  await waitForMountState(device, info, 'readWrite', {
    timeoutMs: 100, intervalMs: 0,
    read: async (path, timeoutMs) => { assert.equal(path, device.devicePath); budgets.push(timeoutMs); return rw(); }
  });
  assert.equal(budgets.length, 2);
  assert.ok(budgets.every(value => value > 0 && value <= 100));
  assert.ok(budgets[1] <= budgets[0]);
});

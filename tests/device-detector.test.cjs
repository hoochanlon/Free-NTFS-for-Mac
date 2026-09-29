const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const { DeviceDetector } = require('../scripts/ntfs-manager/device-detector');

test.afterEach(() => test.mock.restoreAll());

async function detect(options, staleMarker = true) {
  const mounted = new Set(['disk999999s3']);
  test.mock.method(fs, 'access', async () => { if (!staleMarker) throw new Error('missing'); });
  test.mock.method(fs, 'unlink', async () => {});
  const executor = {
    execute: async command => {
      if (command.startsWith('mount ')) return { stdout: '/dev/disk999999s3 on /Volumes/Data on USB (备份) (' + options + ')\n', stderr: '' };
      if (command.startsWith('diskutil list')) return { stdout: '', stderr: '' };
      if (command.startsWith('diskutil info')) return { stdout: 'Volume UUID: AAA-BBB\n', stderr: '' };
      throw new Error('Unexpected command: ' + command);
    }
  };
  const detector = new DeviceDetector(mounted, new Map(), undefined, executor);
  detector.getDiskCapacity = async () => ({ total: 1000, used: 100, available: 900 });
  const devices = await detector.getNTFSDevices(true);
  assert.equal(devices.length, 1);
  assert.equal(devices[0].volume, '/Volumes/Data on USB (备份)');
  assert.equal(devices[0].volumeName, 'Data on USB (备份)');
  return { device: devices[0], mounted };
}

test('stale marker and memory cannot override FUSE read-only flags', async () => {
  const result = await detect('macfuse, local, read-only');
  assert.equal(result.device.isReadOnly, true);
  assert.equal(result.device.isMounted, false);
  assert.equal(result.mounted.size, 0);
});

test('system readonly mounts remain readonly even with a stale marker', async () => {
  const result = await detect('ntfs, local, read-only, fskit');
  assert.equal(result.device.isReadOnly, true);
  assert.equal(result.device.isMounted, false);
});

test('normal managed FUSE RW mounts remain visible with complete volume names', async () => {
  const result = await detect('macfuse, local, noatime');
  assert.equal(result.device.isReadOnly, false);
  assert.equal(result.device.isMounted, true);
});

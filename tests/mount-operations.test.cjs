const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const policy = require('../scripts/ntfs-manager/mount-policy');
const state = require('../scripts/ntfs-manager/mount-state');
const probe = require('../scripts/ntfs-manager/write-verifier');

test.afterEach(() => test.mock.restoreAll());

function harness() {
  const device = { disk: 'disk999999s3', devicePath: '/dev/disk999999s3', volume: '/Volumes/Test Disk (数据)', volumeName: 'Test Disk (数据)', volumeUuid: 'AAA-BBB', isReadOnly: true, isMounted: false, options: '' };
  const h = { device, mode: 'readOnly', identity: { uid: 501, gid: 20 }, owner: { uid: 0, gid: 0 }, uuid: device.volumeUuid, calls: [], events: [], passwords: 0, probes: 0, markerWrites: 0, mounted: new Set(), unmounted: new Map(), busy: false, driverError: null, driverMode: 'readWrite', directoryEntries: [], symlink: false, readonlyActuallyWritable: false, ejectError: null, driverCalls: 0 };
  h.snapshot = () => ({
    info: { DeviceNode: device.devicePath, FilesystemType: 'ntfs', VolumeUUID: h.uuid, DiskUUID: 'CCC-DDD', Size: 12000, WritableMedia: true, WritableVolume: h.mode === 'unmounted' ? undefined : h.mode === 'readWrite', MountPoint: h.mode === 'unmounted' ? undefined : device.volume },
    entry: h.mode === 'unmounted' ? undefined : { devicePath: device.devicePath, volume: device.volume, options: h.mode === 'readWrite' ? 'macfuse, local' : 'ntfs, read-only', isReadOnly: h.mode === 'readOnly', isFuse: h.mode === 'readWrite' }
  });
  test.mock.method(policy, 'currentMountIdentity', () => { if (h.identityError) throw h.identityError; return { ...h.identity }; });
  test.mock.method(state, 'readMountSnapshot', async () => h.snapshot());
  test.mock.method(state, 'readMountTable', async () => h.snapshot().entry ? [h.snapshot().entry] : []);
  test.mock.method(state, 'waitForMountState', async (target, baseline, mode) => {
    h.events.push('verify-' + mode);
    const snapshot = h.snapshot();
    state.assertMountState(snapshot, target, baseline, mode);
    return snapshot;
  });
  test.mock.method(probe, 'verifyFileWrites', async (volume, identity) => {
    h.probes++;
    h.events.push('probe');
    assert.equal(volume, device.volume);
    assert.deepEqual(identity, h.identity);
    if (h.probeError) throw h.probeError;
    if (h.afterProbe) h.afterProbe();
  });
  test.mock.method(fs, 'access', async () => {});
  test.mock.method(fs, 'lstat', async () => ({ ...h.owner, isDirectory: () => true, isSymbolicLink: () => h.symlink }));
  test.mock.method(fs, 'readdir', async () => h.directoryEntries);
  test.mock.method(fs, 'unlink', async file => { assert.match(file, /^\/tmp\/ntfs_mounted_disk999999s3$/); });
  test.mock.method(fs, 'writeFile', async (file, value, options) => {
    assert.equal(file, '/tmp/ntfs_mounted_disk999999s3');
    assert.equal(options.flag, 'wx');
    assert.equal(h.mode, 'readWrite');
    h.events.push('marker');
    h.markerWrites++;
  });
  // Inject a command runner explicitly; never monkey-patch a promisified
  // child_process API (its custom promisifier may retain the real function).
  const runSystemCommand = async (file, args) => {
    h.calls.push([file, ...args]);
    if (file !== '/usr/sbin/diskutil') throw new Error('Unexpected executable: ' + file);
    if (args[0] === 'mount') {
      assert.deepEqual(args, ['mount', 'readOnly', '-mountPoint', device.volume, device.devicePath]);
      h.mode = h.readonlyActuallyWritable ? 'readWrite' : 'readOnly';
    } else if (args[0] === 'eject') {
      if (h.ejectError) throw h.ejectError;
      h.mode = 'unmounted';
    } else if (args[0] === 'unmount') {
      if (h.busy) throw new Error('Resource busy');
      h.mode = 'unmounted';
    } else throw new Error('Unexpected diskutil command');
  };
  delete require.cache[require.resolve('../scripts/ntfs-manager/mount-operations')];
  const { MountOperations } = require('../scripts/ntfs-manager/mount-operations');
  h.service = new MountOperations(h.mounted, h.unmounted, {
    getPassword: async () => { h.passwords++; return 'unit-test-placeholder'; }
  }, {
    executeSudoWithPassword: async args => {
      h.calls.push(args);
      if (h.commandHook) await h.commandHook(args);
      if (args[0] === '/usr/sbin/diskutil' && args[1] === 'unmount') {
        if (h.busy) throw new Error('Resource busy');
        h.mode = 'unmounted';
      } else if (args[0] === '/opt/homebrew/bin/ntfs-3g') {
        h.driverCalls++;
        if (h.driverError) throw h.driverError;
        h.mode = h.driverMode;
        h.owner = { ...h.identity };
      } else if (args[0] !== '/bin/mkdir') throw new Error('Unexpected privileged command: ' + args[0]);
      return { stdout: '', stderr: '' };
    }
  }, async () => '/opt/homebrew/bin/ntfs-3g', runSystemCommand);
  return h;
}

test('GUI path uses dynamic uid/gid and records success only after verification', async () => {
  const h = harness();
  assert.match(await h.service.mountDevice(h.device), /自检通过/);
  const args = h.calls.find(call => call[0].endsWith('ntfs-3g'));
  assert.ok(args.includes('-ouid=501') && args.includes('-ogid=20') && args.includes('-onorecover'));
  assert.ok(!args.includes('-oremove_hiberfile'));
  assert.deepEqual(args.slice(-2), [h.device.devicePath, h.device.volume]);
  assert.ok(h.events.indexOf('verify-readWrite') < h.events.indexOf('probe'));
  assert.ok(h.events.indexOf('probe') < h.events.indexOf('marker'));
  assert.equal(h.markerWrites, 1);
  assert.ok(h.mounted.has(h.device.disk));
});

test('changing the initiating identity remounts with the new IDs', async () => {
  const h = harness();
  await h.service.mountDevice(h.device);
  h.identity = { uid: 502, gid: 80 };
  await h.service.mountDevice(h.device);
  const commands = h.calls.filter(call => call[0].endsWith('ntfs-3g'));
  assert.equal(commands.length, 2);
  assert.ok(commands[1].includes('-ouid=502') && commands[1].includes('-ogid=80'));
});

test('already mapped mounts are inspected and probed without another unmount', async () => {
  const h = harness();
  await h.service.mountDevice(h.device);
  const count = h.calls.length;
  assert.match(await h.service.mountDevice(h.device), /已是读写模式/);
  assert.equal(h.calls.length, count);
  assert.equal(h.probes, 2);
});

test('root and bad volume identity fail before password requests or commands', async () => {
  const h = harness();
  h.identityError = new Error('请以普通用户启动');
  await assert.rejects(h.service.mountDevice(h.device), /普通用户/);
  h.identityError = null;
  h.uuid = 'OTHER';
  await assert.rejects(h.service.mountDevice(h.device), /UUID/);
  assert.equal(h.passwords, 0);
  assert.equal(h.calls.length, 0);
});

test('busy unmount stops the driver and never forces or repairs', async () => {
  const h = harness();
  h.busy = true;
  await assert.rejects(h.service.mountDevice(h.device), /Resource busy/);
  assert.deepEqual(h.calls, [['/usr/sbin/diskutil', 'unmount', h.device.devicePath]]);
  assert.equal(h.markerWrites, 0);
  h.busy = false;
  await h.service.mountDevice(h.device); // lock released after failure
});

test('failed driver returns to verified readonly without repair', async () => {
  const h = harness();
  h.driverError = new Error('Windows is hibernated');
  await assert.rejects(h.service.mountDevice(h.device), /完全关机.*恢复为只读/);
  assert.equal(h.mode, 'readOnly');
  assert.equal(h.markerWrites, 0);
  assert.equal(h.probes, 0);
  assert.ok(!h.calls.some(args => args.includes('ntfsfix') || args.includes('force')));
});

test('exit code zero is not sufficient if the actual mount stays readonly', async () => {
  const h = harness();
  h.driverMode = 'readOnly';
  await assert.rejects(h.service.mountDevice(h.device), /读写挂载/);
  assert.equal(h.probes, 0);
  assert.equal(h.markerWrites, 0);
});

test('failed write verification never creates a success marker', async () => {
  const h = harness();
  h.probeError = new Error('metadata permission denied');
  await assert.rejects(h.service.mountDevice(h.device), /metadata permission denied/);
  assert.equal(h.markerWrites, 0);
  assert.equal(h.mounted.size, 0);
  assert.equal(h.mode, 'readOnly');
});

test('a changed device after the probe is never unmounted or marked successful', async () => {
  const h = harness();
  h.afterProbe = () => { h.uuid = 'REPLACED'; };
  await assert.rejects(h.service.mountDevice(h.device), /UUID/);
  assert.equal(h.markerWrites, 0);
  assert.equal(h.calls.filter(args => args[1] === 'unmount').length, 1);
});

test('a timeout does not launch a second mount or claim cancellation', async () => {
  const h = harness();
  h.driverError = new Error('操作超时');
  await assert.rejects(h.service.mountDevice(h.device), /实际状态尚未确认/);
  assert.equal(h.driverCalls, 1);
  assert.equal(h.calls.filter(args => args[1] === 'mount').length, 0);
  assert.equal(h.markerWrites, 0);
});

test('password failure retries authentication once', async () => {
  const h = harness();
  let failed = false;
  h.commandHook = async args => {
    if (args[0].endsWith('ntfs-3g') && !failed) { failed = true; throw new Error('密码错误，请重试'); }
  };
  await h.service.mountDevice(h.device);
  assert.equal(h.passwords, 2);
});

test('rejects simultaneous operations on the same device', async () => {
  const h = harness();
  let release, started;
  const pending = new Promise(resolve => { release = resolve; });
  const entering = new Promise(resolve => { started = resolve; });
  h.commandHook = async args => { if (args[1] === 'unmount') { started(); await pending; } };
  const first = h.service.mountDevice(h.device);
  await entering;
  await assert.rejects(h.service.restoreToReadOnly(h.device), /正在执行其他操作/);
  release();
  await first;
});

test('refuses nonempty or symlink mount directories', async () => {
  const h = harness();
  h.directoryEntries = ['existing-data'];
  await assert.rejects(h.service.mountDevice(h.device), /目录非空/);
  assert.equal(h.driverCalls, 0);
  h.directoryEntries = [];
  h.symlink = true;
  await assert.rejects(h.service.mountDevice(h.device), /不是普通目录/);
  assert.equal(h.driverCalls, 0);
});

test('restores readonly explicitly and verifies the final state', async () => {
  const h = harness();
  h.mode = 'readWrite';
  h.mounted.add(h.device.disk);
  assert.match(await h.service.restoreToReadOnly(h.device), /已还原为只读/);
  assert.equal(h.mode, 'readOnly');
  assert.equal(h.mounted.size, 0);
  assert.ok(h.calls.some(args => args[1] === 'mount' && args[2] === 'readOnly'));
});

test('readonly restoration does not swallow busy errors or writable results', async () => {
  const h = harness();
  h.mode = 'readWrite';
  h.busy = true;
  await assert.rejects(h.service.restoreToReadOnly(h.device), /Resource busy/);
  h.busy = false;
  h.readonlyActuallyWritable = true;
  await assert.rejects(h.service.restoreToReadOnly(h.device), /只读挂载/);
});

test('already readonly volumes need no privileged operation', async () => {
  const h = harness();
  assert.match(await h.service.restoreToReadOnly(h.device), /已是只读/);
  assert.equal(h.passwords, 0);
  assert.equal(h.calls.length, 0);
});

test('unmount records detached state only after verification', async () => {
  const h = harness();
  await h.service.unmountDevice(h.device);
  assert.equal(h.mode, 'unmounted');
  assert.equal(h.unmounted.get(h.device.disk).isUnmounted, true);
});

test('failed eject preserves tracking and a successful eject clears it', async () => {
  const h = harness();
  h.mounted.add(h.device.disk);
  h.ejectError = new Error('disk in use');
  await assert.rejects(h.service.ejectDevice(h.device), /disk in use/);
  assert.ok(h.mounted.has(h.device.disk));
  h.ejectError = null;
  await h.service.ejectDevice(h.device);
  assert.equal(h.mounted.size, 0);
  assert.equal(h.mode, 'unmounted');
});

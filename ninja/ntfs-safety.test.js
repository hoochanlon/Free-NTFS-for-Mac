const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const util = require('node:util');
const { test } = require('node:test');
const ts = require('typescript');

// Load the production TypeScript while replacing every OS-facing dependency.
// These tests never invoke sudo, access Keychain, or operate on a real disk.
function load(relativePath, dependencies = {}, timers = []) {
  const filename = path.join(__dirname, '..', relativePath);
  const source = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  vm.runInNewContext(source, {
    module, exports: module.exports,
    require(name) {
      if (Object.hasOwn(dependencies, name)) return dependencies[name];
      if (name === 'path') return path;
      throw new Error(`Unexpected production dependency: ${name}`);
    },
    console: { log() {}, warn() {}, error() {} },
    process: { getuid: () => 501, getgid: () => 20 },
    setTimeout(callback, delay) {
      timers.push(delay);
      return setTimeout(callback, Math.min(delay, 5));
    },
    clearTimeout
  }, { filename });
  return module.exports;
}

function keychainHarness(error) {
  const calls = [];
  const execFile = () => { throw new Error('Expected promisified execFile'); };
  // Node supplies a custom promisifier for execFile, returning both streams.
  execFile[util.promisify.custom] = async (file, args) => {
    calls.push({ file, args: Array.from(args) });
    if (error) throw error;
    return { stdout: '  password with spaces  \n', stderr: '' };
  };
  const { KeychainManager } = load('src/scripts/utils/keychain.ts', {
    util,
    child_process: { execFile }
  });
  return { KeychainManager, calls };
}

test('Keychain receives passwords literally, including shell syntax and whitespace', async () => {
  const { KeychainManager, calls } = keychainHarness();
  const password = '  $VALUE $(printf test) `printf test` "quoted" \\ unicode密码  ';
  await KeychainManager.savePassword(password);
  assert.equal(calls[0].file, '/usr/bin/security');
  assert.equal(calls[0].args[calls[0].args.indexOf('-w') + 1], password);
  assert.equal(await KeychainManager.getPassword(), '  password with spaces  ');
  await KeychainManager.deletePassword();
  assert.deepEqual(calls.map(call => call.args[0]), [
    'add-generic-password', 'find-generic-password', 'delete-generic-password'
  ]);
});

test('Keychain failures do not expose the password from execFile error messages', async () => {
  const password = 'private-test-value';
  const { KeychainManager } = keychainHarness(Object.assign(
    new Error(`Command failed: security -w ${password}`), { code: 1, stderr: '' }
  ));
  await assert.rejects(KeychainManager.savePassword(password), error => {
    assert.ok(!error.message.includes(password));
    return error.message.includes('security failed');
  });
});

test('Capacity lookup passes the entire volume path as a literal df argument', async () => {
  const calls = [];
  const volume = '/Volumes/$(printf test) with spaces';
  const { DeviceDetector } = load('src/scripts/ntfs-manager/device-detector.ts', {
    './utils': {
      execFileAsync: async (file, args, options) => {
        calls.push({ file, args: Array.from(args), options });
        return { stdout: `Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/disk999s1 1000 100 900 10% ${volume}\n` };
      },
      execAsync: async () => { throw new Error('Unexpected shell command'); },
      fileExists: async () => false
    },
    './device-cache': { DeviceCacheManager: class {} },
    './batch-executor': { BatchExecutor: class {} },
    './disk-safety': load('src/scripts/ntfs-manager/disk-safety.ts')
  });
  const detector = new DeviceDetector(new Set(), new Map());
  const capacity = await detector.getDiskCapacity(volume, '/dev/disk999s1');
  assert.equal(calls[0].file, 'df');
  assert.deepEqual(calls[0].args, ['-k', volume]);
  assert.equal(calls[0].options.timeout, 1500);
  assert.equal(capacity.total, 1000 * 1024);
  assert.equal(capacity.used, 100 * 1024);
});

const device = {
  disk: 'disk999s1', devicePath: '/dev/disk999s1',
  volume: '/Volumes/TEST', volumeName: 'TEST', isReadOnly: true,
  isMounted: false, options: ''
};

test('Device refresh respects read-only FUSE mounts even with a stale writable marker', async () => {
  const { DeviceDetector } = load('src/scripts/ntfs-manager/device-detector.ts', {
    './utils': {
      execFileAsync: async () => ({ stdout: `Filesystem 1024-blocks Used Available Capacity Mounted on\n${device.devicePath} 1000 100 900 10% ${device.volume}\n` }),
      execAsync: async () => { throw new Error('Unexpected shell command'); },
      fileExists: async () => true
    },
    './device-cache': { DeviceCacheManager: class {} },
    './batch-executor': { BatchExecutor: class {} },
    './disk-safety': load('src/scripts/ntfs-manager/disk-safety.ts')
  });
  const cache = {
    getDeviceList: () => null,
    getMountInfo: () => `${device.devicePath} on ${device.volume} (macfuse, local, read-only)\n`,
    getDiskutilList: () => '', getDiskutilInfo: () => 'Volume UUID: ABCD-1234\n',
    setDeviceList() {}, invalidateMountInfo() {}
  };
  const detector = new DeviceDetector(new Set([device.disk]), new Map(), cache, {
    execute: async () => ({ stdout: '' })
  });
  const devices = await detector.getNTFSDevices();
  assert.equal(devices.length, 1);
  assert.equal(devices[0].isReadOnly, true);
  assert.equal(devices[0].isMounted, false);
});

function mountHarness({ execute, execFile, mounted = [], passwordManager } = {}) {
  const calls = [];
  const files = [];
  const timers = [];
  let mountedForWrite = false;
  const mountedDevices = new Set(mounted);
  const unmountedDevices = new Map();
  const { MountOperations } = load('src/scripts/ntfs-manager/mount-operations.ts', {
    'fs/promises': {
      writeFile: async name => { files.push(['write', name]); },
      unlink: async name => { files.push(['unlink', name]); }
    },
    './utils': {
      fileExists: async () => true,
      findExecutablePath: async command => `/test/bin/${command}`,
      execFileAsync: async (file, args) => {
        calls.push([file, ...args]);
        if (execFile) return execFile(file, args);
        return { stdout: `${device.devicePath} on ${device.volume} (${mountedForWrite ? 'macfuse, local' : 'ntfs, local, read-only'})\n`, stderr: '' };
      },
      execAsync: async command => {
        if (command === 'diskutil info /') return { stdout: 'Device Identifier: disk1s1\n' };
        if (command === 'diskutil info /dev/disk999') {
          return { stdout: 'Whole: Yes\nInternal: No\nDevice Location: External\nVirtual: No\nProtocol: USB\n' };
        }
        throw new Error(`Unexpected shell command: ${command}`);
      }
    },
    './password-manager': { PasswordManager: class {} },
    './sudo-executor': { SudoExecutor: class {} },
    './disk-safety': load('src/scripts/ntfs-manager/disk-safety.ts')
  }, timers);
  const operations = new MountOperations(
    mountedDevices, unmountedDevices,
    passwordManager || { getPassword: async () => 'fake-password' },
    { executeSudoWithPassword: async (args, password, timeout) => {
      calls.push(Array.from(args));
      const result = execute ? await execute(args, password, timeout) : { stdout: '', stderr: '' };
      if (args[0] === '/test/bin/ntfs-3g') mountedForWrite = true;
      return result;
    } },
    async () => '/test/bin/ntfs-3g'
  );
  return { operations, calls, files, timers, mountedDevices, unmountedDevices };
}

for (const method of ['mountDevice', 'restoreToReadOnly', 'resetDevice']) {
  test(`${method} stops on a busy volume without mounting, repairing, or clearing state`, async () => {
    const state = mountHarness({
      mounted: [device.disk],
      execute: async args => {
        assert.deepEqual(Array.from(args), ['diskutil', 'unmount', device.devicePath]);
        throw new Error('Resource busy');
      }
    });
    await assert.rejects(state.operations[method](device), /Resource busy/);
    assert.ok(state.mountedDevices.has(device.disk));
    assert.equal(state.files.length, 0);
    assert.equal(state.calls.filter(call => call[0] !== 'mount').length, 1);
  });
}

test('Normal unload and its fallback both respect a busy volume', async () => {
  const state = mountHarness({
    mounted: [device.disk],
    execute: async () => { throw new Error('Resource busy'); },
    execFile: async () => { throw new Error('Resource busy'); }
  });
  await assert.rejects(state.operations.unmountDevice(device), /Resource busy/);
  assert.ok(state.mountedDevices.has(device.disk));
  assert.equal(state.files.length, 0);
  assert.deepEqual(state.calls, [
    ['diskutil', 'unmount', device.devicePath], ['diskutil', 'unmount', device.devicePath]
  ]);
});

test('A successful mount preserves xattrs without deleting a Windows hibernation file', async () => {
  const state = mountHarness();
  await state.operations.mountDevice(device);
  const args = state.calls.find(call => call[0] === '/test/bin/ntfs-3g');
  assert.ok(args.includes('-ostreams_interface=openxattr'));
  assert.ok(!args.includes('-oauto_xattr'));
  assert.ok(!args.includes('-oremove_hiberfile'));
  assert.ok(state.mountedDevices.has(device.disk));
  assert.deepEqual(state.calls[0], ['diskutil', 'unmount', device.devicePath]);
});

test('A failed hibernated mount remains a failure and does not create a mounted marker', async () => {
  const state = mountHarness({ execute: async args => {
    if (args[0] === '/test/bin/ntfs-3g') throw new Error('Windows is hibernated');
    return { stdout: '', stderr: '' };
  } });
  await assert.rejects(state.operations.mountDevice(device), /Windows is hibernated/);
  assert.ok(!state.mountedDevices.has(device.disk));
  assert.ok(!state.files.some(([action]) => action === 'write'));
});

test('A mount stays pending until the executor actually finishes', async () => {
  let finish;
  const state = mountHarness({ execute: async args => {
    if (args[0] === '/test/bin/ntfs-3g') return new Promise(resolve => { finish = resolve; });
    return { stdout: '', stderr: '' };
  } });
  let settled = false;
  const result = state.operations.mountDevice(device).then(() => { settled = true; });
  await new Promise(resolve => setTimeout(resolve, 15));
  assert.equal(settled, false);
  assert.ok(!state.files.some(([action]) => action === 'write'));
  assert.ok(!state.timers.includes(10000));
  finish({ stdout: '', stderr: '' });
  await result;
  assert.ok(state.mountedDevices.has(device.disk));
});

test('A successful read-only fallback is not reported or marked as read-write', async () => {
  const state = mountHarness({ execFile: async () => ({
    stdout: `${device.devicePath} on ${device.volume} (macfuse, local, read-only)\n`, stderr: ''
  }) });
  await assert.rejects(state.operations.mountDevice(device), /只读/);
  assert.ok(!state.mountedDevices.has(device.disk));
  assert.ok(!state.files.some(([action]) => action === 'write'));
});

test('A volume name containing read-only does not change its actual mount mode', async () => {
  const state = mountHarness({ execFile: async () => ({
    stdout: `${device.devicePath} on /Volumes/read-only data (macfuse, local)\n`, stderr: ''
  }) });
  await state.operations.mountDevice(device);
  assert.ok(state.mountedDevices.has(device.disk));
});

test('Password retry must safely unmount before proceeding', async () => {
  let attempts = 0;
  let prompts = 0;
  const state = mountHarness({
    passwordManager: { getPassword: async () => ++prompts === 1 ? 'old' : 'new' },
    execute: async (args, password) => {
      if (args[1] === 'unmount') {
        if (++attempts === 1) throw new Error('password is incorrect');
        assert.equal(password, 'new');
      }
      return { stdout: '', stderr: '' };
    }
  });
  await state.operations.mountDevice(device);
  assert.equal(attempts, 2);
  assert.equal(prompts, 2);
});

test('Failed eject retains mounted markers and state', async () => {
  const state = mountHarness({ mounted: [device.disk], execFile: async () => { throw new Error('Resource busy'); } });
  await assert.rejects(state.operations.ejectDevice(device), /Resource busy/);
  assert.ok(state.mountedDevices.has(device.disk));
  assert.equal(state.files.length, 0);
});

test('Whole-disk format refuses to erase when any partition cannot safely unmount', async () => {
  const state = mountHarness({ mounted: [device.disk], execute: async args => {
    assert.deepEqual(Array.from(args), ['diskutil', 'unmountDisk', '/dev/disk999']);
    throw new Error('Resource busy');
  } });
  await assert.rejects(state.operations.formatDevice(device), /Resource busy/);
  assert.equal(state.calls.length, 1);
  assert.equal(state.files.length, 0);
  assert.ok(state.mountedDevices.has(device.disk));
});

test('GPT name refresh skips a busy neighboring volume instead of forcing it off', async () => {
  const state = mountHarness();
  const calls = [];
  await state.operations.tryRefreshDiskName(async args => {
    calls.push(Array.from(args));
    throw new Error('Resource busy');
  }, device.devicePath, device.disk, 'NEW');
  assert.deepEqual(calls, [['diskutil', 'unmountDisk', '/dev/disk999']]);
});

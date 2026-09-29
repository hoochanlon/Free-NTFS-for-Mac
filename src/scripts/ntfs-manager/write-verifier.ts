import * as fs from 'fs/promises';
import * as path from 'path';
import type { MountIdentity } from './mount-policy';

// Called only after the service verifies the device, UUID and real RW mount.
// All writes run as the GUI user, never under sudo. Only private fixtures are
// touched; cleanup is deliberately non-recursive.
export async function verifyFileWrites(volume: string, identity: MountIdentity): Promise<void> {
  const directory = await fs.mkdtemp(path.join(volume, '.nigate-rw-'));
  const original = path.join(directory, 'original.txt');
  const renamed = path.join(directory, 'renamed.txt');
  let handle: fs.FileHandle | undefined;
  let failure: unknown;
  try {
    handle = await fs.open(original, 'wx+', 0o600);
    await handle.writeFile('0123456789\n', 'utf8');
    await handle.sync();
    const initial = await handle.stat();
    if (initial.uid !== identity.uid || initial.gid !== identity.gid) {
      throw new Error(`文件归属不匹配：实际 ${initial.uid}:${initial.gid}，预期 ${identity.uid}:${identity.gid}`);
    }
    await handle.close();
    handle = undefined;
    if (await fs.readFile(original, 'utf8') !== '0123456789\n') throw new Error('初次写入校验失败');

    handle = await fs.open(original, 'r+');
    const { bytesWritten } = await handle.write(Buffer.from('ABC'), 0, 3, 3);
    if (bytesWritten !== 3) throw new Error('偏移写入不完整');
    await handle.sync();
    if (await fs.readFile(original, 'utf8') !== '012ABC6789\n') throw new Error('偏移写入校验失败');
    await handle.truncate(5);
    await handle.sync();
    if (await fs.readFile(original, 'utf8') !== '012AB') throw new Error('截断校验失败');
    await handle.close();
    handle = await fs.open(original, 'a');
    await handle.writeFile('XYZ\n', 'utf8');
    await handle.sync();
    await handle.close();
    handle = undefined;

    const final = await fs.stat(original);
    if (final.ino !== initial.ino || final.dev !== initial.dev || final.size !== 9 ||
        await fs.readFile(original, 'utf8') !== '012ABXYZ\n') {
      throw new Error('原地写入、截断或追加校验失败');
    }
    const timestamp = new Date(Date.now() - 1000);
    await fs.utimes(original, timestamp, timestamp);
    await fs.rename(original, renamed);
    if (await fs.readFile(renamed, 'utf8') !== '012ABXYZ\n') throw new Error('重命名后内容不一致');
    await fs.unlink(renamed);
  } catch (error) {
    failure = error;
  } finally {
    const cleanupErrors: string[] = [];
    if (handle) await handle.close().catch(error => cleanupErrors.push(String(error)));
    for (const name of ['original.txt', 'renamed.txt', '._original.txt', '._renamed.txt']) {
      await fs.unlink(path.join(directory, name)).catch(error => {
        if (error.code !== 'ENOENT') cleanupErrors.push(String(error));
      });
    }
    await fs.rmdir(directory).catch(error => cleanupErrors.push(String(error)));
    if (cleanupErrors.length) {
      throw new Error(`读写自检${failure ? `失败：${String(failure)}；` : '完成，但'}临时文件清理失败：${directory}；${cleanupErrors.join('; ')}`);
    }
  }
  if (failure) throw failure;
}

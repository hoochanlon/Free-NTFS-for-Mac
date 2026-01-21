// 依赖检查模块
import type { Dependencies } from '../../types/electron';
import { commandExists, execAsync, fileExists } from './utils';
import { PathFinder } from './path-finder';

// 检查 MacFUSE（使用多种方法，提高可靠性）
async function checkMacFUSE(brewExists: boolean): Promise<boolean> {
  // 方法1：优先使用 brew list --cask（最准确的方法，如果 Homebrew 可用）
  if (brewExists) {
    try {
      // 确保 PATH 包含 Homebrew 路径（合并现有 PATH 和默认路径）
      const defaultPaths = [
        '/usr/local/bin',
        '/opt/homebrew/bin',
        '/usr/bin',
        '/bin',
        '/usr/sbin',
        '/sbin'
      ];
      const existingPath = process.env.PATH || '';
      const pathArray = existingPath ? existingPath.split(':') : [];
      // 合并并去重
      const mergedPaths = [...new Set([...defaultPaths, ...pathArray])];

      const env = {
        ...process.env,
        PATH: mergedPaths.join(':')
      };

      // 使用 brew list --cask 检查（最准确的方法）
      try {
        await Promise.race([
          execAsync('brew list --cask macfuse 2>/dev/null', { env }),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000))
        ]);
        // 如果命令成功执行（退出码为 0），说明已安装
        console.log('[依赖检查] MacFUSE 通过 brew list --cask 检查');
        return true;
      } catch (error) {
        // brew list --cask 返回非零退出码或抛出异常，说明未安装
        console.log('[依赖检查] brew list --cask 检查：MacFUSE 未通过 Homebrew 安装');
      }
    } catch {
      // 忽略错误，继续尝试其他方法
    }
  }

  // 方法2：检查系统扩展是否加载（如果通过其他方式安装）
  try {
    const { stdout } = await Promise.race([
      execAsync('systemextensionsctl list 2>/dev/null'),
      new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000))
    ]) as { stdout: string };

    // 检查输出中是否包含 macfuse 相关的扩展
    if (stdout && (stdout.toLowerCase().includes('macfuse') || stdout.toLowerCase().includes('fuse'))) {
      // 进一步检查是否已启用（状态为 enabled 或 activated）
      const lines = stdout.split('\n');
      for (const line of lines) {
        const lowerLine = line.toLowerCase();
        if (lowerLine.includes('macfuse') || lowerLine.includes('fuse')) {
          // 如果包含 enabled、activated 或 running，认为已安装
          if (lowerLine.includes('enabled') || lowerLine.includes('activated') ||
              lowerLine.includes('running') || lowerLine.includes('*')) {
            console.log('[依赖检查] MacFUSE 通过系统扩展检查');
            return true;
          }
        }
      }
    }
  } catch (error) {
    // 系统扩展检查失败，继续尝试其他方法
    console.log('[依赖检查] 系统扩展检查失败，尝试其他方法:', error);
  }

  // 方法3：检查关键文件是否存在（快速且可靠）
  const macfuseFiles = [
    '/Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse',
    '/Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse',
    '/usr/local/lib/libfuse.dylib',
    '/opt/homebrew/lib/libfuse.dylib'
  ];

  for (const file of macfuseFiles) {
    try {
      if (await fileExists(file)) {
        console.log('[依赖检查] MacFUSE 通过文件检查:', file);
        return true;
      }
    } catch {
      // 继续检查下一个文件
    }
  }

  // 方法4：使用 brew info 作为备用（如果 Homebrew 可用但 brew list 失败）
  if (brewExists) {
    try {
      // 确保 PATH 包含 Homebrew 路径（合并现有 PATH 和默认路径）
      const defaultPaths = [
        '/usr/local/bin',
        '/opt/homebrew/bin',
        '/usr/bin',
        '/bin',
        '/usr/sbin',
        '/sbin'
      ];
      const existingPath = process.env.PATH || '';
      const pathArray = existingPath ? existingPath.split(':') : [];
      // 合并并去重
      const mergedPaths = [...new Set([...defaultPaths, ...pathArray])];

      const env = {
        ...process.env,
        PATH: mergedPaths.join(':')
      };

      // 使用 brew info 检查（带超时保护）
      try {
        const infoResult = await Promise.race([
          execAsync('brew info macfuse 2>/dev/null', { env }),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000))
        ]);
        // 检查输出中是否包含 "Not installed"，如果包含则未安装
        const output = (infoResult as { stdout: string }).stdout || '';
        const lowerOutput = output.toLowerCase();
        // 明确检查是否包含 "Not installed"，避免误判
        if (lowerOutput.includes('not installed')) {
          console.log('[依赖检查] brew info 检查：MacFUSE 未安装');
          return false;
        }
        // 如果输出中包含 "Installed" 且不包含 "Not installed"，认为已安装
        if (lowerOutput.includes('installed') && !lowerOutput.includes('not installed')) {
          console.log('[依赖检查] MacFUSE 通过 brew info 检查');
          return true;
        }
      } catch (error) {
        // brew info 失败，可能因为网络问题或 brew 未正确配置
        console.log('[依赖检查] brew info 检查失败:', error);
      }
    } catch {
      // 忽略错误
    }
  }

  // 如果所有方法都失败，返回 false
  // 但可以尝试一次重试（延迟后再次检查系统扩展，因为有时需要时间加载）
  console.log('[依赖检查] MacFUSE 所有检查方法均失败，尝试延迟重试...');
  try {
    await new Promise(resolve => setTimeout(resolve, 500)); // 延迟 500ms
    // 重试系统扩展检查
    const { stdout } = await Promise.race([
      execAsync('systemextensionsctl list 2>/dev/null'),
      new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000))
    ]) as { stdout: string };

    if (stdout && (stdout.toLowerCase().includes('macfuse') || stdout.toLowerCase().includes('fuse'))) {
      const lines = stdout.split('\n');
      for (const line of lines) {
        const lowerLine = line.toLowerCase();
        if ((lowerLine.includes('macfuse') || lowerLine.includes('fuse')) &&
            (lowerLine.includes('enabled') || lowerLine.includes('activated') ||
             lowerLine.includes('running') || lowerLine.includes('*'))) {
          console.log('[依赖检查] MacFUSE 通过延迟重试检查');
          return true;
        }
      }
    }
  } catch {
    // 重试也失败，返回 false
  }

  return false;
}

// 检查macOS版本是否满足要求（macOS 14 Sonoma或更高版本）
async function checkMacOSVersion(): Promise<{ satisfied: boolean; version: string }> {
  let macosVersionString = '未知';
  let satisfied = false;

  try {
    // 使用 sw_vers 命令获取macOS版本
    const { stdout } = await execAsync('sw_vers -productVersion');
    macosVersionString = stdout.trim();

    // 解析版本号
    const versionParts = macosVersionString.split('.');
    const major = parseInt(versionParts[0] || '0', 10);
    const minor = parseInt(versionParts[1] || '0', 10);

    // 要求至少 macOS 14.0 (Sonoma) 或更高版本
    satisfied = major >= 14;
  } catch (error) {
    // 如果 sw_vers 失败，假设版本满足要求（避免误报）
    console.warn('无法使用 sw_vers 获取版本:', error);
    satisfied = true;
    macosVersionString = '未知';
  }

  return { satisfied, version: macosVersionString };
}

export async function checkDependencies(): Promise<Dependencies> {
  const result: Dependencies = {
    swift: false,
    brew: false,
    macfuse: false,
    ntfs3g: false,
    ntfs3gPath: null,
    macosVersion: false,
    macosVersionString: undefined,
    fswatch: false
  };

  // 检查macOS版本（带超时）
  try {
    const macosCheck = await Promise.race([
      checkMacOSVersion(),
      new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000))
    ]);
    result.macosVersion = macosCheck.satisfied;
    result.macosVersionString = macosCheck.version;
  } catch (error) {
    // 如果检查失败，尝试直接获取版本号（不检查是否满足要求）
    try {
      const { stdout } = await execAsync('sw_vers -productVersion');
      result.macosVersionString = stdout.trim();
      // 解析版本号判断是否满足要求
      const versionParts = result.macosVersionString.split('.');
      const major = parseInt(versionParts[0] || '0', 10);
      result.macosVersion = major >= 14;
    } catch {
      // 如果都失败了，设置为未知
      console.warn('无法获取macOS版本:', error);
      result.macosVersion = false;
      result.macosVersionString = '未知';
    }
  }

  try {
    // 并行检查 Xcode Command Line Tools (通过 swift 命令) 和 brew，提高速度
    const [swiftExists, brewExists] = await Promise.all([
      commandExists('swift'),
      commandExists('brew')
    ]);

    result.swift = swiftExists;
    result.brew = brewExists;

    // 检查 MacFUSE（使用多种方法，提高可靠性）
    // 方法1：检查系统扩展是否加载（最可靠）
    // 方法2：检查关键文件是否存在
    // 方法3：使用 brew info 作为备用
    result.macfuse = await checkMacFUSE(result.brew);

    // 检查 ntfs-3g（带超时）
    try {
      const pathFinder = new PathFinder();
      const ntfs3gPath = await Promise.race([
        pathFinder.getNTFS3GPath(),
        new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000))
      ]);
      if (ntfs3gPath) {
        result.ntfs3g = true;
        result.ntfs3gPath = ntfs3gPath as string;
      }
    } catch {
      result.ntfs3g = false;
    }

    // 检查 fswatch（可选，用于事件驱动检测）
    if (result.brew) {
      try {
        // 确保 PATH 包含 Homebrew 路径（合并现有 PATH 和默认路径）
        const defaultPaths = [
          '/usr/local/bin',
          '/opt/homebrew/bin',
          '/usr/bin',
          '/bin',
          '/usr/sbin',
          '/sbin'
        ];
        const existingPath = process.env.PATH || '';
        const pathArray = existingPath ? existingPath.split(':') : [];
        // 合并并去重
        const mergedPaths = [...new Set([...defaultPaths, ...pathArray])];

        const env = {
          ...process.env,
          PATH: mergedPaths.join(':')
        };

        const fswatchResult = await Promise.race([
          execAsync('which fswatch 2>/dev/null', { env }),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000))
        ]);
        result.fswatch = (fswatchResult as { stdout: string }).stdout.trim().length > 0;
      } catch {
        result.fswatch = false;
      }
    }
  } catch (error) {
    console.error('检查依赖时出错:', error);
  }

  return result;
}

export async function installDependencies(): Promise<string> {
  const logs: string[] = [];

  // 禁用系统完整性保护（需要用户手动操作）
  logs.push('提示: 需要禁用系统完整性保护，请在终端运行: sudo spctl --master-disable');

  // 检查并安装 Xcode Command Line Tools
  if (!(await commandExists('swift'))) {
    logs.push('正在安装 Xcode Command Line Tools...');
    try {
      await execAsync('xcode-select --install');
      logs.push('Xcode Command Line Tools 安装程序已启动');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logs.push(`Xcode Command Line Tools 安装失败: ${errorMessage}`);
    }
  }

  // 检查并安装 Homebrew
  if (!(await commandExists('brew'))) {
    logs.push('正在安装 Homebrew...');
    try {
      await execAsync('/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"');
      logs.push('Homebrew 安装完成');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logs.push(`Homebrew 安装失败: ${errorMessage}`);
    }
  }

  // 安装 MacFUSE 和 ntfs-3g
  if (await commandExists('brew')) {
    logs.push('正在安装 MacFUSE 和 ntfs-3g...');
    try {
      // 确保 PATH 包含 Homebrew 路径（合并现有 PATH 和默认路径）
      const defaultPaths = [
        '/usr/local/bin',
        '/opt/homebrew/bin',
        '/usr/bin',
        '/bin',
        '/usr/sbin',
        '/sbin'
      ];
      const existingPath = process.env.PATH || '';
      const pathArray = existingPath ? existingPath.split(':') : [];
      // 合并并去重
      const mergedPaths = [...new Set([...defaultPaths, ...pathArray])];

      const env = {
        ...process.env,
        PATH: mergedPaths.join(':')
      };
      await execAsync('brew tap gromgit/homebrew-fuse', { env });
      await execAsync('brew install --cask macfuse', { env });
      await execAsync('brew install ntfs-3g-mac', { env });
      logs.push('MacFUSE 和 ntfs-3g 安装完成');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logs.push(`安装失败: ${errorMessage}`);
    }
  }

  return logs.join('\n');
}

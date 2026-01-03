// 依赖检查模块
import type { Dependencies } from '../../types/electron';
import { commandExists, execAsync } from './utils';
import { PathFinder } from './path-finder';

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
    macosVersionString: undefined
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
    // 并行检查 swift 和 brew，提高速度
    const [swiftExists, brewExists] = await Promise.all([
      commandExists('swift'),
      commandExists('brew')
    ]);

    result.swift = swiftExists;
    result.brew = brewExists;

    // 检查 MacFUSE（使用 brew info 方法，最准确且不需要网络）
    if (result.brew) {
      try {
        // 确保 PATH 包含 Homebrew 路径
        const env = {
          ...process.env,
          PATH: process.env.PATH || [
            '/usr/local/bin',
            '/opt/homebrew/bin',
            '/usr/bin',
            '/bin',
            '/usr/sbin',
            '/sbin'
          ].join(':')
        };

        // 使用 brew info 检查（带超时保护）
        try {
          const infoResult = await Promise.race([
            execAsync('brew info macfuse 2>/dev/null', { env }),
            new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 10000))
          ]);
          // 检查输出中是否包含 "Installed" 字符串
          const output = (infoResult as { stdout: string }).stdout || '';
          result.macfuse = output.includes('Installed') || output.includes('installed');
        } catch {
          result.macfuse = false;
        }
      } catch {
        result.macfuse = false;
      }
    } else {
      result.macfuse = false;
    }

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
      // 确保 PATH 包含 Homebrew 路径
      const env = {
        ...process.env,
        PATH: process.env.PATH || [
          '/usr/local/bin',
          '/opt/homebrew/bin',
          '/usr/bin',
          '/bin',
          '/usr/sbin',
          '/sbin'
        ].join(':')
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

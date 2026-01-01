// 依赖检查模块
import type { Dependencies } from '../../types/electron';
import { commandExists, execAsync } from './utils';
import { PathFinder } from './path-finder';

export async function checkDependencies(): Promise<Dependencies> {
  const result: Dependencies = {
    swift: false,
    brew: false,
    macfuse: false,
    ntfs3g: false,
    ntfs3gPath: null
  };

  try {
    // 并行检查 swift 和 brew，提高速度
    const [swiftExists, brewExists] = await Promise.all([
      commandExists('swift'),
      commandExists('brew')
    ]);

    result.swift = swiftExists;
    result.brew = brewExists;

    // 检查 MacFUSE（带超时）
    if (result.brew) {
      try {
        await Promise.race([
          execAsync('brew list --cask macfuse 2>/dev/null'),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000))
        ]);
        result.macfuse = true;
      } catch {
        result.macfuse = false;
      }
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
      await execAsync('brew tap gromgit/homebrew-fuse');
      await execAsync('brew install --cask macfuse');
      await execAsync('brew install ntfs-3g-mac');
      logs.push('MacFUSE 和 ntfs-3g 安装完成');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logs.push(`安装失败: ${errorMessage}`);
    }
  }

  return logs.join('\n');
}

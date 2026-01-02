// Sudo 命令执行模块
import { spawn } from 'child_process';
import { ExecResult } from './utils';
import { KeychainManager } from '../utils/keychain';
import { SettingsManager } from '../utils/settings';

export class SudoExecutor {
  // 使用密码执行 sudo 命令
  async executeSudoWithPassword(args: string[], password: string): Promise<ExecResult> {
    return new Promise<ExecResult>((resolve, reject) => {
      const process = spawn('sudo', ['-S', ...args], {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';

      process.stdout?.on('data', (data) => {
        stdout += data.toString();
      });

      process.stderr?.on('data', (data) => {
        stderr += data.toString();
      });

      process.stdin?.write(password + '\n');
      process.stdin?.end();

      const timeout = setTimeout(() => {
        try {
          process.kill('SIGKILL');
        } catch {}
        reject(new Error('操作超时'));
      }, 30000);

      process.on('close', async (code) => {
        clearTimeout(timeout);
        if (code === 0) {
          resolve({ stdout, stderr });
        } else {
          // 检查是否是密码错误
          if (stderr.includes('password is incorrect') || stderr.includes('Sorry, try again') || stderr.includes('incorrect password')) {
            // 如果密码错误，删除保存的密码
            const settings = await SettingsManager.getSettings();
            if (settings.savePassword) {
              try {
                await KeychainManager.deletePassword();
                console.log('密码错误，已删除保存的密码');
              } catch (error) {
                console.warn('删除保存的密码失败:', error);
              }
            }
            reject(new Error('密码错误，请重试'));
          } else {
            reject(new Error(stderr.trim() || stdout.trim() || `退出码 ${code}`));
          }
        }
      });

      process.on('error', (error) => {
        clearTimeout(timeout);
        reject(new Error(`执行失败: ${error.message}`));
      });
    });
  }
}

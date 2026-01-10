// Sudo 命令执行模块
import { spawn } from 'child_process';
import { ExecResult } from './utils';
import { KeychainManager } from '../utils/keychain';
import { SettingsManager } from '../utils/settings';

export class SudoExecutor {
  // 使用密码执行 sudo 命令
  async executeSudoWithPassword(args: string[], password: string): Promise<ExecResult> {
    return new Promise<ExecResult>((resolve, reject) => {
      // 验证密码不为空
      if (!password || password.trim().length === 0) {
        reject(new Error('密码不能为空'));
        return;
      }

      const childProcess = spawn('sudo', ['-S', ...args], {
        stdio: ['pipe', 'pipe', 'pipe'],
        env: { ...process.env }
      });

      let stdout = '';
      let stderr = '';
      let passwordWritten = false;

      childProcess.stdout?.on('data', (data: Buffer) => {
        stdout += data.toString();
      });

      childProcess.stderr?.on('data', (data: Buffer) => {
        stderr += data.toString();
      });

      // 等待一小段时间确保进程已启动，然后写入密码
      setTimeout(() => {
        if (childProcess.stdin && !passwordWritten) {
          try {
            childProcess.stdin.write(password + '\n');
            passwordWritten = true;
            childProcess.stdin.end();
          } catch (error) {
            console.error('[SudoExecutor] 写入密码失败:', error);
          }
        }
      }, 100);

      const timeout = setTimeout(() => {
        try {
          childProcess.kill('SIGKILL');
        } catch {}
        reject(new Error('操作超时'));
      }, 30000);

      childProcess.on('close', async (code: number | null) => {
        clearTimeout(timeout);

        // 记录详细的错误信息用于调试
        console.log('[SudoExecutor] 命令执行完成:', {
          code,
          args: args.join(' '),
          stdout: stdout.substring(0, 200), // 只记录前200个字符
          stderr: stderr.substring(0, 200),
          hasPasswordError: stderr.includes('password is incorrect') || stderr.includes('Sorry, try again') || stderr.includes('incorrect password')
        });

        if (code === 0) {
          resolve({ stdout, stderr });
        } else {
          // 检查是否是密码错误（更严格的检查）
          const stderrLower = stderr.toLowerCase();
          const isPasswordError = stderrLower.includes('password is incorrect') ||
                                  stderrLower.includes('sorry, try again') ||
                                  stderrLower.includes('incorrect password') ||
                                  (code === 1 && stderrLower.includes('password'));

          if (isPasswordError) {
            // 如果密码错误，删除保存的密码
            const settings = await SettingsManager.getSettings();
            if (settings.savePassword) {
              try {
                await KeychainManager.deletePassword();
                console.log('[SudoExecutor] 密码错误，已删除保存的密码');
              } catch (error) {
                console.warn('[SudoExecutor] 删除保存的密码失败:', error);
              }
            }
            reject(new Error('密码错误，请重试'));
          } else {
            // 其他错误，返回详细错误信息
            const errorMsg = stderr.trim() || stdout.trim() || `退出码 ${code}`;
            console.error('[SudoExecutor] 命令执行失败:', {
              code,
              error: errorMsg,
              args: args.join(' ')
            });
            reject(new Error(errorMsg));
          }
        }
      });

      childProcess.on('error', (error: Error) => {
        clearTimeout(timeout);
        console.error('[SudoExecutor] 进程错误:', error);
        reject(new Error(`执行失败: ${error.message}`));
      });
    });
  }
}

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

      // 监听 stdin 错误，避免 EPIPE 错误
      childProcess.stdin?.on('error', (error: Error) => {
        // EPIPE 错误通常是因为进程已关闭，这是正常的
        if (error.message.includes('EPIPE')) {
          console.log('[SudoExecutor] stdin 管道已关闭（正常情况）');
        } else {
          console.error('[SudoExecutor] stdin 错误:', error);
        }
      });

      // 等待进程准备好接收输入，然后写入密码
      const writePassword = () => {
        if (childProcess.stdin && !passwordWritten && !childProcess.stdin.destroyed) {
          try {
            if (childProcess.stdin.writable) {
              childProcess.stdin.write(password + '\n', (error) => {
                if (error) {
                  console.error('[SudoExecutor] 写入密码失败:', error);
                } else {
                  passwordWritten = true;
                  childProcess.stdin?.end();
                }
              });
            } else {
              // 如果不可写，稍后重试
              setTimeout(writePassword, 50);
            }
          } catch (error: any) {
            // EPIPE 错误可以忽略，说明进程已关闭
            if (error.code !== 'EPIPE') {
              console.error('[SudoExecutor] 写入密码异常:', error);
            }
          }
        }
      };

      // 立即尝试写入，如果失败则稍后重试
      setTimeout(writePassword, 50);

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
          // 检查是否是密码错误（更全面和严格的检查）
          const stderrLower = stderr.toLowerCase();
          const stdoutLower = stdout.toLowerCase();
          const allOutput = (stderr + ' ' + stdout).toLowerCase();

          // macOS sudo 密码错误的常见提示（包括中英文）
          const isPasswordError =
            stderrLower.includes('password is incorrect') ||
            stderrLower.includes('sorry, try again') ||
            stderrLower.includes('incorrect password') ||
            stderrLower.includes('password incorrect') ||
            stderrLower.includes('wrong password') ||
            stderrLower.includes('authentication failure') ||
            stderrLower.includes('authentication failed') ||
            allOutput.includes('password is incorrect') ||
            allOutput.includes('sorry, try again') ||
            allOutput.includes('incorrect password') ||
            // 中文错误提示
            stderrLower.includes('密码错误') ||
            stderrLower.includes('密码不正确') ||
            allOutput.includes('密码错误') ||
            allOutput.includes('密码不正确') ||
            // 日文错误提示
            stderrLower.includes('パスワードが間違っています') ||
            allOutput.includes('パスワードが間違っています') ||
            // 如果退出码是1且输出中包含password相关关键词
            (code === 1 && (stderrLower.includes('password') || stdoutLower.includes('password')));

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
              args: args.join(' '),
              stderr: stderr.substring(0, 200),
              stdout: stdout.substring(0, 200)
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

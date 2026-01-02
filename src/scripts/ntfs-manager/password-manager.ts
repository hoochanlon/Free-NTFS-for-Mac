// 密码管理模块
import * as fs from 'fs/promises';
import { execAsync } from './utils';
import { KeychainManager } from '../utils/keychain';
import { SettingsManager } from '../utils/settings';

export class PasswordManager {
  // 获取管理员密码
  async getPassword(prompt: string = '需要管理员权限'): Promise<string> {
    // 先检查设置，看是否允许使用保存的密码
    const settings = await SettingsManager.getSettings();

    if (settings.savePassword) {
      try {
        const savedPassword = await KeychainManager.getPassword();
        if (savedPassword && savedPassword.length > 0) {
          // 直接返回保存的密码，在实际使用时验证
          // 这样可以避免预验证可能的问题
          console.log('使用保存的密码');
          return savedPassword;
        }
      } catch (error) {
        console.warn('读取保存的密码失败:', error);
      }
    }

    // 如果没有保存的密码或密码无效，提示用户输入
    try {
      const escapedPrompt = prompt.replace(/"/g, '\\"').replace(/\n/g, ' ');
      const scriptPath = `/tmp/ntfs_password_${Date.now()}.scpt`;
      const script = `tell application "System Events"
  activate
end tell
tell application "System Events"
  set theAnswer to display dialog "${escapedPrompt}" & return & return & "请输入您的管理员密码：" default answer "" with hidden answer buttons {"取消", "确定"} default button "确定" with icon caution
  return text returned of theAnswer
end tell`;

      await fs.writeFile(scriptPath, script);

      try {
        const result = await execAsync(`osascript "${scriptPath}"`) as { stdout: string };
        const match = result.stdout.match(/text returned:(.+)/i);
        let password: string;

        if (match && match[1]) {
          password = match[1].trim();
        } else {
          const trimmed = result.stdout.trim();
          if (trimmed && !trimmed.toLowerCase().includes('error')) {
            password = trimmed;
          } else {
            throw new Error('无法解析密码输入结果');
          }
        }

        // 如果设置允许保存密码，保存新输入的密码
        if (settings.savePassword && password) {
          try {
            await KeychainManager.savePassword(password);
            console.log('密码已保存到 Keychain');
          } catch (error) {
            console.warn('保存密码失败:', error);
          }
        }

        return password;
      } finally {
        fs.unlink(scriptPath).catch(() => {});
      }
    } catch (error: any) {
      if (error.code === 1 || error.stderr?.includes('User canceled') || error.stderr?.includes('用户取消了') || error.message?.includes('取消')) {
        throw new Error('用户取消了密码输入');
      }
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`获取密码失败: ${errorMessage}`);
    }
  }
}

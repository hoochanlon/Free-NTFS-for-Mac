import * as child_process from 'child_process';
import { promisify } from 'util';

const exec = promisify(child_process.exec);

// Keychain 服务名称（与 appId 对齐）
const KEYCHAIN_SERVICE = 'io.hoochanlon.github';

/**
 * 使用 macOS Keychain 安全存储密码
 */
export class KeychainManager {
  /**
   * 保存密码到 Keychain
   */
  static async savePassword(password: string): Promise<void> {
    try {
      // 使用 security 命令将密码保存到 Keychain
      // -a 指定账户名（使用服务名作为账户名）
      // -s 指定服务名
      // -w 指定密码
      const command = `security add-generic-password -a "${KEYCHAIN_SERVICE}" -s "${KEYCHAIN_SERVICE}" -w "${password.replace(/"/g, '\\"')}" -U`;
      await exec(command);
    } catch (error: any) {
      // 如果密码已存在，先删除再添加
      if (error.message?.includes('already exists')) {
        await this.deletePassword();
        await this.savePassword(password);
      } else {
        throw new Error(`保存密码失败: ${error.message}`);
      }
    }
  }

  /**
   * 从 Keychain 读取密码
   */
  static async getPassword(): Promise<string | null> {
    try {
      const command = `security find-generic-password -a "${KEYCHAIN_SERVICE}" -s "${KEYCHAIN_SERVICE}" -w`;
      const { stdout } = await exec(command);
      // 保留密码的所有字符，包括前后空格
      // 只去除末尾的换行符（security 命令会自动添加）
      return stdout.replace(/\n$/, '');
    } catch (error: any) {
      // 如果密码不存在，返回 null
      if (error.message?.includes('could not be found') || error.message?.includes('The specified item could not be found')) {
        return null;
      }
      throw new Error(`读取密码失败: ${error.message}`);
    }
  }

  /**
   * 删除 Keychain 中的密码
   */
  static async deletePassword(): Promise<void> {
    try {
      const command = `security delete-generic-password -a "${KEYCHAIN_SERVICE}" -s "${KEYCHAIN_SERVICE}"`;
      await exec(command);
    } catch (error: any) {
      // 如果密码不存在，忽略错误
      if (!error.message?.includes('could not be found') && !error.message?.includes('The specified item could not be found')) {
        throw new Error(`删除密码失败: ${error.message}`);
      }
    }
  }

  /**
   * 检查 Keychain 中是否存在密码
   */
  static async hasPassword(): Promise<boolean> {
    try {
      await this.getPassword();
      return true;
    } catch {
      return false;
    }
  }
}

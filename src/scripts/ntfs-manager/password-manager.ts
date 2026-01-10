// 密码管理模块
import * as fs from 'fs/promises';
import * as path from 'path';
import { app } from 'electron';
import { execAsync } from './utils';
import { KeychainManager } from '../utils/keychain';
import { SettingsManager } from '../utils/settings';

// 翻译缓存
let translations: Record<string, any> = {};

// 加载语言文件
async function loadTranslations(lang: string): Promise<void> {
  try {
    const appPath = app.getAppPath();
    const langFile = path.join(appPath, 'src', 'locales', `${lang}.json`);
    if (await fs.access(langFile).then(() => true).catch(() => false)) {
      const content = await fs.readFile(langFile, 'utf-8');
      translations = JSON.parse(content);
    } else {
      // 如果文件不存在，使用默认的中文
      const defaultLangFile = path.join(appPath, 'src', 'locales', 'zh-CN.json');
      const content = await fs.readFile(defaultLangFile, 'utf-8');
      translations = JSON.parse(content);
    }
  } catch (error) {
    console.error('加载语言文件失败:', error);
    // 使用硬编码的默认值
    translations = {
      messages: {
        passwordDialog: {
          title: '需要管理员权限',
          prompt: '请输入您的管理员密码：',
          cancel: '取消',
          confirm: '确定',
          passwordEmpty: '密码不能为空',
          passwordParseError: '无法解析密码输入结果：密码为空',
          userCancelled: '用户取消了密码输入',
          getPasswordFailed: '获取密码失败'
        }
      }
    };
  }
}

// 获取翻译文本（支持参数替换）
function t(key: string, params?: Record<string, string | number>): string {
  const keys = key.split('.');
  let value: any = translations;
  for (const k of keys) {
    if (value && typeof value === 'object' && k in value) {
      value = value[k];
    } else {
      // 如果找不到翻译，返回 key
      return key;
    }
  }
  let result = typeof value === 'string' ? value : key;

  // 替换参数
  if (params) {
    result = result.replace(/\{(\w+)\}/g, (match, paramKey) => {
      return params[paramKey] !== undefined ? String(params[paramKey]) : match;
    });
  }

  return result;
}

export class PasswordManager {
  // 获取管理员密码
  // prompt: 可以是直接的文本，也可以是翻译键（如 'messages.passwordDialog.mountDevice'）
  // params: 如果 prompt 是翻译键，可以使用 params 替换翻译中的参数（如 {name}）
  async getPassword(prompt: string = '', params?: Record<string, string | number>): Promise<string> {
    // 加载翻译
    const settings = await SettingsManager.getSettings();
    let lang = settings.language;

    // 如果选择跟随系统，检测系统语言
    if (lang === 'system') {
      const systemLang = app.getLocale();
      if (systemLang.startsWith('ja')) {
        lang = 'ja';
      } else if (systemLang.startsWith('en')) {
        lang = 'en';
      } else if (systemLang.startsWith('zh-TW') || systemLang.startsWith('zh-Hant')) {
        lang = 'zh-TW';
      } else {
        lang = 'zh-CN';
      }
    }

    await loadTranslations(lang);

    // 如果 prompt 是翻译键（以 'messages.' 开头），使用翻译
    // 否则直接使用 prompt 文本
    let defaultPrompt: string;
    if (prompt && prompt.startsWith('messages.')) {
      defaultPrompt = t(prompt, params);
    } else {
      defaultPrompt = prompt || t('messages.passwordDialog.title');
    }

    // 先检查设置，看是否允许使用保存的密码

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
      const passwordPrompt = t('messages.passwordDialog.prompt');
      const cancelButton = t('messages.passwordDialog.cancel');
      const confirmButton = t('messages.passwordDialog.confirm');

      const escapedPrompt = defaultPrompt.replace(/"/g, '\\"').replace(/\n/g, ' ');
      const escapedPasswordPrompt = passwordPrompt.replace(/"/g, '\\"').replace(/\n/g, ' ');
      const scriptPath = `/tmp/ntfs_password_${Date.now()}.scpt`;
      const script = `tell application "System Events"
  activate
end tell
tell application "System Events"
  set theAnswer to display dialog "${escapedPrompt}" & return & return & "${escapedPasswordPrompt}" default answer "" with hidden answer buttons {"${cancelButton}", "${confirmButton}"} default button "${confirmButton}" with icon caution
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
          // 检查是否是错误或取消
          if (trimmed.toLowerCase().includes('error') || trimmed.toLowerCase().includes('cancel')) {
            throw new Error(t('messages.passwordDialog.userCancelled'));
          }
          // 尝试直接使用输出（可能是密码本身）
          if (trimmed && trimmed.length > 0) {
            password = trimmed;
          } else {
            throw new Error(t('messages.passwordDialog.passwordParseError'));
          }
        }

        // 验证密码不为空
        if (!password || password.length === 0) {
          throw new Error(t('messages.passwordDialog.passwordEmpty'));
        }

        console.log('[PasswordManager] 成功获取密码，长度:', password.length);

        // 如果设置允许保存密码，保存新输入的密码
        if (settings.savePassword && password) {
          try {
            await KeychainManager.savePassword(password);
            console.log('[PasswordManager] 密码已保存到 Keychain');
          } catch (error) {
            console.warn('[PasswordManager] 保存密码失败:', error);
          }
        }

        return password;
      } finally {
        fs.unlink(scriptPath).catch(() => {});
      }
    } catch (error: any) {
      const cancelText = t('messages.passwordDialog.cancel');
      if (error.code === 1 ||
          error.stderr?.includes('User canceled') ||
          error.stderr?.includes('用户取消了') ||
          error.stderr?.includes('キャンセル') ||
          error.message?.includes('取消') ||
          error.message?.includes('キャンセル') ||
          error.message?.includes('cancel')) {
        throw new Error(t('messages.passwordDialog.userCancelled'));
      }
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`${t('messages.passwordDialog.getPasswordFailed')}: ${errorMessage}`);
    }
  }
}

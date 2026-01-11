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
      // 改进的 AppleScript：明确区分取消和空密码
      const script = `try
  tell application "System Events"
    activate
  end tell
  tell application "System Events"
    set theAnswer to display dialog "${escapedPrompt}" & return & return & "${escapedPasswordPrompt}" default answer "" with hidden answer buttons {"${cancelButton}", "${confirmButton}"} default button "${confirmButton}" with icon caution
    set buttonPressed to button returned of theAnswer
    set passwordText to text returned of theAnswer

    if buttonPressed is "${cancelButton}" then
      return "CANCELED"
    else if passwordText is "" then
      return "EMPTY"
    else
      return passwordText
    end if
  end tell
on error errorMessage
  if errorMessage contains "canceled" or errorMessage contains "取消" or errorMessage contains "キャンセル" then
    return "CANCELED"
  else
    return "ERROR:" & errorMessage
  end if
end try`;

      await fs.writeFile(scriptPath, script);

      try {
        const result = await execAsync(`osascript "${scriptPath}"`) as { stdout: string; stderr?: string };
        const output = (result.stdout || '').trim();
        const errorOutput = (result.stderr || '').trim();

        // 检查是否是用户取消
        if (output === 'CANCELED' ||
            errorOutput.toLowerCase().includes('user canceled') ||
            errorOutput.toLowerCase().includes('用户取消了') ||
            errorOutput.toLowerCase().includes('キャンセル') ||
            output.toLowerCase().includes('canceled')) {
          throw new Error(t('messages.passwordDialog.userCancelled'));
        }

        // 检查是否是空密码
        if (output === 'EMPTY' || output === '') {
          throw new Error(t('messages.passwordDialog.passwordEmpty'));
        }

        // 检查是否是错误
        if (output.startsWith('ERROR:')) {
          const errorMsg = output.substring(6);
          if (errorMsg.toLowerCase().includes('cancel') ||
              errorMsg.toLowerCase().includes('取消') ||
              errorMsg.toLowerCase().includes('キャンセル')) {
            throw new Error(t('messages.passwordDialog.userCancelled'));
          }
          throw new Error(`AppleScript error: ${errorMsg}`);
        }

        // 提取密码（去除可能的引号）
        let password = output;
        // 移除首尾引号（如果存在）
        if ((password.startsWith('"') && password.endsWith('"')) ||
            (password.startsWith("'") && password.endsWith("'"))) {
          password = password.slice(1, -1);
        }
        password = password.trim();

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
      const errorOutput = error.stderr || '';
      const errorMessage = error.message || '';
      const fullError = (errorOutput + ' ' + errorMessage).toLowerCase();

      // 检查是否是用户取消（更全面的检查）
      if (error.code === 1 ||
          errorOutput.includes('User canceled') ||
          errorOutput.includes('用户取消了') ||
          errorOutput.includes('キャンセル') ||
          errorOutput.includes('button returned') ||
          fullError.includes('cancel') ||
          fullError.includes('取消') ||
          fullError.includes('キャンセル') ||
          errorMessage.includes('userCancelled') ||
          errorMessage.includes('用户取消')) {
        throw new Error(t('messages.passwordDialog.userCancelled'));
      }

      // 检查是否是空密码错误（已经在内部处理，这里只是传递）
      if (errorMessage.includes('passwordEmpty') ||
          errorMessage.includes('密码为空') ||
          errorMessage.includes('password is empty')) {
        throw error; // 直接抛出，保持原始错误消息
      }

      // 其他错误
      const finalErrorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`${t('messages.passwordDialog.getPasswordFailed')}: ${finalErrorMessage}`);
    }
  }
}

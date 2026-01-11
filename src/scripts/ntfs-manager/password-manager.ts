// 密码管理模块
import * as fs from 'fs/promises';
import * as path from 'path';
import { app } from 'electron';
import { execAsync } from './utils';
import { KeychainManager } from '../utils/keychain';
import { SettingsManager } from '../utils/settings';
import { SudoExecutor } from './sudo-executor';
import { createPasswordDialog } from '../utils/password-dialog-window';

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

      // 使用自定义密码对话框（支持显示/隐藏密码）
      const password = await createPasswordDialog({
        title: defaultPrompt,
        message: passwordPrompt,
        label: passwordPrompt,
        cancelText: cancelButton,
        confirmText: confirmButton,
        emptyPasswordText: t('messages.passwordDialog.passwordEmpty')
      });

      // 检查用户是否取消
      if (password === null) {
        throw new Error(t('messages.passwordDialog.userCancelled'));
      }

      // 验证密码不为空或只包含空格（仅用于验证，不修改密码）
      if (!password || password.trim().length === 0) {
        throw new Error(t('messages.passwordDialog.passwordEmpty'));
      }

      // 保留密码的所有字符，包括前后空格和中间空格
      const finalPassword = password;

      console.log('[PasswordManager] 成功获取密码，长度:', finalPassword.length);

      // 验证密码是否正确（使用 sudo -v 验证）
      // 注意：为了确保每次都验证新密码，我们使用 sudo -K 先清除缓存（不需要密码）
      // 然后使用 sudo -v 验证密码（需要密码）
      try {
        // 先清除 sudo 缓存（使用 execAsync，不需要密码）
        try {
          await execAsync('sudo -K');
        } catch {
          // 清除缓存失败不影响，继续验证
        }

        // 然后验证密码（使用 sudo -v，需要密码）
        const sudoExecutor = new SudoExecutor();
        await sudoExecutor.executeSudoWithPassword(['-v'], finalPassword);
        console.log('[PasswordManager] 密码验证成功');
      } catch (error: any) {
        const errorMessage = error.message || String(error);
        const errorString = String(error).toLowerCase();
        console.log('[PasswordManager] 密码验证失败:', errorMessage);

        // 检查是否是密码错误（更全面的检查）
        const isPasswordError =
          errorMessage.includes('密码错误') ||
          errorMessage.includes('incorrect password') ||
          errorMessage.includes('Sorry, try again') ||
          errorMessage.includes('password is incorrect') ||
          errorMessage.includes('authentication failure') ||
          errorMessage.includes('authentication failed') ||
          errorMessage.includes('no password was provided') ||
          errorMessage.includes('incorrect password attempt') ||
          errorString.includes('password') && (errorString.includes('incorrect') || errorString.includes('wrong') || errorString.includes('error') || errorString.includes('failed'));

        if (isPasswordError) {
          // 如果之前保存了密码，删除它
          if (settings.savePassword) {
            try {
              await KeychainManager.deletePassword();
              console.log('[PasswordManager] 密码错误，已删除保存的密码');
            } catch (deleteError) {
              console.warn('[PasswordManager] 删除保存的密码失败:', deleteError);
            }
          }
          throw new Error('密码错误，请重试');
        }
        // 其他错误也抛出，让调用者处理
        throw new Error(`密码验证失败: ${errorMessage}`);
      }

      // 如果设置允许保存密码，保存新输入的密码（仅在验证成功后）
      if (settings.savePassword && finalPassword) {
        try {
          await KeychainManager.savePassword(finalPassword);
          console.log('[PasswordManager] 密码已保存到 Keychain');
        } catch (error) {
          console.warn('[PasswordManager] 保存密码失败:', error);
        }
      }

      return finalPassword;
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

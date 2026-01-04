import { app } from 'electron';
import * as path from 'path';
import * as fs from 'fs';

// 翻译数据缓存
let translations: Record<string, any> = {};

/**
 * 加载语言文件
 */
export async function loadTranslations(lang: string): Promise<void> {
  try {
    const appPath = app.getAppPath();
    const langFile = path.join(appPath, 'src', 'locales', `${lang}.json`);
    if (fs.existsSync(langFile)) {
      const content = await fs.promises.readFile(langFile, 'utf-8');
      translations = JSON.parse(content);
    } else {
      const defaultLangFile = path.join(appPath, 'src', 'locales', 'zh-CN.json');
      const content = await fs.promises.readFile(defaultLangFile, 'utf-8');
      translations = JSON.parse(content);
    }
  } catch (error) {
    console.error('加载语言文件失败:', error);
    translations = {};
  }
}

/**
 * 获取翻译文本
 */
export function t(key: string): string {
  const keys = key.split('.');
  let value: any = translations;
  for (const k of keys) {
    if (value && typeof value === 'object' && k in value) {
      value = value[k];
    } else {
      return key; // 如果找不到翻译，返回 key
    }
  }
  return typeof value === 'string' ? value : key;
}

/**
 * 检测并返回当前语言代码
 */
export function detectLanguage(settingsLanguage: string): string {
  if (settingsLanguage === 'system') {
    const systemLang = app.getLocale();
    if (systemLang.startsWith('ja')) {
      return 'ja';
    } else if (systemLang.startsWith('en')) {
      return 'en';
    } else if (systemLang.startsWith('zh-TW') || systemLang.startsWith('zh-Hant')) {
      return 'zh-TW';
    } else {
      return 'zh-CN';
    }
  }
  return settingsLanguage;
}

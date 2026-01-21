// 国际化工具模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;

  // 支持的语言
  type SupportedLanguage = 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'de';
  type LanguageSetting = SupportedLanguage | 'system';

  // 当前语言
  let currentLanguage: SupportedLanguage = 'zh-CN';

  // 检测系统语言
  function detectSystemLanguage(): SupportedLanguage {
    const systemLang = navigator.language;
    if (systemLang.startsWith('ja')) {
      return 'ja';
    } else if (systemLang.startsWith('de')) {
      return 'de';
    } else if (systemLang.startsWith('en')) {
      return 'en';
    } else if (systemLang.startsWith('zh-TW') || systemLang.startsWith('zh-Hant')) {
      return 'zh-TW';
    } else if (systemLang.startsWith('zh')) {
      return 'zh-CN';
    } else {
      return 'zh-CN';
    }
  }

  // 翻译数据
  let translations: Record<string, any> = {};

  // 加载语言文件
  async function loadLanguage(lang: SupportedLanguage): Promise<void> {
    try {
      // 尝试多个可能的路径
      const possiblePaths = [
        `../locales/${lang}.json`,
        `./locales/${lang}.json`,
        `locales/${lang}.json`,
        `../../locales/${lang}.json`
      ];

      let loaded = false;
      for (const path of possiblePaths) {
        try {
          const response = await fetch(path);
          if (response.ok) {
            translations = await response.json();
            currentLanguage = lang;
            // 更新 HTML lang 属性
            document.documentElement.lang = lang;
            loaded = true;
            console.log(`Language file loaded successfully: ${path}`);
            break;
          }
        } catch (e) {
          // 继续尝试下一个路径
          continue;
        }
      }

      if (!loaded) {
        console.error(`Failed to load language file: ${lang}.json from any path`);
        // 如果加载失败，尝试加载默认语言（中文）
        if (lang !== 'zh-CN') {
          await loadLanguage('zh-CN');
        } else {
          // 如果连默认语言都加载失败，使用空对象避免错误
          translations = {};
          console.warn('Using empty translations object');
        }
      }
    } catch (error) {
      console.error(`Error loading language file: ${lang}.json`, error);
      // 如果加载失败，尝试加载默认语言（中文）
      if (lang !== 'zh-CN') {
        await loadLanguage('zh-CN');
      } else {
        // 如果连默认语言都加载失败，使用空对象避免错误
        translations = {};
        console.warn('Using empty translations object');
      }
    }
  }

  // 获取翻译文本
  function t(key: string, params?: Record<string, string | number>): string {
    // 如果 translations 为空或未初始化，返回 key（不输出警告，避免控制台噪音）
    if (!translations || Object.keys(translations).length === 0) {
      return key;
    }

    const keys = key.split('.');
    let value: any = translations;

    for (const k of keys) {
      if (value && typeof value === 'object' && k in value) {
        value = value[k];
      } else {
        // 只在开发模式下显示警告，避免生产环境的控制台噪音
        if (typeof process !== 'undefined' && process.env && process.env.NODE_ENV === 'development') {
          console.warn(`Translation key not found: ${key}`);
        }
        return key; // 如果找不到翻译，返回 key
      }
    }

    if (typeof value !== 'string') {
      // 只在开发模式下显示警告
      if (typeof process !== 'undefined' && process.env && process.env.NODE_ENV === 'development') {
        console.warn(`Translation value is not a string: ${key}`);
      }
      return key;
    }

    // 如果翻译值为空字符串，返回 key 作为后备
    if (value === '') {
      // 只在开发模式下显示警告
      if (typeof process !== 'undefined' && process.env && process.env.NODE_ENV === 'development') {
        console.warn(`Translation value is empty string: ${key}`);
      }
      return key;
    }

    // 替换参数
    if (params) {
      return value.replace(/\{(\w+)\}/g, (match, paramKey) => {
        return params[paramKey] !== undefined ? String(params[paramKey]) : match;
      });
    }

    return value;
  }

  // 初始化 i18n
  async function init(lang?: SupportedLanguage | LanguageSetting): Promise<void> {
    // 如果没有指定语言，尝试从设置中获取
    if (!lang) {
      try {
        const settings = await (window as any).electronAPI?.getSettings();
        if (settings && settings.language) {
          lang = settings.language as LanguageSetting;
        }
      } catch (error) {
        console.error('Failed to get language from settings:', error);
      }
    }

    // 如果选择跟随系统或没有语言，使用系统语言
    if (!lang || lang === 'system') {
      lang = detectSystemLanguage();
      } else {
      // 确保是支持的语言
      lang = lang as SupportedLanguage;
    }

    await loadLanguage(lang);
  }

  // 切换语言
  async function setLanguage(lang: LanguageSetting): Promise<void> {
    let actualLang: SupportedLanguage;

    // 如果选择跟随系统，检测系统语言
    if (lang === 'system') {
      actualLang = detectSystemLanguage();
    } else {
      actualLang = lang as SupportedLanguage;
    }

    await loadLanguage(actualLang);
    // 保存到设置（保存原始值，可能是 'system'）
    try {
      await (window as any).electronAPI?.saveSettings({ language: lang });
    } catch (error) {
      console.error('Failed to save language setting:', error);
    }
    // 触发语言变更事件
    window.dispatchEvent(new CustomEvent('languageChanged', { detail: actualLang }));
  }

  // 获取系统语言
  function getSystemLanguage(): SupportedLanguage {
    return detectSystemLanguage();
  }

  // 获取当前语言
  function getLanguage(): SupportedLanguage {
    return currentLanguage;
  }

  // 导出 i18n 工具
  AppUtils.I18n = {
    init,
    t,
    setLanguage,
    getLanguage,
    getSystemLanguage
  };

})();

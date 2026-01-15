(function () {
  'use strict';

  const cancelBtn = document.getElementById('quitCancelBtn') as HTMLButtonElement | null;
  const confirmBtn = document.getElementById('quitConfirmBtn') as HTMLButtonElement | null;
  const titleEl = document.getElementById('quitTitle') as HTMLElement | null;
  const messageEl = document.getElementById('quitMessage') as HTMLElement | null;

  async function initI18nAndRender(): Promise<void> {
    const AppUtils = (window as any).AppUtils;
    if (AppUtils && AppUtils.I18n && typeof AppUtils.I18n.init === 'function') {
      await AppUtils.I18n.init();
    }

    const t = AppUtils && AppUtils.I18n && AppUtils.I18n.t
      ? AppUtils.I18n.t
      : (key: string) => key;

    // 应用国际化文本
    if (titleEl) {
      titleEl.textContent = t('tray.quitConfirmTitle') || '确认退出';
    }
    if (messageEl) {
      messageEl.textContent = t('tray.quitConfirmMessage') || '确定要退出应用吗？';
    }
    if (cancelBtn) {
      cancelBtn.textContent = t('dialog.cancel') || '取消';
    }
    if (confirmBtn) {
      confirmBtn.textContent = t('tray.quit') || '退出';
    }

    // 更新窗口标题（不影响主界面 hover 行为）
    try {
      document.title = t('tray.quit') || '退出';
    } catch (e) {
      // ignore
    }
  }

  // 初始化（确保 i18n 完成后再渲染，避免显示 key）
  initI18nAndRender().catch((err) => {
    console.error('初始化退出窗口 i18n 失败:', err);
  });

  cancelBtn?.addEventListener('click', () => {
    if ((window as any).electronAPI && (window as any).electronAPI.closeQuitWindow) {
      (window as any).electronAPI.closeQuitWindow();
    } else {
      window.close();
    }
  });

  confirmBtn?.addEventListener('click', async () => {
    try {
      if ((window as any).electronAPI && (window as any).electronAPI.quitApp) {
        await (window as any).electronAPI.quitApp();
      } else {
        window.close();
      }
    } catch (error) {
      console.error('退出应用失败:', error);
    }
  });
})();


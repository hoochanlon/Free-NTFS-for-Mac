// 关于窗口页面逻辑
(function() {
  'use strict';

  document.addEventListener('DOMContentLoaded', async () => {
    const appUtils = (window as any).AppUtils;
    const electronAPI = window.electronAPI;
    const checkButton = document.getElementById('checkUpdatesBtn') as HTMLButtonElement;
    const openReleaseButton = document.getElementById('openReleaseBtn') as HTMLButtonElement;
    const status = document.getElementById('updateStatus') as HTMLParagraphElement;
    const statusText = document.getElementById('updateStatusText') as HTMLSpanElement;
    const version = document.getElementById('currentVersion') as HTMLSpanElement;

    await appUtils?.I18n?.init();
    const translate = (key: string): string => appUtils?.I18n?.t(key) || key;
    document.querySelectorAll<HTMLElement>('[data-i18n]').forEach((element) => {
      element.textContent = translate(element.dataset.i18n || '');
    });

    if (appUtils?.Theme) {
      appUtils.Theme.initializeTheme(document.body, null);
    }
    electronAPI.onThemeChange((isLightMode) => {
      appUtils?.Theme?.updateTheme(isLightMode, document.body, null);
    });

    const closeButton = document.querySelector('.traffic-light-close');
    closeButton?.addEventListener('click', () => electronAPI.closeModuleWindow());

    document.querySelectorAll<HTMLAnchorElement>('.about-icon-link').forEach((link) => {
      link.addEventListener('click', (event) => {
        event.preventDefault();
        const href = link.getAttribute('href');
        if (href) {
          void electronAPI.openExternal(href);
        }
      });
    });

    version.textContent = await electronAPI.getAppVersion();

    openReleaseButton.addEventListener('click', () => {
      void electronAPI.openExternal('https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/latest');
    });

    const setUpdateStatus = (message: string, state: string) => {
      status.hidden = false;
      status.dataset.state = state;
      statusText.textContent = message;
    };

    checkButton.addEventListener('click', async () => {
      checkButton.disabled = true;
      openReleaseButton.hidden = true;
      setUpdateStatus(translate('about.checkingUpdates'), 'checking');

      try {
        const result = await electronAPI.checkForUpdates();
        if (!result.success) {
          const messageKey = result.reason === 'invalid' ? 'about.invalidRelease' : 'about.checkFailed';
          setUpdateStatus(translate(messageKey), 'error');
          openReleaseButton.hidden = false;
          return;
        }

        if (result.updateAvailable && result.latestVersion) {
          setUpdateStatus(translate('about.updateAvailable').replace('{version}', result.latestVersion), 'update');
          openReleaseButton.hidden = false;
        } else if (result.currentAhead && result.latestVersion) {
          setUpdateStatus(translate('about.versionAhead')
            .replace('{version}', result.currentVersion)
            .replace('{latestVersion}', result.latestVersion), 'info');
        } else {
          setUpdateStatus(translate('about.upToDate').replace('{version}', result.currentVersion), 'success');
        }
      } catch (error) {
        console.error('检查更新失败:', error);
        setUpdateStatus(translate('about.checkFailed'), 'error');
        openReleaseButton.hidden = false;
      } finally {
        checkButton.disabled = false;
      }
    });
  });
})();

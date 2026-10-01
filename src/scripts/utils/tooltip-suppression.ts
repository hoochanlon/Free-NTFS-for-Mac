(() => {
  'use strict';

  const electronAPI = (window as any).electronAPI;
  const ipcRenderer = electronAPI ? null : (window as any).require?.('electron').ipcRenderer;
  const toggleButton = document.getElementById('iconTooltipToggleBtn') as HTMLButtonElement | null;
  const originalTitles = new Map<Element, string>();
  let hideIconTooltips = false;
  let holdTimer: number | null = null;

  const hasIconControlOwner = (element: Element): boolean => {
    if (element.closest('button')) {
      return true;
    }
    const link = element.closest('a');
    return !!link && !!link.querySelector('img, svg');
  };

  const suppressTitle = (element: Element): void => {
    if (!element.hasAttribute('title') || !hasIconControlOwner(element)) {
      return;
    }

    originalTitles.set(element, element.getAttribute('title') || '');
    element.removeAttribute('title');
  };

  const scanTitles = (root: ParentNode): void => {
    if (root instanceof Element && root.hasAttribute('title')) {
      suppressTitle(root);
    }
    root.querySelectorAll('[title]').forEach(suppressTitle);
  };

  const observer = new MutationObserver((records) => {
    if (!hideIconTooltips) {
      return;
    }

    records.forEach((record) => {
      if (record.type === 'attributes' && record.target instanceof Element) {
        suppressTitle(record.target);
      }
      record.addedNodes.forEach((node) => {
        if (node instanceof Element) {
          scanTitles(node);
        }
      });
    });
  });

  const applyState = (hidden: boolean): void => {
    if (hideIconTooltips === hidden) {
      toggleButton?.classList.toggle('is-active', hidden);
      toggleButton?.setAttribute('aria-pressed', String(hidden));
      return;
    }

    if (hidden) {
      hideIconTooltips = true;
      document.documentElement.classList.add('hide-icon-tooltips');
      scanTitles(document);
      observer.observe(document.documentElement, {
        attributes: true,
        attributeFilter: ['title'],
        childList: true,
        subtree: true
      });
    } else {
      observer.takeRecords().forEach((record) => {
        if (record.type === 'attributes' && record.target instanceof Element) {
          suppressTitle(record.target);
        }
        record.addedNodes.forEach((node) => {
          if (node instanceof Element) {
            scanTitles(node);
          }
        });
      });
      observer.disconnect();
      hideIconTooltips = false;
      document.documentElement.classList.remove('hide-icon-tooltips');
      originalTitles.forEach((title, element) => {
        if (element.isConnected && !element.hasAttribute('title')) {
          element.setAttribute('title', title);
        }
      });
      originalTitles.clear();
    }

    toggleButton?.classList.toggle('is-active', hidden);
    toggleButton?.setAttribute('aria-pressed', String(hidden));
  };

  const toggleState = async (): Promise<void> => {
    const nextState = !hideIconTooltips;
    applyState(nextState);
    try {
      if (electronAPI) {
        await electronAPI.saveSettings({ hideIconTooltips: nextState });
      } else {
        await ipcRenderer?.invoke('save-settings', { hideIconTooltips: nextState });
      }
    } catch (error) {
      console.error('保存图标提示设置失败:', error);
      applyState(!nextState);
    }
  };

  const stopHold = (): void => {
    if (holdTimer !== null) {
      window.clearTimeout(holdTimer);
      holdTimer = null;
    }
    toggleButton?.classList.remove('is-holding');
  };

  if (toggleButton) {
    toggleButton.addEventListener('pointerdown', (event) => {
      if (event.button !== 0 || holdTimer !== null) {
        return;
      }
      toggleButton.classList.add('is-holding');
      holdTimer = window.setTimeout(() => {
        holdTimer = null;
        toggleButton.classList.remove('is-holding');
        void toggleState();
      }, 3000);
    });
    toggleButton.addEventListener('pointerup', stopHold);
    toggleButton.addEventListener('pointerleave', stopHold);
    toggleButton.addEventListener('pointercancel', stopHold);
    toggleButton.addEventListener('click', (event) => {
      if (event.detail === 0) {
        void toggleState();
      }
    });
  }

  const onSettingsChange = (settings: { hideIconTooltips?: boolean }): void => {
    if (typeof settings.hideIconTooltips === 'boolean') {
      applyState(settings.hideIconTooltips);
    }
  };
  if (electronAPI) {
    electronAPI.onSettingsChange(onSettingsChange);
  } else {
    ipcRenderer?.on('settings-changed', (_event: unknown, settings: { hideIconTooltips?: boolean }) => {
      onSettingsChange(settings);
    });
  }

  const settingsPromise = electronAPI
    ? electronAPI.getSettings()
    : ipcRenderer?.invoke('get-settings');
  if (settingsPromise) {
    settingsPromise
      .then((settings: { hideIconTooltips?: boolean }) => {
        applyState(settings.hideIconTooltips === true);
      })
      .catch((error: unknown) => {
        console.error('读取图标提示设置失败:', error);
      });
  }
})();

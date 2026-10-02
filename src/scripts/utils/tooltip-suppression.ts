(() => {
  'use strict';

  const electronAPI = (window as any).electronAPI;
  const ipcRenderer = electronAPI ? null : (window as any).require?.('electron').ipcRenderer;
  const tooltipHoverDelay = 3000;
  let toggleButton: HTMLButtonElement | null = null;
  let hideIconTooltips = true;
  let userChangedState = false;
  let holdTimer: number | null = null;
  let tooltip: HTMLDivElement | null = null;
  let activeControl: HTMLElement | null = null;
  let suppressedControl: HTMLElement | null = null;
  let showTimer: number | null = null;

  const getTooltipTarget = (target: EventTarget | null): HTMLElement | null => {
    if (!(target instanceof Element)) return null;
    const tooltipTarget = target.closest('[data-tooltip]');
    return tooltipTarget instanceof HTMLElement ? tooltipTarget : null;
  };

  const ensureTooltip = (): HTMLDivElement | null => {
    if (tooltip?.isConnected) return tooltip;
    if (!document.body) return null;

    tooltip = document.createElement('div');
    tooltip.className = 'app-tooltip';
    tooltip.setAttribute('role', 'tooltip');
    tooltip.hidden = true;
    document.body.appendChild(tooltip);
    return tooltip;
  };

  const hideTooltip = (): void => {
    if (showTimer !== null) {
      window.clearTimeout(showTimer);
      showTimer = null;
    }
    activeControl = null;
    if (tooltip) tooltip.hidden = true;
  };

  const positionTooltip = (control: HTMLElement): void => {
    if (!tooltip || tooltip.hidden || activeControl !== control) return;

    const bounds = control.getBoundingClientRect();
    const tooltipBounds = tooltip.getBoundingClientRect();
    const left = Math.max(8, Math.min(
      bounds.left + bounds.width / 2 - tooltipBounds.width / 2,
      window.innerWidth - tooltipBounds.width - 8
    ));
    const above = bounds.top - tooltipBounds.height - 8;
    const top = above >= 8
      ? above
      : Math.min(bounds.bottom + 8, window.innerHeight - tooltipBounds.height - 8);

    tooltip.style.left = `${left}px`;
    tooltip.style.top = `${top}px`;
  };

  const isTextClipped = (element: Element): boolean => {
    if (!(element instanceof HTMLElement)) return false;
    const bounds = element.getBoundingClientRect();
    if (bounds.width === 0 && bounds.height === 0) return false;

    const style = window.getComputedStyle(element);
    const clipsHorizontally = style.textOverflow === 'ellipsis' || style.overflowX === 'hidden' || style.overflowX === 'clip';
    const clipsVertically = style.overflowY === 'hidden' || style.overflowY === 'clip';
    return (clipsHorizontally && element.scrollWidth > element.clientWidth + 1)
      || (clipsVertically && element.scrollHeight > element.clientHeight + 1);
  };

  const needsTooltip = (control: HTMLElement): boolean => {
    if (control.hasAttribute('data-icon-tooltip')) return true;
    return [control, ...Array.from(control.querySelectorAll('*'))].some(isTextClipped);
  };

  const showTooltip = (control: HTMLElement, delay: number): void => {
    const text = control.dataset.tooltip;
    const isIconTooltip = control.hasAttribute('data-icon-tooltip');
    if ((hideIconTooltips && isIconTooltip) || suppressedControl === control || !text || !needsTooltip(control)) return;

    hideTooltip();
    activeControl = control;
    showTimer = window.setTimeout(() => {
      showTimer = null;
      const element = ensureTooltip();
      if (!element || activeControl !== control || (hideIconTooltips && isIconTooltip)) return;
      element.textContent = text;
      element.classList.toggle('is-icon-tooltip', isIconTooltip);
      element.hidden = false;
      positionTooltip(control);
    }, delay);
  };

  const hasIconControlOwner = (element: Element): boolean => {
    if (element.closest('button')) {
      return true;
    }
    const link = element.closest('a');
    return !!link && !!link.querySelector('img, svg');
  };

  const migrateTitle = (element: Element): void => {
    if (!element.hasAttribute('title')) return;

    const title = element.getAttribute('title')?.trim();
    if (!title) return;

    element.setAttribute('data-tooltip', title);
    if (hasIconControlOwner(element)) element.setAttribute('data-icon-tooltip', '');
    if (hasIconControlOwner(element) && !element.hasAttribute('aria-label') && !element.textContent?.trim()) {
      element.setAttribute('aria-label', title);
    }
    element.removeAttribute('title');
  };

  const scanTitles = (root: ParentNode): void => {
    if (root instanceof Element && root.hasAttribute('title')) {
      migrateTitle(root);
    }
    root.querySelectorAll('[title]').forEach(migrateTitle);
  };

  const observer = new MutationObserver((records) => {
    records.forEach((record) => {
      if (record.type === 'attributes' && record.target instanceof Element) {
        migrateTitle(record.target);
      }
      record.addedNodes.forEach((node) => {
        if (node instanceof Element) {
          scanTitles(node);
        }
      });
    });
  });

  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['title'],
    childList: true,
    subtree: true
  });
  scanTitles(document);

  document.addEventListener('pointerover', (event) => {
    if (event instanceof PointerEvent && event.pointerType === 'touch') return;
    const target = getTooltipTarget(event.target);
    if (target) showTooltip(target, tooltipHoverDelay);
  });

  document.addEventListener('pointerout', (event) => {
    const target = getTooltipTarget(event.target);
    if (!target || (event.relatedTarget instanceof Node && target.contains(event.relatedTarget))) return;
    if (suppressedControl === target) suppressedControl = null;
    if (activeControl === target) hideTooltip();
  });

  document.addEventListener('focusin', (event) => {
    const target = getTooltipTarget(event.target);
    if (target) showTooltip(target, 0);
  });

  document.addEventListener('focusout', (event) => {
    const target = getTooltipTarget(event.target);
    if (!target || (event.relatedTarget instanceof Node && target.contains(event.relatedTarget))) return;
    if (activeControl === target) hideTooltip();
  });

  document.addEventListener('click', (event) => {
    const target = getTooltipTarget(event.target);
    if (!target) return;
    if (event instanceof MouseEvent && event.detail > 0) {
      suppressedControl = target;
    }
    hideTooltip();
  });

  window.addEventListener('blur', hideTooltip);
  window.addEventListener('resize', hideTooltip);
  window.addEventListener('scroll', hideTooltip, true);

  const applyState = (hidden: boolean): void => {
    hideIconTooltips = hidden;
    document.documentElement.classList.toggle('hide-icon-tooltips', hidden);
    if (hidden && activeControl?.hasAttribute('data-icon-tooltip')) hideTooltip();
    toggleButton?.classList.toggle('is-active', hidden);
    toggleButton?.setAttribute('aria-pressed', String(hidden));
  };

  const toggleState = async (): Promise<void> => {
    const nextState = !hideIconTooltips;
    userChangedState = true;
    applyState(nextState);
    try {
      if (electronAPI) {
        await electronAPI.saveSettings({ hideIconTooltips: nextState });
      } else {
        await ipcRenderer?.invoke('save-settings', { hideIconTooltips: nextState });
      }
    } catch (error) {
      console.error('保存图标提示设置失败:', error);
      userChangedState = false;
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

  document.addEventListener('DOMContentLoaded', () => {
    toggleButton = document.getElementById('iconTooltipToggleBtn') as HTMLButtonElement | null;
    scanTitles(document);

    if (!toggleButton) return;
    applyState(hideIconTooltips);

    toggleButton.addEventListener('pointerdown', (event) => {
      if (event.button !== 0 || holdTimer !== null) return;
      toggleButton?.classList.add('is-holding');
      holdTimer = window.setTimeout(() => {
        holdTimer = null;
        toggleButton?.classList.remove('is-holding');
        void toggleState();
      }, 3000);
    });
    toggleButton.addEventListener('pointerup', stopHold);
    toggleButton.addEventListener('pointerleave', stopHold);
    toggleButton.addEventListener('pointercancel', stopHold);
    toggleButton.addEventListener('click', (event) => {
      if (event.detail === 0) void toggleState();
    });
  });

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
        if (!userChangedState) {
          applyState(settings.hideIconTooltips === true);
        }
      })
      .catch((error: unknown) => {
        console.error('读取图标提示设置失败:', error);
      });
  }
})();

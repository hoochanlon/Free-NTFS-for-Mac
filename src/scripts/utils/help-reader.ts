// 指南手册阅读器：目录、搜索、滚动进度、置顶
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;
  const RING_LENGTH = 100;

  type HelpReaderState = {
    abort: AbortController;
    hits: HTMLElement[];
    activeIndex: number;
  };

  let tocOpen = false;
  let searchOpen = false;
  let state: HelpReaderState | null = null;

  function applyPanelState(container: HTMLElement): void {
    const reader = container.classList.contains('help-reader')
      ? container
      : container.querySelector('.help-reader') as HTMLElement | null;
    if (!reader) return;
    reader.classList.toggle('is-toc-open', tocOpen);
    reader.classList.toggle('is-search-open', searchOpen);
    const tocToggle = container.querySelector('#helpTocToggle') as HTMLElement | null;
    const searchToggle = container.querySelector('#helpSearchToggle') as HTMLElement | null;
    tocToggle?.setAttribute('aria-pressed', String(tocOpen));
    searchToggle?.setAttribute('aria-pressed', String(searchOpen));
  }

  function t(key: string, params?: Record<string, string | number>): string {
    if (AppUtils?.I18n?.t) {
      return AppUtils.I18n.t(key, params);
    }
    return key;
  }

  function slugify(text: string, used: Set<string>): string {
    const base = text
      .trim()
      .toLowerCase()
      .replace(/[^\p{L}\p{N}]+/gu, '-')
      .replace(/^-+|-+$/g, '') || 'section';
    let id = base;
    let n = 2;
    while (used.has(id)) {
      id = `${base}-${n++}`;
    }
    used.add(id);
    return id;
  }

  function headingLabel(heading: HTMLElement): string {
    const clone = heading.cloneNode(true) as HTMLElement;
    clone.querySelectorAll('img').forEach((img) => img.remove());
    return (clone.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function clearHighlights(root: HTMLElement): void {
    root.querySelectorAll('mark.help-search-hit').forEach((mark) => {
      const parent = mark.parentNode;
      if (!parent) return;
      parent.replaceChild(document.createTextNode(mark.textContent || ''), mark);
      parent.normalize();
    });
  }

  function highlight(root: HTMLElement, query: string): HTMLElement[] {
    clearHighlights(root);
    const needle = query.trim();
    if (!needle) return [];

    const hits: HTMLElement[] = [];
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        const parent = (node as Text).parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;
        if (parent.closest('button, script, style, svg, mark.help-search-hit')) {
          return NodeFilter.FILTER_REJECT;
        }
        if (!(node.nodeValue || '').trim()) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });

    const nodes: Text[] = [];
    while (walker.nextNode()) {
      nodes.push(walker.currentNode as Text);
    }

    const lowerNeedle = needle.toLowerCase();
    for (const textNode of nodes) {
      const text = textNode.nodeValue || '';
      const lower = text.toLowerCase();
      let idx = lower.indexOf(lowerNeedle);
      if (idx < 0) continue;

      const frag = document.createDocumentFragment();
      let last = 0;
      while (idx >= 0) {
        if (idx > last) {
          frag.appendChild(document.createTextNode(text.slice(last, idx)));
        }
        const mark = document.createElement('mark');
        mark.className = 'help-search-hit';
        mark.textContent = text.slice(idx, idx + needle.length);
        hits.push(mark);
        frag.appendChild(mark);
        last = idx + needle.length;
        idx = lower.indexOf(lowerNeedle, last);
      }
      if (last < text.length) {
        frag.appendChild(document.createTextNode(text.slice(last)));
      }
      textNode.parentNode?.replaceChild(frag, textNode);
    }

    return hits;
  }

  function isInView(element: HTMLElement, scrollRoot: HTMLElement): boolean {
    const rootRect = scrollRoot.getBoundingClientRect();
    const rect = element.getBoundingClientRect();
    return rect.top >= rootRect.top + 8 && rect.bottom <= rootRect.bottom - 8;
  }

  function setActiveHit(hits: HTMLElement[], index: number): void {
    hits.forEach((hit, i) => hit.classList.toggle('is-current', i === index));
    const current = hits[index];
    if (current) {
      current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }

  function buildToc(article: HTMLElement, tocList: HTMLElement): HTMLElement[] {
    tocList.replaceChildren();
    const used = new Set<string>();
    const headings = Array.from(article.querySelectorAll<HTMLElement>('h2, h3'));
    headings.forEach((heading) => {
      const label = headingLabel(heading);
      if (!label) return;
      if (!heading.id) heading.id = slugify(label, used);
      else used.add(heading.id);

      const item = document.createElement('li');
      item.className = `help-toc-item help-toc-${heading.tagName.toLowerCase()}`;
      const link = document.createElement('a');
      link.href = `#${heading.id}`;
      link.textContent = label;
      item.appendChild(link);
      tocList.appendChild(item);
    });
    return headings;
  }

  function updateProgress(
    scrollRoot: HTMLElement,
    bar: SVGCircleElement | null,
    valueEl: HTMLElement | null,
    button: HTMLElement
  ): number {
    const max = scrollRoot.scrollHeight - scrollRoot.clientHeight;
    const percent = max <= 0 ? 0 : Math.min(100, Math.round((scrollRoot.scrollTop / max) * 100));
    if (valueEl) valueEl.textContent = String(percent);
    if (bar) bar.style.strokeDashoffset = String(RING_LENGTH - percent);
    button.classList.toggle('is-hidden', percent < 2);
    button.setAttribute('aria-label', t('help.backToTop', { percent }));
    return percent;
  }

  function updateActiveToc(scrollRoot: HTMLElement, headings: HTMLElement[], tocList: HTMLElement): void {
    if (headings.length === 0) return;
    const rootTop = scrollRoot.getBoundingClientRect().top;
    let current = headings[0];
    for (const heading of headings) {
      if (heading.getBoundingClientRect().top - rootTop <= 72) {
        current = heading;
      }
    }
    tocList.querySelectorAll('a').forEach((link) => {
      link.classList.toggle('is-active', link.getAttribute('href') === `#${current.id}`);
    });

    const activeLink = tocList.querySelector('a.is-active') as HTMLElement | null;
    const toc = tocList.closest('.help-toc') as HTMLElement | null;
    if (!activeLink || !toc) return;

    const linkRect = activeLink.getBoundingClientRect();
    const tocRect = toc.getBoundingClientRect();
    if (linkRect.top < tocRect.top + 12 || linkRect.bottom > tocRect.bottom - 12) {
      activeLink.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    }
  }

  function applyChromeTexts(container: HTMLElement): void {
    const tocTitle = container.querySelector('.help-toc-title');
    if (tocTitle) tocTitle.textContent = t('help.toc');
    const searchInput = container.querySelector('#helpSearchInput') as HTMLInputElement | null;
    if (searchInput) searchInput.placeholder = t('help.searchPlaceholder');
    const prevBtn = container.querySelector('#helpSearchPrev') as HTMLElement | null;
    if (prevBtn) prevBtn.setAttribute('aria-label', t('help.searchPrev'));
    const nextBtn = container.querySelector('#helpSearchNext') as HTMLElement | null;
    if (nextBtn) nextBtn.setAttribute('aria-label', t('help.searchNext'));
    const toc = container.querySelector('#helpToc');
    if (toc) toc.setAttribute('aria-label', t('help.toc'));
    const tocToggle = container.querySelector('#helpTocToggle');
    if (tocToggle) {
      const label = `${t('help.toggleToc')} (⌥⌘T)`;
      tocToggle.setAttribute('aria-label', label);
      tocToggle.setAttribute('title', label);
    }
    const searchToggle = container.querySelector('#helpSearchToggle');
    if (searchToggle) {
      const label = `${t('help.toggleSearch')} (⌘F)`;
      searchToggle.setAttribute('aria-label', label);
      searchToggle.setAttribute('title', label);
    }
  }

  function helpTabEl(): HTMLElement | null {
    return document.getElementById('helpTab');
  }

  function ensureHelpTab(): HTMLElement | null {
    const helpTab = helpTabEl();
    if (!helpTab) return null;
    if (!helpTab.classList.contains('active')) {
      const logContainer = document.getElementById('logContainer');
      const Tabs = (window as any).AppModules?.Tabs;
      if (Tabs?.switchToTab && logContainer) {
        Tabs.switchToTab('help', logContainer, helpTab);
      }
    }
    return helpTab;
  }

  function focusSearchInput(helpTab: HTMLElement): void {
    const input = helpTab.querySelector('#helpSearchInput') as HTMLInputElement | null;
    if (!input) return;
    input.focus();
    input.select();
  }

  function openSearch(): void {
    const helpTab = ensureHelpTab();
    if (!helpTab) return;
    const input = helpTab.querySelector('#helpSearchInput') as HTMLInputElement | null;
    const selected = window.getSelection()?.toString().trim() || '';
    if (input && selected && document.activeElement !== input) {
      input.value = selected;
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }
    searchOpen = true;
    applyPanelState(helpTab);
    focusSearchInput(helpTab);
  }

  function toggleToc(): void {
    const helpTab = helpTabEl();
    if (!helpTab) return;
    if (!helpTab.classList.contains('active')) {
      tocOpen = true;
      ensureHelpTab();
    } else {
      tocOpen = !tocOpen;
    }
    applyPanelState(helpTabEl() || helpTab);
  }

  let shortcutsInstalled = false;
  function installShortcuts(): void {
    if (shortcutsInstalled) return;
    shortcutsInstalled = true;
    window.addEventListener('keydown', (event) => {
      const cmd = event.metaKey || event.ctrlKey;
      if (!cmd || (event.metaKey && event.ctrlKey)) return;

      if (event.code === 'KeyF' && !event.shiftKey && !event.altKey) {
        event.preventDefault();
        openSearch();
        return;
      }
      if (event.code === 'KeyT' && event.altKey && !event.shiftKey) {
        event.preventDefault();
        toggleToc();
      }
    });
  }

  AppUtils.HelpReader = {
    bind(container: HTMLElement): void {
      const article = container.querySelector('#helpArticle') as HTMLElement | null;
      const tocList = container.querySelector('#helpTocList') as HTMLElement | null;
      const scrollRoot = container.querySelector('#helpArticleScroll') as HTMLElement | null;
      const searchInput = container.querySelector('#helpSearchInput') as HTMLInputElement | null;
      const searchMeta = container.querySelector('#helpSearchMeta') as HTMLElement | null;
      const prevBtn = container.querySelector('#helpSearchPrev') as HTMLButtonElement | null;
      const nextBtn = container.querySelector('#helpSearchNext') as HTMLButtonElement | null;
      const tocToggle = container.querySelector('#helpTocToggle') as HTMLButtonElement | null;
      const searchToggle = container.querySelector('#helpSearchToggle') as HTMLButtonElement | null;
      const backTop = container.querySelector('#helpBackTop') as HTMLButtonElement | null;
      const backTopValue = container.querySelector('#helpBackTopValue') as HTMLElement | null;
      const backTopBar = container.querySelector('.help-back-top-bar') as SVGCircleElement | null;

      if (!article || !tocList || !scrollRoot || !searchInput || !backTop) {
        return;
      }

      state?.abort.abort();
      const abort = new AbortController();
      const { signal } = abort;
      state = { abort, hits: [], activeIndex: -1 };

      applyChromeTexts(container);
      applyPanelState(container);
      installShortcuts();
      const headings = buildToc(article, tocList);
      if (backTopBar) {
        backTopBar.style.strokeDasharray = String(RING_LENGTH);
      }

      const syncChrome = () => {
        updateProgress(scrollRoot, backTopBar, backTopValue, backTop);
        updateActiveToc(scrollRoot, headings, tocList);
      };

      const applySearch = (cycle: number | 'refresh') => {
        const query = searchInput.value;
        const previousIndex = state!.activeIndex;
        state!.hits = highlight(article, query);
        if (state!.hits.length === 0) {
          state!.activeIndex = -1;
          if (searchMeta) {
            searchMeta.textContent = query.trim() ? t('help.searchNoResult') : '';
          }
          return;
        }

        let nextIndex = 0;
        if (cycle === 'refresh') {
          nextIndex = previousIndex >= 0 ? Math.min(previousIndex, state!.hits.length - 1) : 0;
        } else if (previousIndex < 0) {
          nextIndex = cycle < 0 ? state!.hits.length - 1 : 0;
        } else {
          nextIndex = (previousIndex + cycle + state!.hits.length) % state!.hits.length;
        }

        state!.activeIndex = nextIndex;
        if (nextIndex >= 0 && cycle !== 'refresh') {
          setActiveHit(state!.hits, nextIndex);
        } else if (nextIndex >= 0) {
          state!.hits.forEach((hit, i) => hit.classList.toggle('is-current', i === nextIndex));
        }

        if (searchMeta) {
          searchMeta.textContent = nextIndex >= 0
            ? t('help.searchCount', { current: nextIndex + 1, total: state!.hits.length })
            : t('help.searchCount', { current: 0, total: state!.hits.length });
        }
      };

      if (searchInput.value.trim()) {
        applySearch('refresh');
      } else if (searchMeta) {
        searchMeta.textContent = '';
      }

      searchInput.addEventListener('input', () => applySearch('refresh'), { signal });
      searchInput.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
          event.preventDefault();
          const current = state!.hits[state!.activeIndex];
          const stayOnCurrent = Boolean(current && !isInView(current, scrollRoot));
          applySearch(event.shiftKey ? -1 : (stayOnCurrent ? 0 : 1));
        } else if (event.key === 'Escape') {
          if (searchInput.value) {
            searchInput.value = '';
            applySearch('refresh');
          } else {
            searchOpen = false;
            applyPanelState(container);
          }
        }
      }, { signal });
      prevBtn?.addEventListener('click', () => applySearch(-1), { signal });
      nextBtn?.addEventListener('click', () => {
        const current = state!.hits[state!.activeIndex];
        applySearch(current && !isInView(current, scrollRoot) ? 0 : 1);
      }, { signal });

      tocToggle?.addEventListener('click', () => {
        tocOpen = !tocOpen;
        applyPanelState(container);
      }, { signal });
      searchToggle?.addEventListener('click', () => {
        searchOpen = !searchOpen;
        applyPanelState(container);
        if (searchOpen) {
          searchInput.focus();
          searchInput.select();
        }
      }, { signal });

      tocList.addEventListener('click', (event) => {
        const link = (event.target as HTMLElement).closest('a');
        if (!link) return;
        const id = (link.getAttribute('href') || '').slice(1);
        const target = id ? article.querySelector(`#${CSS.escape(id)}`) : null;
        if (!target) return;
        event.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, { signal });

      scrollRoot.addEventListener('scroll', syncChrome, { signal, passive: true });
      backTop.addEventListener('click', () => {
        scrollRoot.scrollTo({ top: 0, behavior: 'smooth' });
      }, { signal });

      if (searchOpen) {
        focusSearchInput(container);
      }

      syncChrome();
    },
    openSearch,
    toggleToc
  };

  installShortcuts();
})();

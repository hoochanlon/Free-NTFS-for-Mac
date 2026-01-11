// Markdown 渲染工具模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;
  const electronAPI = (window as any).electronAPI;

  // 获取翻译文本的辅助函数
  function t(key: string, params?: Record<string, string | number>): string {
    if (AppUtils && AppUtils.I18n) {
      return AppUtils.I18n.t(key, params);
    }
    return key; // 如果 i18n 未初始化，返回 key
  }

  // 根据当前语言获取文件名
  function getLocalizedFilename(filename: string): string {
    // 获取当前语言
    const currentLang = AppUtils && AppUtils.I18n ? AppUtils.I18n.getLanguage() : 'zh-CN';

    // 如果文件名是 help.md，根据语言返回对应的文件名
    if (filename === 'help.md') {
      const langMap: Record<string, string> = {
        'zh-CN': 'help.zh-CN.md',
        'zh-TW': 'help.zh-TW.md',
        'ja': 'help.ja.md',
        'en': 'help.en.md',
        'de': 'help.de.md'
      };
      return langMap[currentLang] || 'help.zh-CN.md';
    }

    // 其他文件保持原样
    return filename;
  }

  // Markdown 渲染
  AppUtils.Markdown = {
    // 加载并渲染 markdown 文件
    async loadMarkdown(filename: string, container: HTMLElement): Promise<void> {
      try {
        // 根据当前语言获取本地化的文件名
        const localizedFilename = getLocalizedFilename(filename);
        let result = await electronAPI.readMarkdown(localizedFilename);

        // 如果本地化文件加载失败，尝试加载默认文件（仅对 help.md）
        if (!result.success && filename === 'help.md' && localizedFilename !== 'help.md') {
          const fallbackResult = await electronAPI.readMarkdown('help.md');
          if (fallbackResult.success) {
            // 使用默认文件
            result = fallbackResult;
          }
        }

        if (result.success && result.content) {
          // 使用 marked 库渲染 markdown
          if (typeof (window as any).marked !== 'undefined') {
            const marked = (window as any).marked;

            // 配置 marked 选项
            marked.setOptions({
              breaks: true,
              gfm: true
            });

            // 先渲染 markdown 为 HTML
            let html = marked.parse(result.content);

            // 先处理代码块：添加复制按钮（在 help-section 处理之前，避免嵌套问题）
            // marked 库会将代码块渲染为 <pre><code>...</code></pre>
            // 匹配所有代码块，包括带语言标识的
            html = html.replace(
              /<pre><code(?: class="language-(\w+)")?>([\s\S]*?)<\/code><\/pre>/g,
              (match: string, lang: string, code: string) => {
                // marked 库已经将代码中的 HTML 转义了，我们需要解码
                // 创建一个临时元素来解码 HTML 实体
                const tempDiv = document.createElement('div');
                tempDiv.innerHTML = code;
                const decodedCode = tempDiv.textContent || tempDiv.innerText || code;

                // 转义用于 data 属性（避免在 HTML 属性中出现问题）
                const escapedForAttr = decodedCode
                  .replace(/&/g, '&amp;')
                  .replace(/</g, '&lt;')
                  .replace(/>/g, '&gt;')
                  .replace(/"/g, '&quot;')
                  .replace(/'/g, '&#39;')
                  .replace(/\n/g, '&#10;');

                const langClass = lang ? ` class="language-${lang}"` : '';
                const copyText = t('dependencies.copyCommand');
                return `<div class="code-block-wrapper"><pre><code${langClass}>${code}</code></pre><button class="code-copy-btn" data-code="${escapedForAttr}" title="${copyText}" aria-label="${copyText}"><svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M5.5 3.5H3.5C2.67 3.5 2 4.17 2 5V12.5C2 13.33 2.67 14 3.5 14H9.5C10.33 14 11 13.33 11 12.5V10.5M11 5.5H13.5C14.33 5.5 15 6.17 15 7V12.5C15 13.33 14.33 14 13.5 14H11M11 5.5V3.5C11 2.67 10.33 2 9.5 2H7M11 5.5H9.5C8.67 5.5 8 6.17 8 7V8.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg></button></div>`;
              }
            );

            // 如果是关于页面，不使用 help-section 包装，但保留标题
            if (filename === 'about.md') {
              // 保留 h1 标题，但转换为较小的样式
              html = html.replace(/<h1>([^<]+)<\/h1>/, '<h1 class="about-title">$1</h1>');
            } else {
              // 处理结构：将每个 h2 及其后续内容包裹在 help-section 中
              // 先处理 h1（第一个标题）
              html = html.replace(/<h1>([^<]+)<\/h1>/, '<div class="help-section"><h2>$1</h2>');

              // 处理 h2：关闭前一个 section，开始新 section
              html = html.replace(/<h2>([^<]+)<\/h2>/g, '</div><div class="help-section"><h2>$1</h2>');

              // 确保最后一个 section 被关闭
              if (!html.endsWith('</div>')) {
                html += '</div>';
              }

              // 如果第一个 section 没有正确开始，添加开始标签
              if (!html.startsWith('<div class="help-section">')) {
                html = '<div class="help-section">' + html;
              }
            }

            // 处理警告框：将包含 ⚠️ 的段落和后续列表包裹在 help-warning 中
            html = html.replace(
              /<p>(⚠️\s*\*\*(?:重要提示|注意事项)：\*\*[^<]*)<\/p>(\s*<ul>[\s\S]*?<\/ul>)?/g,
              (match: string, warningText: string, list?: string) => {
                const cleanText = warningText.replace(/\*\*/g, '');
                const listHtml = list ? list : '';
                return `<div class="help-warning"><p><strong>${cleanText}</strong></p>${listHtml}</div>`;
              }
            );

            // 如果是关于页面，处理链接并添加图标
            if (filename === 'about.md') {
              // 找到"作者"部分后的列表，将其转换为一行显示的图标
              html = html.replace(
                /<h2>作者<\/h2>([\s\S]*?)(<ul>[\s\S]*?<\/ul>)/g,
                (match: string, afterTitle: string, listHtml: string) => {
                  // 提取列表中的所有链接
                  const links: Array<{url: string, icon: string, alt: string}> = [];

                  // 匹配项目地址（GitHub 仓库链接）
                  const projectMatch = listHtml.match(/<a href="(https:\/\/github\.com\/[^"]+\/[^"]+)">([^<]+)<\/a>/);
                  if (projectMatch) {
                    links.push({
                      url: projectMatch[1],
                      icon: '../imgs/svg/github.svg',
                      alt: '项目地址'
                    });
                  }

                  // 匹配邮箱
                  const emailMatch = listHtml.match(/<a href="(mailto:[^"]+)">([^<]+)<\/a>/);
                  if (emailMatch) {
                    links.push({
                      url: emailMatch[1],
                      icon: '../imgs/svg/email.svg',
                      alt: '邮箱'
                    });
                  }


                  // 生成图标链接 HTML
                  const iconsHtml = links.map(link => {
                    const targetAttr = link.url.startsWith('mailto:') ? '' : ' target="_blank"';
                    return `<a href="${link.url}"${targetAttr} class="about-icon-link" title="${link.alt}"><img src="${link.icon}" alt="${link.alt}" class="about-icon" onerror="this.style.display='none'"></a>`;
                  }).join('');

                  return `<h2>作者</h2>${afterTitle}<div class="about-icons-row">${iconsHtml}</div>`;
                }
              );
            }

            container.innerHTML = `<div class="help-content">${html}</div>`;

            // 绑定代码复制按钮事件
            AppUtils.Markdown.setupCopyButtons(container);
          } else {
            // 如果没有 marked，使用简单的文本显示
            container.innerHTML = `<div class="help-content"><pre>${result.content}</pre></div>`;
            console.warn('marked 库未加载，使用纯文本显示');
          }
        } else {
          const errorMsg = t('help.loadError', { error: result.error || t('help.unknownError') });
          container.innerHTML = `<div class="help-content"><p class="error">${errorMsg}</p></div>`;
        }
      } catch (error) {
        const errorMsg = t('help.loadError', { error: error instanceof Error ? error.message : String(error) });
        container.innerHTML = `<div class="help-content"><p class="error">${errorMsg}</p></div>`;
      }
    },

    // 设置代码复制按钮
    setupCopyButtons(container: HTMLElement): void {
      const copyButtons = container.querySelectorAll('.code-copy-btn');
      copyButtons.forEach((btn: Element) => {
        btn.addEventListener('click', async (e) => {
          e.stopPropagation();
          const button = btn as HTMLElement;
          const escapedCode = button.getAttribute('data-code');
          if (escapedCode) {
            try {
              // 解码 HTML 实体
              const tempDiv = document.createElement('div');
              tempDiv.innerHTML = escapedCode
                .replace(/&#10;/g, '\n');
              const decodedCode = tempDiv.textContent || tempDiv.innerText || escapedCode;

              await navigator.clipboard.writeText(decodedCode);

              // 临时改变按钮显示已复制
              const originalHTML = button.innerHTML;
              button.innerHTML = '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M13 4L6 11L3 8" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
              button.classList.add('copied');

              setTimeout(() => {
                button.innerHTML = originalHTML;
                button.classList.remove('copied');
              }, 2000);
            } catch (err) {
              console.error('复制失败:', err);
            }
          }
        });
      });
    }
  };

})();

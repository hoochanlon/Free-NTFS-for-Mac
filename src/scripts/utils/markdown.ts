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

  // Markdown 渲染
  AppUtils.Markdown = {
    // 加载并渲染 markdown 文件
    async loadMarkdown(filename: string, container: HTMLElement): Promise<void> {
      try {
        const result = await electronAPI.readMarkdown(filename);
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

                  // 匹配 Bluesky
                  const blueskyMatch = listHtml.match(/<a href="(https:\/\/bsky\.app\/[^"]+)">([^<]+)<\/a>/);
                  if (blueskyMatch) {
                    links.push({
                      url: blueskyMatch[1],
                      icon: '../imgs/svg/bluesky.svg',
                      alt: 'Bluesky'
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
          } else {
            // 如果没有 marked，使用简单的文本显示
            container.innerHTML = `<div class="help-content"><pre>${result.content}</pre></div>`;
            console.warn('marked 库未加载，使用纯文本显示');
          }
        } else {
          container.innerHTML = `<div class="help-content"><p class="error">加载失败: ${result.error || '未知错误'}</p></div>`;
        }
      } catch (error) {
        container.innerHTML = `<div class="help-content"><p class="error">加载失败: ${error instanceof Error ? error.message : String(error)}</p></div>`;
      }
    }
  };

})();

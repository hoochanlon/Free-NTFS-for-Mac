// UI 工具函数模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 类型定义
  type StatusType = 'active' | 'error';

  // 创建全局命名空间
  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;

  // UI 工具函数
  AppUtils.UI = {
    // 显示/隐藏加载遮罩
    showLoading(loadingOverlay: HTMLElement, show: boolean = true, text?: string): void {
      if (show) {
        loadingOverlay.classList.add('visible');
        // 如果提供了文本，更新加载文本（用于刷新设备时显示"刷新中..."）
        if (text) {
          const loadingText = loadingOverlay.querySelector('p');
          if (loadingText) {
            loadingText.textContent = text;
          }
        }
      } else {
        loadingOverlay.classList.remove('visible');
      }
    },

    // 更新状态指示器
    updateStatus(
      status: StatusType,
      text: string,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): void {
      statusDot.className = 'status-dot';
      if (status === 'active') {
        statusDot.classList.add('active');
      } else if (status === 'error') {
        statusDot.classList.add('error');
      }
      statusText.textContent = text;
    },

    // 确认对话框（自定义 HTML 对话框，文字不可选中）
    async showConfirm(title: string, message: string): Promise<boolean> {
      return new Promise((resolve) => {
        // 获取翻译函数
        const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string) => key);

        // 创建遮罩层
        const overlay = document.createElement('div');
        overlay.className = 'confirm-dialog-overlay';

        // 创建对话框
        const dialog = document.createElement('div');
        dialog.className = 'confirm-dialog';

        // 创建标题
        const titleEl = document.createElement('div');
        titleEl.className = 'confirm-dialog-title';
        titleEl.textContent = title;

        // 创建内容区域
        const contentEl = document.createElement('div');
        contentEl.className = 'confirm-dialog-content';

        // 解析消息，支持换行、加粗标记和列表
        const lines = message.split('\n');
        let inList = false;
        let ul: HTMLUListElement | null = null;

        lines.forEach((line, index) => {
          const trimmedLine = line.trim();

          // 空行
          if (trimmedLine === '') {
            if (inList && ul) {
              contentEl.appendChild(ul);
              ul = null;
              inList = false;
            }
            if (index < lines.length - 1) {
              const br = document.createElement('br');
              contentEl.appendChild(br);
            }
          }
          // 列表项（以 * 开头，但不是加粗标记）
          else if (trimmedLine.startsWith('* ') && !trimmedLine.match(/^\*[^*]+\*$/)) {
            if (!inList) {
              ul = document.createElement('ul');
              inList = true;
            }
            const li = document.createElement('li');
            // 处理列表项中的加粗标记
            const itemText = trimmedLine.slice(2); // 移除 "* "
            const parts = itemText.split(/(\*[^*]+\*)/);
            parts.forEach((part) => {
              if (part.startsWith('*') && part.endsWith('*') && part.length > 2) {
                const strong = document.createElement('strong');
                strong.textContent = part.slice(1, -1);
                li.appendChild(strong);
              } else if (part.trim() !== '') {
                const text = document.createTextNode(part);
                li.appendChild(text);
              }
            });
            ul!.appendChild(li);
          }
          // 普通文本
          else {
            if (inList && ul) {
              contentEl.appendChild(ul);
              ul = null;
              inList = false;
            }
            const p = document.createElement('p');
            // 处理加粗标记：*文本*（单个星号，但不是列表项）
            const parts = trimmedLine.split(/(\*[^*]+\*)/);
            parts.forEach((part) => {
              if (part.startsWith('*') && part.endsWith('*') && part.length > 2) {
                const strong = document.createElement('strong');
                strong.textContent = part.slice(1, -1);
                p.appendChild(strong);
              } else if (part.trim() !== '') {
                const text = document.createTextNode(part);
                p.appendChild(text);
              }
            });
            contentEl.appendChild(p);
          }
        });

        // 如果最后还在列表中，添加列表
        if (inList && ul) {
          contentEl.appendChild(ul);
        }

        // 创建按钮容器
        const buttonsEl = document.createElement('div');
        buttonsEl.className = 'confirm-dialog-buttons';

        // 取消按钮
        const cancelBtn = document.createElement('button');
        cancelBtn.className = 'btn btn-secondary';
        cancelBtn.textContent = t('dialog.cancel') || '取消';
        cancelBtn.addEventListener('click', () => {
          document.body.removeChild(overlay);
          resolve(false);
        });

        // 确定按钮
        const confirmBtn = document.createElement('button');
        confirmBtn.className = 'btn btn-primary';
        confirmBtn.textContent = t('dialog.confirm') || '确定';
        confirmBtn.addEventListener('click', () => {
          document.body.removeChild(overlay);
          resolve(true);
        });

        // 组装对话框
        buttonsEl.appendChild(cancelBtn);
        buttonsEl.appendChild(confirmBtn);
        dialog.appendChild(titleEl);
        dialog.appendChild(contentEl);
        dialog.appendChild(buttonsEl);
        overlay.appendChild(dialog);

        // 添加到页面
        document.body.appendChild(overlay);

        // 点击遮罩层关闭对话框
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            document.body.removeChild(overlay);
            resolve(false);
          }
        });

        // ESC 键关闭
        const handleKeyDown = (e: KeyboardEvent) => {
          if (e.key === 'Escape') {
            document.body.removeChild(overlay);
            document.removeEventListener('keydown', handleKeyDown);
            resolve(false);
          }
        };
        document.addEventListener('keydown', handleKeyDown);

        // 聚焦到确定按钮
        setTimeout(() => {
          confirmBtn.focus();
        }, 100);
      });
    },

    // 消息对话框（自定义 HTML 对话框，文字不可选中）
    async showMessage(title: string, message: string, type: 'info' | 'warning' | 'error' = 'info'): Promise<void> {
      return new Promise((resolve) => {
        // 获取翻译函数
        const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string) => key);

        // 创建遮罩层
        const overlay = document.createElement('div');
        overlay.className = 'confirm-dialog-overlay';

        // 创建对话框
        const dialog = document.createElement('div');
        dialog.className = 'confirm-dialog';

        // 创建标题
        const titleEl = document.createElement('div');
        titleEl.className = 'confirm-dialog-title';
        titleEl.textContent = title;

        // 创建内容区域
        const contentEl = document.createElement('div');
        contentEl.className = 'confirm-dialog-content';
        contentEl.textContent = message;

        // 创建按钮容器
        const buttonsEl = document.createElement('div');
        buttonsEl.className = 'confirm-dialog-buttons';

        // 确定按钮
        const okBtn = document.createElement('button');
        okBtn.className = 'btn btn-primary';
        okBtn.textContent = t('dialog.ok') || '确定';
        okBtn.addEventListener('click', () => {
          document.body.removeChild(overlay);
          resolve();
        });

        buttonsEl.appendChild(okBtn);

        dialog.appendChild(titleEl);
        dialog.appendChild(contentEl);
        dialog.appendChild(buttonsEl);
        overlay.appendChild(dialog);
        document.body.appendChild(overlay);

        // 点击遮罩层关闭对话框
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            document.body.removeChild(overlay);
            resolve();
          }
        });

        // ESC 键关闭
        const handleKeyDown = (e: KeyboardEvent) => {
          if (e.key === 'Escape') {
            document.body.removeChild(overlay);
            document.removeEventListener('keydown', handleKeyDown);
            resolve();
          }
        };
        document.addEventListener('keydown', handleKeyDown);

        // 聚焦到确定按钮
        setTimeout(() => {
          okBtn.focus();
        }, 100);
      });
    },

    // 关于对话框（自定义 HTML 对话框）
    async showAbout(): Promise<void> {
      return new Promise((resolve) => {
        // 获取翻译函数
        const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string) => key);

        // 创建遮罩层
        const overlay = document.createElement('div');
        overlay.className = 'confirm-dialog-overlay';

        // 创建对话框
        const dialog = document.createElement('div');
        dialog.className = 'confirm-dialog about-dialog';

        // 创建标题
        const titleEl = document.createElement('div');
        titleEl.className = 'confirm-dialog-title';
        titleEl.textContent = t('about.title') || '关于';

        // 创建内容区域
        const contentEl = document.createElement('div');
        contentEl.className = 'confirm-dialog-content about-dialog-content';

        // 创建关于内容
        const aboutContent = document.createElement('div');
        aboutContent.className = 'about-content';

        // 标题
        const h1 = document.createElement('h1');
        h1.className = 'about-title';
        h1.textContent = 'Nigate';
        aboutContent.appendChild(h1);

        // 描述
        const p1 = document.createElement('p');
        p1.textContent = t('about.description') || 'Nigate 是基于 ntfs-3g 驱动制作的免费读写 NTFS 格式存储设备工具。';
        aboutContent.appendChild(p1);

        // 软件信息标题
        const h2 = document.createElement('h2');
        h2.textContent = t('about.softwareInfo') || '软件信息';
        aboutContent.appendChild(h2);

        // 软件信息列表
        const ul = document.createElement('ul');
        const items = [
          { label: t('about.author') || '作者：', value: 'Hoochanlon' },
          { label: t('about.version') || '软件版本：', value: 'Nigate v1.3.5' },
          { label: t('about.technology') || '基于技术：', value: 'Electron + Shell + TypeScript + Stylus' }
        ];
        items.forEach(item => {
          const li = document.createElement('li');
          const strong = document.createElement('strong');
          strong.textContent = item.label;
          li.appendChild(strong);
          li.appendChild(document.createTextNode(' ' + item.value));
          ul.appendChild(li);
        });
        aboutContent.appendChild(ul);

        // 图标行
        const iconsRow = document.createElement('div');
        iconsRow.className = 'about-icons-row';

        const links = [
          { href: 'https://github.com/hoochanlon/Free-NTFS-for-Mac', icon: '../imgs/svg/github.svg', title: t('about.projectLink') || '项目地址' },
          { href: 'mailto:hoochanlon@outlook.com', icon: '../imgs/svg/email.svg', title: t('about.email') || '邮箱' }
        ];

        links.forEach(linkData => {
          const link = document.createElement('a');
          link.href = linkData.href;
          link.className = 'about-icon-link';
          // 移除 title 属性，不需要悬浮提示
          if (linkData.href.startsWith('http')) {
            link.target = '_blank';
          }

          const img = document.createElement('img');
          img.src = linkData.icon;
          img.alt = ''; // 移除 alt 属性，不需要悬浮提示
          img.className = 'about-icon';
          img.onerror = function() {
            (this as HTMLImageElement).style.display = 'none';
          };

          link.appendChild(img);
          iconsRow.appendChild(link);

          // 处理链接点击
          link.addEventListener('click', (e) => {
            e.preventDefault();
            const href = link.getAttribute('href');
            if (href) {
              if ((window as any).electronAPI && (window as any).electronAPI.openExternal) {
                (window as any).electronAPI.openExternal(href);
              } else {
                window.open(href, '_blank');
              }
            }
          });
        });

        aboutContent.appendChild(iconsRow);
        contentEl.appendChild(aboutContent);

        // 创建按钮容器
        const buttonsEl = document.createElement('div');
        buttonsEl.className = 'confirm-dialog-buttons';

        // 确定按钮
        const okBtn = document.createElement('button');
        okBtn.className = 'btn btn-primary';
        okBtn.textContent = t('about.ok') || '确定';
        okBtn.addEventListener('click', () => {
          document.body.removeChild(overlay);
          resolve();
        });

        buttonsEl.appendChild(okBtn);

        dialog.appendChild(titleEl);
        dialog.appendChild(contentEl);
        dialog.appendChild(buttonsEl);
        overlay.appendChild(dialog);
        document.body.appendChild(overlay);

        // 点击遮罩层关闭对话框
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            document.body.removeChild(overlay);
            resolve();
          }
        });

        // ESC 键关闭
        const handleKeyDown = (e: KeyboardEvent) => {
          if (e.key === 'Escape') {
            document.body.removeChild(overlay);
            document.removeEventListener('keydown', handleKeyDown);
            resolve();
          }
        };
        document.addEventListener('keydown', handleKeyDown);

        // 聚焦到确定按钮
        setTimeout(() => {
          okBtn.focus();
        }, 100);
      });
    }
  };

})();

// 依赖信息和安装指引
const DEPENDENCY_INFO = {
  swift: {
    name: 'Swift (Xcode Command Line Tools)',
    description: 'Apple 官方开发工具，提供 Swift 编译器和基础开发库',
    installCommand: 'xcode-select --install',
    installGuide: '在终端运行上述命令，会弹出安装窗口，按照提示完成安装。安装过程可能需要几分钟到几十分钟，请耐心等待。'
  },
  brew: {
    name: 'Homebrew',
    description: 'macOS 的包管理器，用于安装和管理软件包',
    installCommand: '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
    installGuide: '在终端运行上述命令，按照提示完成安装。如果网络较慢，可以使用国内镜像源。'
  },
  macfuse: {
    name: 'MacFUSE',
    description: '文件系统用户空间框架，ntfs-3g 需要此依赖',
    installCommand: 'brew install --cask macfuse',
    installGuide: '需要先安装 Homebrew。在终端运行上述命令即可安装。'
  },
  ntfs3g: {
    name: 'ntfs-3g',
    description: 'NTFS 文件系统驱动，提供 NTFS 读写支持',
    installCommand: 'brew tap gromgit/homebrew-fuse && brew install ntfs-3g-mac',
    installGuide: '需要先安装 Homebrew 和 MacFUSE。在终端运行上述命令即可安装。'
  }
};

// 依赖检查模块
export function renderDependencies(depsList: HTMLElement, dependencies: any, installGuideSection: HTMLElement): void {
  if (!dependencies) return;

  depsList.innerHTML = '';
  installGuideSection.innerHTML = '';

  const deps = [
    { key: 'swift', name: DEPENDENCY_INFO.swift.name, status: dependencies.swift },
    { key: 'brew', name: DEPENDENCY_INFO.brew.name, status: dependencies.brew },
    { key: 'macfuse', name: DEPENDENCY_INFO.macfuse.name, status: dependencies.macfuse },
    { key: 'ntfs3g', name: DEPENDENCY_INFO.ntfs3g.name, status: dependencies.ntfs3g }
  ];

  const missingDeps: Array<{ key: string; name: string }> = [];

  deps.forEach((dep, index) => {
    const item = document.createElement('div');
    item.className = 'dep-item';
    item.innerHTML = `
      <span class="dep-name"><span class="dep-number ${dep.status ? 'installed' : 'missing'}">${index + 1}</span> ${dep.name}</span>
      <span class="dep-status ${dep.status ? 'installed' : 'missing'}">
        ${dep.status ? '✓ 已安装' : '✗ 未安装'}
      </span>
    `;
    depsList.appendChild(item);

    if (!dep.status) {
      missingDeps.push({ key: dep.key, name: dep.name });
    }
  });

  // 如果有缺失的依赖，显示安装指引
  if (missingDeps.length > 0) {
    installGuideSection.style.display = 'block';
    missingDeps.forEach((dep) => {
      const info = DEPENDENCY_INFO[dep.key as keyof typeof DEPENDENCY_INFO];
      const guideCard = document.createElement('div');
      guideCard.className = 'install-guide-card';
      guideCard.innerHTML = `
        <div class="guide-header">
          <h3>${info.name}</h3>
          <span class="guide-status missing">未安装</span>
        </div>
        <p class="guide-description">${info.description}</p>
        <div class="guide-command">
          <label>安装命令：</label>
          <div class="command-box">
            <code class="command-text">${info.installCommand}</code>
            <button class="btn-copy" data-command="${info.installCommand.replace(/"/g, '&quot;')}" title="复制命令">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M5.5 3.5H3.5C2.67 3.5 2 4.17 2 5V12.5C2 13.33 2.67 14 3.5 14H9.5C10.33 14 11 13.33 11 12.5V10.5M11 5.5H13.5C14.33 5.5 15 6.17 15 7V12.5C15 13.33 14.33 14 13.5 14H11M11 5.5V3.5C11 2.67 10.33 2 9.5 2H7M11 5.5H9.5C8.67 5.5 8 6.17 8 7V8.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
              </svg>
            </button>
          </div>
        </div>
        <p class="guide-instructions">${info.installGuide}</p>
      `;
      installGuideSection.appendChild(guideCard);
    });
  } else {
    installGuideSection.style.display = 'none';
  }
}

export async function checkDependencies(
  electronAPI: any,
  depsList: HTMLElement,
  installGuideSection: HTMLElement,
  updateStatusFn: (status: 'active' | 'error', text: string) => void,
  addLogFn: (message: string, type?: 'info' | 'success' | 'error' | 'warning') => void,
  showLoadingFn: (show: boolean) => void
): Promise<any> {
  try {
    showLoadingFn(true);
    updateStatusFn('active', '正在检查...');

    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(() => reject(new Error('检查超时，请重试')), 15000);
    });

    const dependencies = await Promise.race([
      electronAPI.checkDependencies(),
      timeoutPromise
    ]);

    renderDependencies(depsList, dependencies, installGuideSection);

    const allInstalled = dependencies.swift && dependencies.brew &&
                        dependencies.macfuse && dependencies.ntfs3g;

    if (allInstalled) {
      updateStatusFn('active', '系统就绪');
      addLogFn('所有依赖已安装', 'success');
    } else {
      updateStatusFn('error', '缺少依赖');
      addLogFn('检测到缺失的依赖，请查看下方安装指引', 'warning');
    }

    return dependencies;
  } catch (error) {
    updateStatusFn('error', '检查失败');
    const errorMessage = error instanceof Error ? error.message : String(error);
    addLogFn(`检查依赖失败: ${errorMessage}`, 'error');
    console.error('检查依赖错误:', error);
    return null;
  } finally {
    showLoadingFn(false);
  }
}

// 复制命令到剪贴板
export function setupCopyButtons(installGuideSection: HTMLElement): void {
  installGuideSection.addEventListener('click', (e) => {
    const target = e.target as HTMLElement;
    const copyBtn = target.closest('.btn-copy') as HTMLElement;
    if (copyBtn) {
      const command = copyBtn.getAttribute('data-command');
      if (command) {
        navigator.clipboard.writeText(command).then(() => {
          // 临时改变按钮文本显示已复制
          const originalHTML = copyBtn.innerHTML;
          copyBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M13 4L6 11L3 8" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
          copyBtn.style.color = 'var(--success)';
          setTimeout(() => {
            copyBtn.innerHTML = originalHTML;
            copyBtn.style.color = '';
          }, 2000);
        }).catch((err) => {
          console.error('复制失败:', err);
        });
      }
    }
  });
}


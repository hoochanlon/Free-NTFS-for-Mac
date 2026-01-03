// 系统依赖页面脚本
(function() {
  'use strict';

  // 检查 electronAPI 是否已存在
  if (typeof window.electronAPI === 'undefined') {
    console.error('electronAPI 未定义，请检查 preload.js 是否正确加载');
    window.electronAPI = {} as any;
  }

  const electronAPI = window.electronAPI;

  // DOM 元素
  const depsList = document.getElementById('depsList')!;
  const checkDepsBtn = document.getElementById('checkDepsBtn') as HTMLButtonElement;
  const installSection = document.getElementById('installSection') as HTMLElement;
  const installDepsBtn = document.getElementById('installDepsBtn') as HTMLButtonElement;
  const installLog = document.getElementById('installLog') as HTMLElement;
  const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;
  const closeBtn = document.getElementById('closeBtn') as HTMLButtonElement;

  // 状态管理
  let dependencies: any = null;

  type LogType = 'info' | 'success' | 'error' | 'warning';

  // 添加日志
  function addLog(message: string, type: LogType = 'info'): void {
    const time = new Date().toLocaleTimeString('zh-CN');
    const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
    logs.push({ time, message, type });
    // 限制日志数量
    if (logs.length > 1000) {
      logs.shift();
    }
    localStorage.setItem('appLogs', JSON.stringify(logs));
  }

  // 显示/隐藏加载遮罩
  function showLoading(show: boolean = true): void {
    if (show) {
      loadingOverlay.classList.add('visible');
    } else {
      loadingOverlay.classList.remove('visible');
    }
  }

  // 检查依赖
  async function checkDependencies(): Promise<void> {
    try {
      showLoading(true);
      addLog('开始检查系统依赖...', 'info');

      const timeoutPromise = new Promise<never>((_, reject) => {
        setTimeout(() => reject(new Error('检查超时，请重试')), 15000);
      });

      dependencies = await Promise.race([
        electronAPI.checkDependencies(),
        timeoutPromise
      ]);

      renderDependencies();

      const allInstalled = dependencies.swift && dependencies.brew &&
                          dependencies.macfuse && dependencies.ntfs3g &&
                          dependencies.macosVersion;

      if (allInstalled) {
        installSection.classList.remove('visible');
        addLog('所有依赖已安装', 'success');
      } else {
        installSection.classList.add('visible');
        addLog('检测到缺失的依赖，请点击安装', 'warning');
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`检查依赖失败: ${errorMessage}`, 'error');
      console.error('检查依赖错误:', error);
    } finally {
      showLoading(false);
    }
  }

  // 渲染依赖列表
  function renderDependencies(): void {
    if (!dependencies) return;

    depsList.innerHTML = '';

    const deps = [
      { name: 'Swift (Xcode Command Line Tools)', status: dependencies.swift },
      { name: 'Homebrew', status: dependencies.brew },
      { name: 'ntfs-3g', status: dependencies.ntfs3g },
      { name: 'MacFUSE', status: dependencies.macfuse },
      {
        name: `macOS 版本 (${dependencies.macosVersionString || '未知'})`,
        status: dependencies.macosVersion
      }
    ];

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
    });
  }

  // 已移除自动安装功能，改为仅检测和提供安装指引
  // async function installDependencies(): Promise<void> {
  //   if (!confirm('这将安装缺失的系统依赖，可能需要较长时间。是否继续？')) {
  //     return;
  //   }

  //   try {
  //     showLoading(true);
  //     installDepsBtn.disabled = true;
  //     installLog.textContent = '开始安装依赖...\n';
  //     addLog('开始安装系统依赖...', 'info');

  //     const result = await electronAPI.installDependencies();
  //     if (result.success && result.result) {
  //       installLog.textContent += result.result;
  //       addLog('依赖安装完成，请重新检查依赖状态', 'success');

  //       setTimeout(() => {
  //         checkDependencies();
  //       }, 3000);
  //     } else {
  //       throw new Error(result.error || '安装失败');
  //     }
  //   } catch (error) {
  //     const errorMessage = error instanceof Error ? error.message : String(error);
  //     installLog.textContent += `\n错误: ${errorMessage}`;
  //     addLog(`安装依赖失败: ${errorMessage}`, 'error');
  //   } finally {
  //     showLoading(false);
  //     installDepsBtn.disabled = false;
  //   }
  // }

  // 关闭窗口
  async function closeWindow(): Promise<void> {
    try {
      if (electronAPI.closeModuleWindow) {
        await electronAPI.closeModuleWindow();
      } else {
        window.close();
      }
    } catch (error) {
      window.close();
    }
  }

  // 初始化
  document.addEventListener('DOMContentLoaded', () => {
    checkDepsBtn.addEventListener('click', checkDependencies);
    // 已移除自动安装功能
    // installDepsBtn.addEventListener('click', installDependencies);
    closeBtn.addEventListener('click', closeWindow);

    // 自动检查一次
    checkDependencies();
  });
})();

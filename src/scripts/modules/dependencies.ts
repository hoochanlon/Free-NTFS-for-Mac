// 依赖管理模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;
  const electronAPI = (window as any).electronAPI;
  const AppUtils = (window as any).AppUtils;

  // 依赖管理
  AppModules.Dependencies = {
    // 依赖数据
    dependencies: null as any,

    // 检查依赖
    async checkDependencies(
      depsList: HTMLElement,
      installSection: HTMLElement,
      loadingOverlay: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.UI.updateStatus('active', '正在检查...', statusDot, statusText);

        // 添加超时保护
        const timeoutPromise = new Promise<never>((_, reject) => {
          setTimeout(() => reject(new Error('检查超时，请重试')), 15000);
        });

        AppModules.Dependencies.dependencies = await Promise.race([
          electronAPI.checkDependencies(),
          timeoutPromise
        ]);

        AppModules.Dependencies.renderDependencies(depsList);

        const allInstalled = AppModules.Dependencies.dependencies.swift &&
                            AppModules.Dependencies.dependencies.brew &&
                            AppModules.Dependencies.dependencies.macfuse &&
                            AppModules.Dependencies.dependencies.ntfs3g;

        if (allInstalled) {
          AppUtils.UI.updateStatus('active', '系统就绪', statusDot, statusText);
          installSection.classList.remove('visible');
          AppUtils.Logs.addLog('所有依赖已安装', 'success');
        } else {
          AppUtils.UI.updateStatus('error', '缺少依赖', statusDot, statusText);
          installSection.classList.add('visible');
          AppUtils.Logs.addLog('检测到缺失的依赖，请点击安装', 'warning');
        }
      } catch (error) {
        AppUtils.UI.updateStatus('error', '检查失败', statusDot, statusText);
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`检查依赖失败: ${errorMessage}`, 'error');
        console.error('检查依赖错误:', error);
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    },

    // 渲染依赖列表
    renderDependencies(depsList: HTMLElement): void {
      if (!AppModules.Dependencies.dependencies) return;

      depsList.innerHTML = '';

      const deps = [
        { name: 'Swift (Xcode Command Line Tools)', status: AppModules.Dependencies.dependencies.swift },
        { name: 'Homebrew', status: AppModules.Dependencies.dependencies.brew },
        { name: 'MacFUSE', status: AppModules.Dependencies.dependencies.macfuse },
        { name: 'ntfs-3g', status: AppModules.Dependencies.dependencies.ntfs3g }
      ];

      deps.forEach(dep => {
        const item = document.createElement('div');
        item.className = 'dep-item';
        item.innerHTML = `
          <span class="dep-name">${dep.name}</span>
          <span class="dep-status ${dep.status ? 'installed' : 'missing'}">
            ${dep.status ? '✓ 已安装' : '✗ 未安装'}
          </span>
        `;
        depsList.appendChild(item);
      });
    },

    // 安装依赖
    async installDependencies(
      installDepsBtn: HTMLButtonElement,
      installLog: HTMLElement,
      installSection: HTMLElement,
      depsList: HTMLElement,
      loadingOverlay: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      if (!confirm('这将安装缺失的系统依赖，可能需要较长时间。是否继续？')) {
        return;
      }

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        installDepsBtn.disabled = true;
        installLog.textContent = '开始安装依赖...\n';

        const result = await electronAPI.installDependencies();
        if (result.success && result.result) {
          installLog.textContent += result.result;
          AppUtils.Logs.addLog('依赖安装完成，请重新检查依赖状态', 'success');

          // 等待几秒后重新检查
          setTimeout(() => {
            AppModules.Dependencies.checkDependencies(
              depsList,
              installSection,
              loadingOverlay,
              statusDot,
              statusText
            );
          }, 3000);
        } else {
          throw new Error(result.error || '安装失败');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        installLog.textContent += `\n错误: ${errorMessage}`;
        AppUtils.Logs.addLog(`安装依赖失败: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
        installDepsBtn.disabled = false;
      }
    }
  };

})();

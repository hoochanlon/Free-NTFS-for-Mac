// 依赖检查模块
export function renderDependencies(depsList: HTMLElement, dependencies: any): void {
  if (!dependencies) return;

  depsList.innerHTML = '';

  const deps = [
    { name: 'Swift (Xcode Command Line Tools)', status: dependencies.swift },
    { name: 'Homebrew', status: dependencies.brew },
    { name: 'ntfs-3g', status: dependencies.ntfs3g },
    { name: 'MacFUSE', status: dependencies.macfuse }
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

export async function checkDependencies(
  electronAPI: any,
  depsList: HTMLElement,
  installSection: HTMLElement,
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

    renderDependencies(depsList, dependencies);

    const allInstalled = dependencies.swift && dependencies.brew &&
                        dependencies.macfuse && dependencies.ntfs3g;

    if (allInstalled) {
      updateStatusFn('active', '系统就绪');
      installSection.style.display = 'none';
      addLogFn('所有依赖已安装', 'success');
    } else {
      updateStatusFn('error', '缺少依赖');
      installSection.style.display = 'block';
      addLogFn('检测到缺失的依赖，请点击安装', 'warning');
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

export async function installDependencies(
  electronAPI: any,
  installDepsBtn: HTMLButtonElement,
  installLog: HTMLElement,
  addLogFn: (message: string, type?: 'info' | 'success' | 'error' | 'warning') => void,
  showLoadingFn: (show: boolean) => void,
  checkDepsFn: () => void
): Promise<void> {
  if (!confirm('这将安装缺失的系统依赖，可能需要较长时间。是否继续？')) {
    return;
  }

  try {
    showLoadingFn(true);
    installDepsBtn.disabled = true;
    installLog.textContent = '开始安装依赖...\n';

    const result = await electronAPI.installDependencies();
    if (result.success && result.result) {
      installLog.textContent += result.result;
      addLogFn('依赖安装完成，请重新检查依赖状态', 'success');

      setTimeout(() => {
        checkDepsFn();
      }, 3000);
    } else {
      throw new Error(result.error || '安装失败');
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    installLog.textContent += `\n错误: ${errorMessage}`;
    addLogFn(`安装依赖失败: ${errorMessage}`, 'error');
  } finally {
    showLoadingFn(false);
    installDepsBtn.disabled = false;
  }
}

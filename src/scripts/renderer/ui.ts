// UI 工具函数模块
type LogType = 'info' | 'success' | 'error' | 'warning';
type StatusType = 'active' | 'error';

export function addLog(logContainer: HTMLElement, message: string, type: LogType = 'info'): void {
  const time = new Date().toLocaleTimeString('zh-CN');
  const logEntry = document.createElement('div');
  logEntry.className = `log-entry ${type}`;
  logEntry.innerHTML = `<span class="log-time">[${time}]</span>${message}`;

  if (logContainer.querySelector('.log-empty')) {
    logContainer.innerHTML = '';
  }

  logContainer.appendChild(logEntry);
  logContainer.scrollTop = logContainer.scrollHeight;
}

export function clearLog(logContainer: HTMLElement): void {
  logContainer.innerHTML = '<div class="log-empty">暂无日志</div>';
}

export function showLoading(loadingOverlay: HTMLElement, show: boolean = true): void {
  loadingOverlay.style.display = show ? 'flex' : 'none';
}

export function updateStatus(
  statusDot: HTMLElement,
  statusText: HTMLElement,
  status: StatusType,
  text: string
): void {
  statusDot.className = 'status-dot';
  if (status === 'active') {
    statusDot.classList.add('active');
  } else if (status === 'error') {
    statusDot.classList.add('error');
  }
  statusText.textContent = text;
}

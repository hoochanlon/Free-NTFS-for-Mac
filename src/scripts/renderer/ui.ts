// UI 工具函数模块
type StatusType = 'active' | 'error';

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

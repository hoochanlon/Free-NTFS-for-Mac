// 主题管理模块
export function initTheme(): void {
  const savedTheme = (localStorage.getItem('theme') || 'dark') as 'light' | 'dark';
  setTheme(savedTheme);
}

export function setTheme(theme: 'light' | 'dark'): void {
  if (theme === 'light') {
    document.body.classList.add('light-theme');
    const themeIcon = document.getElementById('themeIcon');
    if (themeIcon) themeIcon.textContent = '☀️';
    localStorage.setItem('theme', 'light');
  } else {
    document.body.classList.remove('light-theme');
    const themeIcon = document.getElementById('themeIcon');
    if (themeIcon) themeIcon.textContent = '🌙';
    localStorage.setItem('theme', 'dark');
  }
}

export function toggleTheme(): void {
  const currentTheme = document.body.classList.contains('light-theme') ? 'light' : 'dark';
  setTheme(currentTheme === 'light' ? 'dark' : 'light');
}

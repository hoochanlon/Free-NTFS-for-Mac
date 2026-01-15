// Electron API 类型定义
export interface AppSettings {
  savePassword: boolean;
  autoMount: boolean;
  startupTab: 'dependencies' | 'devices' | 'logs' | 'help';
  enableLogs: boolean;
  language: 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'system';
  windowWidth: number;
  windowHeight: number;
  trayMode: boolean;
  autoStart: boolean;
}

export interface ElectronAPI {
  checkDependencies: () => Promise<Dependencies>;
  getNTFSDevices: () => Promise<NTFSDevice[]>;
  mountDevice: (device: NTFSDevice) => Promise<OperationResult>;
  unmountDevice: (device: NTFSDevice) => Promise<OperationResult>;
  restoreToReadOnly: (device: NTFSDevice) => Promise<OperationResult>;
  ejectDevice: (device: NTFSDevice) => Promise<OperationResult>;
  // 已移除自动安装功能
  // installDependencies: () => Promise<OperationResult>;
  requestSudoPassword: () => Promise<void>;
  onDeviceUpdate: (callback: (data: any) => void) => void;
  // 混合检测相关
  startHybridDetection: (callback: (devices: NTFSDevice[]) => void) => Promise<void>;
  stopHybridDetection: () => Promise<void>;
  updateWindowVisibility: (isVisible: boolean) => Promise<void>;
  getDetectionMode: () => Promise<'event-driven' | 'polling' | 'not-started'>;
  checkEventDrivenAvailable: () => Promise<boolean>;
  openLogsWindow: () => Promise<void>;
  closeLogsWindow: () => Promise<void>;
  openModuleWindow: (moduleName: string) => Promise<void>;
  closeModuleWindow: () => Promise<void>;
  readMarkdown: (filename: string) => Promise<{ success: boolean; content?: string; error?: string }>;
  openAboutWindow: () => Promise<void>;
  openExternal: (url: string) => Promise<void>;
  broadcastThemeChange: (isLightMode: boolean) => Promise<void>;
  onThemeChange: (callback: (isLightMode: boolean) => void) => void;
  getSettings: () => Promise<AppSettings>;
  saveSettings: (settings: Partial<AppSettings>) => Promise<{ success: boolean }>;
  onSettingsChange: (callback: (settings: Partial<AppSettings>) => void) => void;
  getWindowSizeConfig: () => Promise<{
    defaultWidth: number;
    defaultHeight: number;
    minWidth: number;
    minHeight: number;
    minWidthLimit: number;
    maxWidthLimit: number;
    minHeightLimit: number;
    maxHeightLimit: number;
  }>;
  hasSavedPassword: () => Promise<boolean>;
  deleteSavedPassword: () => Promise<{ success: boolean }>;
  exportLogs: (content: string) => Promise<{ success: boolean; path?: string; error?: string }>;
  switchToTab: (tabName: string) => Promise<void>;
  onSwitchTab: (callback: (tabName: string) => void) => void;
  onShowAboutDialog: (callback: () => void) => void;
  onTrayAction: (callback: (action: string) => void) => void;
  onTrayDeviceAction: (callback: (data: { action: string; device: any }) => void) => void;
  showConfirmDialog: (title: string, message: string) => Promise<boolean>;
  showMessageDialog: (title: string, message: string, type?: 'info' | 'warning' | 'error') => Promise<void>;
  readLogsFile: () => Promise<{ success: boolean; content?: string; error?: string }>;
  writeLogsFile: (content: string) => Promise<{ success: boolean; error?: string }>;
  showMainWindow: () => Promise<void>;
  adjustTrayWindowHeightByDeviceCount: (deviceCount: number) => Promise<void>;
  quitApp: () => Promise<void>;
  openQuitWindow: () => Promise<void>;
  closeQuitWindow: () => Promise<void>;
}

export interface Dependencies {
  swift: boolean;
  brew: boolean;
  macfuse: boolean;
  ntfs3g: boolean;
  ntfs3gPath: string | null;
  macosVersion: boolean;
  macosVersionString?: string;
  fswatch?: boolean; // fswatch 用于事件驱动检测（可选）
}

export interface NTFSDevice {
  disk: string;
  devicePath: string;
  volume: string;
  volumeName: string;
  isReadOnly: boolean;
  options: string;
  isMounted: boolean;
  isUnmounted?: boolean; // 标记设备是否已卸载但仍在系统中
  capacity?: {
    total: number; // 总容量（字节）
    used: number; // 已使用容量（字节）
    available: number; // 可用容量（字节）
  };
}

export interface OperationResult {
  success: boolean;
  result?: string;
  error?: string;
}

declare global {
  interface Window {
    electronAPI: ElectronAPI;
    __rendererInitialized?: boolean;
    AppUtils?: any;
    AppModules?: any;
  }
}

// 窗口尺寸配置常量（统一管理所有窗口的尺寸配置）
export const WINDOW_SIZE_CONFIG = {
  // 主窗口默认尺寸
  defaultWidth: 900,
  defaultHeight: 680,
  // 主窗口最小尺寸
  minWidth: 900,
  minHeight: 680,
  // 主窗口尺寸范围（用于设置页面验证）
  minWidthLimit: 840,
  maxWidthLimit: 2000,
  minHeightLimit: 660,
  maxHeightLimit: 2000
} as const;

// 模块窗口配置
export const MODULE_WINDOW_CONFIG = {
  width: 600,
  height: 450,
  minWidth: 500,
  minHeight: 400
};

// 日志窗口配置
export const LOGS_WINDOW_CONFIG = {
  width: 800,
  height: 600,
  minWidth: 600,
  minHeight: 400
};

// 托盘设备窗口配置
export const TRAY_DEVICES_WINDOW_CONFIG = {
  minWidth: 350,
  minHeight: 256, // 1 个设备时的高度作为最小高度
  maxWidth: 430,
  maxHeight: 745,
  defaultWidth: 350,
  defaultHeight: 256,
  // 根据设备数量的默认高度（用户手动拉伸后不再强制套用）
  heightFor1Device: 256,
  heightFor2Devices: 410
};

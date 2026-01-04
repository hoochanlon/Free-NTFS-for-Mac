import { nativeImage, app } from 'electron';
import * as path from 'path';
import * as fs from 'fs';

/**
 * 创建设备图标（使用高分辨率图标，避免模糊）
 * 注意：Electron 的 Menu API 不支持直接使用 SVG，所以需要转换为 PNG
 */
export function createDeviceIcon(): Electron.NativeImage | undefined {
  try {
    const appPath = app.getAppPath();

    // 优先尝试高分辨率 PNG（@2x，用于 Retina 显示，64x64）
    const driveIconPng2xPath = path.join(appPath, 'src', 'imgs', 'ico', 'drive@2x.png');
    if (fs.existsSync(driveIconPng2xPath)) {
      try {
        const image = nativeImage.createFromPath(driveIconPng2xPath);
        if (!image.isEmpty()) {
          // 64x64 @2x 图标，在 Retina 显示器上会显示为清晰的 32x32
          // 系统会自动处理缩放，保持清晰度
          return image;
        }
      } catch (error) {
        console.warn('加载 @2x PNG 图标失败:', error);
      }
    }

    // 尝试标准 PNG 格式（32x32）
    const driveIconPngPath = path.join(appPath, 'src', 'imgs', 'ico', 'drive.png');
    if (fs.existsSync(driveIconPngPath)) {
      try {
        const image = nativeImage.createFromPath(driveIconPngPath);
        if (!image.isEmpty()) {
          // 32x32 图标，在普通显示器上显示为 16x16
          return image;
        }
      } catch (error) {
        console.warn('加载 PNG 图标失败:', error);
      }
    }

    // 注意：Electron 的 Menu API 不支持直接使用 SVG
    // 如果 PNG 文件不存在，应该运行 scripts/generate-device-icon.js 来生成
    // 这里不尝试从 SVG 动态生成，因为：
    // 1. sharp 在 devDependencies 中，生产环境可能不可用
    // 2. 动态生成会增加启动时间
    // 3. 预生成的 PNG 文件性能更好

    // 如果 PNG 不存在，尝试 SVG（Electron 可能不支持，但先尝试）
    const driveIconSvgPath = path.join(appPath, 'src', 'imgs', 'ico', 'drive.svg');
    if (fs.existsSync(driveIconSvgPath)) {
      try {
        // Electron 的 nativeImage 不支持直接加载 SVG
        // 这里尝试加载，但通常会失败
        const image = nativeImage.createFromPath(driveIconSvgPath);
        if (!image.isEmpty()) {
          return image.resize({ width: 16, height: 16 });
        }
      } catch (error) {
        // SVG 无法直接加载是正常的，尝试其他路径
        console.debug('SVG 图标无法直接加载（这是正常的）:', error);
      }
    }

    // 尝试其他可能的路径
    const alternativePaths = [
      path.join(appPath, 'src', 'ico', 'drive.png'),
      path.join(appPath, 'src', 'ico', 'drive.svg')
    ];

    for (const iconPath of alternativePaths) {
      if (fs.existsSync(iconPath)) {
        try {
          const image = nativeImage.createFromPath(iconPath);
          if (!image.isEmpty()) {
            return image.resize({ width: 16, height: 16 });
          }
        } catch (error) {
          continue;
        }
      }
    }
  } catch (error) {
    console.warn('加载设备图标失败:', error);
  }
  // 如果所有方法都失败，返回 undefined（不显示图标）
  return undefined;
}

/**
 * 创建托盘图标（白色图标，用于 macOS 菜单栏）
 */
export function createTrayIcon(): Electron.NativeImage {
  const appPath = app.getAppPath();

  // 优先使用 flash.icns（macOS 最佳格式，包含多种尺寸）
  const icnsPath = path.join(appPath, 'src', 'ico', 'flash.icns');
  if (fs.existsSync(icnsPath)) {
    try {
      const image = nativeImage.createFromPath(icnsPath);
      if (!image.isEmpty()) {
        // icns 文件已经包含多种尺寸，直接使用，系统会自动选择合适的大小
        // 在 macOS 上，单色图标会自动作为模板图标处理，显示为白色
        const resized = image.resize({ width: 22, height: 22 });
        if (!resized.isEmpty()) {
          // 成功加载托盘图标
          // 在 macOS 上，将图标设置为模板图标（会自动显示为白色）
          if (process.platform === 'darwin') {
            // 创建模板图标：将图标转换为单色（黑白），系统会自动处理为白色
            const templateImage = resized;
            // Electron 会自动识别单色图标为模板图标
            return templateImage;
          }
          return resized;
        }
        // 如果调整大小失败，直接返回原图
        // 成功加载托盘图标（原始尺寸）
        return image;
      }
    } catch (error) {
      console.warn(`无法加载图标 ${icnsPath}:`, error);
    }
  }

  // 备用：尝试使用 flash.svg（需要转换为位图）
  const svgPath = path.join(appPath, 'src', 'ico', 'flash.svg');
  if (fs.existsSync(svgPath)) {
    try {
      // Electron 的 nativeImage 不支持直接加载 SVG，需要先转换为位图
      // 这里尝试读取 SVG 并转换为 PNG
      const image = nativeImage.createFromPath(svgPath);
      if (!image.isEmpty()) {
        const resized = image.resize({ width: 22, height: 22 });
        if (!resized.isEmpty()) {
          // 成功加载托盘图标: flash.svg
          return resized;
        }
      }
    } catch (error) {
      console.warn(`无法加载图标 ${svgPath}:`, error);
    }
  }

  // 备用：尝试使用 iconset 中的图标
  const possiblePaths = [
    path.join(appPath, 'src', 'ico', 'flash.iconset', 'icon_16x16@2x.png'),
    path.join(appPath, 'src', 'ico', 'flash.iconset', 'icon_32x32.png'),
    path.join(appPath, 'src', 'ico', 'flash.iconset', 'icon_16x16.png'),
    path.join(appPath, 'src', 'imgs', 'icon-tray.png'),
    path.join(appPath, 'src', 'imgs', 'icon.png')
  ];

  for (const iconPath of possiblePaths) {
    if (fs.existsSync(iconPath)) {
      try {
        const image = nativeImage.createFromPath(iconPath);
        const resized = image.resize({ width: 22, height: 22 });
        if (!resized.isEmpty()) {
          // 成功加载托盘图标
          return resized;
        }
      } catch (error) {
        console.warn(`无法加载图标 ${iconPath}:`, error);
        continue;
      }
    }
  }

  // 如果所有图标都加载失败，尝试使用应用图标
  try {
    const resourcesPath = path.join(appPath, '..', '..', 'Contents', 'Resources');
    const appIconPath = path.join(resourcesPath, 'app.icns');
    if (fs.existsSync(appIconPath)) {
      const appIcon = nativeImage.createFromPath(appIconPath);
      if (!appIcon.isEmpty()) {
        // 使用应用图标作为托盘图标
        return appIcon.resize({ width: 22, height: 22 });
      }
    }
  } catch (error) {
    console.warn('无法加载应用图标:', error);
  }

  // 如果所有图标都加载失败，创建一个空图标（Electron 会使用默认图标）
  console.warn('无法找到托盘图标，使用默认图标');
  return nativeImage.createEmpty();
}

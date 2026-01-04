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

  // 优先使用 iconset 中的单色 PNG（确保是单色的，macOS 能正确识别为模板图标）
  // 使用 32x32@2x (64x64) 尺寸，适合 Retina 显示
  const iconsetPaths = [
    path.join(appPath, 'src', 'imgs', 'ico', 'flash-white.iconset', 'icon_32x32@2x.png'),
    path.join(appPath, 'src', 'imgs', 'ico', 'flash-white.iconset', 'icon_32x32.png'),
    path.join(appPath, 'src', 'imgs', 'ico', 'flash-white.iconset', 'icon_16x16@2x.png'),
    path.join(appPath, 'src', 'imgs', 'ico', 'flash-white.iconset', 'icon_16x16.png')
  ];

  for (const iconsetPath of iconsetPaths) {
    if (fs.existsSync(iconsetPath)) {
      try {
        const image = nativeImage.createFromPath(iconsetPath);
        if (!image.isEmpty()) {
          const resized = image.resize({ width: 22, height: 22 });
          if (!resized.isEmpty()) {
            return resized;
          }
          return image;
        }
      } catch (error) {
        // 继续尝试下一个
        continue;
      }
    }
  }

  // 备用：使用 flash-white.icns
  const icnsPath = path.join(appPath, 'src', 'imgs', 'ico', 'flash-white.icns');
  if (fs.existsSync(icnsPath)) {
    try {
      const image = nativeImage.createFromPath(icnsPath);
      if (!image.isEmpty()) {
        const resized = image.resize({ width: 22, height: 22 });
        if (!resized.isEmpty()) {
          return resized;
        }
        return image;
      }
    } catch (error) {
      console.warn(`无法加载图标 ${icnsPath}:`, error);
    }
  }

  // 注意：不再使用 flash.svg 或 flash.iconset，因为它们可能是彩色的
  // 只使用 flash-white.iconset 中的单色图标，确保 macOS 能正确识别为模板图标

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

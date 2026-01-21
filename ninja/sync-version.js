#!/usr/bin/env node
/**
 * 版本号同步脚本
 * 从 package.json 读取版本号，自动更新所有相关文件
 *
 * 使用方法：
 *   node sync-version.js
 *   或
 *   pnpm run sync-version
 */

const fs = require('fs');
const path = require('path');

// 读取 package.json 获取版本号
// 注意：脚本在 ninja/ 文件夹中，需要访问根目录的 package.json
const packageJsonPath = path.join(__dirname, '..', 'package.json');

if (!fs.existsSync(packageJsonPath)) {
  console.error('❌ 错误: 找不到 package.json 文件');
  process.exit(1);
}

let packageJson;
try {
  packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf-8'));
} catch (error) {
  console.error('❌ 错误: 无法解析 package.json 文件');
  console.error(error.message);
  process.exit(1);
}

const version = packageJson.version;

if (!version || !/^\d+\.\d+\.\d+/.test(version)) {
  console.error(`❌ 错误: 无效的版本号格式: ${version}`);
  console.error('   版本号应该是 x.y.z 格式（例如: 1.3.4）');
  process.exit(1);
}

const versionWithV = `v${version}`;
const versionWithNigate = `Nigate v${version}`;

console.log(`🔄 同步版本号: ${version}`);

// 需要更新的文件列表
const filesToUpdate = [
  {
    path: 'src/scripts/utils/ui.ts',
    patterns: [
      {
        search: /'Nigate v\d+\.\d+\.\d+'/g,
        replace: `'${versionWithNigate}'`
      }
    ]
  },
  {
    path: 'src/scripts/app-config.ts',
    patterns: [
      {
        search: /applicationVersion: 'v\d+\.\d+\.\d+'/g,
        replace: `applicationVersion: '${versionWithV}'`
      }
    ]
  },
  {
    path: 'src/html/about.html',
    patterns: [
      {
        search: /<strong>软件版本：<\/strong> Nigate v\d+\.\d+\.\d+/g,
        replace: `<strong>软件版本：</strong> ${versionWithNigate}`
      }
    ]
  }
];

// 更新文件
let updatedCount = 0;
let errorCount = 0;

filesToUpdate.forEach(({ path: filePath, patterns }) => {
  // 文件路径相对于项目根目录，需要从 ninja/ 文件夹向上查找
  const fullPath = path.join(__dirname, '..', filePath);

  if (!fs.existsSync(fullPath)) {
    console.warn(`⚠️  文件不存在: ${filePath}`);
    errorCount++;
    return;
  }

  try {
    let content = fs.readFileSync(fullPath, 'utf-8');
    let modified = false;

    patterns.forEach(({ search, replace }) => {
      if (search.test(content)) {
        content = content.replace(search, replace);
        modified = true;
      }
    });

    if (modified) {
      fs.writeFileSync(fullPath, content, 'utf-8');
      console.log(`✅ 已更新: ${filePath}`);
      updatedCount++;
    } else {
      console.log(`ℹ️  无需更新: ${filePath} (未找到匹配的版本号)`);
    }
  } catch (error) {
    console.error(`❌ 更新失败: ${filePath}`);
    console.error(`   错误: ${error.message}`);
    errorCount++;
  }
});

console.log(`\n✨ 版本号同步完成！`);
console.log(`   ✅ 成功更新: ${updatedCount} 个文件`);
if (errorCount > 0) {
  console.log(`   ⚠️  错误: ${errorCount} 个文件`);
}
console.log(`📦 当前版本: ${version}`);

// 如果有错误，退出码为非零
if (errorCount > 0) {
  process.exit(1);
}

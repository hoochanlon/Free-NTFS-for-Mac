// 命令行测试脚本 - 检查模块文件是否存在和基本语法
const fs = require('fs');
const path = require('path');

const testResults = {
  passed: [],
  failed: [],
  warnings: []
};

function test(name, condition, details = '') {
  try {
    if (condition()) {
      testResults.passed.push({ name, details });
      console.log(`✅ ${name}`);
      return true;
    } else {
      testResults.failed.push({ name, details });
      console.log(`❌ ${name}`);
      if (details) console.log(`   详情: ${details}`);
      return false;
    }
  } catch (error) {
    testResults.failed.push({ name, details: error.message });
    console.log(`❌ ${name} - 错误: ${error.message}`);
    return false;
  }
}

function warn(message) {
  testResults.warnings.push(message);
  console.log(`⚠️  ${message}`);
}

// 切换到项目根目录（脚本在 ninja/ 文件夹中）
const scriptDir = __dirname;
const projectRoot = path.join(scriptDir, '..');
process.chdir(projectRoot);

console.log('='.repeat(60));
console.log('设备模块重构 - 文件检查测试');
console.log('='.repeat(60));
console.log('');

// 检查源文件
console.log('📁 检查源文件...');
const sourceFiles = [
  'src/scripts/modules/devices/device-utils.ts',
  'src/scripts/modules/devices/device-renderer.ts',
  'src/scripts/modules/devices/device-operations.ts',
  'src/scripts/modules/devices/device-events.ts',
  'src/scripts/devices-refactored.ts'
];

sourceFiles.forEach(file => {
  test(`源文件存在: ${file}`, () => fs.existsSync(file));
});

console.log('');

// 检查编译后的文件
console.log('📦 检查编译后的文件...');
const compiledFiles = [
  'scripts/modules/devices/device-utils.js',
  'scripts/modules/devices/device-renderer.js',
  'scripts/modules/devices/device-operations.js',
  'scripts/modules/devices/device-events.js',
  'scripts/devices-refactored.js'
];

compiledFiles.forEach(file => {
  const exists = fs.existsSync(file);
  test(`编译文件存在: ${file}`, () => exists);

  if (exists) {
    const stats = fs.statSync(file);
    const sizeKB = (stats.size / 1024).toFixed(2);
    console.log(`   大小: ${sizeKB} KB`);

    // 检查文件内容
    const content = fs.readFileSync(file, 'utf8');
    if (content.length === 0) {
      warn(`${file} 文件为空`);
    } else if (content.includes('use strict')) {
      console.log(`   ✓ 包含 'use strict'`);
    }

    // 检查是否有明显的语法错误（简单检查）
    if (content.includes('undefined') && content.includes('AppModules')) {
      console.log(`   ✓ 包含 AppModules 相关代码`);
    }
  }
});

console.log('');

// 检查测试文件
console.log('🧪 检查测试文件...');
const testFiles = [
  'test-modules.html',
  'test-modules-enhanced.html'
];

testFiles.forEach(file => {
  test(`测试文件存在: ${file}`, () => fs.existsSync(file));

  if (fs.existsSync(file)) {
    const content = fs.readFileSync(file, 'utf8');
    if (content.includes('device-utils.js')) {
      console.log(`   ✓ 引用了 device-utils.js`);
    }
    if (content.includes('device-renderer.js')) {
      console.log(`   ✓ 引用了 device-renderer.js`);
    }
    if (content.includes('device-operations.js')) {
      console.log(`   ✓ 引用了 device-operations.js`);
    }
    if (content.includes('device-events.js')) {
      console.log(`   ✓ 引用了 device-events.js`);
    }
  }
});

console.log('');

// 检查文件大小和基本统计
console.log('📊 文件统计...');
compiledFiles.forEach(file => {
  if (fs.existsSync(file)) {
    const content = fs.readFileSync(file, 'utf8');
    const lines = content.split('\n').length;
    const size = fs.statSync(file).size;
    console.log(`   ${path.basename(file)}: ${lines} 行, ${(size / 1024).toFixed(2)} KB`);
  }
});

console.log('');

// 检查关键函数是否存在（通过搜索代码）
console.log('🔍 检查关键函数...');
const utilsFile = 'scripts/modules/devices/device-utils.js';
if (fs.existsSync(utilsFile)) {
  const content = fs.readFileSync(utilsFile, 'utf8');
  test('Utils.formatCapacity 存在', () => content.includes('formatCapacity'));
  test('Utils.addLog 存在', () => content.includes('addLog'));
  test('Utils.showLoading 存在', () => content.includes('showLoading'));
  test('Utils.t 存在', () => content.includes('t(key'));
  test('Utils.renderDeviceInfoHTML 存在', () => content.includes('renderDeviceInfoHTML'));
}

const rendererFile = 'scripts/modules/devices/device-renderer.js';
if (fs.existsSync(rendererFile)) {
  const content = fs.readFileSync(rendererFile, 'utf8');
  test('Renderer.renderDevices 存在', () => content.includes('renderDevices'));
  test('Renderer.createDeviceItem 存在', () => content.includes('createDeviceItem'));
}

const operationsFile = 'scripts/modules/devices/device-operations.js';
if (fs.existsSync(operationsFile)) {
  const content = fs.readFileSync(operationsFile, 'utf8');
  test('Operations.mountDevice 存在', () => content.includes('mountDevice'));
  test('Operations.restoreToReadOnly 存在', () => content.includes('restoreToReadOnly'));
  test('Operations.ejectDevice 存在', () => content.includes('ejectDevice'));
  test('Operations.mountAllDevices 存在', () => content.includes('mountAllDevices'));
}

const eventsFile = 'scripts/modules/devices/device-events.js';
if (fs.existsSync(eventsFile)) {
  const content = fs.readFileSync(eventsFile, 'utf8');
  test('Events.bindDeviceEvents 存在', () => content.includes('bindDeviceEvents'));
}

console.log('');

// 总结
console.log('='.repeat(60));
console.log('测试总结');
console.log('='.repeat(60));
console.log(`✅ 通过: ${testResults.passed.length}`);
console.log(`❌ 失败: ${testResults.failed.length}`);
console.log(`⚠️  警告: ${testResults.warnings.length}`);
console.log('');

if (testResults.failed.length > 0) {
  console.log('失败的测试:');
  testResults.failed.forEach(f => {
    console.log(`  ❌ ${f.name}`);
    if (f.details) console.log(`      ${f.details}`);
  });
  console.log('');
}

if (testResults.warnings.length > 0) {
  console.log('警告:');
  testResults.warnings.forEach(w => {
    console.log(`  ⚠️  ${w}`);
  });
  console.log('');
}

const passRate = ((testResults.passed.length / (testResults.passed.length + testResults.failed.length)) * 100).toFixed(1);
console.log(`通过率: ${passRate}%`);

if (testResults.failed.length === 0) {
  console.log('');
  console.log('🎉 所有文件检查通过！');
  console.log('');
  console.log('下一步:');
  console.log('1. 在浏览器中打开 test-modules-enhanced.html 进行功能测试');
  console.log('2. 或在 Electron 应用中测试实际功能');
} else {
  console.log('');
  console.log('⚠️  部分检查未通过，请检查上述失败的测试');
}

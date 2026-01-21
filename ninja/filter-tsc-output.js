#!/usr/bin/env node
// TypeScript 编译输出过滤器
// 用于过滤和格式化 tsc --watch 的输出

const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// 需要过滤的关键词（可以忽略的警告或信息）
const ignorePatterns = [
  /Found \d+ error/,
  /error TS\d+:/,
  /^$/,
];

// 需要保留的重要信息
const importantPatterns = [
  /Compilation complete/,
  /Found \d+ error/,
  /error TS/,
  /warning TS/,
];

let hasErrors = false;
let errorCount = 0;

rl.on('line', (line) => {
  // 检查是否是错误信息
  if (line.includes('error TS')) {
    hasErrors = true;
    errorCount++;
    console.log(line);
    return;
  }

  // 检查是否是警告信息
  if (line.includes('warning TS')) {
    console.log(line);
    return;
  }

  // 检查是否是编译完成信息
  if (line.includes('Compilation complete') || line.includes('Found')) {
    console.log(line);
    return;
  }

  // 检查是否是文件路径（通常包含 src/ 或 .ts）
  if (line.includes('src/') && (line.includes('.ts') || line.includes('error'))) {
    console.log(line);
    return;
  }

  // 忽略空行和无关信息
  if (line.trim() === '') {
    return;
  }

  // 默认输出（保留其他可能有用的信息）
  // 如果需要更严格的过滤，可以取消下面的注释
  // return;

  // 或者输出所有信息（用于调试）
  // console.log(line);
});

rl.on('close', () => {
  if (hasErrors) {
    process.exit(1);
  } else {
    process.exit(0);
  }
});

# 打包配置说明

## 备份文件

- `package.json.backup.arm64` - ARM64 版本的 package.json 配置备份
- `ninja/build.sh.backup.arm64` - ARM64 版本的 build.sh 脚本备份

## 当前配置（通用版本）

## Electron 下载失败（EOF）如何处理

- 默认已启用 **Electron 镜像**（`https://npmmirror.com/mirrors/electron/`），用于解决打包时从 GitHub 下载 Electron 经常 EOF/超时的问题。
- 如需切回官方源，可在打包前显式执行：

```bash
ELECTRON_MIRROR="" pnpm run build:universal
```

### package.json 配置

当前 `package.json` 中的 `build.mac.target` 配置为：

```json
"arch": ["x64", "arm64"]
```

这会创建两个独立的包：
- Intel Mac (x64) 版本
- Apple Silicon (arm64) 版本

### 打包命令

1. **默认打包**（创建 x64 和 arm64 两个包）：
   ```bash
   pnpm run build
   # 或
   ./ninja/build.sh
   ```

2. **只打包 DMG**：
   ```bash
   pnpm run build:dmg
   # 或
   ./ninja/build.sh --dmg
   ```

3. **只打包 ZIP**：
   ```bash
   pnpm run build:zip
   # 或
   ./ninja/build.sh --zip
   ```

4. **打包通用二进制文件**（单一文件，同时支持 x64 和 arm64）：
   ```bash
   pnpm run build:universal
   # 或
   ./ninja/build.sh --universal
   ```

5. **只打包 ARM64 版本**：
   ```bash
   pnpm run build:arm64
   # 或
   ./ninja/build.sh --arm64
   ```

6. **只打包 Intel (x64) 版本**：
   ```bash
   pnpm run build:x64
   # 或
   ./ninja/build.sh --x64
   ```

## 恢复 ARM64 配置

如果需要恢复到之前的 ARM64 配置：

```bash
cp package.json.backup.arm64 package.json
cp ninja/build.sh.backup.arm64 ninja/build.sh
```

## 注意事项

- `--universal` 选项会创建一个包含两个架构的单一通用二进制文件（fat binary）
- `["x64", "arm64"]` 配置会创建两个独立的包文件
- 通用二进制文件体积会更大，但用户只需要下载一个文件
- 两个独立包的体积更小，但用户需要根据 Mac 架构选择对应的版本

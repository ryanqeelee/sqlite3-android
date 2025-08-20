# SQLite3 多平台构建项目

本项目提供了在多个平台上构建 SQLite3 的完整解决方案，包括 **Android**、**macOS** 和 **NVIDIA Jetson Orin Nano** 平台。

## 🎯 支持平台

| 平台 | 架构 | 状态 |
|------|------|------|
| **Android** | ARM32, ARM64, x86, x86_64 | ✅ 完全支持 |
| **macOS** | Intel x64, Apple Silicon | ✅ 完全支持 |
| **Jetson Orin Nano** | ARM64 | ✅ 完全支持 |

## 🚀 快速开始

### 自动构建（推荐）
```bash
# 自动检测当前平台并构建
./build_auto.sh
```

### 手动选择平台
```bash
# 查看所有构建选项
make help

# Android 构建
make android

# macOS 构建  
make mac

# Jetson 构建
make jetson

# 自动检测平台
make auto
```

## 📋 环境要求

### Android 平台
- Android NDK (推荐 28+)
- 设置 NDK_ROOT 环境变量

### macOS 平台  
- Xcode 命令行工具
- macOS 10.15+ (Intel) / 11.0+ (Apple Silicon)

### Jetson Orin Nano
- Ubuntu 22.04
- build-essential

## 📚 详细文档

- **[多平台构建指南](README_MULTIPLATFORM.md)** - 完整的多平台构建说明
- **[使用说明](README_USAGE.md)** - Android 平台集成指南  
- **[集成指南](INTEGRATION_GUIDE.md)** - 详细的项目集成方法

## ⚡ 特性

- **完整功能**：支持 FTS、JSON、R-Tree、向量扩展
- **高性能**：针对各平台优化编译
- **易集成**：提供完整的头文件和库文件
- **多架构**：支持通用二进制文件（macOS）

---

**💡 提示**：首次使用建议运行 `./build_auto.sh` 进行自动构建！

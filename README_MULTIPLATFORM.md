# SQLite3 多平台构建指南

本项目现已支持多个平台的 SQLite3 构建，包括 Android、macOS 和 NVIDIA Jetson Orin Nano 平台。

## 🎯 支持的平台

| 平台 | 架构 | 状态 | 说明 |
|------|------|------|------|
| **Android** | ARM32, ARM64 | ✅ 完全支持 | 使用 Android NDK 构建 |
| **macOS** | Intel x64, Apple Silicon | ✅ 完全支持 | 支持通用二进制文件 |
| **Jetson Orin Nano** | ARM64 | ✅ 完全支持 | 针对 NVIDIA Jetson 优化 |
| **Linux (通用)** | x64, ARM64 | ✅ 基础支持 | 通用 Linux 构建 |

## 🚀 快速开始

### 自动构建（推荐）

使用自动检测脚本，系统会自动识别当前平台并选择最佳构建方式：

```bash
# 交互式自动构建
./build_auto.sh

# 或者直接自动构建
./build_auto.sh auto
```

### 使用 Makefile

```bash
# 显示帮助信息
make help

# 自动检测平台构建
make auto

# 指定平台构建
make android    # Android 版本
make mac        # macOS 版本
make jetson     # Jetson 版本

# 构建所有平台（需要相应环境）
make all
```

## 📦 分平台构建说明

### Android 平台

**要求**：
- Android NDK (推荐版本 28+)
- 设置 `NDK_ROOT` 或 `ANDROID_NDK_ROOT` 环境变量

**构建命令**：
```bash
# 使用 Makefile
make android

# 或使用原有脚本
export NDK_ROOT=/path/to/android-ndk
./build_sqlite3.sh
```

**输出文件**：
```
libs/
├── armeabi-v7a/libsqlite3.so
└── arm64-v8a/libsqlite3.so
```

### macOS 平台

**要求**：
- Xcode 命令行工具 (`xcode-select --install`)
- Homebrew (可选，用于安装依赖)

**构建命令**：
```bash
# 使用 Makefile
make mac

# 或直接运行脚本
./build_sqlite3_mac.sh

# 构建通用二进制文件（默认）
./build_sqlite3_mac.sh true

# 只构建当前架构
./build_sqlite3_mac.sh false
```

**输出文件**：
```
libs/macos/
├── libsqlite3.dylib          # 通用动态库
├── libsqlite3.a              # 通用静态库
├── libsqlite3_x86_64.dylib   # Intel 专用动态库
├── libsqlite3_arm64.dylib    # Apple Silicon 专用动态库
├── libsqlite3_x86_64.a       # Intel 专用静态库
├── libsqlite3_arm64.a        # Apple Silicon 专用静态库
├── sqlite3                   # 命令行工具
├── sqlite3.h                 # 头文件
├── sqlite3ext.h              # 扩展头文件
└── sqlite-vec.h              # 向量扩展头文件
```

### Jetson Orin Nano 平台

**要求**：
- Ubuntu 22.04 (推荐)
- build-essential 工具链
- NVIDIA JetPack (推荐)

**准备环境**：
```bash
sudo apt update
sudo apt install build-essential wget unzip
```

**构建命令**：
```bash
# 使用 Makefile
make jetson

# 或直接运行脚本
./build_sqlite3_jetson.sh
```

**输出文件**：
```
libs/jetson/
├── libsqlite3.so.0.8.6       # 共享库
├── libsqlite3.so.0 -> libsqlite3.so.0.8.6
├── libsqlite3.so -> libsqlite3.so.0
├── libsqlite3.a              # 静态库
├── sqlite3                   # 命令行工具
├── sqlite3.pc                # pkg-config 文件
├── sqlite3.h                 # 头文件
├── sqlite3ext.h              # 扩展头文件
└── sqlite-vec.h              # 向量扩展头文件
```

**安装到系统**：
```bash
# 安装库文件
sudo cp libs/jetson/libsqlite3.so* /usr/local/lib/
sudo cp libs/jetson/libsqlite3.a /usr/local/lib/
sudo ldconfig

# 安装头文件
sudo cp libs/jetson/sqlite3*.h /usr/local/include/

# 安装 pkg-config 文件
sudo cp libs/jetson/sqlite3.pc /usr/local/lib/pkgconfig/

# 安装命令行工具（可选）
sudo cp libs/jetson/sqlite3 /usr/local/bin/
```

## 🔧 特性和优化

### 共同特性
- **完整的 SQLite3 功能**：FTS3/4、R-Tree、JSON1、列元数据
- **SQLite-vec 扩展**：向量数据库功能
- **线程安全**：支持多线程环境
- **性能优化**：针对各平台优化编译选项

### 平台特定优化

#### Android
- ARM NEON 指令集优化
- 针对移动设备的内存管理
- 支持 API Level 16+ (Android 4.1+)

#### macOS
- 通用二进制文件支持（Intel + Apple Silicon）
- 充分利用苹果芯片性能
- 兼容 macOS 10.15+ (Intel) / macOS 11.0+ (Apple Silicon)

#### Jetson Orin Nano
- ARM Cortex-A78 核心优化
- NEON 浮点加速
- NVIDIA Jetson 平台特定优化
- 低功耗场景优化

## 📚 使用示例

### C/C++ 项目集成

#### macOS 项目
```c
#include <sqlite3.h>

int main() {
    sqlite3 *db;
    int rc = sqlite3_open("test.db", &db);
    
    if (rc) {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        return 1;
    }
    
    // 使用数据库...
    
    sqlite3_close(db);
    return 0;
}
```

编译：
```bash
# 使用动态库
gcc -o myapp myapp.c -lsqlite3

# 使用静态库
gcc -o myapp myapp.c libs/macos/libsqlite3.a -lm
```

#### Jetson 项目
```bash
# 使用 pkg-config（推荐）
gcc -o myapp myapp.c $(pkg-config --cflags --libs sqlite3)

# 手动链接
gcc -o myapp myapp.c -lsqlite3 -lm -lpthread -ldl
```

#### Android 项目
参考原有的 `README_USAGE.md` 文档。

### Python 项目
```python
import sqlite3

# 使用编译的 SQLite3 库
conn = sqlite3.connect('test.db')
cursor = conn.cursor()

# 测试向量扩展功能
cursor.execute("SELECT vec_version()")
print("SQLite-vec version:", cursor.fetchone()[0])

conn.close()
```

## 🛠️ 高级配置

### 自定义编译选项

修改各平台构建脚本中的 `cflags` 变量来自定义编译选项：

```bash
# 示例：添加自定义宏定义
LOCAL_CFLAGS += -DCUSTOM_FEATURE=1
```

### 交叉编译

对于需要交叉编译的场景（如在 x64 机器上为 ARM 编译），可以修改对应的构建脚本设置交叉编译工具链。

### 性能调优

不同平台的性能调优建议：

**Android**：
- 使用 `-O3` 优化级别
- 启用 ARM NEON 指令集
- 考虑使用 `-flto` 链接时优化

**macOS**：
- 根据目标架构选择合适的 `-march` 参数
- 利用 Accelerate 框架进行数学运算优化

**Jetson**：
- 使用 `-mtune=cortex-a78` 针对处理器优化
- 启用 NEON 浮点运算加速
- 考虑使用 CUDA 加速（未来扩展）

## 📋 已知限制

1. **Windows 支持**：目前不支持 Windows 原生构建，建议使用 WSL 或 Android NDK
2. **交叉编译**：部分交叉编译场景需要手动配置工具链
3. **旧版本兼容性**：某些非常老的系统版本可能不支持

## 🔍 故障排除

### 常见问题

**编译失败 - 找不到编译器**：
```bash
# macOS
xcode-select --install

# Ubuntu/Jetson
sudo apt install build-essential
```

**Android NDK 路径问题**：
```bash
export NDK_ROOT=/path/to/android-ndk
# 或者
export ANDROID_NDK_ROOT=/path/to/android-ndk
```

**权限问题**：
```bash
chmod +x *.sh
```

**库文件找不到**：
```bash
# Linux/Jetson
sudo ldconfig

# macOS
export DYLD_LIBRARY_PATH=/path/to/libs:$DYLD_LIBRARY_PATH
```

### 调试构建

启用详细构建输出：
```bash
# 查看平台检测信息
./build_auto.sh info

# 查看具体构建命令
make android V=1
```

## 📞 技术支持

如果遇到问题或需要支持新平台，请：

1. 检查 [故障排除](#故障排除) 部分
2. 查看构建日志获取详细错误信息
3. 提交 Issue 并附上以下信息：
   - 操作系统和版本
   - CPU 架构
   - 错误日志
   - 使用的构建命令

## 🎉 贡献

欢迎为此项目贡献代码！特别欢迎：

- 新平台支持 (Windows, iOS, 其他 Linux 发行版)
- 性能优化
- 构建脚本改进
- 文档完善

---

**准备就绪！现在您可以在多个平台上使用高性能的 SQLite3 库了！** 🚀

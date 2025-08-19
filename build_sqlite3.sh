#!/bin/bash

# SQLite3 NDK 编译脚本
# 支持 armv7 (armeabi-v7a) 和 armv8 (arm64-v8a) 架构

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印消息函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取 CPU 核心数
get_cpu_cores() {
    if command -v nproc > /dev/null 2>&1; then
        nproc
    elif command -v sysctl > /dev/null 2>&1; then
        sysctl -n hw.ncpu
    else
        echo "4"  # 默认值
    fi
}

# 检查 NDK 环境
check_ndk() {
    if [ -z "$NDK_ROOT" ] && [ -z "$ANDROID_NDK_ROOT" ]; then
        print_error "NDK_ROOT 或 ANDROID_NDK_ROOT 环境变量未设置"
        print_info "请设置 NDK 路径，例如："
        print_info "export NDK_ROOT=/path/to/android-ndk"
        print_info "或者"
        print_info "export ANDROID_NDK_ROOT=/path/to/android-ndk"
        exit 1
    fi
    
    # 使用 NDK_ROOT 或 ANDROID_NDK_ROOT
    if [ -n "$NDK_ROOT" ]; then
        NDK_PATH="$NDK_ROOT"
    else
        NDK_PATH="$ANDROID_NDK_ROOT"
    fi
    
    if [ ! -d "$NDK_PATH" ]; then
        print_error "NDK 路径不存在: $NDK_PATH"
        exit 1
    fi
    
    # 检查 ndk-build 是否存在
    if [ ! -f "$NDK_PATH/ndk-build" ]; then
        print_error "ndk-build 不存在: $NDK_PATH/ndk-build"
        exit 1
    fi
    
    # 添加 NDK 路径到 PATH
    export PATH="$NDK_PATH:$PATH"
    
    print_info "使用 NDK 路径: $NDK_PATH"
}

# 清理输出目录
clean_output() {
    print_info "清理输出目录..."
    rm -rf libs
    rm -rf obj
}

# 编译 SQLite3
build_sqlite3() {
    print_info "开始编译 SQLite3..."
    print_info "目标架构: armv7 (armeabi-v7a) 和 armv8 (arm64-v8a)"
    
    # 获取 CPU 核心数
    CPU_CORES=$(get_cpu_cores)
    print_info "使用 $CPU_CORES 个 CPU 核心进行编译"
    
    # 运行 ndk-build
    ndk-build -j$CPU_CORES V=1
    
    if [ $? -eq 0 ]; then
        print_info "编译成功！"
        print_info "输出文件位置:"
        find libs -name "*.so" -o -name "*.a" | while read file; do
            print_info "  $file"
        done
    else
        print_error "编译失败"
        exit 1
    fi
}

# 显示库信息
show_lib_info() {
    print_info "编译完成的库信息:"
    
    for arch in armeabi-v7a arm64-v8a; do
        if [ -d "libs/$arch" ]; then
            print_info "架构: $arch"
            for lib in libs/$arch/*.so libs/$arch/*.a; do
                if [ -f "$lib" ]; then
                    size=$(du -h "$lib" | cut -f1)
                    print_info "  $(basename "$lib"): $size"
                fi
            done
        fi
    done
}

# 主函数
main() {
    print_info "SQLite3 Android NDK 编译脚本"
    print_info "==============================="
    
    # 检查 NDK 环境
    check_ndk
    
    # 清理输出目录
    clean_output
    
    # 编译 SQLite3
    build_sqlite3
    
    # 显示库信息
    show_lib_info
    
    print_info "编译完成！"
    print_info "您可以在 libs/ 目录下找到编译好的库文件"
}

# 运行主函数
main "$@" 
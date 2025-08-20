#!/bin/bash

# SQLite3 macOS 编译脚本
# 支持 x64 和 ARM64 (Apple Silicon) 架构

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
    sysctl -n hw.ncpu
}

# 检测 macOS 架构
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        "x86_64")
            echo "x86_64"
            ;;
        "arm64")
            echo "arm64"
            ;;
        *)
            print_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
}

# 检查编译工具
check_build_tools() {
    # 检查 Xcode 命令行工具
    if ! command -v clang &> /dev/null; then
        print_error "未找到 clang 编译器"
        print_info "请安装 Xcode 命令行工具:"
        print_info "xcode-select --install"
        exit 1
    fi
    
    # 检查必要工具
    for tool in make wget unzip; do
        if ! command -v $tool &> /dev/null; then
            print_error "未找到必要工具: $tool"
            print_info "请使用 Homebrew 安装: brew install $tool"
            exit 1
        fi
    done
    
    print_info "编译工具检查通过"
}

# 下载 SQLite 源码
download_sqlite() {
    local sqlite_version="sqlite-amalgamation-3500200"
    local download_url="https://sqlite.org/2025/${sqlite_version}.zip"
    
    print_info "下载 SQLite 源码..."
    
    if [ ! -f "${sqlite_version}.zip" ]; then
        wget -c "$download_url"
    else
        print_info "SQLite 源码已存在，跳过下载"
    fi
    
    # 解压源码
    if [ ! -d "build" ]; then
        print_info "解压 SQLite 源码..."
        unzip -qo "${sqlite_version}.zip"
        mv "$sqlite_version" build
    else
        print_info "build 目录已存在，跳过解压"
    fi
}

# 清理输出目录
clean_output() {
    print_info "清理输出目录..."
    rm -rf libs/macos
    mkdir -p libs/macos
}

# 编译 SQLite3 动态库
build_sqlite3_dylib() {
    local arch=$1
    local cpu_cores=$(get_cpu_cores)
    
    print_info "编译 SQLite3 动态库 (架构: $arch)"
    
    # 设置编译标志
    local cflags="-DSQLITE_CORE \
                  -DSQLITE_THREADSAFE=1 \
                  -DSQLITE_ENABLE_FTS3 \
                  -DSQLITE_ENABLE_FTS4 \
                  -DSQLITE_ENABLE_RTREE \
                  -DSQLITE_ENABLE_JSON1 \
                  -DSQLITE_ENABLE_COLUMN_METADATA \
                  -DSQLITE_SECURE_DELETE \
                  -DSQLITE_TEMP_STORE=2 \
                  -DSQLITE_VEC_STATIC=1 \
                  -O3 \
                  -fPIC"
    
    # 根据架构设置特定编译选项
    case $arch in
        "x86_64")
            cflags="$cflags -arch x86_64 -mmacosx-version-min=10.15"
            ;;
        "arm64")
            cflags="$cflags -arch arm64 -mmacosx-version-min=11.0"
            ;;
    esac
    
    # 编译动态库
    clang $cflags \
          -dynamiclib \
          -install_name @rpath/libsqlite3.dylib \
          -o "libs/macos/libsqlite3_${arch}.dylib" \
          build/sqlite3.c build/sqlite-vec.c \
          -lm
    
    if [ $? -eq 0 ]; then
        print_info "动态库编译成功: libsqlite3_${arch}.dylib"
    else
        print_error "动态库编译失败"
        exit 1
    fi
}

# 编译 SQLite3 静态库
build_sqlite3_static() {
    local arch=$1
    
    print_info "编译 SQLite3 静态库 (架构: $arch)"
    
    # 设置编译标志
    local cflags="-DSQLITE_CORE \
                  -DSQLITE_THREADSAFE=1 \
                  -DSQLITE_ENABLE_FTS3 \
                  -DSQLITE_ENABLE_FTS4 \
                  -DSQLITE_ENABLE_RTREE \
                  -DSQLITE_ENABLE_JSON1 \
                  -DSQLITE_ENABLE_COLUMN_METADATA \
                  -DSQLITE_SECURE_DELETE \
                  -DSQLITE_TEMP_STORE=2 \
                  -DSQLITE_VEC_STATIC=1 \
                  -O3"
    
    # 根据架构设置特定编译选项
    case $arch in
        "x86_64")
            cflags="$cflags -arch x86_64 -mmacosx-version-min=10.15"
            ;;
        "arm64")
            cflags="$cflags -arch arm64 -mmacosx-version-min=11.0"
            ;;
    esac
    
    # 编译目标文件
    clang $cflags -c build/sqlite3.c -o "sqlite3_${arch}.o"
    clang $cflags -c build/sqlite-vec.c -o "sqlite-vec_${arch}.o"
    
    # 创建静态库
    ar rcs "libs/macos/libsqlite3_${arch}.a" "sqlite3_${arch}.o" "sqlite-vec_${arch}.o"
    
    # 清理临时文件
    rm -f "sqlite3_${arch}.o" "sqlite-vec_${arch}.o"
    
    if [ $? -eq 0 ]; then
        print_info "静态库编译成功: libsqlite3_${arch}.a"
    else
        print_error "静态库编译失败"
        exit 1
    fi
}

# 创建通用二进制文件 (Universal Binary)
create_universal_binary() {
    print_info "创建通用二进制文件..."
    
    # 检查是否存在两个架构的库
    if [ -f "libs/macos/libsqlite3_x86_64.dylib" ] && [ -f "libs/macos/libsqlite3_arm64.dylib" ]; then
        lipo -create \
             "libs/macos/libsqlite3_x86_64.dylib" \
             "libs/macos/libsqlite3_arm64.dylib" \
             -output "libs/macos/libsqlite3.dylib"
        print_info "通用动态库创建成功: libsqlite3.dylib"
    fi
    
    if [ -f "libs/macos/libsqlite3_x86_64.a" ] && [ -f "libs/macos/libsqlite3_arm64.a" ]; then
        lipo -create \
             "libs/macos/libsqlite3_x86_64.a" \
             "libs/macos/libsqlite3_arm64.a" \
             -output "libs/macos/libsqlite3.a"
        print_info "通用静态库创建成功: libsqlite3.a"
    fi
}

# 编译命令行工具
build_sqlite3_cli() {
    local arch=$(detect_architecture)
    
    print_info "编译 SQLite3 命令行工具（包含 SQLite-vec）..."
    
    
    local cflags="-O3 \
                  -DSQLITE_THREADSAFE=0 \
                  -DSQLITE_OMIT_LOAD_EXTENSION \
                  -DSQLITE_CORE \
                  -DSQLITE_VEC_STATIC=1"
    
    case $arch in
        "x86_64")
            cflags="$cflags -arch x86_64 -mmacosx-version-min=10.15"
            ;;
        "arm64")
            cflags="$cflags -arch arm64 -mmacosx-version-min=11.0"
            ;;
    esac
    
    clang $cflags \
          -o "libs/macos/sqlite3" \
          build/shell.c build/sqlite3.c build/sqlite-vec.c \
          -lm
    
    if [ $? -eq 0 ]; then
        print_info "命令行工具编译成功: sqlite3"
        chmod +x "libs/macos/sqlite3"
    else
        print_warning "命令行工具编译失败（非致命错误）"
    fi
}

# 复制头文件
copy_headers() {
    print_info "复制头文件..."
    cp build/sqlite3.h libs/macos/
    cp build/sqlite3ext.h libs/macos/
    if [ -f build/sqlite-vec.h ]; then
        cp build/sqlite-vec.h libs/macos/
    fi
}

# 显示库信息
show_lib_info() {
    print_info "编译完成的库信息:"
    
    if [ -d "libs/macos" ]; then
        print_info "macOS 库:"
        for lib in libs/macos/*; do
            if [ -f "$lib" ]; then
                local filename=$(basename "$lib")
                local size=$(du -h "$lib" | cut -f1)
                local arch_info=""
                
                # 检查架构信息
                if [[ "$filename" == *.dylib ]] || [[ "$filename" == *.a ]]; then
                    arch_info=$(lipo -info "$lib" 2>/dev/null | sed 's/.*: //' || echo "未知")
                    print_info "  $filename: $size (架构: $arch_info)"
                elif [[ "$filename" == "sqlite3" ]]; then
                    arch_info=$(lipo -info "$lib" 2>/dev/null | sed 's/.*: //' || echo "未知")
                    print_info "  $filename: $size (可执行文件, 架构: $arch_info)"
                else
                    print_info "  $filename: $size"
                fi
            fi
        done
    fi
}

# 主函数
main() {
    print_info "SQLite3 macOS 编译脚本"
    print_info "========================"
    
    local build_universal=${1:-"true"}
    local current_arch=$(detect_architecture)
    
    print_info "当前系统架构: $current_arch"
    
    # 检查编译工具
    check_build_tools
    
    # 下载源码
    download_sqlite
    
    # 清理输出目录
    clean_output
    
    if [ "$build_universal" = "true" ]; then
        print_info "构建通用二进制文件（支持 x86_64 和 arm64）"
        
        # 编译两种架构
        for arch in x86_64 arm64; do
            build_sqlite3_dylib $arch
            build_sqlite3_static $arch
        done
        
        # 创建通用二进制文件
        create_universal_binary
    else
        print_info "构建当前架构二进制文件: $current_arch"
        build_sqlite3_dylib $current_arch
        build_sqlite3_static $current_arch
    fi
    
    # 编译命令行工具
    build_sqlite3_cli
    
    # 复制头文件
    copy_headers
    
    # 显示库信息
    show_lib_info
    
    print_info "macOS 编译完成！"
    print_info "库文件位置: libs/macos/"
}

# 运行主函数
main "$@"

#!/bin/bash

# SQLite3 Jetson Orin Nano (Ubuntu 22.04) 编译脚本
# 专门为 ARM64 架构优化，支持 NVIDIA Jetson 平台

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
    nproc
}

# 检测系统架构和平台
detect_platform() {
    local arch=$(uname -m)
    local os=$(uname -s)
    local platform_info=""
    
    if [ "$os" != "Linux" ]; then
        print_error "此脚本仅支持 Linux 系统"
        exit 1
    fi
    
    if [ "$arch" != "aarch64" ]; then
        print_error "此脚本仅支持 ARM64 (aarch64) 架构"
        print_error "当前架构: $arch"
        exit 1
    fi
    
    # 检测是否为 Jetson 平台
    if [ -f "/etc/nv_tegra_release" ]; then
        local jetson_version=$(cat /etc/nv_tegra_release | grep -oP 'R\d+' | head -1)
        platform_info="NVIDIA Jetson (JetPack $jetson_version)"
    elif grep -q "tegra" /proc/cpuinfo 2>/dev/null; then
        platform_info="NVIDIA Jetson (未知版本)"
    else
        platform_info="通用 ARM64 Linux"
    fi
    
    print_info "平台信息: $platform_info"
    print_info "系统架构: $arch"
}

# 检查编译工具和依赖
check_build_tools() {
    print_info "检查编译工具和依赖..."
    
    # 检查基础编译工具
    local missing_tools=()
    for tool in gcc g++ make wget unzip ar; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "缺少必要的编译工具: ${missing_tools[*]}"
        print_info "请安装必要工具:"
        print_info "sudo apt update"
        print_info "sudo apt install build-essential wget unzip"
        exit 1
    fi
    
    # 检查 GCC 版本
    local gcc_version=$(gcc --version | head -n1 | grep -oP '\d+\.\d+' | head -1)
    print_info "GCC 版本: $gcc_version"
    
    # 检查 NEON 支持
    if grep -q "asimd" /proc/cpuinfo; then
        print_info "检测到 ARM NEON (Advanced SIMD) 支持"
    else
        print_warning "未检测到 ARM NEON 支持，性能可能受影响"
    fi
    
    print_info "编译工具检查完成"
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
    rm -rf libs/jetson
    mkdir -p libs/jetson
}

# 编译 SQLite3 共享库 (.so)
build_sqlite3_shared() {
    local cpu_cores=$(get_cpu_cores)
    
    print_info "编译 SQLite3 共享库..."
    
    # 针对 ARM64/Jetson 优化的编译标志
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
                  -DSQLITE_VEC_ENABLE_NEON \
                  -O3 \
                  -fPIC \
                  -march=armv8-a \
                  -mtune=cortex-a78 \
                  -mfpu=neon-fp-armv8"
    
    # 检查是否为 Jetson 平台，添加特定优化
    if [ -f "/etc/nv_tegra_release" ]; then
        cflags="$cflags -DJETSON_PLATFORM=1"
        print_info "启用 Jetson 平台特定优化"
    fi
    
    # 编译共享库
    gcc $cflags \
        -shared \
        -Wl,-soname,libsqlite3.so.0 \
        -o "libs/jetson/libsqlite3.so.0.8.6" \
        build/sqlite3.c build/sqlite-vec.c \
        -lm -lpthread -ldl
    
    if [ $? -eq 0 ]; then
        # 创建符号链接
        cd libs/jetson
        ln -sf libsqlite3.so.0.8.6 libsqlite3.so.0
        ln -sf libsqlite3.so.0 libsqlite3.so
        cd ../..
        
        print_info "共享库编译成功: libsqlite3.so"
    else
        print_error "共享库编译失败"
        exit 1
    fi
}

# 编译 SQLite3 静态库 (.a)
build_sqlite3_static() {
    print_info "编译 SQLite3 静态库..."
    
    # 针对 ARM64/Jetson 优化的编译标志
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
                  -DSQLITE_VEC_ENABLE_NEON \
                  -O3 \
                  -march=armv8-a \
                  -mtune=cortex-a78 \
                  -mfpu=neon-fp-armv8"
    
    # 检查是否为 Jetson 平台
    if [ -f "/etc/nv_tegra_release" ]; then
        cflags="$cflags -DJETSON_PLATFORM=1"
    fi
    
    # 编译目标文件
    gcc $cflags -c build/sqlite3.c -o sqlite3_jetson.o
    gcc $cflags -c build/sqlite-vec.c -o sqlite-vec_jetson.o
    
    # 创建静态库
    ar rcs libs/jetson/libsqlite3.a sqlite3_jetson.o sqlite-vec_jetson.o
    
    # 清理临时文件
    rm -f sqlite3_jetson.o sqlite-vec_jetson.o
    
    if [ $? -eq 0 ]; then
        print_info "静态库编译成功: libsqlite3.a"
    else
        print_error "静态库编译失败"
        exit 1
    fi
}

# 编译命令行工具
build_sqlite3_cli() {
    print_info "编译 SQLite3 命令行工具..."
    
    local cflags="-O3 \
                  -DSQLITE_THREADSAFE=0 \
                  -DSQLITE_OMIT_LOAD_EXTENSION \
                  -DSQLITE_VEC_STATIC=1 \
                  -DSQLITE_VEC_ENABLE_NEON \
                  -march=armv8-a \
                  -mtune=cortex-a78 \
                  -mfpu=neon-fp-armv8"
    
    # 检查是否为 Jetson 平台
    if [ -f "/etc/nv_tegra_release" ]; then
        cflags="$cflags -DJETSON_PLATFORM=1"
    fi
    
    gcc $cflags \
        -o "libs/jetson/sqlite3" \
        build/shell.c build/sqlite3.c build/sqlite-vec.c \
        -lm -lpthread -ldl
    
    if [ $? -eq 0 ]; then
        print_info "命令行工具编译成功: sqlite3"
        chmod +x "libs/jetson/sqlite3"
    else
        print_warning "命令行工具编译失败（非致命错误）"
    fi
}

# 复制头文件
copy_headers() {
    print_info "复制头文件..."
    cp build/sqlite3.h libs/jetson/
    cp build/sqlite3ext.h libs/jetson/
    if [ -f build/sqlite-vec.h ]; then
        cp build/sqlite-vec.h libs/jetson/
    fi
}

# 创建 pkg-config 文件
create_pkgconfig() {
    print_info "创建 pkg-config 文件..."
    
    local prefix="/usr/local"
    local version="3.50.2"
    
    cat > libs/jetson/sqlite3.pc << EOF
prefix=$prefix
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: SQLite3
Description: SQL database engine with vector extensions
Version: $version
Libs: -L\${libdir} -lsqlite3
Libs.private: -lm -lpthread -ldl
Cflags: -I\${includedir}
EOF
    
    print_info "pkg-config 文件创建完成: sqlite3.pc"
}

# 运行基本功能测试
run_basic_test() {
    print_info "运行基本功能测试..."
    
    if [ -f "libs/jetson/sqlite3" ]; then
        # 创建临时测试数据库
        local test_db="/tmp/sqlite3_test.db"
        rm -f "$test_db"
        
        # 测试基本SQL功能
        echo "CREATE TABLE test(id INTEGER PRIMARY KEY, name TEXT);" | "./libs/jetson/sqlite3" "$test_db"
        echo "INSERT INTO test(name) VALUES('Jetson Orin Nano');" | "./libs/jetson/sqlite3" "$test_db"
        
        local result=$(echo "SELECT name FROM test WHERE id=1;" | "./libs/jetson/sqlite3" "$test_db")
        
        if [ "$result" = "Jetson Orin Nano" ]; then
            print_info "基本功能测试通过"
        else
            print_warning "基本功能测试失败"
        fi
        
        # 清理测试文件
        rm -f "$test_db"
    else
        print_warning "跳过功能测试（命令行工具不可用）"
    fi
}

# 显示库信息
show_lib_info() {
    print_info "编译完成的库信息:"
    
    if [ -d "libs/jetson" ]; then
        print_info "Jetson Orin Nano 库:"
        for lib in libs/jetson/*; do
            if [ -f "$lib" ]; then
                local filename=$(basename "$lib")
                local size=$(du -h "$lib" | cut -f1)
                
                # 显示详细信息
                if [[ "$filename" == *.so* ]]; then
                    local arch_info=$(file "$lib" | grep -o "ARM aarch64" || echo "未知")
                    print_info "  $filename: $size (共享库, $arch_info)"
                elif [[ "$filename" == *.a ]]; then
                    local arch_info=$(file "$lib" | grep -o "ARM aarch64" || echo "未知")
                    print_info "  $filename: $size (静态库, $arch_info)"
                elif [[ "$filename" == "sqlite3" ]]; then
                    local arch_info=$(file "$lib" | grep -o "ARM aarch64" || echo "未知")
                    print_info "  $filename: $size (可执行文件, $arch_info)"
                else
                    print_info "  $filename: $size"
                fi
            fi
        done
    fi
}

# 显示安装说明
show_install_instructions() {
    print_info ""
    print_info "=========================================="
    print_info "Jetson Orin Nano 安装说明"
    print_info "=========================================="
    print_info ""
    print_info "1. 安装库文件到系统："
    print_info "   sudo cp libs/jetson/libsqlite3.so* /usr/local/lib/"
    print_info "   sudo cp libs/jetson/libsqlite3.a /usr/local/lib/"
    print_info "   sudo ldconfig"
    print_info ""
    print_info "2. 安装头文件："
    print_info "   sudo cp libs/jetson/sqlite3.h /usr/local/include/"
    print_info "   sudo cp libs/jetson/sqlite3ext.h /usr/local/include/"
    print_info "   sudo cp libs/jetson/sqlite-vec.h /usr/local/include/"
    print_info ""
    print_info "3. 安装 pkg-config 文件："
    print_info "   sudo cp libs/jetson/sqlite3.pc /usr/local/lib/pkgconfig/"
    print_info ""
    print_info "4. 安装命令行工具（可选）："
    print_info "   sudo cp libs/jetson/sqlite3 /usr/local/bin/"
    print_info ""
    print_info "5. 在 C/C++ 项目中使用："
    print_info "   编译: gcc -o myapp myapp.c \$(pkg-config --cflags --libs sqlite3)"
    print_info "   或者: gcc -o myapp myapp.c -lsqlite3"
    print_info ""
}

# 主函数
main() {
    print_info "SQLite3 Jetson Orin Nano 编译脚本"
    print_info "=================================="
    
    # 检测平台
    detect_platform
    
    # 检查编译工具
    check_build_tools
    
    # 下载源码
    download_sqlite
    
    # 清理输出目录
    clean_output
    
    # 编译库文件
    build_sqlite3_shared
    build_sqlite3_static
    
    # 编译命令行工具
    build_sqlite3_cli
    
    # 复制头文件
    copy_headers
    
    # 创建 pkg-config 文件
    create_pkgconfig
    
    # 运行基本测试
    run_basic_test
    
    # 显示库信息
    show_lib_info
    
    # 显示安装说明
    show_install_instructions
    
    print_info "Jetson Orin Nano 编译完成！"
    print_info "库文件位置: libs/jetson/"
}

# 运行主函数
main "$@"

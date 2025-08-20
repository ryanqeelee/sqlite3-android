#!/bin/bash

# SQLite3 自动平台检测和构建脚本
# 根据当前运行环境自动选择合适的构建方式

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# 检测当前操作系统
detect_os() {
    local os=$(uname -s)
    case $os in
        "Darwin")
            echo "macos"
            ;;
        "Linux")
            echo "linux"
            ;;
        "CYGWIN"*|"MINGW"*|"MSYS"*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 检测 CPU 架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        "x86_64"|"amd64")
            echo "x86_64"
            ;;
        "arm64"|"aarch64")
            echo "arm64"
            ;;
        "armv7l")
            echo "armv7"
            ;;
        "i386"|"i686")
            echo "i386"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# 检测是否为 Jetson 平台
is_jetson_platform() {
    if [ -f "/etc/nv_tegra_release" ]; then
        return 0  # 是 Jetson 平台
    elif grep -q "tegra" /proc/cpuinfo 2>/dev/null; then
        return 0  # 可能是 Jetson 平台
    else
        return 1  # 不是 Jetson 平台
    fi
}

# 检测 Android NDK
check_android_ndk() {
    if command -v ndk-build &> /dev/null; then
        return 0  # NDK 可用
    elif [ -n "$NDK_ROOT" ] && [ -f "$NDK_ROOT/ndk-build" ]; then
        export PATH="$NDK_ROOT:$PATH"
        return 0  # NDK 可用
    elif [ -n "$ANDROID_NDK_ROOT" ] && [ -f "$ANDROID_NDK_ROOT/ndk-build" ]; then
        export PATH="$ANDROID_NDK_ROOT:$PATH"
        return 0  # NDK 可用
    else
        return 1  # NDK 不可用
    fi
}

# 检测 macOS 构建工具
check_macos_tools() {
    if command -v clang &> /dev/null && command -v lipo &> /dev/null; then
        return 0  # macOS 工具可用
    else
        return 1  # macOS 工具不可用
    fi
}

# 检测 Linux 构建工具
check_linux_tools() {
    if command -v gcc &> /dev/null && command -v make &> /dev/null; then
        return 0  # Linux 工具可用
    else
        return 1  # Linux 工具不可用
    fi
}

# 平台检测主函数（静默版本，仅返回平台名称）
detect_platform_silent() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    # 根据操作系统和架构确定平台
    case $os in
        "macos")
            if check_macos_tools; then
                echo "mac"
            else
                return 1
            fi
            ;;
        "linux")
            if [ "$arch" = "arm64" ] && is_jetson_platform; then
                if check_linux_tools; then
                    echo "jetson"
                else
                    return 1
                fi
            elif check_linux_tools; then
                echo "linux"
            else
                return 1
            fi
            ;;
        "windows")
            if check_android_ndk; then
                echo "android"
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# 平台检测主函数（带输出信息）
detect_platform() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    print_header "平台检测结果"
    print_info "操作系统: $os"
    print_info "CPU 架构: $arch"
    
    # 根据操作系统和架构确定平台
    case $os in
        "macos")
            if check_macos_tools; then
                echo "mac"
            else
                print_error "macOS 构建工具不可用（需要 Xcode 命令行工具）"
                return 1
            fi
            ;;
        "linux")
            if [ "$arch" = "arm64" ] && is_jetson_platform; then
                print_info "检测到 NVIDIA Jetson 平台"
                if check_linux_tools; then
                    echo "jetson"
                else
                    print_error "Linux 构建工具不可用（需要 build-essential）"
                    return 1
                fi
            elif check_linux_tools; then
                print_info "检测到通用 Linux 平台"
                echo "linux"
            else
                print_error "Linux 构建工具不可用（需要 build-essential）"
                return 1
            fi
            ;;
        "windows")
            print_warning "Windows 平台需要特殊配置"
            if check_android_ndk; then
                print_info "检测到 Android NDK，将构建 Android 版本"
                echo "android"
            else
                print_error "Windows 平台暂不支持原生构建"
                return 1
            fi
            ;;
        *)
            print_error "不支持的操作系统: $os"
            return 1
            ;;
    esac
}

# 显示构建选项
show_build_options() {
    local detected_platform=$1
    
    print_header "可用的构建选项"
    
    echo "1. 自动构建 (推荐) - 构建检测到的平台: $detected_platform"
    
    echo "2. 指定平台构建:"
    
    # 检查各平台可用性
    local available_platforms=()
    
    # 检查 macOS
    if [ "$(detect_os)" = "macos" ] && check_macos_tools; then
        available_platforms+=("mac")
        echo "   - mac: macOS 原生构建 (Intel + Apple Silicon)"
    fi
    
    # 检查 Linux/Jetson
    if [ "$(detect_os)" = "linux" ] && check_linux_tools; then
        if is_jetson_platform; then
            available_platforms+=("jetson")
            echo "   - jetson: Jetson Orin Nano 优化构建"
        fi
        available_platforms+=("linux")
        echo "   - linux: 通用 Linux 构建"
    fi
    
    # 检查 Android NDK
    if check_android_ndk; then
        available_platforms+=("android")
        echo "   - android: Android NDK 构建 (ARM32/ARM64)"
    fi
    
    echo "3. 构建所有可用平台"
    echo "4. 显示详细平台信息"
    echo "5. 退出"
    
    return 0
}

# 执行构建
execute_build() {
    local platform=$1
    local build_options=$2
    
    print_header "开始构建 $platform 平台"
    
    case $platform in
        "mac")
            print_info "执行 macOS 构建..."
            if [ "$build_options" = "universal" ]; then
                ./build_sqlite3_mac.sh true
            else
                ./build_sqlite3_mac.sh false
            fi
            ;;
        "jetson")
            print_info "执行 Jetson Orin Nano 构建..."
            ./build_sqlite3_jetson.sh
            ;;
        "linux")
            print_info "执行通用 Linux 构建..."
            # 使用 Jetson 脚本，但跳过 Jetson 特定优化
            ./build_sqlite3_jetson.sh
            ;;
        "android")
            print_info "执行 Android 构建..."
            make android
            ;;
        *)
            print_error "不支持的平台: $platform"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_info "$platform 平台构建成功!"
        return 0
    else
        print_error "$platform 平台构建失败!"
        return 1
    fi
}

# 显示详细平台信息
show_platform_info() {
    print_header "详细平台信息"
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    echo "基本信息:"
    echo "  操作系统: $os ($(uname -s))"
    echo "  CPU 架构: $arch ($(uname -m))"
    echo "  内核版本: $(uname -r)"
    
    if [ "$os" = "linux" ] && [ -f "/etc/os-release" ]; then
        echo "  Linux 发行版: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    fi
    
    if [ "$os" = "macos" ]; then
        echo "  macOS 版本: $(sw_vers -productVersion)"
    fi
    
    # 检查 Jetson 平台
    if is_jetson_platform; then
        echo ""
        echo "NVIDIA Jetson 信息:"
        if [ -f "/etc/nv_tegra_release" ]; then
            echo "  Tegra 版本: $(cat /etc/nv_tegra_release)"
        fi
        if command -v jetson_clocks &> /dev/null; then
            echo "  Jetson 工具: 可用"
        fi
    fi
    
    echo ""
    echo "构建工具可用性:"
    
    # 检查 Android NDK
    if check_android_ndk; then
        local ndk_version=$(ndk-build --version 2>/dev/null | head -1 || echo "未知版本")
        echo "  Android NDK: ✓ ($ndk_version)"
    else
        echo "  Android NDK: ✗"
    fi
    
    # 检查 macOS 工具
    if [ "$os" = "macos" ]; then
        if check_macos_tools; then
            local xcode_version=$(xcodebuild -version 2>/dev/null | head -1 || echo "命令行工具")
            echo "  Xcode 工具: ✓ ($xcode_version)"
        else
            echo "  Xcode 工具: ✗"
        fi
    fi
    
    # 检查 Linux 工具
    if [ "$os" = "linux" ]; then
        if check_linux_tools; then
            local gcc_version=$(gcc --version | head -1)
            echo "  GCC 编译器: ✓ ($gcc_version)"
        else
            echo "  GCC 编译器: ✗"
        fi
    fi
    
    echo ""
}

# 交互式构建选择
interactive_build() {
    local detected_platform
    detected_platform=$(detect_platform_silent)
    
    if [ $? -ne 0 ]; then
        print_error "平台检测失败"
        return 1
    fi
    
    # 显示平台检测结果
    local os=$(detect_os)
    local arch=$(detect_arch)
    print_header "平台检测结果"
    print_info "操作系统: $os"
    print_info "CPU 架构: $arch"
    print_info "检测到平台: $detected_platform"
    
    while true; do
        echo ""
        show_build_options "$detected_platform"
        echo ""
        read -p "请选择构建选项 (1-5): " choice
        
        case $choice in
            1)
                execute_build "$detected_platform"
                break
                ;;
            2)
                echo ""
                read -p "请输入平台名称 (mac/jetson/linux/android): " platform
                execute_build "$platform"
                break
                ;;
            3)
                print_info "构建所有可用平台..."
                make all
                break
                ;;
            4)
                show_platform_info
                ;;
            5)
                print_info "退出构建"
                exit 0
                ;;
            *)
                print_warning "无效选择，请重新输入"
                ;;
        esac
    done
}

# 主函数
main() {
    print_header "SQLite3 自动构建系统"
    print_info "正在检测当前平台..."
    
    # 检查参数
    if [ $# -eq 0 ]; then
        # 交互式模式
        interactive_build
    else
        case $1 in
            "detect")
                detected_platform=$(detect_platform_silent)
                if [ $? -eq 0 ]; then
                    echo "$detected_platform"
                else
                    exit 1
                fi
                ;;
            "info")
                show_platform_info
                ;;
            "auto")
                detected_platform=$(detect_platform_silent)
                if [ $? -eq 0 ]; then
                    print_info "检测到平台: $detected_platform"
                    execute_build "$detected_platform"
                else
                    print_error "平台检测失败"
                    exit 1
                fi
                ;;
            *)
                execute_build "$1"
                ;;
        esac
    fi
}

# 运行主函数
main "$@"

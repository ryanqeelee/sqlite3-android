# SQLite3 多平台构建 Makefile
# 支持 Android, macOS, Jetson Orin Nano 平台
#
.DEFAULT_GOAL		:= help
SQLITE_AMALGATION	:= sqlite-amalgamation-3500200
SQLITE_SOURCEURL	:= https://sqlite.org/2025/$(SQLITE_AMALGATION).zip
# TARGET ABI := armeabi armeabi-v7a arm64-v8a x86 x86_64 mips mips64 (or all)
TARGET_ABI		:= armeabi-v7a
URL_DOWNLOADER	:= wget -c
# URL_DOWNLOADER		:= aria2c -q -c -x 3
CHECK_NDKPATH		:= $(shell which ndk-build >/dev/null 2>&1 ; echo $$?)

# 平台检测
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# 根据平台设置默认目标
ifeq ($(UNAME_S),Darwin)
    DEFAULT_PLATFORM := mac
else ifeq ($(UNAME_S),Linux)
    ifeq ($(UNAME_M),aarch64)
        # 检查是否为 Jetson 平台
        ifneq ($(wildcard /etc/nv_tegra_release),)
            DEFAULT_PLATFORM := jetson
        else
            DEFAULT_PLATFORM := linux-arm64
        endif
    else
        DEFAULT_PLATFORM := linux
    endif
else
    DEFAULT_PLATFORM := android
endif


check-ndk-path:
ifneq ($(CHECK_NDKPATH), 0)
	$(error Cannot find ndk-build in $(PATH). Make sure Android NDK directory is included in your $$PATH variable)
endif

download: check-ndk-path
	@echo "===> Downloading file $(SQLITE_SOURCEURL)"
	@test ! -s "$(SQLITE_AMALGATION).zip" && \
		$(URL_DOWNLOADER) "$(SQLITE_SOURCEURL)" || \
		echo "===> File $(SQLITE_AMALGATION).zip already exists... skipping download."

unpack: download
	@echo "===> Unpacking $(SQLITE_AMALGATION).zip"
	@unzip -qo "$(SQLITE_AMALGATION).zip"
	@mv "$(SQLITE_AMALGATION)" build

# 帮助信息
help:
	@echo "SQLite3 多平台构建系统"
	@echo "======================"
	@echo ""
	@echo "支持的平台："
	@echo "  android  - Android NDK 构建 (ARM32/ARM64)"
	@echo "  mac      - macOS 构建 (Intel/Apple Silicon)"
	@echo "  jetson   - Jetson Orin Nano 构建 (ARM64)"
	@echo "  auto     - 自动检测平台构建"
	@echo ""
	@echo "使用方法："
	@echo "  make android         - 构建 Android 版本"
	@echo "  make mac             - 构建 macOS 版本"
	@echo "  make jetson          - 构建 Jetson 版本"
	@echo "  make auto            - 自动检测并构建"
	@echo "  make all             - 构建所有支持的平台"
	@echo "  make clean           - 清理构建文件"
	@echo "  make clean-all       - 清理所有文件（包括源码）"
	@echo ""
	@echo "当前检测到的平台: $(DEFAULT_PLATFORM)"
	@echo ""

# 自动检测平台构建
auto:
	@echo "===> 自动检测平台: $(DEFAULT_PLATFORM)"
	@$(MAKE) $(DEFAULT_PLATFORM)

# Android 平台构建
android: unpack check-ndk-path
	@echo "===> Building $(SQLITE_AMALGATION) for Android"
	@ndk-build NDK_DEBUG=0 APP_ABI="$(TARGET_ABI)"

# Android 构建（兼容原有接口）
build: android

# macOS 平台构建
mac: unpack-source
	@echo "===> Building $(SQLITE_AMALGATION) for macOS"
	@./build_sqlite3_mac.sh

# Jetson 平台构建
jetson: unpack-source
	@echo "===> Building $(SQLITE_AMALGATION) for Jetson Orin Nano"
	@./build_sqlite3_jetson.sh

# 仅解压源码（不检查 NDK）
unpack-source: download-source
	@echo "===> Unpacking $(SQLITE_AMALGATION).zip"
	@unzip -qo "$(SQLITE_AMALGATION).zip"
	@mv "$(SQLITE_AMALGATION)" build

# 仅下载源码（不检查 NDK）
download-source:
	@echo "===> Downloading file $(SQLITE_SOURCEURL)"
	@test ! -s "$(SQLITE_AMALGATION).zip" && \
		$(URL_DOWNLOADER) "$(SQLITE_SOURCEURL)" || \
		echo "===> File $(SQLITE_AMALGATION).zip already exists... skipping download."

# 构建所有平台（需要相应环境）
all: unpack-source
	@echo "===> Building for all platforms"
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		echo "Building macOS version..."; \
		./build_sqlite3_mac.sh; \
	fi
	@if command -v ndk-build >/dev/null 2>&1; then \
		echo "Building Android version..."; \
		ndk-build NDK_DEBUG=0 APP_ABI="$(TARGET_ABI)"; \
	else \
		echo "Skipping Android build (NDK not found)"; \
	fi
	@echo "Note: Jetson build requires Jetson hardware or cross-compilation setup"

clean:
	@echo "===> Cleaning up $(SQLITE_AMALGATION), build, libs, and obj directory"
	@rm -rf "$(SQLITE_AMALGATION)" build obj libs

clean-all: clean
	@echo "===> Deleting $(SQLITE_AMALGATION).zip"
	@rm -f "$(SQLITE_AMALGATION).zip"

APP_PLATFORM := android-16
APP_PIE := true

# 添加编译选项支持
# 使用 SQLITE_VEC_STATIC=1 进行静态编译（当前方式）
# 使用 SQLITE_VEC_STATIC=0 进行分离编译（传统方式）
SQLITE_VEC_STATIC ?= 1

LOCAL_PATH := $(call my-dir)

ifeq ($(SQLITE_VEC_STATIC),1)
# 静态编译模式 - 编译到一起（推荐用于移动端）
include $(CLEAR_VARS)
LOCAL_MODULE            := sqlite3
LOCAL_MODULE_FILENAME   := libsqlite3
LOCAL_SRC_FILES         := ../build/sqlite3.c ../build/sqlite-vec.c
LOCAL_C_INCLUDES        := ../build
LOCAL_EXPORT_C_INCLUDES := ../build

# 基础编译选项
LOCAL_CFLAGS            := -DSQLITE_CORE \
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
                          -O3

# 针对不同架构的条件编译
# ARMv7: 启用 NEON 优化，使用 ARMv7 兼容版本
ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
    LOCAL_CFLAGS += -mfpu=neon -mfloat-abi=softfp
    LOCAL_ARM_NEON := true
endif

# ARM64: 启用 NEON 优化，使用 ARMv8 原版本
ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
    LOCAL_CFLAGS += -march=armv8-a
endif

LOCAL_LDLIBS            := -llog -lm
include $(BUILD_SHARED_LIBRARY)

# 编译 SQLite3 命令行工具 (可选)
include $(CLEAR_VARS)
LOCAL_MODULE            := sqlite3-cli
LOCAL_MODULE_FILENAME   := sqlite3
LOCAL_STATIC_LIBRARIES  := sqlite3
LOCAL_SRC_FILES         := ../build/shell.c
LOCAL_C_INCLUDES        := ../build
LOCAL_CFLAGS            := -O3 -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION
LOCAL_LDLIBS            := -llog
include $(BUILD_EXECUTABLE)

else
# 分离编译模式 - 符合传统惯例
include $(CLEAR_VARS)
LOCAL_MODULE            := sqlite3
LOCAL_MODULE_FILENAME   := libsqlite3
LOCAL_SRC_FILES         := ../build/sqlite3.c
LOCAL_C_INCLUDES        := ../build
LOCAL_EXPORT_C_INCLUDES := ../build

LOCAL_CFLAGS            := -DSQLITE_CORE \
                          -DSQLITE_THREADSAFE=1 \
                          -DSQLITE_ENABLE_FTS3 \
                          -DSQLITE_ENABLE_FTS4 \
                          -DSQLITE_ENABLE_RTREE \
                          -DSQLITE_ENABLE_JSON1 \
                          -DSQLITE_ENABLE_COLUMN_METADATA \
                          -DSQLITE_SECURE_DELETE \
                          -DSQLITE_TEMP_STORE=2 \
                          -O3

include $(BUILD_SHARED_LIBRARY)

# SQLite-vec 扩展库
include $(CLEAR_VARS)
LOCAL_MODULE            := sqlite-vec
LOCAL_MODULE_FILENAME   := libsqlite-vec
LOCAL_SRC_FILES         := ../build/sqlite-vec.c
LOCAL_C_INCLUDES        := ../build
LOCAL_SHARED_LIBRARIES  := sqlite3

LOCAL_CFLAGS            := -DSQLITE_VEC_ENABLE_NEON \
                          -O3

# 针对不同架构的条件编译
ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
LOCAL_CFLAGS += -mfloat-abi=softfp -mfpu=neon
LOCAL_ARM_NEON := true
endif

ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
LOCAL_CFLAGS += -O3
endif

include $(BUILD_SHARED_LIBRARY)
endif

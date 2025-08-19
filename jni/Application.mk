APP_PLATFORM	:= android-16
APP_PIE		:= true

# 支持 armv7 (armeabi-v7a) 和 armv8 (arm64-v8a) 架构
APP_ABI := armeabi-v7a arm64-v8a

# 设置 STL 库
APP_STL := c++_static

# 优化设置
APP_CPPFLAGS := -frtti -fexceptions
APP_LDFLAGS := -llog

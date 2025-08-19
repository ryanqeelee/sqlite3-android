# SQLite3 Android 集成指南

## 编译结果

成功编译生成的 SQLite3 共享库文件：

### 文件列表
```
libs/
├── armeabi-v7a/
│   ├── libsqlite3.so (1.0M)
│   └── sqlite3 (命令行工具)
└── arm64-v8a/
    ├── libsqlite3.so (1.5M)
    └── sqlite3 (命令行工具)
```

### 库特性
- **线程安全**: 启用 SQLITE_THREADSAFE=1
- **全文搜索**: 支持 FTS3、FTS4
- **空间索引**: 支持 R-Tree
- **JSON 支持**: 启用 JSON1 扩展
- **列元数据**: 启用 COLUMN_METADATA
- **安全删除**: 启用 SECURE_DELETE
- **内存存储**: 设置 TEMP_STORE=2

## 集成到 Android 项目

### 方法一：使用 Android Studio (推荐)

1. **复制库文件**
   ```bash
   # 在您的 Android 项目根目录下
   mkdir -p app/src/main/jniLibs/armeabi-v7a
   mkdir -p app/src/main/jniLibs/arm64-v8a
   
   # 复制 .so 文件
   cp libs/armeabi-v7a/libsqlite3.so app/src/main/jniLibs/armeabi-v7a/
   cp libs/arm64-v8a/libsqlite3.so app/src/main/jniLibs/arm64-v8a/
   ```

2. **复制头文件**
   ```bash
   mkdir -p app/src/main/cpp/include
   cp build/sqlite3.h app/src/main/cpp/include/
   cp build/sqlite3ext.h app/src/main/cpp/include/
   ```

3. **配置 CMakeLists.txt**
   ```cmake
   cmake_minimum_required(VERSION 3.18.1)
   project("yourproject")
   
   # 添加预构建的 SQLite3 库
   add_library(sqlite3 SHARED IMPORTED)
   set_target_properties(sqlite3 PROPERTIES
       IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libsqlite3.so)
   
   # 包含头文件目录
   include_directories(include)
   
   # 您的本地库
   add_library(yourproject SHARED
       yourproject.cpp)
   
   # 链接库
   target_link_libraries(yourproject
       sqlite3
       android
       log)
   ```

4. **在 C++ 代码中使用**
   ```cpp
   #include <sqlite3.h>
   #include <android/log.h>
   
   extern "C" JNIEXPORT jstring JNICALL
   Java_com_yourpackage_MainActivity_testSQLite(JNIEnv *env, jobject /* this */) {
       sqlite3 *db;
       char *errMsg = 0;
       int rc;
       
       // 打开数据库
       rc = sqlite3_open("/data/data/com.yourpackage/databases/test.db", &db);
       if (rc) {
           __android_log_print(ANDROID_LOG_ERROR, "SQLite", "Can't open database: %s", sqlite3_errmsg(db));
           return env->NewStringUTF("Error opening database");
       }
       
       // 创建表
       const char *sql = "CREATE TABLE IF NOT EXISTS test(id INTEGER PRIMARY KEY, name TEXT);";
       rc = sqlite3_exec(db, sql, 0, 0, &errMsg);
       if (rc != SQLITE_OK) {
           __android_log_print(ANDROID_LOG_ERROR, "SQLite", "SQL error: %s", errMsg);
           sqlite3_free(errMsg);
           sqlite3_close(db);
           return env->NewStringUTF("Error creating table");
       }
       
       sqlite3_close(db);
       return env->NewStringUTF("SQLite test successful");
   }
   ```

### 方法二：使用 Gradle 配置

1. **在 `app/build.gradle` 中配置**
   ```gradle
   android {
       compileSdkVersion 34
       
       defaultConfig {
           // ...
           ndk {
               abiFilters 'armeabi-v7a', 'arm64-v8a'
           }
       }
       
       sourceSets {
           main {
               jniLibs.srcDirs = ['src/main/jniLibs']
           }
       }
   }
   ```

### 方法三：使用现有的 ndk-build 项目

1. **复制到现有项目**
   ```bash
   # 复制 .so 文件到您的项目
   cp libs/armeabi-v7a/libsqlite3.so /path/to/your/project/libs/armeabi-v7a/
   cp libs/arm64-v8a/libsqlite3.so /path/to/your/project/libs/arm64-v8a/
   
   # 复制头文件
   cp build/sqlite3.h /path/to/your/project/jni/
   cp build/sqlite3ext.h /path/to/your/project/jni/
   ```

2. **在 Android.mk 中添加**
   ```makefile
   LOCAL_PATH := $(call my-dir)
   
   # 预构建的 SQLite3 库
   include $(CLEAR_VARS)
   LOCAL_MODULE := sqlite3
   LOCAL_SRC_FILES := ../libs/$(TARGET_ARCH_ABI)/libsqlite3.so
   include $(PREBUILT_SHARED_LIBRARY)
   
   # 您的模块
   include $(CLEAR_VARS)
   LOCAL_MODULE := yourmodule
   LOCAL_SRC_FILES := yourmodule.c
   LOCAL_SHARED_LIBRARIES := sqlite3
   include $(BUILD_SHARED_LIBRARY)
   ```

## Java/Kotlin 中使用

### 1. 加载本地库
```java
public class SQLiteHelper {
    static {
        System.loadLibrary("sqlite3");
        System.loadLibrary("yourproject");
    }
    
    public native String testSQLite();
}
```

### 2. 权限配置
在 `AndroidManifest.xml` 中添加：
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 验证集成

### 检查库是否正确加载
```java
public class MainActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        try {
            SQLiteHelper helper = new SQLiteHelper();
            String result = helper.testSQLite();
            Log.d("SQLite", "Test result: " + result);
        } catch (UnsatisfiedLinkError e) {
            Log.e("SQLite", "Error loading library: " + e.getMessage());
        }
    }
}
```

## 常见问题

### 1. 库文件找不到
- 确保 .so 文件在正确的 `jniLibs` 目录下
- 检查 `abiFilters` 配置是否正确

### 2. 符号未定义
- 确保包含了正确的头文件 `sqlite3.h`
- 检查链接库配置是否正确

### 3. 运行时崩溃
- 检查数据库文件路径权限
- 确保在主线程中调用 SQLite 函数

## 性能优化建议

1. **使用连接池**: 避免频繁打开/关闭数据库
2. **批量操作**: 使用事务处理大量数据
3. **索引优化**: 为查询字段添加合适的索引
4. **预编译语句**: 使用 `sqlite3_prepare_v2()` 预编译常用查询

## 文件大小

- armeabi-v7a: `libsqlite3.so` ≈ 1.0MB
- arm64-v8a: `libsqlite3.so` ≈ 1.5MB

总计 APK 增加约 2.5MB

---

**编译环境**: Android NDK 28.0.13004108
**SQLite 版本**: 3.50.2
**支持架构**: armeabi-v7a, arm64-v8a
**最低 Android 版本**: API 21 (Android 5.0) 
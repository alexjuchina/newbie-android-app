# Newbie Android App

这是一个基于 Flutter 开发的 Android 应用，复刻了 `newbie-app-version` 的核心功能，支持直接在安卓手机上运行并调用火山引擎 API。

## 功能特性

1.  **EP 对话 (Chat)**
    - 支持流式输出 (SSE)。
    - 支持切换模型 (Doubao, DeepSeek 等)。
    - 聊天记录展示。

2.  **即梦 AI 生图 (Image Generation)**
    - 支持文生图。
    - 自动签名鉴权 (AWS V4 Signature)。
    - 结果图片展示。

3.  **配置管理**
    - 支持在 App 内配置 `API Key` (用于对话) 和 `Access Key` / `Secret Key` (用于生图)。
    - 配置持久化保存。

## 目录结构

```
lib/
├── config/
│   └── config_store.dart    # 配置存储 (SharedPreferences)
├── services/
│   └── volc_api.dart        # API 调用逻辑 (HTTP, SSE)
├── utils/
│   └── sign_v4.dart         # 签名工具 (HMAC-SHA256)
├── screens/
│   ├── chat_screen.dart     # 对话页面
│   ├── image_screen.dart    # 生图页面
│   └── settings_screen.dart # 设置页面
└── main.dart                # 程序入口
```

## 运行指南

### 1. 环境准备
确保你的电脑已安装 Flutter 开发环境：
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Android Studio (用于 Android 模拟器或连接真机)

### 2. 获取依赖
在终端进入本目录 (`newbie-android-app`)，运行：
```bash
flutter pub get
```

### 3. 运行应用
连接你的 Android 手机或启动模拟器，运行：
```bash
flutter run
```

### 4. 打包 APK
如果需要生成安装包 (APK) 发送给手机安装：
```bash
flutter build apk --release
```
生成的 APK 文件位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 配置说明
首次启动应用后，请先进入 **"配置"** 页面：
1.  输入 **ARK_API_KEY**：用于对话功能。
2.  输入 **Access Key** 和 **Secret Key**：用于即梦 AI 生图功能。
3.  点击保存。

# 火山方舟野生应用 - Newbie Android App

这是一款基于 Flutter 开发的火山方舟野生应用，支持在安卓手机上直接调用火山引擎 API，提供便捷的 AI 交互体验。

## 核心功能

### 🔹 EP 对话
- 支持 Doubao、DeepSeek 等主流模型
- 实时流式输出 (SSE)
- 聊天记录管理

### 🔹 即梦 AI 生图
- 文生图功能支持
- 自动签名鉴权
- 生成结果展示

### 🔹 配置管理
- 内置 API Key 配置
- Access Key/Secret Key 管理
- 配置持久化保存

## 快速开始

### 1. 环境准备
- Flutter SDK
- Android Studio

### 2. 运行应用
```bash
# 获取依赖
flutter pub get

# 运行应用
flutter run

# 打包 APK
flutter build apk --release
```

### 3. 应用配置
首次启动后，进入"配置"页面：
1. 输入 ARK_API_KEY (对话功能)
2. 输入 Access Key/Secret Key (生图功能)
3. 点击保存

## 项目结构

```
lib/
├── config/          # 配置存储
├── services/        # API 调用逻辑
├── utils/           # 签名工具
├── screens/         # 页面组件
└── main.dart        # 程序入口
```

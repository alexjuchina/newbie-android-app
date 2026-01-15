# 火山方舟野生应用 - Newbie Android App

这是一款基于 Flutter 开发的跨平台 AI 应用，专为火山引擎火山方舟平台设计，支持在安卓、iOS 等多种设备上直接调用火山引擎的各类 AI API，提供便捷、高效的 AI 交互体验。

## 项目背景

火山方舟是火山引擎推出的大模型服务平台，提供丰富的 AI 模型和 API 接口。本应用旨在简化开发者和用户使用火山引擎 AI 能力的流程，无需复杂的后端开发，即可在移动设备上直接体验和调用各类 AI 服务。

## 核心功能

### 🔹 AI 对话系统
- **多模型支持**：集成 Doubao、DeepSeek、GPT 等主流大语言模型
- **深度思考模式**：支持推理模型的思维链展示（Thinking Chain），可配置推理强度
- **实时流式输出**：基于 SSE (Server-Sent Events) 技术实现实时对话响应
- **智能上下文管理**：自动维护对话历史，支持上下文关联
- **聊天记录持久化**：本地保存聊天历史，支持查看和管理

### 🔹 即梦 AI 生图
- **多模型支持**：支持 Seedream 和即梦 AI 两种生图模型
- **文生图功能**：支持通过文字描述生成高质量图片
- **智能鉴权**：自动处理火山引擎 API 的签名认证流程
- **图片预览与保存**：支持生成结果的实时预览和本地保存
- **多风格支持**：可选择不同的图片生成风格

### 🔹 AI 视频功能
- **视频生成预览**：集成火山引擎视频生成 API
- **实时状态反馈**：显示视频生成进度和状态
- **视频播放与保存**：支持生成视频的播放和本地保存

### 🔹 配置管理中心
- **API 密钥管理**：安全存储和管理各类 API 密钥
- **多环境支持**：可切换不同的 API 环境（开发/生产）
- **配置持久化**：本地加密保存配置信息，确保安全性
- **一键导入导出**：支持配置的备份和恢复

## 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.16+ | 跨平台应用框架 |
| Dart | 3.2+ | 开发语言 |
| VolcEngine SDK | 最新 | 火山引擎 API 调用 |
| Provider | 6.0+ | 状态管理 |
| Hive | 2.2+ | 本地数据存储 |
| Dio | 5.0+ | 网络请求 |
| Flutter Secure Storage | 8.0+ | 安全密钥存储 |

## 快速开始

### 1. 环境准备

#### 安装 Flutter SDK
1. 下载并安装 Flutter SDK：[Flutter 官方下载页](https://flutter.dev/docs/get-started/install)
2. 配置 Flutter 环境变量
3. 运行 `flutter doctor` 检查环境配置

#### 安装开发工具
- **Android Studio**：用于 Android 应用开发和调试
- **Xcode**（可选）：用于 iOS 应用开发和调试
- **VS Code**（推荐）：轻量级代码编辑器，支持 Flutter 插件

#### 依赖安装
```bash
# 确保 Flutter 环境正常
flutter doctor

# 获取项目依赖
flutter pub get
```

### 2. 运行应用

#### 运行到 Android 设备
```bash
# 连接 Android 设备并开启 USB 调试
# 运行应用
flutter run
```

#### 运行到 iOS 设备
```bash
# 连接 iOS 设备并配置开发者证书
# 运行应用
flutter run
```

### 3. 打包应用

#### 打包 Android APK
```bash
# 构建 release 版本 APK
flutter build apk --release

# 构建 appbundle（推荐用于 Google Play）
flutter build appbundle
```

#### 打包 iOS IPA
```bash
# 构建 release 版本 IPA
flutter build ios --release
```

### 4. 应用配置

首次启动应用后，进入"配置"页面完成以下设置：

1. **对话功能配置**
   - 输入 `ARK_API_KEY`：用于调用火山方舟对话 API
   - 选择默认模型：设置常用的对话模型

2. **生图功能配置**
   - 输入 `Access Key`：火山引擎账号的访问密钥
   - 输入 `Secret Key`：火山引擎账号的秘密密钥

3. **视频功能配置**
   - 启用/禁用视频生成功能
   - 配置视频生成参数

4. 点击"保存"按钮，配置将自动持久化保存

## 项目结构

```
lib/
├── config/           # 配置管理模块
│   └── config_store.dart   # 配置存储和管理
├── screens/          # 页面组件
│   ├── chat_screen.dart    # 聊天对话页面
│   ├── image_screen.dart   # 图片生成页面
│   ├── video_screen.dart   # 视频生成页面
│   └── settings_screen.dart # 设置页面
├── services/         # API 服务层
│   └── volc_api.dart       # 火山引擎 API 调用封装
├── stores/           # 状态管理
│   └── chat_store.dart     # 聊天状态管理
├── utils/            # 工具类
│   └── sign_v4.dart        # API 签名工具
└── main.dart         # 应用入口文件
```

### 核心文件说明

- **`main.dart`**：应用入口，配置全局状态和路由
- **`config/config_store.dart`**：管理应用配置，包括 API 密钥等敏感信息
- **`services/volc_api.dart`**：封装火山引擎各类 API 调用，处理网络请求和响应
- **`screens/chat_screen.dart`**：实现聊天界面和对话逻辑，支持实时流式输出
- **`screens/image_screen.dart`**：实现图片生成界面和逻辑
- **`utils/sign_v4.dart`**：实现火山引擎 API 的 V4 签名算法

## 注意事项

1. **API 密钥安全**
   - 请勿将 API 密钥硬编码到代码中
   - 生产环境建议使用更安全的密钥管理方案
   - 定期更换密钥，确保账户安全

2. **网络权限**
   - 确保应用已获得网络访问权限
   - 部分功能需要稳定的网络连接

3. **性能优化**
   - 图片和视频生成可能消耗较多资源
   - 建议在性能较好的设备上使用
   - 大文件生成时请耐心等待

## 故障排除

### 1. 无法连接 API
- 检查网络连接是否正常
- 验证 API 密钥是否正确
- 检查火山引擎账号是否有足够的配额

### 2. 生成内容失败
- 检查输入内容是否符合模型要求
- 确认 API 配额是否充足
- 查看应用日志获取详细错误信息

### 3. 应用崩溃
- 确保 Flutter 环境和依赖版本兼容
- 检查设备内存是否充足
- 查看崩溃日志定位问题

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目！

### 开发流程
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

### 代码规范
- 遵循 Flutter 和 Dart 的官方代码规范
- 使用 meaningful 的变量和函数命名
- 添加必要的注释说明复杂逻辑
- 确保代码通过所有测试

## 许可证

本项目采用 MIT 许可证，详情请查看 [LICENSE](LICENSE) 文件。

## 联系方式

如有问题或建议，请通过以下方式联系我们：

- 项目 Issues：[GitHub Issues](https://github.com/your-username/newbie-android-app/issues)
- 邮箱：your-email@example.com
- 微信：your-wechat

---

**感谢使用火山方舟野生应用！** 🚀

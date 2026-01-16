# 火山方舟野生 APP（安卓版）

一款用 Flutter写的安卓APP，主要用来在手机上直接调火山方舟的对话 / 生图 / 视频相关能力。

## 能做什么

- AI 对话：支持多模型（Doubao、DeepSeek、GPT 等），流式输出，带上下文和本地聊天记录。
- 文生图：接入 Seedream、即梦 AI，根据文字生成图片，可预览、保存、选风格。
- 视频生成：调用火山引擎视频生成接口，查看生成进度，播放和保存结果。
- 配置中心：统一管理各种 Key 和环境，配置本地持久化存储。

## 环境要求

- Flutter 3.16+（Dart 3.2+）
- Android Studio（调试 Android）
- Xcode（如需真机 / 模拟器调试 iOS）

## 快速开始

1. 安装 Flutter 并配置好环境变量，保证下面命令正常：

   ```bash
   flutter doctor
   ```

2. 拉依赖：

   ```bash
   flutter pub get
   ```

3. 运行到真机或模拟器：

   ```bash
   # Android 或 iOS（根据已连接设备自动选择）
   flutter run
   ```

## 打包

- Android APK（本地安装用）：

  ```bash
  flutter build apk --release
  ```

- Android AppBundle（上架商店用）：

  ```bash
  flutter build appbundle
  ```

- iOS Release 构建（后续在 Xcode 里导出 IPA）：

  ```bash
  flutter build ios --release
  ```

## 必要配置

首次启动，进入「配置」页面，最少需要设置：

1. 对话相关：
   - ARK_API_KEY：调用火山方舟对话 API 用。
   - 选择默认模型。

2. 生图相关：
   - Access Key / Secret Key：火山引擎账号的访问密钥。

3. 视频相关（如果要用视频功能）：
   - 开关视频生成功能。
   - 视情况调整参数。

配置保存后会本地持久化，下次打开应用会自动读取。

## 项目结构（简版）

```text
lib/
├── config/              配置管理
├── screens/             页面（聊天 / 图片 / 视频 / 设置）
├── services/            调用火山引擎 API
├── stores/              状态管理
├── utils/               工具（如签名算法）
└── main.dart            入口
```

## 开发和贡献

- Fork 仓库，基于新分支开发。
- 改完提 PR 即可，保持代码通过格式检查和基本测试。

## 许可证

MIT，见仓库中的 LICENSE 文件。

## 反馈

- 有问题直接提 Issue，或者发邮件联系 alexju@foxmail.com

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/config_store.dart';
import '../services/volc_api.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _resultVideoUrl;
  String? _errorMessage;
  
  // Seedance 配置
  String _seedanceModel = 'doubao-seedance-1-5-pro-251215';
  String _seedanceRatio = '16:9';
  int _seedanceDuration = 5;
  
  // Seedance 模型列表
  final List<String> _seedanceModels = [
    'doubao-seedance-1-5-pro-251215',
    'doubao-seedance-1-0-pro-fast-251015',
    'doubao-seedance-1-0-pro-250528',
    'doubao-seedance-1-0-lite-t2v-250428',
    'doubao-seedance-1-0-lite-i2v-250428',
  ];
  
  // Seedance 比例列表
  final List<String> _seedanceRatios = [
    '自适应',
    '16:9',
    '9:16',
    '1:1',
    '4:3',
    '3:4',
  ];
  
  // Seedance 时长列表
  final List<int> _seedanceDurations = [5, 10];
  
  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    final config = context.read<ConfigStore>();
    
    // 检查 Ark API Key 配置
    if (!config.hasArkConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 Ark API Key')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resultVideoUrl = null;
    });

    try {
      // 使用 Seedance 视频生成
      final result = await VolcApi.generateSeedanceVideo(
        apiKey: config.arkApiKey,
        prompt: prompt,
        model: _seedanceModel,
        ratio: _getRatioValue(_seedanceRatio),
        duration: _seedanceDuration,
      );

      // 处理不同的结果格式
      dynamic videoData;
      if (result.containsKey('data')) {
        videoData = result['data'];
      } else if (result.containsKey('url')) {
        videoData = {'url': result['url']};
      }
      
      if (videoData != null && videoData['url'] != null) {
        setState(() {
          _resultVideoUrl = videoData['url'];
        });
      } else {
        setState(() {
          _errorMessage = '生成成功但未返回视频链接';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '生成失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 将显示的比例转换为API需要的参数值
  String _getRatioValue(String displayRatio) {
    switch (displayRatio) {
      case '自适应':
        return 'adaptive';
      case '16:9':
        return '16:9';
      case '9:16':
        return '9:16';
      case '1:1':
        return '1:1';
      case '4:3':
        return '4:3';
      case '3:4':
        return '3:4';
      default:
        return '16:9';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Seedance 生视频'),
        backgroundColor: colorScheme.surface,
        elevation: 2,
        surfaceTintColor: colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seedance 配置选项
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '视频生成配置',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 模型选择
                    DropdownButtonFormField<String>(
                      initialValue: _seedanceModel,
                      decoration: InputDecoration(
                        labelText: '模型',
                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                      ),
                      items: _seedanceModels
                          .map((model) => DropdownMenuItem(
                                value: model,
                                child: Text(model),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _seedanceModel = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // 比例选择
                    DropdownButtonFormField<String>(
                      initialValue: _seedanceRatio,
                      decoration: InputDecoration(
                        labelText: '比例',
                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                      ),
                      items: _seedanceRatios
                          .map((ratio) => DropdownMenuItem(
                                value: ratio,
                                child: Text(ratio),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _seedanceRatio = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // 时长选择
                    DropdownButtonFormField<int>(
                      initialValue: _seedanceDuration,
                      decoration: InputDecoration(
                        labelText: '时长（秒）',
                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                      ),
                      items: _seedanceDurations
                          .map((duration) => DropdownMenuItem(
                                value: duration,
                                child: Text('$duration秒'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _seedanceDuration = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 提示词输入卡片
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '视频描述',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '描述你想要生成的视频...',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colorScheme.primary, width: 1),
                        ),
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      maxLines: 4,
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 生成按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), // Web版本按钮颜色
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('开始生成视频'),
            ),
            
            const SizedBox(height: 24),
            
            // 结果展示区域
            if (_resultVideoUrl != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '生成结果',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_resultVideoUrl != null)
                        AspectRatio(
                          aspectRatio: _getAspectRatio(_seedanceRatio),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outline),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.video_library, size: 64),
                                const SizedBox(height: 12),
                                Text(
                                  '视频链接',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _resultVideoUrl!, 
                                  style: TextStyle(color: colorScheme.primary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          // 这里可以添加复制链接或打开视频的功能
                          // 例如使用 url_launcher 打开视频链接
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('打开视频'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (_errorMessage != null)
              Card(
                color: colorScheme.errorContainer,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '错误信息',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!, 
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // 获取比例对应的宽高比
  double _getAspectRatio(String ratio) {
    switch (ratio) {
      case '16:9':
        return 16 / 9;
      case '9:16':
        return 9 / 16;
      case '1:1':
        return 1;
      case '4:3':
        return 4 / 3;
      case '3:4':
        return 3 / 4;
      default:
        return 16 / 9; // 默认16:9
    }
  }
}

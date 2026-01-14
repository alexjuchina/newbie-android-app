import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../config/config_store.dart';
import '../services/volc_api.dart';

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _resultImageUrl;
  String? _errorMessage;
  String _selectedModelType = 'seedream'; // seedream/jimeng
  
  // Seedream 配置
  String _seedreamModel = 'doubao-seedream-4-5-251128';
  String _seedreamSize = '16:9 (2560x1440)';
  bool _seedreamWatermark = false;
  final int _seedreamMaxImages = 1;
  
  // Seedream 模型列表
  final List<String> _seedreamModels = [
    'doubao-seedream-4-5-251128',
    'doubao-seedream-4-0-250828',
  ];
  
  // Seedream 尺寸列表
  final List<String> _seedreamSizes = [
    '1K(不支持4.5)',
    '2K',
    '4K',
    '1:1 (2048x2048)',
    '1:1 (4096x4096)',
    '4:3 (2304x1728)',
    '3:4 (1728x2304)',
    '16:9 (2560x1440)',
    '9:16 (1440x2560)',
    '3:2 (2496x1664)',
    '2:3 (1664x2496)',
    '21:9 (3024x1296)',
  ];

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    final config = context.read<ConfigStore>();
    
    // 检查相应的配置是否存在
    if (_selectedModelType == 'seedream') {
      if (!config.hasArkConfig) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先配置 Ark API Key')),
        );
        return;
      }
    } else {
      if (!config.hasJimengConfig) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先配置即梦 AK/SK')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resultImageUrl = null;
    });

    try {
      if (_selectedModelType == 'seedream') {
        // 使用 Seedream 图片生成
        final result = await VolcApi.generateSeedreamImage(
          apiKey: config.arkApiKey,
          prompt: prompt,
          model: _seedreamModel,
          size: _seedreamSize,
          watermark: _seedreamWatermark,
          maxImages: _seedreamMaxImages,
        );

        final data = result['data'];
        if (data != null && data is List && data.isNotEmpty) {
          setState(() {
            _resultImageUrl = data[0]['url'];
          });
        } else {
          setState(() {
            _errorMessage = '生成成功但未返回图片链接';
          });
        }
      } else {
        // 使用即梦 AI 图片生成
        final result = await VolcApi.generateImage(
          accessKey: config.jimengAccessKey,
          secretKey: config.jimengSecretKey,
          prompt: prompt,
        );

        final urls = result['image_urls'];
        if (urls != null && urls is List && urls.isNotEmpty) {
          setState(() {
            _resultImageUrl = urls[0];
          });
        } else {
          setState(() {
            _errorMessage = '生成成功但未返回图片链接';
          });
        }
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

  /// 保存图片到相册
  Future<void> _saveImage() async {
    if (_resultImageUrl == null) return;

    bool hasPermission = false;
    
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ use photos permission (READ_MEDIA_IMAGES)
        // Note: For saving to MediaStore, we might not strictly need this if just adding,
        // but it's good practice or required by some plugins.
        // Actually for saving, Android 10+ doesn't require WRITE_EXTERNAL_STORAGE.
        // But let's try to get a valid permission status.
        final status = await Permission.photos.request();
        hasPermission = status.isGranted || status.isLimited;
      } else {
        // Android < 13 use storage permission
        final status = await Permission.storage.request();
        hasPermission = status.isGranted;
      }
    } else {
      // iOS
      final status = await Permission.photos.request();
      hasPermission = status.isGranted || status.isLimited;
    }

    // Attempt to save even if permission is denied, as some Android versions allow saving to MediaStore without permission
    // But show warning if it fails.
    
    if (hasPermission || (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 29)) {
      try {
        setState(() {
          _isLoading = true;
        });

        // 下载图片
        final response = await http.get(Uri.parse(_resultImageUrl!));
        if (response.statusCode == 200) {
          // 保存图片到相册
          final result = await ImageGallerySaver.saveImage(
            response.bodyBytes,
            quality: 100,
            name: 'seedream_image_${DateTime.now().millisecondsSinceEpoch}',
          );

          if (mounted) {
            if (result['isSuccess'] == true || result['isSuccess'] == 'true') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('图片已保存到相册'), duration: Duration(milliseconds: 1500)),
              );
            } else {
              throw Exception('保存失败: ${result['errorMessage']}');
            }
          }
        } else {
          throw Exception('图片下载失败');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e'), duration: const Duration(milliseconds: 2000)),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要存储权限才能保存图片')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('图片生成'),
        backgroundColor: colorScheme.surface,
        elevation: 2,
        surfaceTintColor: colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 模型选择切换
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '选择模型',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'seedream',
                          label: Text('Seedream'),
                        ),
                        ButtonSegment<String>(
                          value: 'jimeng',
                          label: Text('即梦 AI'),
                        ),
                      ],
                      selected: <String>{_selectedModelType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedModelType = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Seedream 配置选项
            if (_selectedModelType == 'seedream')
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Seedream 配置',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 模型选择
                      DropdownButtonFormField<String>(
                        initialValue: _seedreamModel,
                        decoration: InputDecoration(
                          labelText: '模型',
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                        ),
                        items: _seedreamModels
                            .map((model) => DropdownMenuItem(
                                  value: model,
                                  child: Text(model),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _seedreamModel = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // 尺寸选择
                      DropdownButtonFormField<String>(
                        initialValue: _seedreamSize,
                        decoration: InputDecoration(
                          labelText: '尺寸',
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                        ),
                        items: _seedreamSizes
                            .map((size) => DropdownMenuItem(
                                  value: size,
                                  child: Text(size),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _seedreamSize = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // 水印选择
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '添加水印',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          Switch(
                            value: _seedreamWatermark,
                            onChanged: (value) {
                              setState(() {
                                _seedreamWatermark = value;
                              });
                            },
                            activeThumbColor: colorScheme.primary,
                          ),
                        ],
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
                      '图片描述',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '描述你想要生成的图片...',
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
                  : Text(_selectedModelType == 'seedream' ? '开始生成图片' : '开始生成'),
            ),
            
            const SizedBox(height: 24),
            
            // 结果展示区域
            if (_errorMessage != null)
              Card(
                color: colorScheme.errorContainer,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            
            if (_resultImageUrl != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '生成结果',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _resultImageUrl!, 
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 300,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 200,
                                alignment: Alignment.center,
                                child: Text(
                                  '图片加载失败',
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _saveImage,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('保存到相册'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
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
}

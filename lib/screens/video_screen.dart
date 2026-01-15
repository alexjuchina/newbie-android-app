import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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
  String? _statusMessage; // 任务状态提示
  String? _resultVideoUrl;
  String? _errorMessage;
  Map<String, dynamic>? _statistics;
  Timer? _timer;
  double _elapsedSeconds = 0.0;
  
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  // Seedance 配置
  String _seedanceModel = 'doubao-seedance-1-5-pro-251215';
  String _seedanceRatio = '16:9';
  int _seedanceDuration = 5;
  String _generationMode = 'text_to_video'; // text_to_video, first_frame, first_last_frame, reference_image

  // Image Inputs
  XFile? _firstFrame;
  XFile? _lastFrame;
  List<XFile> _referenceImages = [];
  final ImagePicker _picker = ImagePicker();
  
  // Seedance 模型列表
  final List<String> _seedanceModels = [
    'doubao-seedance-1-5-pro-251215',
    'doubao-seedance-1-0-pro-fast-251015',
    'doubao-seedance-1-0-pro-250528',
    'doubao-seedance-1-0-lite-t2v-250428',
    'doubao-seedance-1-0-lite-i2v-250428',
  ];
  
  // Generation Modes
  final Map<String, String> _generationModes = {
    'text_to_video': '文生视频',
    'first_frame': '图生视频-首帧',
    'first_last_frame': '图生视频-首尾帧',
    'reference_image': '图生视频-参考图',
  };

  // Get available modes for current model
  List<String> get _availableModes {
    if (_seedanceModel.contains('lite-t2v')) {
      return ['text_to_video'];
    } else if (_seedanceModel.contains('lite-i2v')) {
      return ['first_frame', 'first_last_frame', 'reference_image'];
    } else if (_seedanceModel.contains('pro-fast')) {
      return ['text_to_video', 'first_frame'];
    } else {
      // 1.5 pro and 1.0 pro
      return ['text_to_video', 'first_frame', 'first_last_frame'];
    }
  }
  
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
  
  @override
  void initState() {
    super.initState();
    _updateModeSelection();
  }

  void _updateModeSelection() {
    if (!_availableModes.contains(_generationMode)) {
      setState(() {
        _generationMode = _availableModes.first;
      });
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      if (type == 'reference') {
        if (_referenceImages.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最多只能上传4张参考图')),
          );
          return;
        }
        final List<XFile> images = await _picker.pickMultiImage();
        if (images.isNotEmpty) {
          setState(() {
            _referenceImages.addAll(images);
            if (_referenceImages.length > 4) {
              _referenceImages = _referenceImages.sublist(0, 4);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已截取前4张图片')),
              );
            }
          });
        }
      } else {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          setState(() {
            if (type == 'first') {
              _firstFrame = image;
            } else if (type == 'last') {
              _lastFrame = image;
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  void _removeImage(String type, [int index = 0]) {
    setState(() {
      if (type == 'first') {
        _firstFrame = null;
      } else if (type == 'last') {
        _lastFrame = null;
      } else if (type == 'reference') {
        _referenceImages.removeAt(index);
      }
    });
  }

  Future<String> _imageToBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    final mimeType = lookupMimeType(file.path) ?? 'image/png';
    return 'data:$mimeType;base64,$base64String';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _initializePlayer(String videoUrl) async {
    // 销毁旧控制器
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoPlayerController = controller;

    try {
      await controller.initialize();
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: true,
        aspectRatio: controller.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              '视频加载失败: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      setState(() {
        _errorMessage = '视频播放器初始化失败: $e';
      });
    }
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    // Prompt is optional for some image-to-video modes, but generally good to have. 
    // Docs say text prompt is optional for i2v, but let's keep it simple for now.
    // Actually docs say text is optional for i2v. 
    
    final config = context.read<ConfigStore>();
    
    // 检查 Ark API Key 配置
    if (!config.hasArkConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 Ark API Key')),
      );
      return;
    }

    // Validate images
    if (_generationMode == 'first_frame' && _firstFrame == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请上传首帧图片')),
      );
      return;
    }
    if (_generationMode == 'first_last_frame' && (_firstFrame == null || _lastFrame == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请上传首帧和尾帧图片')),
      );
      return;
    }
    if (_generationMode == 'reference_image' && _referenceImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请上传至少一张参考图')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resultVideoUrl = null;
      _statusMessage = '正在提交任务...'; // 初始状态
      
      // 清理播放器
      _videoPlayerController?.dispose();
      _chewieController?.dispose();
      _videoPlayerController = null;
      _chewieController = null;
    });

    try {
      // Prepare images
      List<Map<String, String>>? images;
      if (_generationMode != 'text_to_video') {
        images = [];
        if (_generationMode == 'first_frame' || _generationMode == 'first_last_frame') {
          if (_firstFrame != null) {
            images.add({
              'base64': await _imageToBase64(_firstFrame!),
              'role': 'first_frame',
            });
          }
        }
        if (_generationMode == 'first_last_frame') {
          if (_lastFrame != null) {
            images.add({
              'base64': await _imageToBase64(_lastFrame!),
              'role': 'last_frame',
            });
          }
        }
        if (_generationMode == 'reference_image') {
          for (var img in _referenceImages) {
            images.add({
              'base64': await _imageToBase64(img),
              'role': 'reference_image',
            });
          }
        }
      }

      setState(() {
        _statusMessage = '任务已提交，正在生成中... (预计需几分钟)';
      });

      final result = await VolcApi.generateSeedanceVideo(
        apiKey: config.arkApiKey,
        prompt: prompt,
        model: _seedanceModel,
        ratio: _getRatioValue(_seedanceRatio),
        duration: _seedanceDuration,
        images: images,
      );

      print('Video Generation Result: $result'); // 打印原始返回结果

      // 处理不同的结果格式
      String? videoUrl;
      if (result.containsKey('content') && result['content'] != null) {
        // 新版 API 结构: content.video_url
        videoUrl = result['content']['video_url'];
      } else if (result.containsKey('data')) {
        // 旧版或兼容结构
        final data = result['data'];
        if (data is Map && data.containsKey('video_url')) {
          videoUrl = data['video_url'];
        } else if (data is Map && data.containsKey('url')) {
          videoUrl = data['url'];
        }
      } else if (result.containsKey('url')) {
        videoUrl = result['url'];
      }
      
      if (videoUrl != null) {
        setState(() {
          _resultVideoUrl = videoUrl;
          _statusMessage = '生成成功！';
        });
        await _initializePlayer(videoUrl);
      } else {
        setState(() {
          _errorMessage = '生成成功但未返回视频链接: $result';
          _statusMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '生成失败: $e';
        _statusMessage = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveVideo() async {
    if (_resultVideoUrl == null) return;

    bool hasPermission = false;
    
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ use videos permission
        final status = await Permission.videos.request();
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
    
    // Android 10+ (API 29+) can save to MediaStore without WRITE_EXTERNAL_STORAGE
    if (hasPermission || (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 29)) {
      try {
        setState(() {
          _isLoading = true;
          _statusMessage = '正在下载视频...';
        });

        // 1. Download video to temporary file
        final response = await http.get(Uri.parse(_resultVideoUrl!));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final savePath = '${tempDir.path}/seedance_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final file = File(savePath);
          await file.writeAsBytes(response.bodyBytes);

          // 2. Save to gallery
          setState(() {
            _statusMessage = '正在保存到相册...';
          });
          
          final result = await ImageGallerySaver.saveFile(savePath);
          
          // Clean up temp file
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}

          if (mounted) {
            if (result['isSuccess'] == true || result['isSuccess'] == 'true') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('视频已保存到相册'), duration: Duration(milliseconds: 1500)),
              );
            } else {
              throw Exception('保存失败: ${result['errorMessage']}');
            }
          }
        } else {
          throw Exception('视频下载失败');
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
            _statusMessage = null;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要存储权限才能保存视频')),
        );
      }
    }
  }

  // Widget Helpers
  Widget _buildImagePicker(String label, XFile? image, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickImage(type),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: image != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(
                                image.path,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(image.path),
                                fit: BoxFit.contain,
                              ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: () => _removeImage(type),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('点击上传图片', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceImagesPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('参考图片 (最多4张)', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._referenceImages.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(
                                image.path,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(image.path),
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: InkWell(
                        onTap: () => _removeImage('reference', index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_referenceImages.length < 4)
              InkWell(
                onTap: () => _pickImage('reference'),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: const Icon(Icons.add, color: Colors.grey),
                ),
              ),
          ],
        ),
      ],
    );
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
                            _updateModeSelection();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // 生成模式
                    DropdownButtonFormField<String>(
                      value: _generationMode,
                      decoration: InputDecoration(
                        labelText: '生成模式',
                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                      ),
                      items: _availableModes.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(_generationModes[mode] ?? mode),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _generationMode = value;
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
            
            // 图片上传
            if (_generationMode != 'text_to_video')
              Column(
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '图片上传',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          if (_generationMode == 'first_frame' || _generationMode == 'first_last_frame')
                            _buildImagePicker('首帧图片', _firstFrame, 'first'),

                          if (_generationMode == 'first_last_frame') ...[
                            const SizedBox(height: 12),
                            _buildImagePicker('尾帧图片', _lastFrame, 'last'),
                          ],

                          if (_generationMode == 'reference_image')
                            _buildReferenceImagesPicker(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            
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
            
            // 状态提示
            if (_statusMessage != null && _isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$_statusMessage${_elapsedSeconds > 0 ? ' (${_elapsedSeconds.toStringAsFixed(1)}s)' : ''}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            
            // 结果展示区域
            if (_resultVideoUrl != null || _chewieController != null)
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
                      
                      // 视频播放器区域
                      if (_chewieController != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                        AspectRatio(
                          aspectRatio: _videoPlayerController!.value.aspectRatio,
                          child: Chewie(controller: _chewieController!),
                        )
                      else if (_resultVideoUrl != null)
                         AspectRatio(
                          aspectRatio: _getAspectRatio(_seedanceRatio),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outline),
                            ),
                            child: const Center(
                                child: CircularProgressIndicator()
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),
                      
                      // 视频链接展示
                      if (_resultVideoUrl != null)
                        Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               '视频链接',
                               style: TextStyle(color: colorScheme.onSurfaceVariant),
                             ),
                             const SizedBox(height: 8),
                             SelectableText(
                               _resultVideoUrl!, 
                               style: TextStyle(color: colorScheme.primary, fontSize: 12),
                               textAlign: TextAlign.left,
                             ),
                           ],
                        ),
                        
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveVideo,
                              icon: const Icon(Icons.save_alt),
                              label: const Text('保存视频'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.secondaryContainer,
                                foregroundColor: colorScheme.onSecondaryContainer,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],
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

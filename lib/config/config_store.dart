import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 配置存储类，用于管理 API Key 和其他配置项
/// 使用 SharedPreferences 进行持久化存储
class ConfigStore extends ChangeNotifier {
  // API Key 配置
  static const String _kArkApiKey = 'ark_api_key';
  static const String _kJimengAccessKey = 'jimeng_access_key';
  static const String _kJimengSecretKey = 'jimeng_secret_key';
  
  // 模型推理配置
  static const String _kThinkingMode = 'thinking_mode';
  static const String _kReasoningEffort = 'reasoning_effort';
  static const String _kTemperature = 'temperature';
  static const String _kTopP = 'top_p';
  static const String _kMaxTokens = 'max_tokens';
  static const String _kModelEp = 'model_ep';
  static const String _kCustomModelEps = 'custom_model_eps';
  
  // 图片生成配置
  static const String _kPictureGenerationModel = 'picture_generation_model';
  static const String _kPictureGenerationSize = 'picture_generation_size';
  
  // 视频生成配置
  static const String _kVideoGenerationModel = 'video_generation_model';
  static const String _kVideoGenerationRatio = 'video_generation_ratio';

  // API Key 字段
  String _arkApiKey = '';
  String _jimengAccessKey = '';
  String _jimengSecretKey = '';
  
  // 模型推理字段
  String _thinkingMode = 'disabled'; // disabled/enabled
  String _reasoningEffort = 'medium'; // low/medium/high
  double _temperature = 0.8;
  double _topP = 0.7;
  int _maxTokens = 4094;
  String _modelEp = 'doubao-seed-1-8-251228';
  List<String> _customModelEps = [];
  
  // 图片生成字段
  String _pictureGenerationModel = 'doubao-seedream-4-5-251128';
  String _pictureGenerationSize = '16:9 (2560x1440)';
  
  // 视频生成字段
  String _videoGenerationModel = 'doubao-seedance-1-0-pro-250528';
  String _videoGenerationRatio = '16:9';

  // API Key getter
  String get arkApiKey => _arkApiKey;
  String get jimengAccessKey => _jimengAccessKey;
  String get jimengSecretKey => _jimengSecretKey;
  
  // 模型推理 getter
  String get thinkingMode => _thinkingMode;
  String get reasoningEffort => _reasoningEffort;
  double get temperature => _temperature;
  double get topP => _topP;
  int get maxTokens => _maxTokens;
  String get modelEp => _modelEp;
  List<String> get customModelEps => List.unmodifiable(_customModelEps);

  static const Map<String, String> defaultModelEpOptions = {
    "doubao-seed-1-8-251228": "Doubao-seed-1-8/251228",
    "ep-m-20251218160703-8vltr": "Doubao-seed-1-8/251215",
    "doubao-seed-1-6-251015": "Doubao-seed-1-6/251015",
    "doubao-seed-1-6-250615": "Doubao-seed-1-6/250615",
    "doubao-seed-1-6-flash-250828": "Doubao-seed-1-6-flash/250828",
    "doubao-seed-1-6-flash-250715": "Doubao-Seed-1.6-flash/250715",
    "doubao-seed-1-6-flash-250615": "Doubao-Seed-1.6-flash/250615",
    "doubao-1-5-pro-32k-250115": "Doubao-1.5-pro-32k/250115",
    "doubao-1-5-vision-pro-32k-250115": "Doubao-1.5-vision-pro-32k/250115",
    "deepseek-r1-250528": "DeepSeek-R1/250528",
  };

  String modelDisplayName(String modelEp) {
    return defaultModelEpOptions[modelEp] ?? modelEp;
  }

  List<String> get modelEpCandidates {
    final result = <String>[];
    for (final k in defaultModelEpOptions.keys) {
      result.add(k);
    }
    for (final k in _customModelEps) {
      if (!result.contains(k)) result.add(k);
    }
    if (!result.contains(_modelEp)) result.add(_modelEp);
    return result;
  }
  
  // 图片生成 getter
  String get pictureGenerationModel => _pictureGenerationModel;
  String get pictureGenerationSize => _pictureGenerationSize;
  
  // 视频生成 getter
  String get videoGenerationModel => _videoGenerationModel;
  String get videoGenerationRatio => _videoGenerationRatio;

  /// 初始化配置，从本地存储加载
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // API Key 配置
    _arkApiKey = prefs.getString(_kArkApiKey) ?? '';
    _jimengAccessKey = prefs.getString(_kJimengAccessKey) ?? '';
    _jimengSecretKey = prefs.getString(_kJimengSecretKey) ?? '';
    
    // 模型推理配置
    _thinkingMode = prefs.getString(_kThinkingMode) ?? 'disabled';
    _reasoningEffort = prefs.getString(_kReasoningEffort) ?? 'medium';
    _temperature = prefs.getDouble(_kTemperature) ?? 0.8;
    _topP = prefs.getDouble(_kTopP) ?? 0.7;
    _maxTokens = prefs.getInt(_kMaxTokens) ?? 4094;
    _modelEp = prefs.getString(_kModelEp) ?? 'doubao-seed-1-8-251228';
    _customModelEps = (prefs.getStringList(_kCustomModelEps) ?? [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    _customModelEps.sort();
    if (!defaultModelEpOptions.containsKey(_modelEp) && !_customModelEps.contains(_modelEp)) {
      _customModelEps.add(_modelEp);
      _customModelEps.sort();
      await prefs.setStringList(_kCustomModelEps, _customModelEps);
    }
    
    // 图片生成配置
    _pictureGenerationModel = prefs.getString(_kPictureGenerationModel) ?? 'doubao-seedream-4-5-251128';
    _pictureGenerationSize = prefs.getString(_kPictureGenerationSize) ?? '16:9 (2560x1440)';
    
    // 视频生成配置
    _videoGenerationModel = prefs.getString(_kVideoGenerationModel) ?? 'doubao-seedance-1-0-pro-250528';
    _videoGenerationRatio = prefs.getString(_kVideoGenerationRatio) ?? '16:9';
    
    notifyListeners();
  }

  /// 保存 Ark API Key
  Future<void> setArkApiKey(String value) async {
    _arkApiKey = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kArkApiKey, value);
    notifyListeners();
  }

  /// 保存即梦 Access Key
  Future<void> setJimengAccessKey(String value) async {
    _jimengAccessKey = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kJimengAccessKey, value);
    notifyListeners();
  }

  /// 保存即梦 Secret Key
  Future<void> setJimengSecretKey(String value) async {
    _jimengSecretKey = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kJimengSecretKey, value);
    notifyListeners();
  }
  
  /// 保存思考模式
  Future<void> setThinkingMode(String value) async {
    _thinkingMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThinkingMode, value);
    notifyListeners();
  }
  
  /// 保存思考努力程度
  Future<void> setReasoningEffort(String value) async {
    _reasoningEffort = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReasoningEffort, value);
    notifyListeners();
  }
  
  /// 保存温度参数
  Future<void> setTemperature(double value) async {
    _temperature = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTemperature, value);
    notifyListeners();
  }
  
  /// 保存 top_p 参数
  Future<void> setTopP(double value) async {
    _topP = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTopP, value);
    notifyListeners();
  }
  
  /// 保存最大 token 数
  Future<void> setMaxTokens(int value) async {
    _maxTokens = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMaxTokens, value);
    notifyListeners();
  }
  
  /// 保存模型端点
  Future<void> setModelEp(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    _modelEp = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelEp, _modelEp);
    notifyListeners();
  }

  Future<void> addCustomModelEp(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    if (defaultModelEpOptions.containsKey(v)) return;
    if (_customModelEps.contains(v)) return;
    _customModelEps = [..._customModelEps, v]..sort();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCustomModelEps, _customModelEps);
    notifyListeners();
  }

  Future<void> removeCustomModelEp(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    if (!_customModelEps.contains(v)) return;
    _customModelEps = _customModelEps.where((e) => e != v).toList()..sort();
    if (_modelEp == v) {
      _modelEp = defaultModelEpOptions.keys.first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModelEp, _modelEp);
      await prefs.setStringList(_kCustomModelEps, _customModelEps);
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCustomModelEps, _customModelEps);
    notifyListeners();
  }
  
  /// 保存图片生成模型
  Future<void> setPictureGenerationModel(String value) async {
    _pictureGenerationModel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPictureGenerationModel, value);
    notifyListeners();
  }
  
  /// 保存图片生成尺寸
  Future<void> setPictureGenerationSize(String value) async {
    _pictureGenerationSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPictureGenerationSize, value);
    notifyListeners();
  }
  
  /// 保存视频生成模型
  Future<void> setVideoGenerationModel(String value) async {
    _videoGenerationModel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVideoGenerationModel, value);
    notifyListeners();
  }
  
  /// 保存视频生成比例
  Future<void> setVideoGenerationRatio(String value) async {
    _videoGenerationRatio = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVideoGenerationRatio, value);
    notifyListeners();
  }

  /// 检查是否已配置 Ark API
  bool get hasArkConfig => _arkApiKey.isNotEmpty;

  /// 检查是否已配置即梦 API
  bool get hasJimengConfig => _jimengAccessKey.isNotEmpty && _jimengSecretKey.isNotEmpty;
}

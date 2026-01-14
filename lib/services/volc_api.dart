import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/sign_v4.dart';

class VolcApi {
  static const String _arkEndpoint = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  static const String _imageGenerationEndpoint = 'https://ark.cn-beijing.volces.com/api/v3/images/generations';
  static const String _videoGenerationEndpoint = 'https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks';
  static const String _jimengHost = 'visual.volcengineapi.com';
  static const String _jimengEndpoint = 'https://visual.volcengineapi.com';
  static const String _jimengRegion = 'cn-north-1';
  static const String _jimengService = 'cv';

  /// EP Chat 流式对话
  static Stream<String> streamChat({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.8,
    double topP = 0.7,
    int maxTokens = 4094,
    String thinkingMode = 'disabled', // disabled/enabled
    String reasoningEffort = 'medium', // low/medium/high
  }) async* {
    final request = http.Request('POST', Uri.parse(_arkEndpoint));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    
    final body = {
      'model': model,
      'messages': messages,
      'stream': true,
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
    };
    
    // 只有在启用思考模式时才发送相关参数
    if (thinkingMode == 'enabled') {
      body['thinking_mode'] = thinkingMode;
      body['reasoning_effort'] = reasoningEffort;
    } else {
      // 显式禁用
      body['thinking_mode'] = 'disabled';
    }
    
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        yield "Error: ${response.statusCode} - $errorBody";
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (data == '[DONE]') break;
          
          try {
            final json = jsonDecode(data);
            if (json['choices'] != null && json['choices'].isNotEmpty) {
              final delta = json['choices'][0]['delta'];
              
              // 优先处理思考内容 (仅在思考模式启用时)
              if (thinkingMode == 'enabled') {
                if (delta['reasoning_content'] != null) {
                  yield 'Thinking:${delta['reasoning_content']}';
                }
                else if (delta['thinking'] != null) {
                  yield 'Thinking:${delta['thinking']}';
                }
              }
              
              // 处理普通内容
              if (delta['content'] != null) {
                yield delta['content'];
              }
            }
          } catch (e) {
            // Ignore parse errors for partial chunks
          }
        }
      }
    } catch (e) {
      yield "Error: $e";
    } finally {
      client.close();
    }
  }

  /// 即梦 AI 生图 (提交任务 + 轮询)
  static Future<Map<String, dynamic>> generateImage({
    required String accessKey,
    required String secretKey,
    required String prompt,
  }) async {
    // 1. 提交任务
    final taskId = await _submitJimengTask(accessKey, secretKey, prompt);
    if (taskId == null) {
      throw Exception("任务提交失败");
    }

    // 2. 轮询结果
    return await _pollJimengResult(accessKey, secretKey, taskId);
  }

  static Future<String?> _submitJimengTask(
      String accessKey, String secretKey, String prompt) async {
    const action = 'CVSync2AsyncSubmitTask';
    const version = '2022-08-31';
    final query = {
      'Action': action,
      'Version': version,
    };
    
    final body = jsonEncode({
      "req_key": "jimeng_t2i_v40",
      "req_json": jsonEncode({"return_url": true}),
      "prompt": prompt,
      "size": 4194304 // 2K (2048x2048)
    });

    final headers = SignV4.generateHeaders(
      accessKey: accessKey,
      secretKey: secretKey,
      service: _jimengService,
      region: _jimengRegion,
      host: _jimengHost,
      path: '/',
      query: query,
      payload: body,
    );

    final uri = Uri.parse('$_jimengEndpoint?${SignV4.formatQuery(query)}');
    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['code'] == 10000) {
        return json['data']['task_id'];
      }
    }
    throw Exception("提交失败: ${response.body}");
  }

  static Future<Map<String, dynamic>> _pollJimengResult(
      String accessKey, String secretKey, String taskId) async {
    const action = 'CVSync2AsyncGetResult';
    const version = '2022-08-31';
    final query = {
      'Action': action,
      'Version': version,
    };

    final body = jsonEncode({
      "req_key": "jimeng_t2i_v40",
      "task_id": taskId,
      "req_json": jsonEncode({"return_url": true}),
    });

    int retry = 0;
    while (retry < 60) { // 最多等待 60秒
      final headers = SignV4.generateHeaders(
        accessKey: accessKey,
        secretKey: secretKey,
        service: _jimengService,
        region: _jimengRegion,
        host: _jimengHost,
        path: '/',
        query: query,
        payload: body,
      );

      final uri = Uri.parse('$_jimengEndpoint?${SignV4.formatQuery(query)}');
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 10000) {
          final status = json['data']['status'];
          if (status == 'done') {
            return json['data'];
          } else if (status == 'failed') {
            throw Exception("生成失败");
          }
        }
      }
      
      await Future.delayed(const Duration(seconds: 1));
      retry++;
    }
    throw Exception("等待超时");
  }

  /// Seedream 图片生成
  static Future<Map<String, dynamic>> generateSeedreamImage({
    required String apiKey,
    required String prompt,
    String model = 'doubao-seedream-4-5-251128',
    String size = '16:9 (2560x1440)',
    bool watermark = false,
    int maxImages = 1,
    String responseFormat = 'url',
  }) async {
    final request = http.Request('POST', Uri.parse(_imageGenerationEndpoint));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    
    // 解析尺寸字符串，提取宽高值
    String sizeValue = size;
    if (size.contains('(') && size.contains(')')) {
      sizeValue = size.substring(size.indexOf('(') + 1, size.indexOf(')'));
    }
    
    request.body = jsonEncode({
      'model': model,
      'prompt': prompt,
      'size': sizeValue,
      'watermark': watermark,
      'n': maxImages,
      'response_format': responseFormat,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception("Error: ${response.statusCode} - $errorBody");
      }

      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Seedance 视频生成 (提交任务 + 轮询)
  static Future<Map<String, dynamic>> generateSeedanceVideo({
    required String apiKey,
    required String prompt,
    String model = 'doubao-seedance-1-5-pro-251215',
    String ratio = '16:9', // adaptive/16:9/9:16/1:1/4:3/3:4
    int duration = 5, // 5/10
    String responseFormat = 'url',
  }) async {
    // 1. 提交任务获取task_id
    final taskId = await _submitVideoGenerationTask(
      apiKey: apiKey,
      prompt: prompt,
      model: model,
      ratio: ratio,
      duration: duration,
      responseFormat: responseFormat,
    );
    if (taskId == null) {
      throw Exception("视频生成任务提交失败");
    }

    // 2. 轮询任务结果
    return await _pollVideoGenerationResult(
      apiKey: apiKey,
      taskId: taskId,
    );
  }

  /// 提交视频生成任务
  static Future<String?> _submitVideoGenerationTask({
    required String apiKey,
    required String prompt,
    required String model,
    required String ratio,
    required int duration,
    required String responseFormat,
  }) async {
    final response = await http.post(
      Uri.parse(_videoGenerationEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'prompt': prompt, // Changed from 'content' to 'prompt'
        'ratio': ratio,
        'dur': duration,
        'response_format': responseFormat,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("视频生成任务提交失败: ${response.statusCode} - ${response.body}");
    }

    final result = jsonDecode(response.body);
    return result['id'] as String?;
  }

  /// 轮询视频生成结果
  static Future<Map<String, dynamic>> _pollVideoGenerationResult({
    required String apiKey,
    required String taskId,
  }) async {
    final statusUrl = '$_videoGenerationEndpoint/$taskId';
    int retry = 0;
    const int maxRetry = 180; // 最多轮询3分钟 (180次 × 1秒)

    while (retry < maxRetry) {
      final response = await http.get(
        Uri.parse(statusUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final status = result['status'] as String;
        
        if (status == 'succeeded') {
          return result;
        } else if (status == 'failed') {
          throw Exception("视频生成失败: ${result['error_msg'] ?? '未知错误'}");
        }
        // 如果状态是pending或running，继续轮询
      } else {
        throw Exception("查询视频生成状态失败: ${response.statusCode} - ${response.body}");
      }
      
      await Future.delayed(const Duration(seconds: 1));
      retry++;
    }
    
    throw Exception("视频生成任务超时");
  }
}

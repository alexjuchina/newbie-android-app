import 'dart:convert';
import 'package:crypto/crypto.dart';

/// AWS V4 风格签名工具类，用于即梦 AI 鉴权
class SignV4 {
  /// 计算 HMAC-SHA256 签名
  static List<int> sign(List<int> key, String msg) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(msg)).bytes;
  }

  /// 获取签名密钥
  static List<int> getSignatureKey(
      String key, String dateStamp, String regionName, String serviceName) {
    final kDate = sign(utf8.encode(key), dateStamp);
    final kRegion = sign(kDate, regionName);
    final kService = sign(kRegion, serviceName);
    final kSigning = sign(kService, 'request');
    return kSigning;
  }

  /// 生成规范查询字符串
  static String formatQuery(Map<String, String> parameters) {
    final sortedKeys = parameters.keys.toList()..sort();
    final buffer = StringBuffer();
    for (var key in sortedKeys) {
      buffer.write('$key=${parameters[key]}&');
    }
    final result = buffer.toString();
    return result.substring(0, result.length - 1);
  }

  /// 生成已签名的 Headers
  /// [accessKey] Access Key
  /// [secretKey] Secret Key
  /// [service] 服务名称 (如 cv)
  /// [region] 区域 (如 cn-north-1)
  /// [host] 主机名
  /// [path] 请求路径
  /// [query] 查询参数 Map
  /// [payload] 请求体 JSON 字符串
  static Map<String, String> generateHeaders({
    required String accessKey,
    required String secretKey,
    required String service,
    required String region,
    required String host,
    required String path,
    required Map<String, String> query,
    required String payload,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatIso8601Basic(now); // YYYYMMDDTHHMMSSZ
    final dateStamp = _formatDate(now); // YYYYMMDD

    // 1. Canonical Request
    final canonicalUri = path;
    final canonicalQueryString = formatQuery(query);
    final payloadHash = sha256.convert(utf8.encode(payload)).toString();
    
    final canonicalHeaders = 'content-type:application/json\n'
        'host:$host\n'
        'x-content-sha256:$payloadHash\n'
        'x-date:$amzDate\n';
    
    const signedHeaders = 'content-type;host;x-content-sha256;x-date';
    
    final canonicalRequest = 'POST\n'
        '$canonicalUri\n'
        '$canonicalQueryString\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    // 2. String to Sign
    const algorithm = 'HMAC-SHA256';
    final credentialScope = '$dateStamp/$region/$service/request';
    final stringToSign = '$algorithm\n'
        '$amzDate\n'
        '$credentialScope\n'
        '${sha256.convert(utf8.encode(canonicalRequest)).toString()}';

    // 3. Signature
    final signingKey = getSignatureKey(secretKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    // 4. Authorization Header
    final authorization = '$algorithm '
        'Credential=$accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    return {
      'Content-Type': 'application/json',
      'X-Date': amzDate,
      'X-Content-Sha256': payloadHash,
      'Authorization': authorization,
      'Host': host, // 添加 Host header
    };
  }

  static String _formatIso8601Basic(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}T'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}Z';
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

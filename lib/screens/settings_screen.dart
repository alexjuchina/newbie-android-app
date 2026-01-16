import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/config_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _arkKeyController = TextEditingController();
  final _jimengAkController = TextEditingController();
  final _jimengSkController = TextEditingController();
  final _customModelEpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final config = context.read<ConfigStore>();
    _arkKeyController.text = _maskKey(config.arkApiKey);
    _jimengAkController.text = _maskKey(config.jimengAccessKey);
    _jimengSkController.text = _maskKey(config.jimengSecretKey);
    _customModelEpController.text = '';
  }

  /// 隐藏 API Key 中间部分
  String _maskKey(String key) {
    if (key.isEmpty) return '';
    if (key.length <= 2) return key;
    return '${key.substring(0, 1)}******${key.substring(key.length - 1)}';
  }

  @override
  void dispose() {
    _arkKeyController.dispose();
    _jimengAkController.dispose();
    _jimengSkController.dispose();
    _customModelEpController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = context.read<ConfigStore>();
    
    String getRealValue(String input, String original) {
      if (input == _maskKey(original)) {
        return original;
      }
      return input;
    }

    await config.setArkApiKey(getRealValue(_arkKeyController.text.trim(), config.arkApiKey));
    await config.setJimengAccessKey(getRealValue(_jimengAkController.text.trim(), config.jimengAccessKey));
    await config.setJimengSecretKey(getRealValue(_jimengSkController.text.trim(), config.jimengSecretKey));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存'),
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<ConfigStore>();
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('默认配置'),
        backgroundColor: colorScheme.surface,
        elevation: 2,
        surfaceTintColor: colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 火山方舟配置卡片
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '火山方舟配置 (仅本地保存)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _arkKeyController,
                    decoration: InputDecoration(
                      labelText: 'ARK_API_KEY',
                      hintText: '请输入火山引擎 API Key',
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(153)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '模型推理 (Chat)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: config.modelEpCandidates.contains(config.modelEp) ? config.modelEp : config.modelEpCandidates.first,
                    decoration: InputDecoration(
                      labelText: '默认模型',
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: config.modelEpCandidates
                        .map(
                          (ep) => DropdownMenuItem(
                            value: ep,
                            child: Text(
                              config.modelDisplayName(ep),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        config.setModelEp(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customModelEpController,
                          decoration: InputDecoration(
                            labelText: '（可选）添加自定义EP',
                            hintText: '例如：ep-xxxx',
                            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(153)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.outline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.outline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final v = _customModelEpController.text.trim();
                            final focusScopeNode = FocusScope.of(context);
                            await config.addCustomModelEp(v);
                            if (!mounted) return;
                            _customModelEpController.clear();
                            focusScopeNode.unfocus();
                          },
                          child: const Text('添加'),
                        ),
                      ),
                    ],
                  ),
                  if (config.customModelEps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: config.customModelEps
                          .map(
                            (ep) => InputChip(
                              label: Text(ep),
                              onDeleted: () {
                                config.removeCustomModelEp(ep);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 即梦 AI 配置卡片
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '即梦AI配置 (Image)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _jimengAkController,
                    decoration: InputDecoration(
                      labelText: 'Access Key',
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _jimengSkController,
                    decoration: InputDecoration(
                      labelText: 'Secret Key',
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 保存按钮
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            child: const Text('保存配置'),
          ),
          
          const SizedBox(height: 24),
          Center(
            child: Text(
              '当前版本 v1.4.0',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

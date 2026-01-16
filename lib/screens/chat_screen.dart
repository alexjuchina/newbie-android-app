import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/config_store.dart';
import '../stores/chat_store.dart';
import '../services/volc_api.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final config = context.read<ConfigStore>();
    final chatStore = context.read<ChatStore>();
    
    if (!config.hasArkConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 API Key')),
      );
      return;
    }

    final currentModel = config.modelEp;
    final currentThinkingMode = config.thinkingMode;
    final currentReasoningEffort = config.reasoningEffort;

    setState(() {
      _isLoading = true;
      _controller.clear();
    });

    // Add user message
    await chatStore.addMessage('user', text);
    // Add assistant placeholder
    await chatStore.addMessage('assistant', '', thinking: '');
    
    _scrollToBottom();

    final messagesPayload = chatStore.currentMessages
        .sublist(0, chatStore.currentMessages.length - 1) // Exclude current empty assistant
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    String fullResponse = '';
    String thinkingContent = '';
    
    try {
      final stream = VolcApi.streamChat(
        apiKey: config.arkApiKey,
        model: currentModel,
        messages: messagesPayload,
        temperature: config.temperature,
        topP: config.topP,
        maxTokens: config.maxTokens,
        thinkingMode: currentThinkingMode,
        reasoningEffort: currentReasoningEffort,
      );

      await for (final chunk in stream) {
        if (!mounted) return;
        
        // 检查是否是思考内容的开始
        if (chunk.startsWith('Thinking:')) {
          thinkingContent += chunk.substring(9); // 去掉 "Thinking:" 前缀
        } else {
          // 普通内容
          fullResponse += chunk;
        }
        
        await chatStore.updateLastMessage(fullResponse, thinking: thinkingContent);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        await chatStore.updateLastMessage('Error: $e');
      }
    } finally {
      await chatStore.saveCurrentMessages();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<ConfigStore>();
    final chatStore = context.watch<ChatStore>();
    final messages = chatStore.currentMessages;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('EP 对话'),
        backgroundColor: colorScheme.surface,
        elevation: 2,
        surfaceTintColor: colorScheme.surface,
      ),
      drawer: Drawer(
        backgroundColor: colorScheme.surface,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(bottom: BorderSide(color: colorScheme.outline.withAlpha(50))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '历史记录',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await chatStore.createNewSession();
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('新对话'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: chatStore.sessions.length,
                itemBuilder: (context, index) {
                  final session = chatStore.sessions[index];
                  final isSelected = session.id == chatStore.currentSessionId;
                  return ListTile(
                    title: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('MM-dd HH:mm').format(session.updatedAt),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: colorScheme.primaryContainer.withAlpha(30),
                    onTap: () async {
                      await chatStore.selectSession(session.id);
                      if (context.mounted) Navigator.pop(context);
                      // Scroll to bottom after loading
                      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.onSurfaceVariant),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF2C2C2C),
                            title: const Text(
                              '删除对话',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: const Text(
                              '确定要删除这条对话记录吗？',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  '取消',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  chatStore.deleteSession(session.id);
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  '删除',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatStore.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty 
                  ? Center(
                      child: Text(
                        '开始一个新的对话', 
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg.role == 'user';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: isUser 
                            ? colorScheme.primaryContainer 
                            : const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                        // 添加细微阴影提升层次感
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          // 添加用户头像占位符
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isUser) ...[
                                Icon(Icons.assistant, size: 20, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                isUser ? '我' : '豆包',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: isUser 
                                      ? colorScheme.onPrimaryContainer.withAlpha(204)
                                      : colorScheme.onSurfaceVariant.withAlpha(204),
                                ),
                              ),
                              if (isUser) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.person, size: 20, color: colorScheme.onPrimaryContainer),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          isUser
                              ? Text(
                                  msg.content, 
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 显示思考内容
                                    if (msg.thinking != null && msg.thinking!.isNotEmpty)
                                      ThinkingBlock(
                                        key: ObjectKey(msg),
                                        content: msg.thinking!,
                                      ),
                                    // 显示最终回答
                                    MarkdownBody(
                                      data: msg.content, 
                                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                        p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Colors.white,
                                        ),
                                        code: TextStyle(backgroundColor: colorScheme.surface),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline.withAlpha(128)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButton<String>(
                          value: config.modelEpCandidates.contains(config.modelEp)
                              ? config.modelEp
                              : config.modelEpCandidates.first,
                          items: config.modelEpCandidates
                              .map(
                                (ep) => DropdownMenuItem(
                                  value: ep,
                                  child: Text(
                                    config.modelDisplayName(ep),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              config.setModelEp(value);
                            }
                          },
                          underline: Container(),
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, size: 16, color: colorScheme.onSurfaceVariant),
                          dropdownColor: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Text('思考', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                        Switch(
                          value: config.thinkingMode == 'enabled',
                          onChanged: (value) {
                            config.setThinkingMode(value ? 'enabled' : 'disabled');
                          },
                          activeThumbColor: colorScheme.primary,
                          inactiveTrackColor: colorScheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    backgroundColor: colorScheme.surface,
                    color: colorScheme.primary,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: '输入消息...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendMessage,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          elevation: 2,
                        ),
                        child: const Icon(Icons.send, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThinkingBlock extends StatefulWidget {
  final String content;
  
  const ThinkingBlock({super.key, required this.content});

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    // Colors from CSS reference
    const backgroundColor = Color(0xFF1F2937);
    const accentColor = Color(0xFF2563EB); 
    const textColor = Color(0xFFE5E7EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.psychology, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  const Text(
                    '思考过程',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: const Color(0xB32563EB),
                  ),
                ],
              ),
            ),
          ),
          // Content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                widget.content,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

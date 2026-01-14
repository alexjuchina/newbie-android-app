import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ChatMessage {
  final String role;
  String content;
  String? thinking;

  ChatMessage({required this.role, required this.content, this.thinking});

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (thinking != null) 'thinking': thinking,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        thinking: json['thinking'] as String?,
      );
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class ChatStore extends ChangeNotifier {
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  List<ChatMessage> _currentMessages = [];
  bool _isLoading = false;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  String? get currentSessionId => _currentSessionId;
  List<ChatMessage> get currentMessages => List.unmodifiable(_currentMessages);
  bool get isLoading => _isLoading;

  ChatStore() {
    _loadSessions();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _sessionsFile async {
    final path = await _localPath;
    return File('$path/chat_sessions.json');
  }

  Future<File> _sessionFile(String id) async {
    final path = await _localPath;
    return File('$path/session_$id.json');
  }

  Future<void> _loadSessions() async {
    try {
      final file = await _sessionsFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        _sessions = jsonList.map((e) => ChatSession.fromJson(e)).toList();
        // Sort by updatedAt desc
        _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading sessions: $e');
      }
    }
  }

  Future<void> _saveSessions() async {
    try {
      final file = await _sessionsFile;
      final jsonList = _sessions.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving sessions: $e');
      }
    }
  }

  Future<void> _saveCurrentSessionMessages() async {
    if (_currentSessionId == null) return;
    try {
      final file = await _sessionFile(_currentSessionId!);
      final jsonList = _currentMessages.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving messages: $e');
      }
    }
  }

  Future<void> createNewSession() async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final newSession = ChatSession(
      id: id,
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    );
    
    _sessions.insert(0, newSession);
    _currentSessionId = id;
    _currentMessages = [];
    
    await _saveSessions();
    await _saveCurrentSessionMessages(); // Create empty file
    notifyListeners();
  }

  Future<void> selectSession(String id) async {
    if (_currentSessionId == id) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final file = await _sessionFile(id);
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(contents);
          _currentMessages = jsonList.map((e) => ChatMessage.fromJson(e)).toList();
        } else {
          _currentMessages = [];
        }
      } else {
        _currentMessages = [];
      }
      _currentSessionId = id;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading session $id: $e');
      }
      _currentMessages = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    if (_currentSessionId == id) {
      _currentSessionId = null;
      _currentMessages = [];
    }
    await _saveSessions();
    
    try {
      final file = await _sessionFile(id);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore
    }
    notifyListeners();
  }

  Future<void> addMessage(String role, String content, {String? thinking}) async {
    if (_currentSessionId == null) {
      await createNewSession();
    }

    final msg = ChatMessage(role: role, content: content, thinking: thinking);
    _currentMessages.add(msg);
    
    // Update session title if it's the first user message and title is default
    if (role == 'user') {
       final index = _sessions.indexWhere((s) => s.id == _currentSessionId);
       if (index != -1) {
         final session = _sessions[index];
         if (session.title == '新对话' && content.isNotEmpty) {
           // Take first 20 chars
           session.title = content.length > 20 ? '${content.substring(0, 20)}...' : content;
         }
         session.updatedAt = DateTime.now();
         // Move to top
         _sessions.removeAt(index);
         _sessions.insert(0, session);
         await _saveSessions();
       }
    }

    notifyListeners();
    await _saveCurrentSessionMessages();
  }

  Future<void> updateLastMessage(String content, {String? thinking}) async {
    if (_currentMessages.isEmpty) return;
    
    final lastMsg = _currentMessages.last;
    lastMsg.content = content;
    if (thinking != null) {
      lastMsg.thinking = thinking;
    }
    
    notifyListeners();
    // Don't save on every chunk update for performance, rely on final save or periodic?
    // For simplicity, we might just save here or let the caller call a "finalize" method.
    // But since this is a local app, saving every few seconds or on completion is better.
    // For now, let's assume the UI calls this often. We shouldn't write to disk on every char.
    // Let's add a `saveCurrentMessages` public method and call it when generation finishes.
  }
  
  Future<void> saveCurrentMessages() async {
    await _saveCurrentSessionMessages();
  }
}

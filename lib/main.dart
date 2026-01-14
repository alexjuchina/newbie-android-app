import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/config_store.dart';
import 'stores/chat_store.dart';
import 'screens/chat_screen.dart';
import 'screens/image_screen.dart';
import 'screens/video_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 创建配置存储并初始化
  final configStore = ConfigStore();
  await configStore.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configStore),
        ChangeNotifierProvider(create: (_) => ChatStore()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doubao API Newbie',
      theme: ThemeData(
        // 采用Web版本的深色配色方案
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Web版本主蓝色
          primary: const Color(0xFF2563EB),
          primaryContainer: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF2563EB),
          secondaryContainer: const Color(0xFF1E3A8A),
          tertiary: const Color(0xFF2563EB),
          tertiaryContainer: const Color(0xFF1E3A8A),
          surface: const Color(0xFF111827), // Web版本卡片背景色
          error: const Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onTertiary: Colors.white,
          onSurface: const Color(0xFFE2E8F0),
          onError: Colors.white,
        ),
        // 使用Material Design 3
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 14, // Reduced from 15
            fontWeight: FontWeight.w600,
            color: Color(0xFFE2E8F0),
          ),
          iconTheme: IconThemeData(color: Color(0xFFE2E8F0)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF1F2937)), // Web版本边框色
          ),
          color: const Color(0xFF111827), // Web版本卡片背景色
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), // Web版本按钮颜色
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF1F2937)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            foregroundColor: const Color(0xFFE2E8F0),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE2E8F0),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF1F2937)), // Web版本边框色
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1), // Web版本主蓝色
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF1F2937)), // Web版本边框色
          ),
          filled: true,
          fillColor: const Color(0xFF0B1220), // Web版本输入框背景色
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          labelStyle: const TextStyle(color: Color(0xFF93C5FD)), // Web版本标签色
          contentPadding: const EdgeInsets.all(8),
        ),
        // 统一字体样式
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE2E8F0)),
          displayMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE2E8F0)),
          displaySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE2E8F0)),
          headlineMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
          headlineSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
          titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
          bodyLarge: TextStyle(fontSize: 13.5, color: Color(0xFFE5E7EB)),
          bodyMedium: TextStyle(fontSize: 12.5, color: Color(0xFFE5E7EB)),
          bodySmall: TextStyle(fontSize: 10.5, color: Color(0xFFE5E7EB)),
          labelLarge: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
          labelMedium: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
          labelSmall: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
        ),
        // 统一图标主题
        iconTheme: const IconThemeData(size: 24, color: Color(0xFFE2E8F0)),
        // 页面背景色
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const ChatScreen(),
    const ImageScreen(),
    const VideoScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        // 使用Material Design 3的NavigationBar替代BottomNavigationBar
        backgroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: '对话',
          ),
          NavigationDestination(
            icon: Icon(Icons.image),
            label: '生图',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library),
            label: '生视频',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '配置',
          ),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        // 扁平风样式
        elevation: 2,
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/deck_client_service.dart';
import 'services/deck_storage_service.dart';
import 'ui/screens/deck_screen.dart';
import 'ui/screens/host_screen.dart';
import 'ui/theme/deck_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = DeckStorageService();
  await storageService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storageService),
        ChangeNotifierProvider(create: (_) => DeckClientService()),
      ],
      child: const StreamDeckApp(),
    ),
  );
}

class StreamDeckApp extends StatelessWidget {
  const StreamDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Deck Cross-Platform',
      debugShowCheckedModeBanner: false,
      theme: DeckTheme.darkTheme,
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  // If on Windows Desktop, default to Host Server mode; on Mobile, default to Deck Client
  late bool _showHostMode;

  @override
  void initState() {
    super.initState();
    _showHostMode = !kIsWeb && Platform.isWindows;

    // On mobile, auto-connect to last used IP if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_showHostMode) {
        final storage = context.read<DeckStorageService>();
        if (storage.lastConnectedIp.isNotEmpty) {
          context.read<DeckClientService>().connect(storage.lastConnectedIp);
        }
      }
    });
  }

  void _toggleMode() {
    setState(() => _showHostMode = !_showHostMode);
  }

  @override
  Widget build(BuildContext context) {
    if (_showHostMode) {
      return HostCompanionScreen(
        onSwitchToDeckView: _toggleMode,
      );
    } else {
      return DeckScreen(
        onSwitchToHostView: (!kIsWeb && Platform.isWindows) ? _toggleMode : null,
      );
    }
  }
}

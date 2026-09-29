import 'dart:async';
import 'dart:io';
import 'package:stream_deck/server/deck_server.dart';

void main(List<String> args) async {
  print('====================================================');
  print('   STREAM DECK WINDOWS COMPANION SERVER (Dart)     ');
  print('====================================================');

  final port = args.isNotEmpty ? int.tryParse(args[0]) ?? 8443 : 8443;
  final server = DeckServer(port: port);

  final started = await server.start();
  if (!started) {
    print('Failed to start server on port $port');
    exit(1);
  }

  final ip = await DeckServer.getLocalIpAddress() ?? '127.0.0.1';

  print('✔ Stream Deck Host Server is active!');
  print('  • Local Wi-Fi Address: ws://$ip:$port');
  print('  • Localhost Address:   ws://127.0.0.1:$port');
  print('  • Status: Waiting for Android/iPhone connections...\n');
  print('Press Ctrl+C to terminate the server.\n');

  server.eventsStream.listen((event) {
    final prefix = event.isError ? '❌' : '⚡';
    print('$prefix [${event.timestamp.toIso8601String().substring(11, 19)}] ${event.title} - ${event.details}');
  });

  server.clientsStream.listen((clients) {
    print('📱 Active Connected Clients: ${clients.length}');
    for (var c in clients) {
      print('   - ${c.deviceName} (${c.platform})');
    }
  });

  // Keep process alive indefinitely until explicitly killed or interrupted
  final keepAlive = Completer<void>();

  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down server...');
    await server.stop();
    if (!keepAlive.isCompleted) keepAlive.complete();
    exit(0);
  });

  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      await server.stop();
      if (!keepAlive.isCompleted) keepAlive.complete();
      exit(0);
    });
  }

  await keepAlive.future;
}

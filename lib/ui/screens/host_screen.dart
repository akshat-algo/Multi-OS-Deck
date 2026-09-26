import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../server/deck_server.dart';
import '../../server/windows_action_executor.dart';
import '../../models/deck_action.dart';
import '../theme/deck_theme.dart';

/// Windows Desktop Companion Screen: Manages the local WebSocket server,
/// shows pairing QR code, lists connected phones, and streams live activity.
class HostCompanionScreen extends StatefulWidget {
  final VoidCallback? onSwitchToDeckView;

  const HostCompanionScreen({super.key, this.onSwitchToDeckView});

  @override
  State<HostCompanionScreen> createState() => _HostCompanionScreenState();
}

class _HostCompanionScreenState extends State<HostCompanionScreen> {
  final DeckServer _server = DeckServer(port: 8443);
  String _localIp = '127.0.0.1';
  final List<ServerEvent> _events = [];
  List<ConnectedClient> _clients = [];

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    final ip = await DeckServer.getLocalIpAddress();
    if (ip != null && mounted) {
      setState(() => _localIp = ip);
    }

    _server.eventsStream.listen((event) {
      if (mounted) {
        setState(() {
          _events.insert(0, event);
          if (_events.length > 50) _events.removeLast();
        });
      }
    });

    _server.clientsStream.listen((clients) {
      if (mounted) {
        setState(() => _clients = List.from(clients));
      }
    });

    await _server.start();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionUrl = 'ws://$_localIp:${_server.port}';

    return Scaffold(
      backgroundColor: DeckTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _server.isRunning ? DeckTheme.green : DeckTheme.red,
                boxShadow: [
                  BoxShadow(
                    color: (_server.isRunning ? DeckTheme.green : DeckTheme.red).withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
            const Text('STREAM DECK COMPANION (Windows Host)'),
          ],
        ),
        actions: [
          if (widget.onSwitchToDeckView != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: widget.onSwitchToDeckView,
                icon: const Icon(Icons.grid_view_rounded, color: DeckTheme.cyan),
                label: const Text('Mobile Deck Preview', style: TextStyle(color: DeckTheme.cyan)),
              ),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column: Pairing & Host Info
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Server Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeckTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DeckTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Host Status', style: TextStyle(color: DeckTheme.textSecondary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (_server.isRunning ? DeckTheme.green : DeckTheme.red).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _server.isRunning ? 'ONLINE' : 'STOPPED',
                                style: TextStyle(
                                  color: _server.isRunning ? DeckTheme.green : DeckTheme.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Wi-Fi IP Address:', style: TextStyle(fontSize: 12, color: DeckTheme.textMuted)),
                        Text(
                          _localIp,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DeckTheme.cyan),
                        ),
                        const SizedBox(height: 6),
                        Text('Port: ${_server.port}', style: const TextStyle(fontSize: 13, color: DeckTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // QR Code Card for Instant Camera Pairing
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: DeckTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DeckTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Scan to Pair Mobile Device',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: DeckTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Point your iPhone or Android camera or enter IP in app',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: DeckTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: QrImageView(
                            data: connectionUrl,
                            version: QrVersions.auto,
                            size: 180,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          connectionUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            color: DeckTheme.cyan,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Tester on Windows
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeckTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DeckTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Windows Action Diagnostics',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _testBtn('Vol Up (+)', () => WindowsActionExecutor.execute(DeckAction.media('volume_up'))),
                            _testBtn('Vol Down (-)', () => WindowsActionExecutor.execute(DeckAction.media('volume_down'))),
                            _testBtn('Mute', () => WindowsActionExecutor.execute(DeckAction.media('volume_mute'))),
                            _testBtn('Desktop', () => WindowsActionExecutor.execute(DeckAction.hotkey('win+d'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(color: DeckTheme.border, width: 1),

          // Right Column: Connected Devices & Live Console Log
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connected Clients Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Connected Devices (${_clients.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_clients.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DeckTheme.card.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DeckTheme.border),
                      ),
                      child: const Center(
                        child: Text(
                          'No mobile devices connected. Open the Stream Deck app on your phone to connect.',
                          style: TextStyle(color: DeckTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _clients.map((c) {
                        final isIos = c.platform.toLowerCase().contains('ios');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: DeckTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: DeckTheme.green.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isIos ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                                color: DeckTheme.green,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.deviceName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '${c.platform} • ⚡ ${c.pingMs}ms',
                                    style: const TextStyle(fontSize: 11, color: DeckTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // Live Activity Feed Section
                  const Row(
                    children: [
                      Icon(Icons.terminal_rounded, size: 18, color: DeckTheme.cyan),
                      SizedBox(width: 8),
                      Text(
                        'Live Activity Console',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090B10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: DeckTheme.border),
                      ),
                      child: _events.isEmpty
                          ? const Center(
                              child: Text(
                                'Awaiting activity...',
                                style: TextStyle(color: DeckTheme.textMuted, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _events.length,
                              itemBuilder: (context, i) {
                                final ev = _events[i];
                                final timeStr = ev.timestamp.toIso8601String().substring(11, 19);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '[$timeStr] ',
                                        style: const TextStyle(
                                          color: DeckTheme.textMuted,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        '${ev.title}: ',
                                        style: TextStyle(
                                          color: ev.isError ? DeckTheme.red : DeckTheme.cyan,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          ev.details,
                                          style: const TextStyle(
                                            color: DeckTheme.textPrimary,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testBtn(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: DeckTheme.cyan,
        side: const BorderSide(color: DeckTheme.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

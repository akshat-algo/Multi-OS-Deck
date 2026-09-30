import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/deck_action.dart';
import '../../services/deck_client_service.dart';
import '../../services/deck_storage_service.dart';
import '../theme/deck_theme.dart';

/// Screen for connecting the Mobile Client to the Windows Host.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _targetHostController;
  bool _isAttempting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final storage = context.read<DeckStorageService>();
    final lastIp = (storage.lastConnectedIp.isNotEmpty && storage.lastConnectedIp != '127.0.0.1')
        ? storage.lastConnectedIp
        : '';

    _ipController = TextEditingController(text: lastIp);
    _portController = TextEditingController(text: '8443');
    _targetHostController = TextEditingController(text: storage.targetHostName);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _targetHostController.dispose();
    super.dispose();
  }

  Future<void> _handleAutoDiscover() async {
    setState(() {
      _isAttempting = true;
      _errorMessage = null;
    });

    final client = context.read<DeckClientService>();
    final storage = context.read<DeckStorageService>();
    final targetName = _targetHostController.text.trim();

    if (targetName.isNotEmpty) {
      await storage.saveTargetHostName(targetName);
      client.setTargetHostName(targetName);
    }

    final success = await client.autoDiscoverAndConnect(
      targetHostName: targetName.isNotEmpty ? targetName : null,
      timeout: const Duration(seconds: 4),
    );

    if (!mounted) return;
    setState(() => _isAttempting = false);

    if (success) {
      if (client.hostAddress.isNotEmpty) {
        _ipController.text = client.hostAddress;
        await storage.saveLastConnectedIp(client.hostAddress);
      }
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _errorMessage =
            'No matching Stream Deck PC receiver found on local Wi-Fi (_streamdeck._tcp.local).'
            '\nEnsure Companion Server is active on your PC and both devices are on the same Wi-Fi.';
      });
    }
  }

  Future<void> _handleConnect(String ip) async {
    setState(() {
      _isAttempting = true;
      _errorMessage = null;
    });

    final client = context.read<DeckClientService>();
    final storage = context.read<DeckStorageService>();
    final port = int.tryParse(_portController.text) ?? 8443;

    final success = await client.connect(ip, port);
    if (!mounted) return;
    setState(() => _isAttempting = false);
    if (success) {
      await storage.saveLastConnectedIp(ip);
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _errorMessage =
            'Could not connect to ws://$ip:$port.\nEnsure Windows Companion is running and both devices are on the same Wi-Fi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<DeckClientService>();
    final storage = context.watch<DeckStorageService>();

    return Scaffold(
      backgroundColor: DeckTheme.background,
      appBar: AppBar(
        title: const Text('Pair PC Companion'),
        actions: [
          if (client.isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DeckTheme.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DeckTheme.green.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 14, color: DeckTheme.green),
                      const SizedBox(width: 4),
                      Text(
                        '${client.latencyMs}ms',
                        style: const TextStyle(
                          color: DeckTheme.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(client),
            const SizedBox(height: 20),

            if (!client.isConnected) ...[
              // Auto-Discover Wi-Fi Button (Signature: _streamdeck._tcp.local)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isAttempting ? null : _handleAutoDiscover,
                  icon: _isAttempting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.wifi_find_rounded),
                  label: Text(
                    client.isDiscovering ? 'SCANNING WI-FI (mDNS)...' : 'AUTO-DISCOVER PC (WI-FI)',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeckTheme.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Discovered Hosts List (if any discovered via mDNS/UDP)
              if (client.discoveryService.discoveredHosts.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, size: 16, color: DeckTheme.green),
                    const SizedBox(width: 6),
                    Text(
                      'Discovered Receivers (${client.discoveryService.discoveredHosts.length})',
                      style: const TextStyle(
                        color: DeckTheme.green,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...client.discoveryService.discoveredHosts.map((host) {
                  final isTarget = _targetHostController.text.isNotEmpty &&
                      host.hostName.toLowerCase().contains(_targetHostController.text.toLowerCase().trim());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: DeckTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTarget ? DeckTheme.green : DeckTheme.border,
                        width: isTarget ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isTarget ? DeckTheme.green : DeckTheme.cyan).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.laptop_windows_rounded,
                          size: 18,
                          color: isTarget ? DeckTheme.green : DeckTheme.cyan,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            host.hostName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (isTarget) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DeckTheme.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('TARGET', style: TextStyle(fontSize: 9, color: DeckTheme.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${host.ip}:${host.port} • ${host.serviceName}',
                        style: const TextStyle(color: DeckTheme.textMuted, fontSize: 11),
                      ),
                      trailing: ElevatedButton(
                        onPressed: _isAttempting
                            ? null
                            : () {
                                _ipController.text = host.ip;
                                _portController.text = host.port.toString();
                                _handleConnect(host.ip);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DeckTheme.cyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('CONNECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              // Target PC Hostname Filter (Device Identification)
              const Text(
                'Target PC Hostname (Device Identification Filter)',
                style: TextStyle(
                  color: DeckTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetHostController,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. its_akshat (only auto-connects to this machine)',
                  prefixIcon: const Icon(Icons.fingerprint_rounded, size: 20, color: DeckTheme.cyan),
                  filled: true,
                  fillColor: DeckTheme.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: DeckTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: DeckTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: DeckTheme.cyan, width: 1.2),
                  ),
                ),
                onChanged: (val) {
                  storage.saveTargetHostName(val);
                  client.setTargetHostName(val);
                },
              ),
              const SizedBox(height: 16),
              // Host IP Input
              const Text(
                'Host IP Address',
                style: TextStyle(
                  color: DeckTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. 192.168.1.100',
                        prefixIcon: const Icon(Icons.desktop_windows_rounded, size: 20, color: DeckTheme.cyan),
                        filled: true,
                        fillColor: DeckTheme.card,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DeckTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DeckTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DeckTheme.cyan, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '8443',
                        filled: true,
                        fillColor: DeckTheme.card,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DeckTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DeckTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DeckTheme.cyan, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick Presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.usb_rounded, size: 14, color: DeckTheme.cyan),
                    label: const Text('127.0.0.1 (USB Cable)', style: TextStyle(fontSize: 11, color: DeckTheme.cyan)),
                    backgroundColor: DeckTheme.card,
                    side: const BorderSide(color: DeckTheme.border),
                    onPressed: () {
                      _ipController.text = '127.0.0.1';
                      setState(() {});
                      _handleConnect('127.0.0.1');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wifi_rounded, size: 14, color: DeckTheme.green),
                    label: const Text('192.168.1.114 (PC Wi-Fi)', style: TextStyle(fontSize: 11, color: DeckTheme.green)),
                    backgroundColor: DeckTheme.card,
                    side: const BorderSide(color: DeckTheme.border),
                    onPressed: () {
                      _ipController.text = '192.168.1.114';
                      setState(() {});
                      _handleConnect('192.168.1.114');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: DeckTheme.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DeckTheme.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: DeckTheme.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: DeckTheme.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Connect Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isAttempting ? null : () => _handleConnect(_ipController.text),
                  icon: _isAttempting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(
                    _isAttempting ? 'CONNECTING...' : 'CONNECT TO PC',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeckTheme.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // Recent IP addresses
              if (storage.recentIps.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Recent Hosts',
                  style: TextStyle(
                    color: DeckTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...storage.recentIps.map((ip) {
                  return Card(
                    color: DeckTheme.card,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.history_rounded, size: 20, color: DeckTheme.textMuted),
                      title: Text(
                        ip,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: DeckTheme.textMuted),
                      onTap: () {
                        _ipController.text = ip;
                        _handleConnect(ip);
                      },
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),
              // Minimal Help
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DeckTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DeckTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: DeckTheme.cyan, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Quick Guide',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: DeckTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _helpStep('1', 'Make sure PC and phone are connected to the same Wi-Fi.'),
                    _helpStep('2', 'Launch Stream Deck Companion on PC.'),
                    _helpStep('3', 'Enter the IP displayed on your PC screen and tap Connect.'),
                  ],
                ),
              ),
            ] else ...[
              // Connected Host Status & Quick Test
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: DeckTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DeckTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Connected Host', style: TextStyle(color: DeckTheme.textSecondary, fontSize: 13)),
                        Text(
                          client.hostAddress,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: DeckTheme.cyan, fontSize: 14),
                        ),
                      ],
                    ),
                    const Divider(color: DeckTheme.border, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Port', style: TextStyle(color: DeckTheme.textSecondary, fontSize: 13)),
                        Text('${client.port}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const Divider(color: DeckTheme.border, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Latency (Ping)', style: TextStyle(color: DeckTheme.textSecondary, fontSize: 13)),
                        Text('⚡ ${client.latencyMs} ms', style: const TextStyle(fontWeight: FontWeight.bold, color: DeckTheme.green, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Test Action trigger
                    const Text('Test Action:', style: TextStyle(color: DeckTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              client.pressButton('test_mute', 0, const DeckAction(type: DeckActionType.media, command: 'volume_mute'));
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: DeckTheme.cyan),
                              foregroundColor: DeckTheme.cyan,
                            ),
                            child: const Text('Test Mute'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              client.pressButton('test_snip', 0, const DeckAction(type: DeckActionType.hotkey, command: 'win+d'));
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: DeckTheme.cyan),
                              foregroundColor: DeckTheme.cyan,
                            ),
                            child: const Text('Test Win+D'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => client.disconnect(),
                        icon: const Icon(Icons.power_settings_new_rounded, color: DeckTheme.red, size: 18),
                        label: const Text('DISCONNECT', style: TextStyle(color: DeckTheme.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: DeckTheme.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(DeckClientService client) {
    Color badgeColor;
    String statusText;
    IconData icon;

    switch (client.status) {
      case ConnectionStatus.connected:
        badgeColor = DeckTheme.green;
        statusText = client.connectedHostName.isNotEmpty
            ? 'Connected to ${client.connectedHostName}'
            : 'Connected to Windows Companion';
        icon = Icons.check_circle_rounded;
        break;
      case ConnectionStatus.discovering:
        badgeColor = DeckTheme.cyan;
        statusText = 'Scanning Wi-Fi for _streamdeck._tcp.local...';
        icon = Icons.wifi_find_rounded;
        break;
      case ConnectionStatus.connecting:
        badgeColor = DeckTheme.yellow;
        statusText = 'Connecting to Windows Companion...';
        icon = Icons.sync_rounded;
        break;
      case ConnectionStatus.disconnected:
        badgeColor = DeckTheme.red;
        statusText = 'Disconnected from PC';
        icon = Icons.cloud_off_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: badgeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DeckTheme.cardHighlight,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DeckTheme.cyan),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, color: DeckTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

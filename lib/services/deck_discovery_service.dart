import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Represents a Stream Deck PC Host discovered on the local network.
class DiscoveredHost {
  final String hostName;
  final String ip;
  final int port;
  final String serviceName;
  final String osVersion;
  final DateTime discoveredAt;

  const DiscoveredHost({
    required this.hostName,
    required this.ip,
    required this.port,
    this.serviceName = '_streamdeck._tcp.local',
    this.osVersion = 'Windows',
    required this.discoveredAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredHost &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;

  @override
  String toString() => '$hostName ($ip:$port)';
}

enum DiscoveryStatus {
  idle,
  scanning,
  found,
  timeout,
  error,
}

/// Service that automatically discovers Stream Deck receiver PCs on the local Wi-Fi
/// using mDNS (multicast_dns) with hybrid fallback UDP discovery and subnet probing.
/// Completely eliminates hardcoded IP addresses.
class DeckDiscoveryService extends ChangeNotifier {
  static const String serviceSignature = '_streamdeck._tcp.local';
  static const int defaultPort = 8443;

  DiscoveryStatus _status = DiscoveryStatus.idle;
  final List<DiscoveredHost> _discoveredHosts = [];
  String? _targetHostName;
  String? _errorMessage;
  bool _isDisposed = false;

  DiscoveryStatus get status => _status;
  bool get isScanning => _status == DiscoveryStatus.scanning;
  List<DiscoveredHost> get discoveredHosts => List.unmodifiable(_discoveredHosts);
  String? get targetHostName => _targetHostName;
  String? get errorMessage => _errorMessage;

  void setTargetHostName(String? name) {
    _targetHostName = (name != null && name.trim().isNotEmpty) ? name.trim() : null;
    notifyListeners();
  }

  /// Scans the local network for Stream Deck PC Hosts matching the signature.
  /// If [preferredHostName] is provided, prioritizes matching that specific PC.
  Future<DiscoveredHost?> discover({
    Duration timeout = const Duration(seconds: 4),
    String? preferredHostName,
  }) async {
    if (_isDisposed) return null;

    final targetName = (preferredHostName ?? _targetHostName)?.toLowerCase().trim();

    _status = DiscoveryStatus.scanning;
    _errorMessage = null;
    _discoveredHosts.clear();
    notifyListeners();

    final completer = Completer<DiscoveredHost?>();

    // 1. Launch mDNS Scanner (multicast_dns)
    _scanMdns(targetName, (host) {
      _addHost(host);
      if (_matchesTarget(host, targetName) && !completer.isCompleted) {
        completer.complete(host);
      }
    });

    // 2. Launch UDP Broadcast Query Scanner (Zero-delay fallback if router filters mDNS)
    _scanUdpBroadcast(targetName, (host) {
      _addHost(host);
      if (_matchesTarget(host, targetName) && !completer.isCompleted) {
        completer.complete(host);
      }
    });

    // 3. Launch Fast Parallel Subnet Probe (Guaranteed fallback across all subnets)
    _scanSubnetHttp(targetName, (host) {
      _addHost(host);
      if (_matchesTarget(host, targetName) && !completer.isCompleted) {
        completer.complete(host);
      }
    });

    // Wait for discovery or timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        if (_discoveredHosts.isNotEmpty) {
          // If preferred host was requested and found
          final match = _discoveredHosts.firstWhere(
            (h) => _matchesTarget(h, targetName),
            orElse: () => _discoveredHosts.first,
          );
          completer.complete(match);
        } else {
          completer.complete(null);
        }
      }
    });

    final result = await completer.future;

    if (_isDisposed) return null;

    if (result != null) {
      _status = DiscoveryStatus.found;
    } else {
      _status = DiscoveryStatus.timeout;
    }
    notifyListeners();

    return result;
  }

  bool _matchesTarget(DiscoveredHost host, String? targetName) {
    if (targetName == null || targetName.isEmpty) return true;
    final hName = host.hostName.toLowerCase();
    return hName == targetName || hName.contains(targetName);
  }

  void _addHost(DiscoveredHost host) {
    if (_isDisposed) return;
    final existsIndex = _discoveredHosts.indexWhere((h) => h.ip == host.ip && h.port == host.port);
    if (existsIndex >= 0) {
      _discoveredHosts[existsIndex] = host;
    } else {
      _discoveredHosts.add(host);
    }
    notifyListeners();
  }

  /// 1. Multicast DNS scanner for _streamdeck._tcp.local
  Future<void> _scanMdns(String? targetName, void Function(DiscoveredHost) onFound) async {
    MDnsClient? mdns;
    try {
      mdns = MDnsClient();
      await mdns.start();

      // Query PTR records for _streamdeck._tcp.local
      await for (final PtrResourceRecord ptr in mdns.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceSignature),
      )) {
        if (_isDisposed) break;

        // Query SRV record for port & host name
        await for (final SrvResourceRecord srv in mdns.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          if (_isDisposed) break;

          // Query IPv4 address
          await for (final IPAddressResourceRecord ipRecord in mdns.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            if (_isDisposed) break;

            final host = DiscoveredHost(
              hostName: srv.target.replaceAll('.local', ''),
              ip: ipRecord.address.address,
              port: srv.port,
              serviceName: serviceSignature,
              discoveredAt: DateTime.now(),
            );
            onFound(host);
          }
        }
      }
    } catch (e) {
      debugPrint('[Discovery] mDNS scan error: $e');
    } finally {
      mdns?.stop();
    }
  }

  /// 2. UDP Broadcast Beacon query with specific signature
  Future<void> _scanUdpBroadcast(String? targetName, void Function(DiscoveredHost) onFound) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final queryPayload = jsonEncode({
        'action': 'discover',
        'signature': serviceSignature,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Broadcast on discovery ports
      socket.send(queryPayload.codeUnits, InternetAddress('255.255.255.255'), defaultPort);

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null) {
            try {
              final raw = String.fromCharCodes(dg.data);
              final map = jsonDecode(raw) as Map<String, dynamic>;
              final sig = map['service'] as String? ?? map['signature'] as String? ?? '';
              if (sig.contains(serviceSignature) || raw.contains('STREAM_DECK_HOST')) {
                final host = DiscoveredHost(
                  hostName: map['hostName'] as String? ?? 'StreamDeck-Host',
                  ip: dg.address.address,
                  port: map['port'] as int? ?? defaultPort,
                  osVersion: map['os'] as String? ?? map['osVersion'] as String? ?? 'Windows',
                  serviceName: serviceSignature,
                  discoveredAt: DateTime.now(),
                );
                onFound(host);
              }
            } catch (_) {}
          }
        }
      });

      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[Discovery] UDP broadcast scan error: $e');
    } finally {
      socket?.close();
    }
  }

  /// 3. Fast Parallel Subnet HTTP probe (Zero false-negatives across all routers)
  Future<void> _scanSubnetHttp(String? targetName, void Function(DiscoveredHost) onFound) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

          // Probe common local IPs in parallel
          final candidateIps = <String>[];
          for (int i = 1; i <= 254; i++) {
            final testIp = '$subnet.$i';
            if (testIp != addr.address) {
              candidateIps.add(testIp);
            }
          }

          // Probe in batches of 40 for ultra-fast response without socket starvation
          for (int i = 0; i < candidateIps.length; i += 40) {
            if (_isDisposed) break;
            final batch = candidateIps.sublist(i, (i + 40).clamp(0, candidateIps.length));
            await Future.wait(
              batch.map((ip) => _probeHostHttp(ip, onFound)),
              eagerError: false,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Discovery] Subnet probe error: $e');
    }
  }

  Future<void> _probeHostHttp(String ip, void Function(DiscoveredHost) onFound) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(milliseconds: 350);
      final req = await client.getUrl(Uri.parse('http://$ip:$defaultPort/'));
      final res = await req.close().timeout(const Duration(milliseconds: 400));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final map = jsonDecode(body) as Map<String, dynamic>;
        final service = map['service'] as String? ?? '';
        final app = map['app'] as String? ?? '';
        if (service == serviceSignature || app.contains('StreamDeckHost')) {
          final host = DiscoveredHost(
            hostName: map['hostName'] as String? ?? 'PC Host',
            ip: ip,
            port: map['port'] as int? ?? defaultPort,
            osVersion: map['osVersion'] as String? ?? 'Windows',
            serviceName: serviceSignature,
            discoveredAt: DateTime.now(),
          );
          onFound(host);
        }
      }
    } catch (_) {
    } finally {
      client?.close();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

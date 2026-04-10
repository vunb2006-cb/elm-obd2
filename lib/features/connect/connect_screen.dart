import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/obd/elm327_connector.dart';
import '../../shared/theme.dart';
import 'connect_provider.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    ref.invalidate(bondedDevicesProvider);
  }

  Future<void> _connect(BluetoothDevice device) async {
    await ref.read(connectNotifierProvider.notifier).connect(device.address);
    if (!mounted) return;
    final connectState = ref.read(connectNotifierProvider);
    if (connectState is! AsyncError) {
      context.go('/intake');
    }
  }

  Future<void> _disconnect() async {
    await ref.read(connectNotifierProvider.notifier).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(bondedDevicesProvider);
    final connState = ref.watch(connectionStateProvider);
    final connectOp = ref.watch(connectNotifierProvider);
    final connectedAddress = ref.watch(lastConnectedAddressProvider);

    final isConnected = connState.valueOrNull == Elm327State.connected;
    final isConnecting = connectOp is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to ELM327'),
        actions: [
          if (!isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(bondedDevicesProvider),
            ),
          if (isConnected)
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.bluetooth_disabled, size: 18),
              label: const Text('Disconnect'),
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentRed),
            ),
        ],
      ),
      body: Column(
        children: [
          _StatusBanner(connState: connState),

          // ── When connected: show a Continue banner ──────────────────────
          if (isConnected)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accentGreen.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.accentGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ELM327 ready. Tap Continue to begin diagnostics.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.accentGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => context.go('/intake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Continue →'),
                  ),
                ],
              ),
            ),

          Expanded(
            child: devices.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bluetooth_disabled,
                        size: 48, color: AppTheme.muted),
                    const SizedBox(height: 12),
                    Text('Bluetooth error: $e',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _requestPermissions,
                      child: const Text('Grant Permissions'),
                    ),
                  ],
                ),
              ),
              data: (deviceList) => deviceList.isEmpty
                  ? _EmptyState(onRefresh: _requestPermissions)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: deviceList.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final d = deviceList[i];
                        final isElm = _isElmDevice(d.name ?? '');
                        final isThisDeviceConnected =
                            isConnected && d.address == connectedAddress;
                        final isOtherDeviceConnected =
                            isConnected && d.address != connectedAddress;
                        return _DeviceTile(
                          device: d,
                          isElm: isElm,
                          isConnected: isThisDeviceConnected,
                          isDisabled:
                              isConnecting || isOtherDeviceConnected,
                          onTap: isThisDeviceConnected
                              ? () => context.go('/intake')
                              : (isConnecting || isOtherDeviceConnected)
                                  ? null
                                  : () => _connect(d),
                        );
                      },
                    ),
            ),
          ),

          if (connectOp is AsyncError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppTheme.accentRed.withAlpha(30),
              child: Text(
                'Connection failed: ${connectOp.error}',
                style: const TextStyle(color: AppTheme.accentRed),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  bool _isElmDevice(String name) {
    final lower = name.toLowerCase();
    return lower.contains('elm') ||
        lower.contains('obd') ||
        lower.contains('obdii') ||
        lower.contains('vlink');
  }
}

class _StatusBanner extends StatelessWidget {
  final AsyncValue<Elm327State> connState;
  const _StatusBanner({required this.connState});

  @override
  Widget build(BuildContext context) {
    final (text, color) = connState.when(
      loading: () => ('Checking connection...', AppTheme.muted),
      error: (_, __) => ('Connection error', AppTheme.accentRed),
      data: (s) => switch (s) {
        Elm327State.connected => ('Connected', AppTheme.accentGreen),
        Elm327State.connecting => ('Connecting...', AppTheme.accent),
        Elm327State.initializing => ('Initializing ELM327...', AppTheme.accent),
        Elm327State.error => ('Connection error', AppTheme.accentRed),
        Elm327State.disconnected => ('Not connected', AppTheme.muted),
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: color.withAlpha(20),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final bool isElm;
  final bool isConnected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _DeviceTile({
    required this.device,
    required this.isElm,
    required this.isConnected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isConnected
        ? AppTheme.accentGreen.withAlpha(120)
        : isDisabled
            ? const Color(0xFF1E1E24)
            : isElm
                ? AppTheme.accent.withAlpha(80)
                : const Color(0xFF2A2A30);

    final iconColor = isConnected
        ? AppTheme.accentGreen
        : isDisabled
            ? AppTheme.muted.withAlpha(80)
            : isElm
                ? AppTheme.accent
                : AppTheme.muted;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isConnected
                ? AppTheme.accentGreen.withAlpha(12)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                color: iconColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name ?? 'Unknown Device',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDisabled ? AppTheme.muted : null,
                          ),
                    ),
                    Text(
                      device.address,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Status / type badge
              if (isConnected)
                _chip('Connected', AppTheme.accentGreen)
              else if (isElm)
                _chip('ELM327', AppTheme.accent),
              const SizedBox(width: 8),
              Icon(
                isConnected ? Icons.arrow_forward : Icons.chevron_right,
                color: isConnected ? AppTheme.accentGreen : AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth_searching,
              size: 64, color: AppTheme.muted),
          const SizedBox(height: 16),
          Text('No paired devices found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Pair your ELM327 adapter in Android\nBluetooth settings first.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

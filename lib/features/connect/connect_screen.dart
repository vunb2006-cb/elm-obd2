import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/obd/elm327_connector.dart';
import '../../core/obd/simulated/fault_profile.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/loading_state.dart';
import 'connect_provider.dart';
import 'simulator_control_panel.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    ref.invalidate(bondedDevicesProvider);
    ref.read(connectNotifierProvider.notifier).clearError();
  }

  Future<void> _connect(BluetoothDevice device) async {
    final ok =
        await ref.read(connectNotifierProvider.notifier).connect(device.address);
    if (!mounted) return;
    if (ok) context.push('/intake');
  }

  Future<void> _disconnect() async {
    if (ref.read(isSimulatingProvider)) {
      await stopSimulating(ref);
    } else {
      await ref.read(connectNotifierProvider.notifier).disconnect();
    }
  }

  Future<void> _startSimulating() async {
    final profile = await showFaultProfilePicker(context);
    if (profile == null) return;
    await startSimulating(ref, profile);
    if (!mounted) return;
    context.push('/intake');
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(bondedDevicesProvider);
    final connState = ref.watch(connectionStateProvider);
    final connectUi = ref.watch(connectNotifierProvider);
    final connectedAddress = ref.watch(lastConnectedAddressProvider);
    final isSimulating = ref.watch(isSimulatingProvider);

    final isConnected = connState.valueOrNull == Elm327State.connected;
    final connectingAddr = connectUi.connectingAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSimulating ? 'Simulated Vehicle' : 'Connect to ELM327'),
        actions: [
          if (!isConnected && !isSimulating)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(bondedDevicesProvider);
                ref.read(connectNotifierProvider.notifier).clearError();
              },
            ),
          if (isSimulating && isConnected)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Simulator Controls',
              onPressed: () => showSimulatorControlPanel(context),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.accentGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ELM327 ready.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppTheme.accentGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/monitor'),
                          icon: const Icon(Icons.show_chart_rounded,
                              size: 16),
                          label: const Text('Live Monitor'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentGreen,
                            side: BorderSide(
                                color: AppTheme.accentGreen.withAlpha(120)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.push('/intake'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Diagnose →'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (connectUi.errorMessage != null)
            _ErrorBanner(
              message: connectUi.errorMessage!,
              onDismiss: () =>
                  ref.read(connectNotifierProvider.notifier).clearError(),
            ),

          if (kDebugMode && !isConnected && !isSimulating)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startSimulating,
                  icon: const Icon(Icons.smart_toy_outlined, size: 18),
                  label: const Text('Simulate Vehicle (No Hardware)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: BorderSide(color: AppTheme.accent.withAlpha(120)),
                  ),
                ),
              ),
            ),

          if (isSimulating && !isConnected)
            const Expanded(
              child: LoadingState(message: 'Starting virtual ECU…'),
            ),

          if (isSimulating && isConnected)
            const Expanded(
              child: _SimulatingHint(),
            ),

          if (!isSimulating)
            Expanded(
              child: devicesAsync.when(
              loading: () => const LoadingState(
                message: 'Loading paired devices…',
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Something went wrong. Pull to refresh or tap Refresh.',
                  textAlign: TextAlign.center,
                ),
              ),
              data: (result) {
                if (result.hasError) {
                  return _BluetoothAccessError(
                    message: result.errorMessage!,
                    onRetry: _requestPermissions,
                    onOpenSettings: () async {
                      await openAppSettings();
                      ref.invalidate(bondedDevicesProvider);
                    },
                  );
                }
                final deviceList = result.devices;
                if (deviceList.isEmpty) {
                  return _EmptyState(onRefresh: _requestPermissions);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: deviceList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = deviceList[i];
                    final isElm = _isElmDevice(d.name ?? '');
                    final isThisDeviceConnected =
                        isConnected && d.address == connectedAddress;
                    final isOtherDeviceConnected =
                        isConnected && d.address != connectedAddress;
                    final isThisConnecting =
                        connectingAddr != null && d.address == connectingAddr;
                    final isAnotherConnecting = connectingAddr != null &&
                        d.address != connectingAddr;

                    return _DeviceTile(
                      device: d,
                      isElm: isElm,
                      isConnected: isThisDeviceConnected,
                      isConnecting: isThisConnecting,
                      isDisabled: isAnotherConnecting || isOtherDeviceConnected,
                      onTap: isThisDeviceConnected
                          ? () => context.push('/intake')
                          : (isAnotherConnecting || isOtherDeviceConnected)
                              ? null
                              : () => _connect(d),
                    );
                  },
                );
              },
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

class _SimulatingHint extends ConsumerWidget {
  const _SimulatingHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fault = ref.watch(simulatedElm327Provider).ecu.fault;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 56, color: AppTheme.accent),
            const SizedBox(height: 16),
            Text('Virtual ECU running',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Scenario: ${fault.label}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showSimulatorControlPanel(context),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Open Simulator Controls'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accentRed.withAlpha(28),
      child: InkWell(
        onTap: onDismiss,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.accentRed, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.accentRed,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppTheme.accentRed,
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BluetoothAccessError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _BluetoothAccessError({
    required this.message,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_disabled,
                size: 56, color: AppTheme.muted),
            const SizedBox(height: 16),
            Text(
              'Bluetooth access needed',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Open app settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final AsyncValue<Elm327State> connState;
  const _StatusBanner({required this.connState});

  @override
  Widget build(BuildContext context) {
    final (text, color) = connState.when(
      loading: () => ('Checking connection…', AppTheme.muted),
      error: (_, __) => ('Connection status unavailable', AppTheme.muted),
      data: (s) => switch (s) {
        Elm327State.connected => ('Connected', AppTheme.accentGreen),
        Elm327State.connecting => ('Connecting…', AppTheme.accent),
        Elm327State.initializing => ('Initializing ELM327…', AppTheme.accent),
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
          Expanded(
            child: Text(text,
                style:
                    TextStyle(color: color, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final bool isElm;
  final bool isConnected;
  final bool isConnecting;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _DeviceTile({
    required this.device,
    required this.isElm,
    required this.isConnected,
    required this.isConnecting,
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
                : isConnecting
                    ? AppTheme.accent.withAlpha(10)
                    : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConnecting
                  ? AppTheme.accent.withAlpha(100)
                  : borderColor,
              width: isConnecting ? 1.5 : 1,
            ),
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
                    if (isConnecting) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Connecting…',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isConnected)
                _chip('Connected', AppTheme.accentGreen)
              else if (isElm)
                _chip('ELM327', AppTheme.accent),
              const SizedBox(width: 8),
              if (isConnecting)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
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

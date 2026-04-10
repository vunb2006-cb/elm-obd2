import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnosis/models/diagnostic_session.dart';
import '../../core/storage/session_repository.dart';
import '../../features/session/session_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/severity_badge.dart';

final _repositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository();
});

final _sessionsProvider =
    FutureProvider<List<DiagnosticSession>>((ref) async {
  final repo = ref.watch(_repositoryProvider);
  await repo.init();
  return repo.loadAll();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(_sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ELM OBD2 Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A30))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.car_repair,
                    size: 40, color: AppTheme.accent),
                const SizedBox(height: 12),
                Text(
                  'AI-Powered\nVehicle Diagnostics',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect your ELM327 to begin',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.go('/connect'),
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Start New Diagnostic'),
                ),
              ],
            ),
          ),

          // Interrupted session resume banner
          _ResumeBanner(),

          // Past sessions
          Expanded(
            child: sessions.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                // Hide interrupted sessions from history list — they show in the banner.
                final completed =
                    list.where((s) => !s.isInterrupted).toList();
                return completed.isEmpty
                    ? _EmptyHistory()
                    : _SessionList(sessions: completed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<DiagnosticSession> sessions;
  const _SessionList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Past Sessions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.muted),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _SessionTile(session: sessions[i]),
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final DiagnosticSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final diagnosis = session.finalDiagnosis;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.vehicleDescription,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (diagnosis != null)
                SeverityBadge(
                  severity:
                      SeverityBadge.fromString(diagnosis.severity),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            session.driverComplaint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (diagnosis != null) ...[
            const SizedBox(height: 8),
            Text(
              diagnosis.primaryFault,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.accent),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _formatDate(session.startTime),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Resume banner ────────────────────────────────────────────────────────────

class _ResumeBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interrupted = ref.watch(interruptedSessionProvider);

    return interrupted.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (session) {
        if (session == null) return const SizedBox.shrink();
        final testsCount = session.testResults.length;
        final testsLabel = testsCount == 0
            ? 'no tests completed'
            : '$testsCount test${testsCount == 1 ? '' : 's'} completed';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.restore, color: AppTheme.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interrupted Session',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppTheme.accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.vehicleDescription} — $testsLabel',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Pass the session to the notifier on the session screen.
                      ref
                          .read(sessionProvider.notifier)
                          .resumeFromCheckpoint(session);
                      context.go('/session');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Resume'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final repo = ref.read(_repositoryProvider);
                      await repo.delete(session.id);
                      ref.invalidate(interruptedSessionProvider);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.muted,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Empty history ────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 48, color: AppTheme.muted),
            const SizedBox(height: 12),
            Text('No past sessions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Your completed diagnostic sessions will appear here.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/app_fonts.dart';
import '../../theme/termius_theme.dart';

/// The desktop terminal's right-hand tools: live search over the visible
/// buffer, session status, font size, and real actions on the running PTY.
/// No placeholder controls — everything here acts on the live session.
class TerminalToolsPanel extends StatelessWidget {
  final AppFonts fonts;
  final Map<String, dynamic>? screen;
  final String search;
  final FocusNode? searchFocus;
  final int matchCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final VoidCallback onReconnect;

  const TerminalToolsPanel({
    super.key,
    required this.fonts,
    required this.screen,
    required this.search,
    this.searchFocus,
    required this.matchCount,
    required this.onSearch,
    required this.onClear,
    required this.onCopy,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final closed = screen?['closed'] != null;
    final status = closed
        ? 'Disconnected'
        : (screen == null ? 'Connecting…' : 'Connected');
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1D2033),
        border: Border(left: BorderSide(color: Color(0xFF262A3D))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('terminal-search'),
            focusNode: searchFocus,
            onChanged: onSearch,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF282B3D),
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            placeholder: const Text(
              'Search terminal',
              style: TextStyle(fontSize: 13, color: Color(0xFF8D91A5)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            search.trim().isEmpty
                ? 'Ctrl+Shift+F'
                : '$matchCount match${matchCount == 1 ? '' : 'es'} in view',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6E7388)),
          ),
          const SizedBox(height: 18),
          const _PanelLabel('SESSION'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: closed
                      ? const Color(0xFFE5484D)
                      : const Color(0xFF21B568),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(fontSize: 13, color: scheme.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _PanelLabel('SYSTEM'),
          const SizedBox(height: 8),
          _ResourceSection(
            state: screen?['resourceState'] as String?,
            sample: screen?['resource'] as Map<String, dynamic>?,
          ),
          const SizedBox(height: 18),
          const _PanelLabel('TERMINAL'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Font size',
                  style: TextStyle(fontSize: 13, color: Color(0xFFC7CBD6)),
                ),
              ),
              _StepButton(
                key: const ValueKey('terminal-size-down'),
                label: '−',
                onTap: () => fonts.setTerminalSize(fonts.terminalSize - 1),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${fonts.terminalSize.round()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.foreground),
                ),
              ),
              _StepButton(
                key: const ValueKey('terminal-size-up'),
                label: '+',
                onTap: () => fonts.setTerminalSize(fonts.terminalSize + 1),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PanelAction(
                  icon: LucideIcons.copy,
                  label: 'Copy',
                  onTap: onCopy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PanelAction(
                  icon: LucideIcons.eraser,
                  label: 'Clear',
                  onTap: onClear,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PanelAction(
            icon: LucideIcons.refreshCw,
            label: 'Reconnect',
            onTap: onReconnect,
          ),
        ],
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  final String text;
  const _PanelLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: Color(0xFF6E7388),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StepButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF282B3D),
          borderRadius: BorderRadius.circular(TermiusRadius.menu),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, color: Color(0xFFC7CBD6)),
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PanelAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF282B3D),
          borderRadius: BorderRadius.circular(TermiusRadius.menu),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFC7CBD6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFC7CBD6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live remote resource sample from the SSH monitor channel.
///
/// Every state is stated rather than hidden: `waiting` while the auxiliary
/// channel starts, `unsupported`/`unavailable` for hosts whose probe cannot
/// answer, `stale` when a previously-good sample stopped updating.
class _ResourceSection extends StatelessWidget {
  final String? state;
  final Map<String, dynamic>? sample;

  const _ResourceSection({required this.state, required this.sample});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.mutedForeground;
    final message = switch (state) {
      'unsupported' => 'Not available on this host',
      'unavailable' => 'No /proc stats from this host',
      'paused' => 'Sampling paused',
      'stale' => 'Last sample is stale',
      'waiting' => 'Measuring…',
      _ when sample == null => 'Measuring…',
      _ => null,
    };
    if (message != null) {
      return Text(
        message,
        key: const ValueKey('terminal-resource-empty'),
        style: TextStyle(fontSize: 12, color: muted),
      );
    }
    final data = sample!;
    final cpu = (data['cpu_percent'] as num?)?.toDouble() ?? 0;
    final cpuSampled = data['cpu_sampled'] == true;
    final memUsed = ((data['mem_used_kib'] as num?)?.toDouble() ?? 0) / 1024;
    final memTotal = ((data['mem_total_kib'] as num?)?.toDouble() ?? 0) / 1024;
    final memFrac = memTotal <= 0 ? 0.0 : (memUsed / memTotal).clamp(0.0, 1.0);
    final disks = (data['disks'] as List?) ?? const [];
    final net = (data['net'] as List?) ?? const [];
    final gpus = (data['gpus'] as List?) ?? const [];
    final user = (data['user'] as String?) ?? '';

    var rx = 0.0;
    var tx = 0.0;
    for (final row in net) {
      if (row is Map) {
        rx += (row['rx'] as num?)?.toDouble() ?? 0;
        tx += (row['tx'] as num?)?.toDouble() ?? 0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              user,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        _ResourceMeter(
          key: const ValueKey('terminal-resource-cpu'),
          label: 'CPU',
          value: cpuSampled ? '${(cpu * 100).clamp(0, 100).round()}%' : '—',
          fraction: cpuSampled ? cpu.clamp(0.0, 1.0) : 0,
        ),
        const SizedBox(height: 8),
        _ResourceMeter(
          key: const ValueKey('terminal-resource-memory'),
          label: 'Memory',
          value: memTotal > 0
              ? '${_formatMib(memUsed)} / ${_formatMib(memTotal)}'
              : '—',
          fraction: memFrac,
        ),
        if (disks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final disk = disks.first as Map;
              final total = (disk['total'] as num?)?.toDouble() ?? 0;
              final available = (disk['available'] as num?)?.toDouble() ?? 0;
              final frac = total <= 0
                  ? 0.0
                  : ((total - available) / total).clamp(0.0, 1.0);
              return _ResourceMeter(
                key: const ValueKey('terminal-resource-disk'),
                label: (disk['path'] as String?) ?? 'Disk',
                value: '${(frac * 100).round()}%',
                fraction: frac,
              );
            },
          ),
        ],
        if (net.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ResourceMeter(
            key: const ValueKey('terminal-resource-net'),
            label: 'Network',
            value: '↓ ${_formatRate(rx)}  ↑ ${_formatRate(tx)}',
            fraction: 0,
          ),
        ],
        if (gpus.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final gpu in gpus.take(2))
            Padding(
              key: const ValueKey('terminal-resource-gpu'),
              padding: const EdgeInsets.only(bottom: 6),
              child: _ResourceMeter(
                label: ((gpu as Map)['name'] as String?) ?? 'GPU',
                value:
                    '${(((gpu['util_percent'] as num?)?.toDouble() ?? 0)).round()}%'
                    '${gpu['temp_c'] != null ? ' · ${gpu['temp_c']}°C' : ''}',
                fraction:
                    (((gpu['util_percent'] as num?)?.toDouble() ?? 0) / 100).clamp(
                      0.0,
                      1.0,
                    ),
              ),
            ),
        ] else if (data['gpu_unsupported'] == true) ...[
          const SizedBox(height: 8),
          Text(
            'GPU: unavailable',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ],
    );
  }
}

String _formatMib(double mib) => mib >= 1024
    ? '${(mib / 1024).toStringAsFixed(1)} GiB'
    : '${mib.round()} MiB';

String _formatRate(double bytes) => bytes >= 1024 * 1024
    ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MiB/s'
    : bytes >= 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KiB/s'
    : '${bytes.round()} B/s';

class _ResourceMeter extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;

  const _ResourceMeter({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.mutedForeground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.foreground),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: const Color(0xFF2B2F44),
            color: const Color(0xFF21B568),
          ),
        ),
      ],
    );
  }
}

/// Copies the visible terminal text to the clipboard (no scrollback yet).
Future<void> copyScreenText(Map<String, dynamic>? screen) async {
  final rows = (screen?['rows'] as List?) ?? const [];
  final text = rows
      .map(
        (row) => ((row as Map<String, dynamic>)['text'] as String? ?? '')
            .replaceFirst(RegExp(r' +$'), ''),
      )
      .join('\n')
      .replaceFirst(RegExp(r'\n+$'), '\n');
  await Clipboard.setData(ClipboardData(text: text));
}

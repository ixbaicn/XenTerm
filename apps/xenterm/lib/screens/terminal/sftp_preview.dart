import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';

/// SFTP workspace placeholder; no remote filesystem or connection is accessed.
class SftpPreview extends StatelessWidget {
  final Host host;

  const SftpPreview({super.key, required this.host});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: const Color(0xFF141729),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            material.Icons.folder_open,
            size: 44,
            color: scheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            'SFTP · ${host.label}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: scheme.foreground),
          ),
          const SizedBox(height: 8),
          Text(
            'UI 预览 · 尚未连接到服务器',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: scheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

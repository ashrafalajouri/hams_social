import 'package:flutter/material.dart';

import 'update_service.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  required bool force,
  required void Function() onUpdate,
}) {
  return showDialog(
    context: context,
    barrierDismissible: !force,
    builder: (_) {
      return AlertDialog(
        title: Text(force ? 'Update Required' : 'Update Available'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New version: ${info.versionName}'),
              const SizedBox(height: 12),
              if (info.changelog.isNotEmpty) ...[
                const Text(
                  'What is new:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...info.changelog.map((e) => Text('• $e')),
              ],
            ],
          ),
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdate();
            },
            child: const Text('Update'),
          ),
        ],
      );
    },
  );
}

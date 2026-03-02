import 'package:flutter/material.dart';

Future<Map<String, String>?> showReportDialog(BuildContext context) async {
  return showDialog<Map<String, String>>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _ReportDialog(),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _detailsController = TextEditingController();
  String _reason = 'Harassment';

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AlertDialog(
      title: const Text('Report'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _reason,
                items: const [
                  DropdownMenuItem(
                    value: 'Harassment',
                    child: Text('Harassment'),
                  ),
                  DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                  DropdownMenuItem(value: 'Hate', child: Text('Hate')),
                  DropdownMenuItem(value: 'Scam', child: Text('Scam')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) {
                  setState(() => _reason = v ?? 'Harassment');
                },
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'reason': _reason,
              'details': _detailsController.text.trim(),
            });
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

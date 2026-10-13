import 'package:flutter/material.dart';

/// Keeps a form mounted while its write is in flight or awaiting retry.
class SaveButton extends StatefulWidget {
  final Future<bool> Function() onSave;
  final VoidCallback onSaved;
  final bool enabled;
  const SaveButton({super.key, required this.onSave, required this.onSaved, this.enabled = true});
  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSave();
      if (mounted && saved) widget.onSaved();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Your entries are kept; try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!)),
      FilledButton(
        onPressed: _saving || !widget.enabled ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

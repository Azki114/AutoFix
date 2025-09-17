import 'package:flutter/material.dart';

class EtaInputDialog extends StatefulWidget {
  const EtaInputDialog({super.key});

  @override
  State<EtaInputDialog> createState() => _EtaInputDialogState();
}

class _EtaInputDialogState extends State<EtaInputDialog> {
  // The controller is created and managed entirely within this widget's state.
  late final TextEditingController _etaController;

  @override
  void initState() {
    super.initState();
    _etaController = TextEditingController();
  }

  @override
  void dispose() {
    // This ensures the controller is always cleaned up when the dialog is closed.
    _etaController.dispose();
    super.dispose();
  }

  void _submit() {
    final int? input = int.tryParse(_etaController.text.trim());
    if (input != null && input > 0) {
      // Pop the dialog and return the valid number.
      Navigator.of(context).pop(input);
    } else {
      // Show an error message if the input is invalid.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number for ETA.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Acceptance & ETA'),
      content: TextField(
        controller: _etaController,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'e.g., 15',
          labelText: 'ETA (minutes)',
        ),
        onSubmitted: (_) => _submit(), // Allow submitting with the keyboard's done button
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
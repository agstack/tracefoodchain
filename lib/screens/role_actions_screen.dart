import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class RoleActionsScreen extends StatelessWidget {
  final String role;
  final List<String> actions;

  const RoleActionsScreen(
      {super.key, required this.role, required this.actions});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.actions} - $role')),
      body: ListView.builder(
        itemCount: actions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(actions[index]),
            onTap: () {
              // TODO: Implement action-specific logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${actions[index]} action selected')),
              );
            },
          );
        },
      ),
    );
  }
}

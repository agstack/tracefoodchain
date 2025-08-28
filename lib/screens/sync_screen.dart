import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  _SyncScreenState createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncData),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSyncing)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _syncData,
                child: Text(l10n.startSync),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // await _databaseHelper.syncData();
      fshowInfoDialog(context, "Syncing not implemented!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.syncSuccess)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${AppLocalizations.of(context)!.syncError}: $e')),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
}

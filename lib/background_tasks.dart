import 'package:workmanager/workmanager.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';

const syncTaskName = "syncData";

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case syncTaskName:
        try {
          final databaseHelper = DatabaseHelper();
          //ToDo: 
          
          return true;
        } catch (e) {
          
          return false;
        }
      default:
        return false;
    }
  });
}

void initializeBackgroundTasks() {
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    "1",
    syncTaskName,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );
}

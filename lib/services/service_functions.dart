import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/repositories/honduras_specifics.dart';
import 'package:trace_foodchain_app/widgets/custom_text_field.dart';
import 'package:trace_foodchain_app/repositories/coffee_species.dart'
    as coffee_species;

Future<String> fshowInfoDialog(BuildContext context, String text) async {
  await showDialog(
    context: context,
    builder: (context) {
      return Theme(
        data: customTheme,
        child: AlertDialog(
          surfaceTintColor: Colors.white,
          content: SizedBox(
            width: 300,
            child: Text(
              text,
              style: const TextStyle(color: Colors.black),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                  surfaceTintColor: Colors.white,
                  textStyle: const TextStyle(color: Colors.black)),
              onPressed: Navigator.of(context).pop,
              child: const Text('OK', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    },
  );
  return "done";
}

Future<String> fshowInputDialog(
    BuildContext context, String description, String oldText) async {
  final textController = TextEditingController();
  textController.text = oldText;
  await showDialog(
    context: context,
    builder: (context) {
      return Theme(
        data: customTheme,
        child: AlertDialog(
          surfaceTintColor: Colors.white,
          content: SizedBox(
            width: 300,
            height: 200,
            child: Column(
              children: [
                Text(description, style: const TextStyle(color: Colors.black)),
                const SizedBox(
                  height: 12,
                ),
                CustomTextField(
                  hintText: '',
                  controller: textController,
                  textColor: Colors.black,
                  obscureText: false,
                ),
              ],
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('OK'),
            ),
          ],
        ),
      );
    },
  );
  return textController.text;
}

Future<bool> fshowQuestionDialog(BuildContext context, String message,
    String button1, String button2) async {
  bool value = false;
  await showCupertinoDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Theme(
        data: customTheme,
        child: AlertDialog(
          surfaceTintColor: Colors.white,
          content: Text(message, style: const TextStyle(color: Colors.black54)),
          actions: [
            TextButton(
              onPressed: () {
                value = true;
                Navigator.pop(context);
              },
              child: Text(button1, style: const TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                value = false;
                Navigator.pop(context);
              },
              child: Text(button2, style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    },
  );
  return value;
}

void hideCurrentSnackbar(BuildContext context) =>
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

void showSnackbar(
  BuildContext context,
  String message,
  String scope, {
  int duration = 4,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: scope == "alert" ? Colors.red : const Color(0xFFD1A256),
      content: Text(message, style: const TextStyle(color: Colors.white)),
      duration: Duration(seconds: duration),
    ),
  );
}

List<String> loadCoffeeSpecies() {
  return coffee_species.species;
}

List<Map<String, dynamic>> getWeightUnits(String country) {
  if (country.toLowerCase() == 'honduras') {
    return weightsHonduras;
  }
  return [
    {"name": "kg", "toKgFactor": 1.0},
    {"name": "t", "toKgFactor": 1000.0},
  ];
}

List<Map<String, dynamic>> getAreaUnits(String country) {
  if (country.toLowerCase() == 'honduras') {
    return areaUnitsHonduras;
  }
  return [
    {"name": "hectares", "symbol": "ha", "toHectareFactor": 1.0},
    {"name": "acres", "symbol": "ac", "toHectareFactor": 0.404686},
  ];
}

/// Konvertiert Hektar in die angegebene Einheit (anhand des toHectareFactor).
/// [areaUnit] ist eine Map aus getAreaUnits(), z.B. {"name":"manzanas","symbol":"mz","toHectareFactor":0.70259}
double convertFromHectares(double hectares, Map<String, dynamic> areaUnit) {
  final factor = (areaUnit['toHectareFactor'] as num).toDouble();
  return hectares / factor;
}

class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final regEx = RegExp(r'^\d*[,.]?\d*$');
    String newString = newValue.text;
    if (regEx.hasMatch(newString)) {
      return newValue;
    }
    return oldValue;
  }
}

String truncateUID(String? uid, {int length = 8, bool showEllipsis = true}) {
  if (uid == null || uid.isEmpty) {
    return '';
  }
  if (uid.length <= length) {
    return uid;
  }
  return '${uid.substring(0, length)}${showEllipsis ? '...' : ''}';
}

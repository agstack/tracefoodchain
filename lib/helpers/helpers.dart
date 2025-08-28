import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:trace_foodchain_app/repositories/honduras_specifics.dart';

List<Map<String, dynamic>> getProcessingStates(String country) {
  if (country.toLowerCase() == 'honduras') {
    return coffeeProcessingStatesHonduras;
  }
  return [
    {
      "name": {
        "spanish": "uva",
        "english": "cherry",
        "french": "cerise",
        "german": "Kirsche"
      },
      "weightCorrectionFactor": 0.1823
    },
    {
      "name": {
        "spanish": "pergamino seco",
        "english": "dry parchment",
        "french": "parche sec",
        "german": "trockenes Pergament"
      },
      "weightCorrectionFactor": 0.8192
    },
    {
      "name": {
        "spanish": "oro",
        "english": "green",
        "french": "vert",
        "german": "Grün"
      },
      "weightCorrectionFactor": 1
    },
    {
      "name": {
        "spanish": "asada",
        "english": "roasted",
        "french": "torréfié",
        "german": "geröstet"
      },
      "weightCorrectionFactor": 1
    },
    {
      "name": {
        "spanish": "asada molido",
        "english": "ground roasted",
        "french": "torréfié moulu",
        "german": "geröstet gemahlen"
      },
      "weightCorrectionFactor": 1
    },
  ];
}

List<Map<String, dynamic>> getQualityReductionCriteria(String country) {
  if (country.toLowerCase() == 'honduras') {
    return coffeeReducedQualityCriteria;
  }
  return [
    {
      "name": {
        "spanish": "demasiada pulpa mezclada con café despulpado",
        "english": "too much fleshy pulp mixed with depulped coffee",
        "french": "trop de pulpe mélangée avec du café dépulpé",
        "german": "zu viel Fruchtfleisch vermischt mit entpulptem Kaffee"
      },
    },
    {
      "name": {
        "spanish": "sobre fermentado",
        "english": "overly fermented",
        "french": "trop fermenté",
        "german": "überfermentiert"
      },
    },
    {
      "name": {
        "spanish": "color extraño",
        "english": "strange color",
        "french": "couleur étrange",
        "german": "ungewöhnliche Farbe"
      },
    },
    {
      "name": {
        "spanish": "olor extraño",
        "english": "strange odor",
        "french": "odeur étrange",
        "german": "ungewöhnlicher Geruch"
      },
    }
  ];
}

Widget getContainerIcon(String containerType) {
  switch (containerType) {
    case "bag":
      return const Icon(Icons.shopping_bag);
    case "container":
      return const Icon(Icons.inventory_2);
    case "building":
      return const Icon(Icons.business);
    case "transportVehicle":
      return const Icon(Icons.local_shipping);

    default:
      return const Icon(Icons.help);
  }
}

String getContainerTypeName(String containerType, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  switch (containerType) {
    case "bag":
      return l10n.bag;
    case "container":
      return l10n.container;
    case "building":
      return l10n.building;
    case "transportVehicle":
      return l10n.transportVehicle;

    default:
      return l10n.container;
  }
}

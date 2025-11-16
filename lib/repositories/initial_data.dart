//This repository contains all data objects and methods that are necessary on initial startup (without any local data)

//! 1. openRAL templates
import 'package:flutter_dotenv/flutter_dotenv.dart';

Map<String, dynamic> initialObjectTemplateFarm = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "A 'farm' is a commercial entity containing of parcel(s) of land, including its buildings and other resources, that is used for the purpose of producing food, fiber, and other agricultural products. Farms can vary greatly in size and function, ranging from small family-owned operations to large industrial enterprises. The primary activities on a farm typically include the cultivation of crops (such as grains, fruits, vegetables, or legumes) and the raising of livestock (such as cattle, sheep, pigs, or poultry). Farms may also include additional facilities like barns, silos, storage sheds, greenhouses, and irrigation systems, all of which support the production process. Some farms may specialize in a single type of production, such as dairy farming or orcharding, while others may be diversified, growing a variety of crops and raising different types of animals. The management of a farm involves not only the physical labor of planting, tending, and harvesting but also the planning and decision-making necessary to ensure sustainable and profitable operation.",
    "definitionURL": " "
  },
  "objectState": "undefined",
  "template": {
    "RALType": "farm",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"name": "phoneNumbers", "value": "", "unit": "comma_separated_stringlist"}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "",
      "cityName": "",
      "cityNumber": "",
      "streetName": "",
      "streetNumber": ""
    },
    "deliveryAddress": {
      "country": "",
      "cityName": "",
      "cityNumber": "",
      "streetName": "",
      "streetNumber": ""
    },
    "billingAddress": {
      "country": "",
      "cityName": "",
      "cityNumber": "",
      "streetName": "",
      "streetNumber": ""
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0.0, "latitude": 0.0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};
Map<String, dynamic> initialObjectTemplateHuman = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {"definitionText": "A human being.", "definitionURL": ""},
  "objectState": "undefined",
  "template": {
    "RALType": "human",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "emailAddress", "value": "", "unit": "emailAddress"},
    {"key": "userRole", "value": "", "unit": "String"},
    {"key": "streetName", "value": "", "unit": "String"},
    {"key": "streetNumber", "value": "", "unit": "String"},
    {"key": "cityName", "value": "", "unit": "String"},
    {"key": "cityNumber", "value": "", "unit": "String"}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
}; //Roles: farmer, seller, buyer, aggregator, importer, exporter

Map<String, dynamic> initialObjectTemplatePlot = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "In an agricultural context, a 'field' refers to a specific area of land designated for the cultivation of crops or the grazing of livestock. Fields are typically delineated by natural boundaries like hedgerows, fences, or other markers, and they are managed by farmers to optimize the production of agricultural products. The size, shape, and use of a field can vary widely depending on the type of farming, the landscape, and the agricultural practices employed. Fields are fundamental units in farming operations, and they may be used for growing a single crop (monoculture) or multiple crops (polyculture), or for rotational grazing in the case of livestock farming. Soil preparation, irrigation, planting, and harvesting are all activities that take place within these fields.",
    "definitionURL": " "
  },
  "objectState": "undefined",
  "template": {
    "RALType": "field",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"name": "area", "value": "", "unit": "ha"},
    {"name": "boundaries", "value": "", "unit": "vector_list"},
    {"name": "soil type", "value": "", "unit": "soil_type"},
    {"name": "soil value", "value": "", "unit": "soil_value_germany"}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0.0, "latitude": 0.0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

Map<String, dynamic> initialObjectTemplateCoffee = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "Coffee, in relation to harvested coffee beans, refers to the seeds of the Coffea plant, typically extracted from its fruit (called cherries). These beans are harvested, processed, dried, and roasted to produce the beverage known as coffee. They are the primary raw material for making brewed coffee, with their flavor influenced by factors like origin, processing methods, and roasting techniques.",
    "definitionURL": ""
  },
  "objectState": "undefined",
  "template": {
    "RALType": "coffee",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "species", "value": "", "unit": "String"},
    {"key": "country", "value": "", "unit": "String"},
    {"key": "amount", "value": null, "unit": "double"},
    {"key": "processingState", "value": "", "unit": "stringlist"},
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

Map<String, dynamic> initialObjectTemplateCompany = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "Eine Firma bezieht sich allgemein auf eine Organisation oder ein Unternehmen, das geschäftliche Aktivitäten ausübt. Es ist eine rechtliche Entität, die gegründet wurde, um Geschäfte zu tätigen, Gewinne zu erzielen und Verantwortung für seine Handlungen zu übernehmen. Der Begriff Firma wird oft als Synonym für ein Unternehmen oder eine Geschäftseinheit verwendet.",
    "definitionURL": "https://de.wikipedia.org/wiki/Company"
  },
  "objectState": "undefined",
  "template": {
    "RALType": "company",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "companyLogo", "value": "", "unit": "URL"},
    {"key": "companyURL", "value": "", "unit": "URL"},
    {"key": "companyEmail", "value": "", "unit": "emailAddress"},
    {
      "key": "companyCI",
      "value": {
        "primaryColor": 0,
        "secondaryColor": 0,
        "accentColor": 0,
        "primaryFont": "",
        "secondaryFont": ""
      },
      "unit": "JSON"
    }
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "deliveryAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "billingAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

Map<String, dynamic> initialObjectTemplateContainer = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "The term 'container' has different meanings depending on the context, but generally, a 'container' refers to an object or vessel used to hold, store, or transport items, substances, or materials. Here are a few specific definitions based on different contexts: A container is any object that can hold and secure contents, often with a lid, seal, or closure. This includes boxes, bottles, jars, cans, and crates used for storage or transport.",
    "definitionURL": "https://www.thefreedictionary.com/container"
  },
  "objectState": "undefined",
  "template": {
    "RALType": "container",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "serial number", "value": "", "unit": "String"},
    {"key": "max capacity", "value": "", "unit": ""}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

Map<String, dynamic> initialObjectTemplateBag = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "A bag is a flexible container typically made of materials like cloth, paper, plastic, or leather, used for carrying or storing items.",
    "definitionURL": ""
  },
  "objectState": "undefined",
  "template": {
    "RALType": "bag",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "serial number", "value": "", "unit": "String"},
    {"key": "max capacity", "value": "", "unit": ""}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

Map<String, dynamic> initialObjectTemplateBuilding = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "A building is a permanent structure with a roof and walls constructed for various uses such as residential living, commercial activities, industrial operations, or storage purposes. Buildings provide shelter and space for human activities and can range in size from small huts to large skyscrapers.",
    "definitionURL": ""
  },
  "objectState": "undefined",
  "template": {
    "RALType": "building",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "serial number", "value": "", "unit": "String"},
    {"key": "max capacity", "value": "", "unit": ""}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

Map<String, dynamic> initialObjectTemplateTransportVehicle = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "A transport vehicle is any means of conveyance designed to move goods or people from one location to another. This includes a wide range of modes such as trucks, cars, vans, trains, ships, and airplanes. Transport vehicles are essential components in logistics and supply chains, facilitating the efficient movement of products.",
    "definitionURL": ""
  },
  "objectState": "undefined",
  "template": {
    "RALType": "transportVehicle",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "serial number", "value": "", "unit": "String"},
    {"key": "max capacity", "value": "", "unit": ""}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

Map<String, dynamic> initialMethodTemplateHarvest = {
  "definition": {
    "definitionText":
        "Harvest refers to the process of gathering mature crops from the fields where they have been grown. It is a crucial stage in the agricultural cycle and typically marks the end of the growing season for a particular crop. The term can also be used to describe the act of collecting other agricultural products, such as fruits, vegetables, or nuts, as well as the gathering of animal products, like honey or fish. The harvest process can vary significantly depending on the type of crop, the scale of farming, and the tools or machinery available. It can involve manual labor, such as picking fruits by hand, or it can be mechanized, using equipment like combines, harvesters, or threshers to efficiently collect large quantities of grain or other crops.Harvesting is not only about collecting the crops but also involves the steps necessary to prepare the produce for storage, sale, or consumption. This may include cleaning, drying, sorting, or packaging the harvested products. The timing of the harvest is crucial, as it directly affects the quality, yield, and profitability of the crops.",
    "definitionURL": ""
  },
  "existenceStarts": null,
  "executor": {},
  "duration": null,
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "methodState": "undefined",
  "template": {
    "RALType": "harvestAgriculturalProducts",
    "version": "1",
    "methodStateTemplates": "generalMethodState"
  },
  "specificProperties": [],
  "inputObjects": [],
  "inputObjectsRef": [],
  "outputObjects": [],
  "outputObjectsRef": [],
  "nestedMethods": []
};

Map<String, dynamic> initialMethodTemplateChangeContainer = {
  "definition": {
    "definitionText": "A Method to change the container of an object",
    "definitionURL": ""
  },
  "existenceStarts": null,
  "executor": {},
  "duration": null,
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "methodState": "undefined",
  "template": {
    "RALType": "changeContainer",
    "version": "1",
    "methodStateTemplates": "generalMethodState"
  },
  "specificProperties": [],
  "inputObjects": [],
  "inputObjectsRef": [],
  "outputObjects": [],
  "outputObjectsRef": [],
  "nestedMethods": []
};

Map<String, dynamic> initialMethodTemplateChangeOwner = {
  "definition": {
    "definitionText": "A Method to change the owner of an object",
    "definitionURL": ""
  },
  "existenceStarts": null,
  "executor": {},
  "duration": null,
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "methodState": "undefined",
  "template": {
    "RALType": "changeOwner",
    "version": "1",
    "methodStateTemplates": "generalMethodState"
  },
  "specificProperties": [],
  "inputObjects": [],
  "inputObjectsRef": [],
  "outputObjects": [],
  "outputObjectsRef": [],
  "nestedMethods": []
};

Map<String, dynamic> initialMethodTemplateChangeProcessingState = {
  "definition": {
    "definitionText": "A Method to change the processing state of an object",
    "definitionURL": ""
  },
  "existenceStarts": null,
  "executor": {},
  "duration": null,
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "methodState": "undefined",
  "template": {
    "RALType": "changeProcessingState",
    "version": "1",
    "methodStateTemplates": "generalMethodState"
  },
  "specificProperties": [],
  "inputObjects": [],
  "inputObjectsRef": [],
  "outputObjects": [],
  "outputObjectsRef": [],
  "nestedMethods": []
};

Map<String, dynamic> initialMethodTemplateGenerateDigitalSibling = {
  "definition": {
    "definitionText":
        "A process that generates a new digital sibling of an existing real world object",
    "definitionURL": ""
  },
  "existenceStarts": null,
  "executor": {},
  "duration": null,
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "methodState": "undefined",
  "template": {
    "RALType": "generateDigitalSibling",
    "version": "1",
    "methodStateTemplates": "generalMethodState"
  },
  "specificProperties": [],
  "inputObjects": [],
  "inputObjectsRef": [],
  "outputObjects": [],
  "outputObjectsRef": [],
  "nestedMethods": []
};

Map<String, dynamic> initialMethodTemplateChangeObjectData = {
  "definition": {
    "definitionText": "A process that persists changes made to an object.",
    "definitionURL": "",
  },
  "existenceStarts": null,
  "executor": {},
  "duration": null,
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": [],
  },
  "methodState": "undefined",
  "template": {
    "RALType": "changeObjectData",
    "version": "1",
    "methodStateTemplates": "generalMethodState",
  },
  "specificProperties": [],
  "inputObjects": [],
  "inputObjectsRef": [],
  "outputObjects": [],
  "outputObjectsRef": [],
  "nestedMethods": [],
};

Map<String, dynamic> initialMethodTemplateChangeUserRole = {
  "definition": {
    "definitionText":
        "A method to change the role of a user with proper audit logging through methodHistory.",
    "definitionURL": "",
  },
  "existenceStarts": null,
  "executor": {},
  "duration": null,
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": [],
  },
  "methodState": "undefined",
  "template": {
    "RALType": "changeUserRole",
    "version": "1",
    "methodStateTemplates": "generalMethodState",
  },
  "specificProperties": [
    {"key": "oldRole", "value": "", "unit": "String"},
    {"key": "newRole", "value": "", "unit": "String"},
    {"key": "roleChangeReason", "value": "", "unit": "String"},
    {"key": "adminUID", "value": "", "unit": "String"}
  ],
  "inputObjects": [],
  "inputObjectsRef": [],
  "outputObjects": [],
  "outputObjectsRef": [],
  "nestedMethods": [],
};

Map<String, dynamic> initialObjectTemplateRoleTemplate = {
  "identity": {
    "UID": "",
    "name": "",
    "siteTag": "",
    "alternateIDs": [],
    "alternateNames": []
  },
  "currentOwners": [],
  "definition": {
    "definitionText":
        "A role template defining permissions and capabilities for different user roles in the system.",
    "definitionURL": ""
  },
  "objectState": "undefined",
  "template": {
    "RALType": "roleTemplate",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  },
  "specificProperties": [
    {"key": "roleName", "value": "", "unit": "String"},
    {"key": "roleLevel", "value": 0, "unit": "int"},
    {"key": "permissions", "value": [], "unit": "stringlist"},
    {"key": "canManageRoles", "value": [], "unit": "stringlist"},
    {"key": "maxUsersCanManage", "value": 0, "unit": "int"},
    {"key": "roleDescription", "value": "", "unit": "String"},
    {"key": "isSystemRole", "value": false, "unit": "boolean"}
  ],
  "currentGeolocation": {
    "container": {"UID": "unknown"},
    "postalAddress": {
      "country": "unknown",
      "cityName": "unknown",
      "cityNumber": "unknown",
      "streetName": "unknown",
      "streetNumber": "unknown"
    },
    "3WordCode": "unknown",
    "geoCoordinates": {"longitude": 0, "latitude": 0},
    "plusCode": "unknown"
  },
  "locationHistoryRef": [],
  "ownerHistoryRef": [],
  "methodHistoryRef": [],
  "linkedObjectRef": []
};

List<Map<String, dynamic>> initialTemplates = [
  initialObjectTemplateFarm,
  initialObjectTemplateHuman,
  initialObjectTemplatePlot,
  initialObjectTemplateContainer,
  initialObjectTemplateCompany,
  initialObjectTemplateCoffee,
  initialObjectTemplateBag,
  initialObjectTemplateBuilding,
  initialObjectTemplateTransportVehicle,
  initialMethodTemplateHarvest,
  initialMethodTemplateChangeContainer,
  initialMethodTemplateChangeOwner,
  initialMethodTemplateChangeProcessingState,
  initialMethodTemplateGenerateDigitalSibling,
  initialMethodTemplateChangeObjectData,
  initialMethodTemplateChangeUserRole,
  initialObjectTemplateRoleTemplate
];

//! 2. cloud connectors
// cloud connector openRAL
Map<String, dynamic> initialCloudConnectorOpenRAL = {
  "currentGeolocation": {
    "3WordCode": "unknown",
    "postalAddress": {
      "cityNumber": "unknown",
      "streetNumber": "unknown",
      "country": "unknown",
      "streetName": "unknown",
      "cityName": "unknown"
    },
    "container": {"UID": "unknown"},
    "plusCode": "unknown",
    "geoCoordinates": {"_latitude": 0, "_longitude": 0}
  },
  "methodHistoryRef": [],
  "specificProperties": [
    {"unit": "String", "value": "open-ral.io", "key": "cloudDomain"}
  ],
  "__propertyIdx": {},
  "identity": {
    "name": "cloud connector openRAL",
    "alternateIDs": [],
    "siteTag": "",
    "alternateNames": [],
    "UID": "ce6PkmUe1p1WRrbJpeYC"
  },
  "currentOwners": [],
  "ownerHistoryRef": [],
  "objectUID": "ce6PkmUe1p1WRrbJpeYC",
  "linkedObjects": [
    {
      "currentOwners": [],
      "linkedObjectRef": [],
      "template": {
        "RALType": "firebaseConnector",
        "version": "1",
        "objectStateTemplates": "generalObjectState"
      },
      "role": "databaseConnector",
      "locationHistoryRef": [],
      "objectState": "undefined",
      "currentGeolocation": {
        "geoCoordinates": {"_latitude": 0, "_longitude": 0},
        "container": {"UID": "unknown"},
        "3WordCode": "unknown",
        "postalAddress": {
          "streetNumber": "unknown",
          "cityNumber": "unknown",
          "cityName": "unknown",
          "country": "unknown",
          "streetName": "unknown"
        },
        "plusCode": "unknown"
      },
      "specificProperties": [
        {"key": "appId", "unit": "String", "value": ""},
        {
          "key": "apiKey",
          "value": dotenv.env['FIREBASE_API_KEY'] ?? '',
          "unit": "String"
        },
        {"value": "", "unit": "String", "key": "projectId"},
        {"unit": "String", "value": "", "key": "messagingSenderId"},
        {"unit": "authDomain", "key": "messagingSenderId", "value": ""}
      ],
      "methodHistoryRef": [],
      "definition": {
        "definitionURL": "",
        "definitionText":
            "Contains all information to connect to a firebase cloud instance"
      },
      "ownerHistoryRef": [],
      "identity": {
        "name": "",
        "alternateNames": [],
        "siteTag": "",
        "UID": "",
        "alternateIDs": []
      }
    },
    {
      "currentGeolocation": {
        "geoCoordinates": {"_latitude": 0, "_longitude": 0},
        "postalAddress": {
          "streetNumber": "unknown",
          "streetName": "unknown",
          "cityName": "unknown",
          "country": "unknown",
          "cityNumber": "unknown"
        },
        "3WordCode": "unknown",
        "plusCode": "unknown",
        "container": {"UID": "unknown"}
      },
      "role": "cloudFunctionsConnector",
      "identity": {
        "name": "",
        "alternateNames": [],
        "siteTag": "",
        "UID": "",
        "alternateIDs": []
      },
      "locationHistoryRef": [],
      "linkedObjectRef": [],
      "definition": {
        "definitionURL": "",
        "definitionText":
            "A specialized type of software component designed to facilitate the integration and communication between cloud-based functions and other services or resources within a cloud environment. This object acts as an intermediary, providing a standardized interface for invoking cloud functions, managing data exchange, and handling responses. It encapsulates the necessary details such as authentication credentials, function identifiers, and network configurations to securely and efficiently connect with cloud functions. By abstracting the underlying complexities, it enables developers to more easily build scalable and responsive applications that leverage serverless computing paradigms"
      },
      "ownerHistoryRef": [],
      "methodHistoryRef": [],
      "specificProperties": [
        {
          "value": {
            "url":
                "https://europe-west3-ral1-80620.cloudfunctions.net/smartRequestTemplateWeb"
          },
          "key": "smartRequestTemplateWeb",
          "unit": "json"
        },
        {
          "value": {
            "url":
                "https://europe-west3-ral1-80620.cloudfunctions.net/smartRequestDescendantsWeb"
          },
          "unit": "json",
          "key": "smartRequestDescendantsWeb"
        },
        {
          "unit": "json",
          "key": "checkHealthWeb",
          "value": {
            "url":
                "https://europe-west3-ral1-80620.cloudfunctions.net/checkHealthWeb"
          }
        },
        {
          "unit": "String",
          "key": "apiKey",
          "value": dotenv.env['FIREBASE_API_KEY'] ?? ''
        }
      ],
      "objectState": "undefined",
      "template": {
        "objectStateTemplates": "generalObjectState",
        "RALType": "cloudFunctionsConnector",
        "version": "1"
      },
      "currentOwners": []
    }
  ],
  "definition": {
    "definitionText":
        "A cloud connection object is a software component or tool that encapsulates the necessary information and functionalities to establish, manage, and maintain a secure and efficient communication link between a local or remote client and a cloud computing instance. It typically includes credentials, endpoint URLs, protocols, and configuration settings required to authenticate, send, and receive data from cloud services. This object abstracts the complexity of direct cloud interactions, providing a simplified interface for applications to leverage cloud resources and services.",
    "definitionURL": ""
  },
  "locationHistoryRef": [],
  "objectState": "undefined",
  "linkedObjectRef": [],
  "template": {
    "RALType": "cloudConnector",
    "version": "1",
    "objectStateTemplates": "generalObjectState"
  }
};
// cloud connector WHISP
Map<String, dynamic> initialCloudConnectorWHISP = {};
// cloud connector Asset Registry
Map<String, dynamic> initialCloudConnectorAssetRegistry = {};
// cloud connector Permarobotics
Map<String, dynamic> initialCloudConnectorTraceFoodchain = {
  "methodHistoryRef": [],
  "ownerHistoryRef": [],
  "objectState": "undefined",
  "specificProperties": [
    {"key": "cloudDomain", "unit": "String", "value": "tracefoodchain.org"}
  ],
  "locationHistoryRef": [],
  "currentOwners": [],
  "definition": {
    "definitionURL": "",
    "definitionText":
        "A cloud connection object is a software component or tool that encapsulates the necessary information and functionalities to establish, manage, and maintain a secure and efficient communication link between a local or remote client and a cloud computing instance. It typically includes credentials, endpoint URLs, protocols, and configuration settings required to authenticate, send, and receive data from cloud services. This object abstracts the complexity of direct cloud interactions, providing a simplified interface for applications to leverage cloud resources and services."
  },
  "linkedObjectRef": [],
  "linkedObjects": [
    {
      "currentOwners": [],
      "objectState": "undefined",
      "methodHistoryRef": [],
      "specificProperties": [
        {"value": "", "key": "appId", "unit": "String"},
        {
          "value": dotenv.env['FIREBASE_API_KEY'] ?? '',
          "key": "apiKey",
          "unit": "String"
        },
        {"value": "", "unit": "String", "key": "projectId"},
        {"unit": "String", "value": "", "key": "messagingSenderId"},
        {"unit": "authDomain", "value": "", "key": "messagingSenderId"}
      ],
      "locationHistoryRef": [],
      "linkedObjectRef": [],
      "template": {
        "version": "1",
        "objectStateTemplates": "generalObjectState",
        "RALType": "firebaseConnector"
      },
      "role": "databaseConnector",
      "currentGeolocation": {
        "plusCode": "unknown",
        "container": {"UID": "unknown"},
        "3WordCode": "unknown",
        "postalAddress": {
          "streetName": "unknown",
          "streetNumber": "unknown",
          "country": "unknown",
          "cityName": "unknown",
          "cityNumber": "unknown"
        },
        "geoCoordinates": {"_latitude": 0, "_longitude": 0}
      },
      "ownerHistoryRef": [],
      "definition": {
        "definitionText":
            "Contains all information to connect to a firebase cloud instance",
        "definitionURL": ""
      },
      "identity": {
        "alternateIDs": [],
        "alternateNames": [],
        "UID": "",
        "name": "",
        "siteTag": ""
      }
    },
    {
      "methodHistoryRef": [],
      "identity": {
        "name": "",
        "alternateIDs": [],
        "UID": "",
        "siteTag": "",
        "alternateNames": []
      },
      "ownerHistoryRef": [],
      "specificProperties": [
        {
          "value": {
            "definition": "Endpoint to persist the public key.",
            "url":
                "https://europe-west3-tracefoodchain.cloudfunctions.net/persistPublicKey"
          },
          "unit": "json",
          "key": "persistPublicKey"
        },
        {
          "key": "apiKey",
          "unit": "String",
          "value": dotenv.env['FIREBASE_API_KEY'] ?? ''
        },
        {
          "value": {
            "definition": "Endpoint to sync local methods to the cloud.",
            "url":
                "https://europe-west3-tracefoodchain.cloudfunctions.net/syncMethodToCloud"
          },
          "unit": "json",
          "key": "syncMethodToCloud"
        },

        {
          "value": {
            "definition":
                "Endpoint to get all relevant objects and methods from cloud.",
            "url":
                "https://europe-west3-tracefoodchain.cloudfunctions.net/syncFromCloud"
          },
          "unit": "json",
          "key": "syncFromCloud"
        },
        {
          "value": {
            "definition": "Endpoint to get a user doc by its email.",
            "url":
                "https://europe-west3-tracefoodchain.cloudfunctions.net/findUserByEmail"
          },
          "unit": "json",
          "key": "findUserByEmail"
        },
        {
          "value": {
            "definition":
                "Endpoint that allows to retrieve a specific method by its UID. from cloud",
            "url":
                "https://europe-west3-tracefoodchain.cloudfunctions.net/getRalMethodByUid"
          },
          "unit": "json",
          "key": "getRALMethodByUID"
        }
        //  ?UID=
      ],
      "locationHistoryRef": [],
      "currentOwners": [],
      "template": {
        "version": "1",
        "objectStateTemplates": "generalObjectState",
        "RALType": "cloudFunctionsConnector"
      },
      "linkedObjectRef": [],
      "currentGeolocation": {
        "plusCode": "unknown",
        "container": {"UID": "unknown"},
        "3WordCode": "unknown",
        "geoCoordinates": {"_latitude": 0, "_longitude": 0},
        "postalAddress": {
          "streetNumber": "unknown",
          "streetName": "unknown",
          "cityName": "unknown",
          "cityNumber": "unknown",
          "country": "unknown"
        }
      },
      "role": "cloudFunctionsConnector",
      "objectState": "undefined",
      "definition": {
        "definitionText":
            "A specialized type of software component designed to facilitate the integration and communication between cloud-based functions and other services or resources within a cloud environment. This object acts as an intermediary, providing a standardized interface for invoking cloud functions, managing data exchange, and handling responses. It encapsulates the necessary details such as authentication credentials, function identifiers, and network configurations to securely and efficiently connect with cloud functions. By abstracting the underlying complexities, it enables developers to more easily build scalable and responsive applications that leverage serverless computing paradigms",
        "definitionURL": ""
      }
    }
  ],
  "template": {
    "objectStateTemplates": "generalObjectState",
    "version": "1",
    "RALType": "cloudConnector"
  },
  "identity": {
    "alternateNames": [],
    "alternateIDs": [],
    "name": "cloud connector tracefoodchain",
    "siteTag": "",
    "UID":
        "O18uLljVZmKetQMs1Jmo" //! Change this to TFC-specific cloud connector! (its from SDx atm)
  },
  "currentGeolocation": {
    "postalAddress": {
      "streetName": "unknown",
      "country": "unknown",
      "streetNumber": "unknown",
      "cityNumber": "unknown",
      "cityName": "unknown"
    },
    "3WordCode": "unknown",
    "container": {"UID": "unknown"},
    "geoCoordinates": {"_latitude": 0, "_longitude": 0},
    "plusCode": "unknown"
  }
};

List<Map<String, dynamic>> initialCloudConnectors = [
  initialCloudConnectorOpenRAL,
  initialCloudConnectorTraceFoodchain,
  //initialCloudConnectorWHISP, //ToDo: Generate Cloud Connector
  //initialCloudConnectorAssetRegistry //ToDo: Generate Cloud Connector
];

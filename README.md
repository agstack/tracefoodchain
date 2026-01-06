# TraceFoodChain App

A comprehensive supply chain tracking application for the coffee industry, supporting EUDR compliance and sustainable trade practices.

![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)
![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)

## Overview

TraceFoodChain is a cross-platform application designed to digitize and streamline coffee supply chain operations. It enables various stakeholders including farmers, traders, processors, and importers to track coffee from farm to cup while ensuring compliance with EU Deforestation Regulation (EUDR). Since the code builds on Flutter, the app can be compiled as native Android or iOS app, webapp, windows, macos or linux. The intention is to minimise native cloud interaction but to use REST-API calls instead to allow to exchange the backend when needed. All internal and external data structures are openRAL.

### Key Features

- 🌱 Complete coffee supply chain tracking
- 📱 Works offline and online
- 🔄 QR code and NFC support for easy tracking
- 📊 EUDR compliance with automated Due Diligence Statements
- 🌍 Multi-language support (English, Spanish, German, French)
- 🔒 Secure authentication and data management
- 🌲 Integration with WHISP for deforestation risk assessment

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase account and project setup
- Android Studio / VS Code with Flutter plugins
- For iOS development: Xcode (on macOS)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/agstack/tracefoodchain.git
cd tracefoodchain
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Create a new Firebase project
   - Download and add the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update Firebase configuration in `lib/firebase_options.dart`

4. Run the app:
```bash
flutter run
```

### Environment Setup

Create a `.env` file in the project root with the following variables:
```
FIREBASE_API_KEY=your_api_key
WHISP_API_KEY=your_whisp_api_key
```

## Architecture

The app follows a clean architecture pattern with the following key components:

- `lib/providers/` - State management using Provider
- `lib/screens/` - UI screens and widgets
- `lib/services/` - Business logic and API interactions
- `lib/repositories/` - Data layer handling local and remote data
- `lib/models/` - Data models and entities

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details. The Apache License 2.0 is a permissive license that allows you to use, modify, and distribute this software, while also providing patent protection and requiring preservation of copyright and license notices.

## Acknowledgments

- Built on the [openRAL](https://open-ral.io) framework
- Deforestation risk assessment powered by [WHISP](https://whisp.openforis.org/)
- Firebase for backend services
- Flutter and the Flutter team for the amazing framework

## Support

For support, please open an issue in the GitHub repository or contact the development team at support@tracefoodchain.org.

## Project Status

Current Version: 1.5.0+21 (2026-01-05)

The project is under active development. Check the [releases page](https://github.com/agstack/tracefoodchain/releases) for the latest updates.

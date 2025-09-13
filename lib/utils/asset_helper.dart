import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AssetHelper {
  static Future<bool> assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      debugPrint("❌ Asset $path does not exist: $e");
      return false;
    }
  }

  static Widget buildBackgroundContainer({
    required Widget child,
    String backgroundAsset = 'assets/images/background.png',
    Color fallbackColor = Colors.white,
    double opacity = 0.5,
  }) {
    return FutureBuilder<bool>(
      future: assetExists(backgroundAsset),
      builder: (context, snapshot) {
        final bool assetExists = snapshot.data ?? false;

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Während des Ladens zeigen wir einen einfachen Container
          return Container(
            color: fallbackColor.withOpacity(opacity),
            child: child,
          );
        }

        if (assetExists) {
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(backgroundAsset),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(opacity),
                  BlendMode.dstATop,
                ),
                onError: (exception, stackTrace) {
                  debugPrint("❌ Error loading background image: $exception");
                },
              ),
            ),
            child: child,
          );
        } else {
          // Fallback wenn Asset nicht existiert
          return Container(
            color: fallbackColor.withOpacity(opacity),
            child: child,
          );
        }
      },
    );
  }

  static Widget buildAssetImage({
    required String assetPath,
    double? width,
    double? height,
    Widget? fallbackWidget,
  }) {
    return FutureBuilder<bool>(
      future: assetExists(assetPath),
      builder: (context, snapshot) {
        final bool assetExists = snapshot.data ?? false;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (assetExists) {
          return Image.asset(
            assetPath,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) {
              debugPrint("❌ Error loading image $assetPath: $error");
              return fallbackWidget ??
                  Icon(
                    Icons.image_not_supported,
                    size: width ?? height ?? 100,
                    color: Colors.grey,
                  );
            },
          );
        } else {
          return fallbackWidget ??
              Icon(
                Icons.image_not_supported,
                size: width ?? height ?? 100,
                color: Colors.grey,
              );
        }
      },
    );
  }
}

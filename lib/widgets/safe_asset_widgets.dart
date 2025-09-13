import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget zum robusten Laden von Assets mit Fallback-Mechanismen
class SafeAssetImage extends StatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final Widget? fallbackWidget;
  final BoxFit fit;

  const SafeAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fallbackWidget,
    this.fit = BoxFit.contain,
  });

  @override
  State<SafeAssetImage> createState() => _SafeAssetImageState();
}

class _SafeAssetImageState extends State<SafeAssetImage> {
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAsset();
  }

  Future<void> _checkAsset() async {
    try {
      await rootBundle.load(widget.assetPath);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Asset ${widget.assetPath} konnte nicht geladen werden: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_hasError) {
      return widget.fallbackWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.image_not_supported,
              size: (widget.width ?? widget.height ?? 100) * 0.5,
              color: Colors.grey[600],
            ),
          );
    }

    return Image.asset(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint("❌ Fehler beim Laden von ${widget.assetPath}: $error");
        return widget.fallbackWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.broken_image,
                size: (widget.width ?? widget.height ?? 100) * 0.5,
                color: Colors.grey[600],
              ),
            );
      },
    );
  }
}

/// Container mit robustem Hintergrundbild
class SafeBackgroundContainer extends StatefulWidget {
  final Widget child;
  final String? backgroundAsset;
  final Color fallbackColor;
  final double opacity;

  const SafeBackgroundContainer({
    super.key,
    required this.child,
    this.backgroundAsset,
    this.fallbackColor = Colors.white,
    this.opacity = 0.5,
  });

  @override
  State<SafeBackgroundContainer> createState() =>
      _SafeBackgroundContainerState();
}

class _SafeBackgroundContainerState extends State<SafeBackgroundContainer> {
  bool _hasBackgroundAsset = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.backgroundAsset != null) {
      _checkBackgroundAsset();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _checkBackgroundAsset() async {
    if (widget.backgroundAsset == null) return;

    try {
      await rootBundle.load(widget.backgroundAsset!);
      if (mounted) {
        setState(() {
          _hasBackgroundAsset = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
          "❌ Hintergrundbild ${widget.backgroundAsset} konnte nicht geladen werden: $e");
      if (mounted) {
        setState(() {
          _hasBackgroundAsset = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: widget.fallbackColor.withOpacity(widget.opacity),
        child: widget.child,
      );
    }

    if (_hasBackgroundAsset && widget.backgroundAsset != null) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(widget.backgroundAsset!),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(widget.opacity),
              BlendMode.dstATop,
            ),
            onError: (exception, stackTrace) {
              debugPrint(
                  "❌ Fehler beim Laden des Hintergrundbilds: $exception");
            },
          ),
        ),
        child: widget.child,
      );
    } else {
      return Container(
        color: widget.fallbackColor.withOpacity(widget.opacity),
        child: widget.child,
      );
    }
  }
}

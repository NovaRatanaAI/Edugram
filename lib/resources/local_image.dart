import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'local_store.dart';

/// Displays an image that may be either:
///   • a local:// url (bytes stored in LocalStore)
///   • a real network url (falls back to a placeholder)
class LocalImage extends StatelessWidget {
  static final Map<String, ImageProvider> _networkProviders = {};
  static final Map<String, ImageProvider> _resizedProviders = {};
  static final Set<String> _precacheKeys = {};

  final String url;
  final double? radius; // if set, renders as CircleAvatar
  final BoxFit fit;
  final double? height;
  final double? width;
  final bool preferHtmlElementOnWeb;

  const LocalImage({
    Key? key,
    required this.url,
    this.radius,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.preferHtmlElementOnWeb = true,
  }) : super(key: key);

  static void precacheUrls(
    BuildContext context,
    Iterable<String?> urls, {
    double? width,
    double? height,
    int limit = 12,
  }) {
    final uniqueUrls = urls
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet()
        .take(limit);

    for (final url in uniqueUrls) {
      final provider = _providerForUrl(url, width: width, height: height);
      if (provider == null) continue;

      final key = '$url@${_cacheDimension(width)}x${_cacheDimension(height)}';
      if (_precacheKeys.length > 200) {
        _precacheKeys.clear();
      }
      if (!_precacheKeys.add(key)) continue;

      precacheImage(provider, context).catchError((_) {
        _precacheKeys.remove(key);
      });
    }
  }

  static ImageProvider? providerForUrl(
    String url, {
    double? width,
    double? height,
  }) {
    return _providerForUrl(url, width: width, height: height);
  }

  Widget _buildPlaceholder() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[800],
      child: const Icon(Icons.image, color: Colors.white54),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (radius != null) {
      final diameter = radius! * 2;
      return _buildImage(width ?? diameter, height ?? diameter);
    }

    if (radius == null && (width == null || height == null)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final resolvedWidth = width ??
              (constraints.hasBoundedWidth ? constraints.maxWidth : null);
          final resolvedHeight = height ??
              (constraints.hasBoundedHeight ? constraints.maxHeight : null);
          return _buildImage(resolvedWidth, resolvedHeight);
        },
      );
    }

    return _buildImage(width, height);
  }

  Widget _buildImage(double? resolvedWidth, double? resolvedHeight) {
    final localProvider = LocalStore.instance.getImageProviderForUrl(url);
    final isWebNetwork = kIsWeb &&
        preferHtmlElementOnWeb &&
        localProvider == null &&
        url.startsWith('http');

    if (isWebNetwork) {
      final image = Image.network(
        url,
        fit: fit,
        height: resolvedHeight,
        width: resolvedWidth,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _buildLoadingPlaceholder(resolvedWidth, resolvedHeight);
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );

      if (radius != null) {
        final diameter = radius! * 2;
        return ClipOval(
          child: SizedBox(
            width: resolvedWidth ?? diameter,
            height: resolvedHeight ?? diameter,
            child: image,
          ),
        );
      }

      return image;
    }

    final ImageProvider? imageProvider = _providerForUrl(
      url,
      width: resolvedWidth,
      height: resolvedHeight,
    );

    Widget image;
    if (imageProvider != null) {
      image = Image(
        image: imageProvider,
        fit: fit,
        height: resolvedHeight,
        width: resolvedWidth,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _buildLoadingPlaceholder(resolvedWidth, resolvedHeight);
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      // fallback placeholder (grey box)
      image = _buildPlaceholder();
    }

    if (radius != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey,
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? const Icon(Icons.person, color: Colors.white70)
            : null,
      );
    }

    return image;
  }

  Widget _buildLoadingPlaceholder(
      double? resolvedWidth, double? resolvedHeight) {
    return Container(
      height: resolvedHeight,
      width: resolvedWidth,
      color: Colors.grey[850],
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  static ImageProvider? _providerForUrl(
    String url, {
    double? width,
    double? height,
  }) {
    final localProvider = LocalStore.instance.getImageProviderForUrl(url);
    final isNetwork = localProvider == null && url.startsWith('http');
    final baseProvider = localProvider ?? _networkProvider(url, isNetwork);
    final cacheWidth = _cacheDimension(width);
    final cacheHeight = _cacheDimension(height);
    return _resolvedProvider(
      url,
      baseProvider,
      cacheWidth,
      cacheHeight,
      isNetwork,
    );
  }

  static int? _cacheDimension(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    final scaled = (value * 2).round();
    return ((scaled / 100).ceil() * 100).clamp(100, 4096);
  }

  static ImageProvider? _networkProvider(String url, bool isNetwork) {
    if (!isNetwork) return null;
    return _networkProviders.putIfAbsent(url, () => NetworkImage(url));
  }

  static ImageProvider? _resolvedProvider(
    String url,
    ImageProvider? baseProvider,
    int? cacheWidth,
    int? cacheHeight,
    bool isNetwork,
  ) {
    if (baseProvider == null) return null;
    if (cacheWidth == null && cacheHeight == null) return baseProvider;

    if (!isNetwork) {
      return ResizeImage.resizeIfNeeded(
        cacheWidth,
        cacheHeight,
        baseProvider,
      );
    }

    final key = '$url@$cacheWidth x $cacheHeight';
    return _resizedProviders.putIfAbsent(
      key,
      () => ResizeImage.resizeIfNeeded(
        cacheWidth,
        cacheHeight,
        baseProvider,
      ),
    );
  }
}

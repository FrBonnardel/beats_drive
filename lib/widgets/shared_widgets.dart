import 'package:flutter/material.dart';

class AlbumArtContainer extends StatelessWidget {
  final Widget child;
  final double size;
  final double borderRadius;
  final EdgeInsets? margin;
  final BoxShadow? shadow;

  const AlbumArtContainer({
    super.key,
    required this.child,
    this.size = 48,
    this.borderRadius = 4,
    this.margin,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow != null ? [shadow!] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

class AlbumArtPlaceholder extends StatelessWidget {
  final double size;
  final Color color;

  const AlbumArtPlaceholder({
    super.key,
    this.size = 24,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.music_note, size: size, color: color);
  }
}

class AlbumArtLoadingIndicator extends StatelessWidget {
  final double strokeWidth;
  final Color color;

  const AlbumArtLoadingIndicator({
    super.key,
    this.strokeWidth = 2,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData? icon;
  final double iconSize;
  final Color? iconColor;

  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
    this.iconSize = 48,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: iconColor ?? colorScheme.error,
            size: iconSize,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: iconColor ?? colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  final String? subMessage;
  final IconData? icon;
  final double iconSize;
  final Color? iconColor;

  const EmptyView({
    super.key,
    required this.message,
    this.subMessage,
    this.icon = Icons.music_off,
    this.iconSize = 64,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = this.iconColor ?? colorScheme.onSurface.withOpacity(0.5);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: iconColor,
            ),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              subMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: iconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/catch_record.dart';

class CatchPostCard extends StatelessWidget {
  final CatchRecord record;
  final String? authToken;
  final String? uploadUrl;
  final String? authorAvatarUrl;
  final VoidCallback onTap;
  final bool showAuthor;
  final VoidCallback? onAuthorTap;

  const CatchPostCard({
    super.key,
    required this.record,
    required this.authToken,
    required this.uploadUrl,
    this.authorAvatarUrl,
    required this.onTap,
    this.showAuthor = true,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final author = record.mine
        ? 'Você'
        : (record.author?.name ?? 'Autor desconhecido');
    final localLabel =
        record.location == null ||
            (!record.mine &&
                record.locationVisibility == LocationVisibility.riverOnly)
        ? 'Local aproximado'
        : 'Ponto exato';

    return Material(
      color: cs.surface,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(uploadUrl: uploadUrl, authToken: authToken),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showAuthor) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _AuthorButton(
                                author: author,
                                enabled: onAuthorTap != null,
                                onTap: onAuthorTap,
                                avatarUrl: authorAvatarUrl,
                                authToken: authToken,
                              ),
                            ),
                            Text(
                              _formatDate(record.caughtAt),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ] else ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatDate(record.caughtAt),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        record.species.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (record.weightGrams != null)
                            _MiniPill(text: '${record.weightGrams} g'),
                          if (record.lengthMm != null)
                            _MiniPill(text: '${record.lengthMm} mm'),
                          _MiniPill(text: localLabel),
                        ],
                      ),
                      if (record.description != null &&
                          record.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          record.description!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _AuthorButton extends StatelessWidget {
  final String author;
  final bool enabled;
  final VoidCallback? onTap;
  final String? avatarUrl;
  final String? authToken;

  const _AuthorButton({
    required this.author,
    required this.enabled,
    required this.onTap,
    required this.avatarUrl,
    required this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthorAvatar(avatarUrl: avatarUrl, authToken: authToken),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            author,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              decoration: enabled
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
      ],
    );

    if (!enabled || onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? authToken;

  const _AuthorAvatar({required this.avatarUrl, required this.authToken});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
    );

    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: SizedBox(
        width: 24,
        height: 24,
        child: Image.network(
          avatarUrl!,
          headers: authToken == null
              ? null
              : {'Authorization': 'Bearer $authToken'},
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? uploadUrl;
  final String? authToken;

  const _Thumbnail({required this.uploadUrl, required this.authToken});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (uploadUrl == null) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.photo, color: cs.onSurfaceVariant),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Image.network(
          uploadUrl!,
          fit: BoxFit.cover,
          headers: authToken == null
              ? null
              : {'Authorization': 'Bearer $authToken'},
          errorBuilder: (context, error, stackTrace) => Container(
            color: cs.surfaceContainerHighest,
            child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;

  const _MiniPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class FeedStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const FeedStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 38, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

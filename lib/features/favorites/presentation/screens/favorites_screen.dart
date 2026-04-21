import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/app_toast.dart';
import 'package:rftranslator/features/translation/domain/translation_history_provider.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';
import 'package:rftranslator/features/translation/presentation/providers/translation_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favoritesAsync = ref.watch(translationFavoriteListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favorites),
        actions: [
          favoritesAsync.maybeWhen(
            data: (items) => items.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: l10n.clearAllFavorites,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.clearAllFavorites),
                          content: Text(l10n.clearAllFavoritesConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: Text(l10n.clearAllFavorites),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(translationFavoriteListProvider.notifier).clearAll();
                        AppToast.show(context, l10n.favoritesCleared);
                      }
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: favoritesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noFavoritesYet,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tapStarToFavorite,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FavoriteListItem(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _FavoriteListItem extends ConsumerWidget {
  final TranslationHistory item;

  const _FavoriteListItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(translationFavoriteListProvider.notifier).deleteEntry(item);
      },
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.removeFavoriteTitle),
            content: Text(l10n.removeFavoriteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ?? false;
      },
      child: ListTile(
        title: Text(
          item.sourceText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.targetText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.star, color: Colors.amber),
          onPressed: () {
            ref.read(translationFavoriteListProvider.notifier).toggleFavorite(item);
          },
        ),
        onTap: () {
          final notifier = ref.read(translationProvider.notifier);
          notifier.updateSourceLang(item.sourceLang);
          notifier.updateTargetLang(item.targetLang);
          notifier.updateSourceText(item.sourceText);
          context.go('/');
          Future.microtask(() => notifier.translate());
        },
      ),
    );
  }
}

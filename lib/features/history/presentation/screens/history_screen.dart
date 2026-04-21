import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/features/translation/domain/translation_history_provider.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';
import 'package:rftranslator/features/translation/presentation/providers/translation_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final historyAsync = ref.watch(translationHistoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        actions: [
          historyAsync.maybeWhen(
            data: (items) => items.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: l10n.clearSearchHistory,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.clearSearchHistory),
                          content: Text(l10n.clearSearchHistoryConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.ok),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(translationHistoryListProvider.notifier).clearAll();
                      }
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noSearchHistory,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _HistoryListItem(item: item);
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

class _HistoryListItem extends ConsumerWidget {
  final TranslationHistory item;

  const _HistoryListItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ref.read(translationHistoryListProvider.notifier).deleteEntry(item);
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

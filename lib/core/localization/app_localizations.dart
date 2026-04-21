import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UIStyle { material3, fluent, adaptive }
enum ThemeModeOption { system, light, dark }
enum LanguageOption { system, zh, en }

const _kUIStyleKey = 'ui_style';
const _kThemeModeKey = 'theme_mode';
const _kLanguageKey = 'language';
const _kCurrentIndexKey = 'current_index';
const _kSeedColorKey = 'seed_color';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'rftranslator',
      'dictionary': 'Dictionary',
      'favorites': 'Favorites',
      'history': 'History',
      'settings': 'Settings',
      'searchHint': 'Enter word or sentence...',
      'recentSearches': 'Recent Searches',
      'startSearching': 'Start searching words',
      'appearance': 'Appearance',
      'uiStyle': 'UI Style',
      'material3': 'Material 3',
      'fluent': 'Fluent',
      'adaptive': 'Adaptive',
      'themeMode': 'Theme Mode',
      'system': 'System',
      'light': 'Light',
      'dark': 'Dark',
      'accentColor': 'Accent Color',
      'language': 'Language',
      'chinese': 'Chinese',
      'english': 'English',
      'aiFeatures': 'AI Features (for sentences or paragraphs)',
      'aiModel': 'AI Model',
      'notInstalled': 'Not Installed',
      'download': 'Download',
      'dataManagement': 'Data Management',
      'clearSearchHistory': 'Clear Search History',
      'clearAllFavorites': 'Clear All Favorites',
      'clearSearchHistoryConfirm': 'Are you sure you want to clear all search history?',
      'clearAllFavoritesConfirm': 'Are you sure you want to remove all favorites?',
      'favoritesCleared': 'All favorites cleared',
      'about': 'About',
      'version': 'Version',
      'ecdictInfo': 'ECDICT (~3.3M entries)',
      'realFree': 'Real Free Dictionary',
      'dictionarySettings': 'Dictionary Settings (for word or short phrase)',
      'dictionaryManagement': 'Dictionary Management',
      'dictionaryReady': 'Dictionary Ready',
      'pleaseSelectDictionary': 'Please select dictionary file',
      'manage': 'Manage',
      'installed': 'Installed',
      'selectModel': 'Select Model',
      'downloadModel': 'Download Model',
      'downloading': 'Downloading',
      'downloadCompleted': 'Download Completed',
      'downloadFailed': 'Download Failed',
      'cancelDownload': 'Cancel Download',
      'retry': 'Retry',
      'clear': 'Clear',
      'reset': 'Reset',
      'selectModelFile': 'Select Model File',
      'modelReady': 'Model Ready',
      'pleaseSelectModel': 'Please select model file',
      'startDownload': 'Start Download',
      'downloadingInBackground': 'Downloading in background, you can continue using other features',
      'usageInstructions': 'Usage Instructions',
      'step1SelectModel': '1. Select the model type you want to use',
      'step2DownloadModel': '2. Click "Start Download" to get the model file, or "Select Model File" to choose an existing file',
      'step3SupportedFormats': '3. Supported formats: .gguf',
      'downloadRecommendations': 'Download Recommendations:',
      'qwen05bDesc': '- Qwen2.5-0.5B: Lightweight, suitable for resource-constrained devices',
      'qwen15bDesc': '- Qwen2.5-1.5B: Balanced, recommended for most users',
      'noModelWarning': 'If no model file is available, AI translation for long sentences will not work.',
      'selectDictionary': 'Select Dictionary',
      'downloadDictionary': 'Download Dictionary',
      'selectDictionaryFile': 'Select Dictionary File',
      'clearSettings': 'Clear Settings',
      'step1SelectDictionary': '1. Select the dictionary type you want to use',
      'step2DownloadDictionary': '2. Click "Start Download" to get the dictionary file, or "Select Dictionary File" to choose an existing file',
      'step3SupportedDictionaryFormats': '3. Supported formats: .db, .sqlite, .sqlite3, .zip',
      'dictionaryRecommendations': 'Download Recommendations:',
      'ecdictDesc': '- ECDict: Recommended, contains over 3 million entries',
      'wiktionaryDesc': '- Wiktionary: Free resource from Wiktionary',
      'noDictionaryWarning': 'If no dictionary file is available, word translation will show "Unable to translate", but AI translation for long sentences will still work.',
      'downloadStatus': 'Download Status',
      'fileSize': 'File Size',
      'dictionaryStatus': 'Dictionary Status',
      'modelStatus': 'Model Status',
      'cancel': 'Cancel',
      'ok': 'OK',
      'allModelsDownloaded': 'All models are downloaded!',
      'deleteModel': 'Delete Model?',
      'deleteModelConfirm': 'Are you sure you want to delete',
      'delete': 'Delete',
      'modelAlreadyInstalled': 'Model already installed',
      'sourceText': 'Source Text',
      'clearText': 'Clear',
      'inputToTranslate': 'Enter text to translate...',
      'translating': 'Translating...',
      'translate': 'Translate',
      'translationResultWillAppear': 'Translation result will appear here',
      'detailedDefinition': 'Detailed Definition',
      'phonetic': 'Phonetic',
      'definition': 'Definition',
      'example': 'Example',
      'copyAll': 'Copy All',
      'copy': 'Copy',
      'copiedToClipboard': 'Copied to clipboard',
      'translationResult': 'Translation Result',
      'swapLanguages': 'Swap Languages',
      'addToFavorites': 'Add to Favorites',
      'removeFromFavorites': 'Remove from Favorites',
      'lookupDictionary': 'Look up in Dictionary',
      'translationSource': 'Source',
      'sourceDictionary': 'Dictionary',
      'sourceOpusMt': 'OPUS-MT',
      'sourceTextLang': 'Source',
      'targetTextLang': 'Target',
      'noSearchHistory': 'No search history',
      'noFavoritesYet': 'No favorites yet',
      'tapStarToFavorite': 'Tap \u2605 to favorite while searching',
      'initializing': 'Initializing...',
      'loadingModelManager': 'Loading model manager...',
      'loadingDictionaryManager': 'Loading dictionary manager...',
      'initComplete': 'Initialization complete!',
      'initFailed': 'Initialization failed',
      'loadingDictionary': 'Loading dictionary, please wait...',
      'firstTimeGuideTitle': 'Welcome to rftranslator!',
      'firstTimeGuideMessage': 'To get started with translation, please go to Settings to download dictionaries or AI models first.',
      'goToSettings': 'Go to Settings',
      'noDictionaryOrModel': 'No dictionary or AI model available. Please download them in Settings.',
      'copySource': 'Copy Source',
      'copyTarget': 'Copy Translation',
      'reTranslate': 'Re-translate',
      'removeFavoriteTitle': 'Remove from Favorites',
      'removeFavoriteConfirm': 'Remove from favorites?',
      'translateNav': 'Translate',
      'speak': 'Play',
      'share': 'Share',
      'selectModelFolder': 'Select Model Folder',
      'modelImportedSuccess': 'Model imported successfully',
      'modelScopeUnavailable': 'This model is not available on ModelScope. Please switch to HuggingFace or Auto Detect.',
      'huggingFaceUnavailableToast': 'HuggingFace unavailable. Please switch to ModelScope or Auto Detect.',
      'downloadError': 'Download error: ',
      'modelScopeModelUnavailable': 'This model is not available on ModelScope. Please switch to HuggingFace or Auto Detect.',
      'modelScopeConnectionUnavailable': 'ModelScope connection unavailable. Please check your network.',
      'huggingFaceConnectionUnavailable': 'HuggingFace connection unavailable. Please switch to ModelScope or Auto Detect.',
      'noDownloadSourceAvailable': 'No download source available for this model.',
      'allSourcesUnavailable': 'All download sources are unavailable. Please check your network.',
      'wordNotFound': 'No dictionary entry found for "',
      'queryError': 'Query error: ',
      'addedToFavorites': 'Added to favorites',
      'removedFromFavorites': 'Removed from favorites',
      'favoriteTooltip': 'Favorite',
      'noDictionaryEntryFound': 'No dictionary entry found',
      'wordExample': 'Examples',
      'modelNotDirectlyDownloadable': 'This model does not support direct download. Please use the local import feature.',
      'downloadFailedRetry': 'Download failed, please try again.',
      'downloadCancelled': 'Download cancelled.',
      'dictionaryNotDirectlyDownloadable': 'This dictionary does not support direct download.',
      'modelScopeModelUnavailableToast': 'This model is not available on ModelScope, please switch to HuggingFace or Auto Detect.',
      'huggingFaceModelUnavailableToast': 'This model is not available on HuggingFace, please switch to ModelScope or Auto Detect.',
      'noDownloadSourceAvailableToast': 'No download source available for this model.',
      'noTranslationModel': 'No translation model available. Please download and enable the model pair from the model management page.',
      'ctranslate2LibraryNotFound': 'CTranslate2 runtime library not found. Please ensure it is installed correctly.',
      'allModelsTranslationFailed': 'All model translations failed.',
      'selectMdictFile': 'Select MDict Dictionary File',
      'mdictImportSuccess': 'Successfully imported: ',
      'mdictImportFailed': 'Import failed. Please ensure it is a valid .mdx file.',
      'selectStarDictFolder': 'Select StarDict Dictionary Folder',
      'noIfoFileFound': 'No .ifo file found. Please ensure it is a valid StarDict dictionary folder.',
      'starDictImported': 'StarDict dictionary imported: ',
      'dictsGroupedByLangDesc': 'Grouped by source language. Tap to expand and see available dictionaries.',
      'installedCountDesc': 'installed',
      'selectInstalledDicts': 'Select Installed Dictionaries',
      'selectDictsToUse': 'Select dictionaries to use (multiple)',
      'deleteDictTooltip': 'Delete',
      'mdictFormatImported': 'MDict format (imported)',
      'importDictionaryTitle': 'Import Dictionary',
      'importDictionaryDesc': 'Supports .mdx format and StarDict folders',
      'selectMdxFile': 'Select .mdx File',
      'selectStarDictFolderBtn': 'Select StarDict Folder',
      'availableLanguagePairs': 'Available Language Pairs',
      'pleaseSelectDictsFirst': 'Please select dictionaries first',
      'modelDisplayNameEnZh': 'OPUS-MT en→zh (English to Chinese)',
      'modelDisplayNameZhEn': 'OPUS-MT zh→en (Chinese to English)',
      'modelDisplayNameEnDe': 'OPUS-MT en→de (English to German)',
      'modelDisplayNameEnFr': 'OPUS-MT en→fr (English to French)',
      'modelDisplayNameEnEs': 'OPUS-MT en→es (English to Spanish)',
      'modelDisplayNameEnIt': 'OPUS-MT en→it (English to Italian)',
      'modelDisplayNameEnRu': 'OPUS-MT en→ru (English to Russian)',
      'modelDisplayNameEnAr': 'OPUS-MT en→ar (English to Arabic)',
      'modelDisplayNameEnJap': 'OPUS-MT en→ja (English to Japanese)',
      'modelDisplayNameEnKo': 'OPUS-MT en→ko (English to Korean)',
      'modelDisplayNameDeEn': 'OPUS-MT de→en (German to English)',
      'modelDisplayNameFrEn': 'OPUS-MT fr→en (French to English)',
      'modelDisplayNameEsEn': 'OPUS-MT es→en (Spanish to English)',
      'modelDisplayNameItEn': 'OPUS-MT it→en (Italian to English)',
      'modelDisplayNameRuEn': 'OPUS-MT ru→en (Russian to English)',
      'modelDisplayNameArEn': 'OPUS-MT ar→en (Arabic to English)',
      'modelDisplayNameJapEn': 'OPUS-MT ja→en (Japanese to English)',
      'modelDisplayNameKoEn': 'OPUS-MT ko→en (Korean to English)',
      'modelDisplayNameZhDe': 'OPUS-MT zh→de (Chinese to German)',
      'modelDisplayNameDeZh': 'OPUS-MT de→zh (German to Chinese)',
      'modelDisplayNameZhIt': 'OPUS-MT zh→it (Chinese to Italian)',
      'modelDisplayNameZhVi': 'OPUS-MT zh→vi (Chinese to Vietnamese)',
      'modelDisplayNameZhJap': 'OPUS-MT zh→ja (Chinese to Japanese)',
      'modelDisplayNameFiZh': 'OPUS-MT fi→zh (Finnish to Chinese)',
      'modelDisplayNameSvZh': 'OPUS-MT sv→zh (Swedish to Chinese)',
      'modelDisplayNameZhBg': 'OPUS-MT zh→bg (Chinese to Bulgarian)',
      'modelDisplayNameZhFi': 'OPUS-MT zh→fi (Chinese to Finnish)',
      'modelDisplayNameZhHe': 'OPUS-MT zh→he (Chinese to Hebrew)',
      'modelDisplayNameZhMs': 'OPUS-MT zh→ms (Chinese to Malay)',
      'modelDisplayNameZhNl': 'OPUS-MT zh→nl (Chinese to Dutch)',
      'modelDisplayNameZhSv': 'OPUS-MT zh→sv (Chinese to Swedish)',
      'modelDisplayNameZhUk': 'OPUS-MT zh→uk (Chinese to Ukrainian)',
      'statusAvailable': 'OK',
      'statusUnavailable': 'Down',
      'modelDownloadCompletedToast': 'Model downloaded successfully',
      'refreshSources': 'Refresh',
      'translationModelsTitle': 'Translation Models',
      'modelsGroupedByLangDesc': 'Grouped by source language. Tap to expand and see available language pairs.',
      'localOnlyLabel': 'Local only',
      'selectToDownloadTooltip': 'Select to download',
      'downloadSourceTitle': 'Download Source',
      'autoDetectOption': 'Auto Detect',
      'autoDetectOptionDesc': 'Automatically select best download source',
      'huggingfaceOption': 'Hugging Face',
      'huggingfaceOptionDesc': 'Official source (may require proxy)',
      'modelscopeOption': 'ModelScope (Alibaba)',
      'modelscopeOptionDesc': 'Alibaba Cloud model hub (recommended in China)',
      'localImportTitle': 'Local Import',
      'localImportDescription': 'Import CTranslate2 format model folder from local disk\nFolder name format:\n  \u00B7 opus-mt-[l1]-[l2] (e.g. opus-mt-zh-de)\nMust contain: model.bin, config.json, shared_vocabulary.json',
      'importedCustomModelsTitle': 'Imported Custom Models',
      'downloadingTitle': 'Downloading...',
      'closeButton': 'Close',
      'installedModelsTitle': 'Installed Models',
      'installedModelsDesc': 'Checked models will be used automatically during translation (matched by language pair)',
      'installedCount': 'installed',
      'architectureOverviewText': 'Architecture Overview\n\n\u2022 Encoder-Decoder architecture optimized for long sentence translation\n\nTranslation Flow:\n1. Words/Phrases \u2192 StarDict Dictionary\n2. Sentences/Paragraphs \u2192 Encoder-Decoder Model\n3. Dictionary not found \u2192 Encoder-Decoder fallback',
    },
    'zh': {
      'appTitle': 'rftranslator',
      'dictionary': '\u8BCD\u5178',
      'favorites': '\u6536\u85CF',
      'history': '\u5386\u53F2',
      'settings': '\u8BBE\u7F6E',
      'searchHint': '\u8F93\u5165\u5355\u8BCD\u6216\u53E5\u5B50...',
      'recentSearches': '\u6700\u8FD1\u641C\u7D22',
      'startSearching': '\u5F00\u59CB\u641C\u7D22\u5355\u8BCD',
      'appearance': '\u5916\u89C2',
      'uiStyle': 'UI \u6837\u5F0F',
      'material3': 'Material 3',
      'fluent': 'Fluent',
      'adaptive': '\u81EA\u9002\u5E94',
      'themeMode': '\u4E3B\u9898\u6A21\u5F0F',
      'system': '\u8DDF\u968F\u7CFB\u7EDF',
      'light': '\u6D45\u8272',
      'dark': '\u6DF1\u8272',
      'accentColor': '\u5F3A\u8C03\u8272',
      'language': '\u8BED\u8A00',
      'chinese': '\u4E2D\u6587',
      'english': '\u82F1\u6587',
      'aiFeatures': 'AI \u529F\u80FD\uFF08\u7528\u4E8E\u53E5\u5B50\u6216\u6BB5\u843D\u7FFB\u8BD1\uFF09',
      'aiModel': 'AI \u6A21\u578B',
      'notInstalled': '\u672A\u5B89\u88C5',
      'download': '\u4E0B\u8F7D',
      'dataManagement': '\u6570\u636E\u7BA1\u7406',
      'clearSearchHistory': '\u6E05\u9664\u641C\u7D22\u5386\u53F2',
      'clearAllFavorites': '\u6E05\u9664\u6240\u6709\u6536\u85CF',
      'clearSearchHistoryConfirm': '\u786E\u5B9A\u8981\u6E05\u7A7A\u6240\u6709\u641C\u7D22\u5386\u53F2\u5417?',
      'clearAllFavoritesConfirm': '\u786E\u5B9A\u8981\u6E05\u7A7A\u6240\u6709\u6536\u85CF\u5417?',
      'favoritesCleared': '\u5DF2\u6E05\u7A7A\u6240\u6709\u6536\u85CF',
      'about': '\u5173\u4E8E',
      'version': '\u7248\u672C',
      'ecdictInfo': 'ECDICT (~330\u4E07\u8BCD\u6761)',
      'realFree': '\u5B8C\u5168\u514D\u8D39\u7684\u5B57\u5178',
      'dictionarySettings': '\u8BCD\u5178\u8BBE\u7F6E\uFF08\u9002\u7528\u4E8E\u5355\u8BCD\u6216\u77ED\u8BED\u7FFB\u8BD1\uFF09',
      'dictionaryManagement': '\u8BCD\u5178\u7BA1\u7406',
      'dictionaryReady': '\u8BCD\u5178\u5DF2\u5C31\u7EEA',
      'pleaseSelectDictionary': '\u8BF7\u9009\u62E9\u8BCD\u5178\u6587\u4EF6',
      'manage': '\u7BA1\u7406',
      'installed': '\u5DF2\u5B89\u88C5',
      'selectModel': '\u9009\u62E9\u6A21\u578B',
      'downloadModel': '\u4E0B\u8F7D\u6A21\u578B',
      'downloading': '\u4E0B\u8F7D\u4E2D',
      'downloadCompleted': '\u4E0B\u8F7D\u5B8C\u6210',
      'downloadFailed': '\u4E0B\u8F7D\u5931\u8D25',
      'cancelDownload': '\u53D6\u6D88\u4E0B\u8F7D',
      'retry': '\u91CD\u8BD5',
      'clear': '\u6E05\u9664',
      'reset': '\u91CD\u7F6E',
      'selectModelFile': '\u9009\u62E9\u6A21\u578B\u6587\u4EF6',
      'modelReady': '\u6A21\u578B\u5DF2\u5C31\u7EEA',
      'pleaseSelectModel': '\u8BF7\u9009\u62E9\u6A21\u578B\u6587\u4EF6',
      'startDownload': '\u5F00\u59CB\u4E0B\u8F7D',
      'downloadingInBackground': '\u4E0B\u8F7D\u5C06\u5728\u540E\u53F0\u8FDB\u884C\uFF0C\u60A8\u53EF\u4EE5\u7EE7\u7EED\u4F7F\u7528\u5E94\u7528\u7684\u5176\u4ED6\u529F\u80FD',
      'usageInstructions': '\u4F7F\u7528\u8BF4\u660E',
      'step1SelectModel': '1. \u9009\u62E9\u60A8\u60F3\u8981\u4F7F\u7528\u7684\u6A21\u578B\u7C7B\u578B',
      'step2DownloadModel': '2. \u70B9\u51FB\u201C\u5F00\u59CB\u4E0B\u8F7D\u201D\u83B7\u53D6\u6A21\u578B\u6587\u4EF6\uFF0C\u6216\u201C\u9009\u62E9\u6A21\u578B\u6587\u4EF6\u201D\u9009\u62E9\u5DF2\u6709\u7684\u6587\u4EF6',
      'step3SupportedFormats': '3. \u652F\u6301\u7684\u683C\u5F0F\uFF1A.gguf',
      'downloadRecommendations': '\u4E0B\u8F7D\u5EFA\u8BAE\uFF1A',
      'qwen05bDesc': '- Qwen2.5-0.5B: \u8F7B\u91CF\u578B\uFF0C\u9002\u5408\u8D44\u6E90\u53D7\u9650\u8BBE\u5907',
      'qwen15bDesc': '- Qwen2.5-1.5B: \u5E73\u8861\u578B\uFF0C\u63A8\u8350\u5927\u591A\u6570\u7528\u6237\u4F7F\u7528',
      'noModelWarning': '\u5982\u679C\u6CA1\u6709\u6A21\u578B\u6587\u4EF6\uFF0C\u957F\u53E5\u7684 AI \u7FFB\u8BD1\u5C06\u65E0\u6CD5\u4F7F\u7528\u3002',
      'selectDictionary': '\u9009\u62E9\u8BCD\u5178',
      'downloadDictionary': '\u4E0B\u8F7D\u8BCD\u5178',
      'selectDictionaryFile': '\u9009\u62E9\u8BCD\u5178\u6587\u4EF6',
      'clearSettings': '\u6E05\u9664\u8BBE\u7F6E',
      'step1SelectDictionary': '1. \u9009\u62E9\u60A8\u60F3\u8981\u4F7F\u7528\u7684\u8BCD\u5178\u7C7B\u578B',
      'step2DownloadDictionary': '2. \u70B9\u51FB\u201C\u5F00\u59CB\u4E0B\u8F7D\u201D\u83B7\u53D6\u8BCD\u5178\u6587\u4EF6\uFF0C\u6216\u201C\u9009\u62E9\u8BCD\u5178\u6587\u4EF6\u201D\u9009\u62E9\u5DF2\u6709\u7684\u6587\u4EF6',
      'step3SupportedDictionaryFormats': '3. \u652F\u6301\u7684\u683C\u5F0F\uFF1A.db, .sqlite, .sqlite3, .zip',
      'dictionaryRecommendations': '\u4E0B\u8F7D\u5EFA\u8BAE\uFF1A',
      'ecdictDesc': '- ECDict: \u63A8\u8350\u4F7F\u7528\uFF0C\u5305\u542B\u8D85\u8FC7 300 \u4E07\u8BCD\u6761',
      'wiktionaryDesc': '- Wiktionary: \u6765\u81EA\u7EF4\u57FA\u8BCD\u5178\u7684\u514D\u8D39\u8D44\u6E90',
      'noDictionaryWarning': '\u5982\u679C\u6CA1\u6709\u8BCD\u5178\u6587\u4EF6\uFF0C\u5355\u8BCD\u7FFB\u8BD1\u4F1A\u663E\u793A\u201C\u65E0\u6CD5\u7FFB\u8BD1\u201D\uFF0C\u4F46\u957F\u53E5\u4ECD\u53EF\u4F7F\u7528 AI \u7FFB\u8BD1\u3002',
      'downloadStatus': '\u4E0B\u8F7D\u72B6\u6001',
      'fileSize': '\u6587\u4EF6\u5927\u5C0F',
      'dictionaryStatus': '\u8BCD\u5178\u72B6\u6001',
      'modelStatus': '\u6A21\u578B\u72B6\u6001',
      'cancel': '\u53D6\u6D88',
      'ok': '\u786E\u5B9A',
      'allModelsDownloaded': '\u6240\u6709\u6A21\u578B\u90FD\u5DF2\u4E0B\u8F7D\uFF01',
      'deleteModel': '\u5220\u9664\u6A21\u578B\uFF1F',
      'deleteModelConfirm': '\u786E\u5B9A\u8981\u5220\u9664',
      'delete': '\u5220\u9664',
      'modelAlreadyInstalled': '\u6A21\u578B\u5DF2\u5B89\u88C5',
      'sourceText': '\u6E90\u6587\u672C',
      'clearText': '\u6E05\u7A7A',
      'inputToTranslate': '\u8F93\u5165\u8981\u7FFB\u8BD1\u7684\u6587\u672C...',
      'translating': '\u7FFB\u8BD1\u4E2D...',
      'translate': '\u7FFB\u8BD1',
      'translationResultWillAppear': '\u7FFB\u8BD1\u7ED3\u679C\u5C06\u663E\u793A\u5728\u8FD9\u91CC',
      'detailedDefinition': '\u8BE6\u7EC6\u91CA\u4E49',
      'phonetic': '\u97F3\u6807',
      'definition': '\u91CA\u4E49',
      'example': '\u4F8B\u53E5',
      'copyAll': '\u590D\u5236\u5168\u90E8',
      'copy': '\u590D\u5236',
      'copiedToClipboard': '\u5DF2\u590D\u5236\u5230\u526A\u8D34\u677F',
      'translationResult': '\u7FFB\u8BD1\u7ED3\u679C',
      'swapLanguages': '\u4EA4\u6362\u8BED\u8A00',
      'addToFavorites': '\u6DFB\u52A0\u5230\u6536\u85CF',
      'removeFromFavorites': '\u53D6\u6D88\u6536\u85CF',
      'lookupDictionary': '\u67E5\u8BE2\u8BCD\u5178',
      'translationSource': '\u6765\u6E90',
      'sourceDictionary': '\u8BCD\u5178',
      'sourceOpusMt': 'OPUS-MT',
      'sourceTextLang': '\u6E90\u8BED\u8A00',
      'targetTextLang': '\u76EE\u6807\u8BED\u8A00',
      'noSearchHistory': '\u6682\u65E0\u641C\u7D22\u8BB0\u5F55',
      'noFavoritesYet': '\u8FD8\u6CA1\u6709\u6536\u85CF',
      'tapStarToFavorite': '\u67E5\u8BCD\u65F6\u70B9\u51FB\u2605\u6536\u85CF',
      'initializing': '\u6B63\u5728\u521D\u59CB\u5316...',
      'loadingModelManager': '\u6B63\u5728\u52A0\u8F7D\u6A21\u578B\u7BA1\u7406\u5668...',
      'loadingDictionaryManager': '\u6B63\u5728\u52A0\u8F7D\u8BCD\u5178\u7BA1\u7406\u5668...',
      'initComplete': '\u521D\u59CB\u5316\u5B8C\u6210\uFF01',
      'initFailed': '\u521D\u59CB\u5316\u5931\u8D25',
      'loadingDictionary': '\u6B63\u5728\u52A0\u8F7D\u8BCD\u5178\uFF0C\u8BF7\u7A0D\u5019...',
      'firstTimeGuideTitle': '\u6B22\u8FCE\u4F7F\u7528 rftranslator\uFF01',
      'firstTimeGuideMessage': '\u4E3A\u4E86\u5F00\u59CB\u4F7F\u7528\u7FFB\u8BD1\u529F\u80FD\uFF0C\u8BF7\u5143\u524D\u5F00\u53BB\u8BBE\u7F6E\u9875\u4E0B\u8F7D\u8BCD\u5178\u6216 AI \u6A21\u578B\u3002',
      'goToSettings': '\u524D\u5F80\u8BBE\u7F6E',
      'noDictionaryOrModel': '\u6682\u65E0\u53EF\u7528\u7684\u8BCD\u5178\u6216 AI \u6A21\u578B\uFF0C\u8BF7\u5148\u5728\u8BBE\u7F6E\u4E2D\u4E0B\u8F7D\u3002',
      'copySource': '\u590D\u5236\u6E90\u6587',
      'copyTarget': '\u590D\u5236\u8BD1\u6587',
      'reTranslate': '\u91CD\u65B0\u7FFB\u8BD1',
      'removeFavoriteTitle': '\u53D6\u6D88\u6536\u85CF',
      'removeFavoriteConfirm': '\u786E\u5B9A\u8981\u53D6\u6D88\u6536\u85CF\u5417\uFF1F',
      'translateNav': '\u7FFB\u8BD1',
      'speak': '\u64AD\u653E',
      'share': '\u5206\u4EAB',
      'selectModelFolder': '\u9009\u62E9\u6A21\u578B\u6587\u4EF6\u5939',
      'modelImportedSuccess': '\u6A21\u578B\u5BFC\u5165\u6210\u529F',
      'modelScopeUnavailable': '\u6B64\u6A21\u578B\u5728 ModelScope \u4E0A\u4E0D\u53EF\u7528\uFF0C\u8BF7\u5207\u6362\u5230 HuggingFace \u6216\u81EA\u52A8\u68C0\u6D4B',
      'huggingFaceUnavailableToast': 'HuggingFace \u4E0D\u53EF\u7528\uFF0C\u8BF7\u5207\u6362\u5230 ModelScope \u6216\u81EA\u52A8\u68C0\u6D4B',
      'downloadError': '\u4E0B\u8F7D\u51FA\u9519: ',
      'modelScopeModelUnavailable': '\u6B64\u6A21\u578B\u5728 ModelScope \u4E0A\u4E0D\u53EF\u7528\uFF0C\u8BF7\u5207\u6362\u5230 HuggingFace \u6216\u81EA\u52A8\u68C0\u6D4B',
      'modelScopeConnectionUnavailable': 'ModelScope \u8FDE\u63A5\u4E0D\u53EF\u7528\uFF0C\u8BF7\u68C0\u67E5\u7F51\u7EDC',
      'huggingFaceConnectionUnavailable': 'HuggingFace \u8FDE\u63A5\u4E0D\u53EF\u7528\uFF0C\u8BF7\u5207\u6362\u5230 ModelScope \u6216\u81EA\u52A8\u68C0\u6D4B',
      'noDownloadSourceAvailable': '\u6B64\u6A21\u578B\u65E0\u53EF\u7528\u4E0B\u8F7D\u6E90',
      'allSourcesUnavailable': '\u6240\u6709\u4E0B\u8F7D\u6E90\u5747\u4E0D\u53EF\u7528\uFF0C\u8BF7\u68C0\u67E5\u7F51\u7EDC',
      'wordNotFound': '\u672A\u627E\u5230 "',
      'queryError': '\u67E5\u8BE2\u51FA\u9519: ',
      'addedToFavorites': '\u5DF2\u6DFB\u52A0\u5230\u6536\u85CF',
      'removedFromFavorites': '\u5DF2\u53D6\u6D88\u6536\u85CF',
      'favoriteTooltip': '\u6536\u85CF',
      'noDictionaryEntryFound': '\u672A\u627E\u5230\u8BCD\u5178\u6761\u76EE',
      'wordExample': '\u4F8B\u53E5',
      'modelNotDirectlyDownloadable': '\u8BE5\u6A21\u578B\u6682\u4E0D\u652F\u6301\u76F4\u63A5\u4E0B\u8F7D\uFF0C\u8BF7\u4F7F\u7528\u672C\u5730\u5BFC\u5165\u529F\u80FD',
      'downloadFailedRetry': '\u4E0B\u8F7D\u5931\u8D25\uFF0C\u8BF7\u91CD\u8BD5',
      'downloadCancelled': '\u4E0B\u8F7D\u5DF2\u53D6\u6D88',
      'dictionaryNotDirectlyDownloadable': '\u8BE5\u8BCD\u5178\u6682\u4E0D\u652F\u6301\u76F4\u63A5\u4E0B\u8F7D',
      'modelScopeModelUnavailableToast': '\u6B64\u6A21\u578B\u5728 ModelScope \u4E0A\u4E0D\u53EF\u7528\uFF0C\u8BF7\u5207\u6362\u5230 HuggingFace \u6216\u81EA\u52A8\u68C0\u6D4B',
      'huggingFaceModelUnavailableToast': '\u6B64\u6A21\u578B\u5728 HuggingFace \u4E0A\u4E0D\u53EF\u7528\uFF0C\u8BF7\u5207\u6362\u5230 ModelScope \u6216\u81EA\u52A8\u68C0\u6D4B',
      'noDownloadSourceAvailableToast': '\u6B64\u6A21\u578B\u65E0\u53EF\u7528\u4E0B\u8F7D\u6E90',
      'noTranslationModel': '\u6CA1\u6709\u53EF\u7528\u7684\u7FFB\u8BD1\u6A21\u578B\uFF0C\u8BF7\u5148\u5728\u6A21\u578B\u7BA1\u7406\u9875\u9762\u4E0B\u8F7D\u5E76\u542F\u7528\u6A21\u578B',
      'ctranslate2LibraryNotFound': 'CTranslate2 \u8FD0\u884C\u5E93\u672A\u627E\u5230\uFF0C\u8BF7\u786E\u4FDD\u5DF2\u6B63\u786E\u5B89\u88C5',
      'allModelsTranslationFailed': '\u6240\u6709\u6A21\u578B\u7FFB\u8BD1\u5931\u8D25',
      'selectMdictFile': '\u9009\u62E9 MDict \u8BCD\u5178\u6587\u4EF6',
      'mdictImportSuccess': '\u6210\u529F\u5BFC\u5165: ',
      'mdictImportFailed': '\u5BFC\u5165\u5931\u8D25\uFF0C\u8BF7\u786E\u4FDD\u662F\u6709\u6548\u7684 .mdx \u6587\u4EF6',
      'selectStarDictFolder': '\u9009\u62E9 StarDict \u8BCD\u5178\u6587\u4EF6\u5939',
      'noIfoFileFound': '\u672A\u627E\u5230 .ifo \u6587\u4EF6\uFF0C\u8BF7\u786E\u4FDD\u662F\u6709\u6548\u7684 StarDict \u8BCD\u5178\u6587\u4EF6\u5939',
      'starDictImported': 'StarDict \u8BCD\u5178\u5DF2\u5BFC\u5165: ',
      'dictsGroupedByLangDesc': '\u6309\u6E90\u8BED\u8A00\u5206\u7EC4\uFF0C\u70B9\u51FB\u5C55\u5F00\u67E5\u770B\u53EF\u4E0B\u8F7D\u7684\u8BCD\u5178',
      'installedCountDesc': '\u5DF2\u5B89\u88C5',
      'selectInstalledDicts': '\u9009\u62E9\u5DF2\u5B89\u88C5\u7684\u8BCD\u5178',
      'selectDictsToUse': '\u9009\u62E9\u8981\u4F7F\u7528\u7684\u8BCD\u5178\uFF08\u53EF\u591A\u9009\uFF09',
      'deleteDictTooltip': '\u5220\u9664',
      'mdictFormatImported': 'MDict \u683C\u5F0F\uFF08\u7528\u6237\u5BFC\u5165\uFF09',
      'importDictionaryTitle': '\u5BFC\u5165\u8BCD\u5178',
      'importDictionaryDesc': '\u652F\u6301 .mdx \u683C\u5F0F\u548C StarDict \u6587\u4EF6\u5939',
      'selectMdxFile': '\u9009\u62E9 .mdx \u6587\u4EF6',
      'selectStarDictFolderBtn': '\u9009\u62E9 StarDict \u6587\u4EF6\u5939',
      'availableLanguagePairs': '\u53EF\u7528\u7684\u8BED\u8A00\u5BF9',
      'pleaseSelectDictsFirst': '\u8BF7\u5148\u9009\u62E9\u8BCD\u5178',
      'statusAvailable': '\u53EF\u7528',
      'statusUnavailable': '\u4E0D\u53EF\u7528',
      'modelDownloadCompletedToast': '\u6A21\u578B\u4E0B\u8F7D\u5B8C\u6210',
      'refreshSources': '\u5237\u65B0',
      'translationModelsTitle': '\u7FFB\u8BD1\u6A21\u578B',
      'modelsGroupedByLangDesc': '\u6309\u6E90\u8BED\u8A00\u5206\u7EC4\uFF0C\u70B9\u51FB\u5C55\u5F00\u67E5\u770B\u53EF\u4E0B\u8F7D\u7684\u8BED\u5BF9\u6A21\u578B',
      'localOnlyLabel': '\u4EC5\u672C\u5730',
      'selectToDownloadTooltip': '\u9009\u62E9\u4E0B\u8F7D',
      'downloadSourceTitle': '\u4E0B\u8F7D\u6E90',
      'autoDetectOption': '\u81EA\u52A8\u68C0\u6D4B',
      'autoDetectOptionDesc': '\u81EA\u52A8\u9009\u62E9\u6700\u4F73\u4E0B\u8F7D\u6E90',
      'huggingfaceOption': 'Hugging Face',
      'huggingfaceOptionDesc': '\u5B98\u65B9\u6E90\uFF08\u53EF\u80FD\u9700\u8981\u4EE3\u7406\uFF09',
      'modelscopeOption': 'ModelScope\uFF08\u963F\u91CC\uFF09',
      'modelscopeOptionDesc': '\u963F\u91CC\u4E91\u6A21\u578B\u5E93\uFF08\u56FD\u5185\u63A8\u8350\uFF09',
      'localImportTitle': '\u672C\u5730\u5BFC\u5165',
      'localImportDescription': '\u4ECE\u672C\u5730\u78C1\u76D8\u5BFC\u5165 CTranslate2 \u683C\u5F0F\u6A21\u578B\u6587\u4EF6\u5939\n\u6587\u4EF6\u5939\u540D\u683C\u5F0F:\n  \u00B7 opus-mt-[l1]-[l2] \uFF08\u5982 opus-mt-zh-de\uFF09\n\u9700\u5305\u542B: model.bin, config.json, shared_vocabulary.json',
      'importedCustomModelsTitle': '\u5DF2\u5BFC\u5165\u7684\u81EA\u5B9A\u4E49\u6A21\u578B',
      'downloadingTitle': '\u6B63\u5728\u4E0B\u8F7D...',
      'closeButton': '\u5173\u95ED',
      'installedModelsTitle': '\u5DF2\u5B89\u88C5\u6A21\u578B',
      'installedModelsDesc': '\u52FE\u9009\u7684\u6A21\u578B\u5C06\u5728\u7FFB\u8BD1\u65F6\u81EA\u52A8\u4F7F\u7528\uFF08\u6839\u636E\u8BED\u5BF9\u5339\u914D\uFF09',
      'installedCount': '\u5DF2\u5B89\u88C5',
      'architectureOverviewText': '\u67B6\u6784\u8BF4\u660E\n\n\u2022 Encoder-Decoder \u67B6\u6784\u6A21\u578B\uFF0C\u4E13\u4E3A\u957F\u53E5\u7FFB\u8BD1\u4F18\u5316\n\n\u7FFB\u8BD1\u6D41\u7A0B:\n1. \u5355\u8BCD/\u77ED\u8BED \u2192 StarDict \u8BCD\u5178\n2. \u957F\u53E5/\u6BB5\u843D \u2192 Encoder-Decoder \u6A21\u578B\n3. \u8BCD\u5178\u672A\u627E\u5230 \u2192 Encoder-Decoder \u5156\u5E95',
    },
  };

  String _t(String key) => _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key]!;

  String get appTitle => _t('appTitle');
  String get dictionary => _t('dictionary');
  String get favorites => _t('favorites');
  String get history => _t('history');
  String get settings => _t('settings');
  String get searchHint => _t('searchHint');
  String get recentSearches => _t('recentSearches');
  String get startSearching => _t('startSearching');
  String get appearance => _t('appearance');
  String get uiStyle => _t('uiStyle');
  String get material3 => _t('material3');
  String get fluent => _t('fluent');
  String get adaptive => _t('adaptive');
  String get themeMode => _t('themeMode');
  String get system => _t('system');
  String get light => _t('light');
  String get dark => _t('dark');
  String get accentColor => _t('accentColor');
  String get language => _t('language');
  String get chinese => _t('chinese');
  String get english => _t('english');
  String get aiFeatures => _t('aiFeatures');
  String get aiModel => _t('aiModel');
  String get notInstalled => _t('notInstalled');
  String get download => _t('download');
  String get dataManagement => _t('dataManagement');
  String get clearSearchHistory => _t('clearSearchHistory');
  String get clearAllFavorites => _t('clearAllFavorites');
  String get clearSearchHistoryConfirm => _t('clearSearchHistoryConfirm');
  String get clearAllFavoritesConfirm => _t('clearAllFavoritesConfirm');
  String get favoritesCleared => _t('favoritesCleared');
  String get about => _t('about');
  String get version => _t('version');
  String get ecdictInfo => _t('ecdictInfo');
  String get realFree => _t('realFree');

  String get dictionarySettings => _t('dictionarySettings');
  String get dictionaryManagement => _t('dictionaryManagement');
  String get dictionaryReady => _t('dictionaryReady');
  String get pleaseSelectDictionary => _t('pleaseSelectDictionary');
  String get manage => _t('manage');
  String get installed => _t('installed');
  String get selectModel => _t('selectModel');
  String get downloadModel => _t('downloadModel');
  String get downloading => _t('downloading');
  String get downloadCompleted => _t('downloadCompleted');
  String get downloadFailed => _t('downloadFailed');
  String get cancelDownload => _t('cancelDownload');
  String get retry => _t('retry');
  String get clear => _t('clear');
  String get reset => _t('reset');
  String get selectModelFile => _t('selectModelFile');
  String get modelReady => _t('modelReady');
  String get pleaseSelectModel => _t('pleaseSelectModel');
  String get startDownload => _t('startDownload');
  String get downloadingInBackground => _t('downloadingInBackground');
  String get usageInstructions => _t('usageInstructions');
  String get step1SelectModel => _t('step1SelectModel');
  String get step2DownloadModel => _t('step2DownloadModel');
  String get step3SupportedFormats => _t('step3SupportedFormats');
  String get downloadRecommendations => _t('downloadRecommendations');
  String get qwen05bDesc => _t('qwen05bDesc');
  String get qwen15bDesc => _t('qwen15bDesc');
  String get noModelWarning => _t('noModelWarning');
  String get selectDictionary => _t('selectDictionary');
  String get downloadDictionary => _t('downloadDictionary');
  String get selectDictionaryFile => _t('selectDictionaryFile');
  String get clearSettings => _t('clearSettings');
  String get step1SelectDictionary => _t('step1SelectDictionary');
  String get step2DownloadDictionary => _t('step2DownloadDictionary');
  String get step3SupportedDictionaryFormats => _t('step3SupportedDictionaryFormats');
  String get dictionaryRecommendations => _t('dictionaryRecommendations');
  String get ecdictDesc => _t('ecdictDesc');
  String get wiktionaryDesc => _t('wiktionaryDesc');
  String get noDictionaryWarning => _t('noDictionaryWarning');
  String get downloadStatus => _t('downloadStatus');
  String get fileSize => _t('fileSize');
  String get dictionaryStatus => _t('dictionaryStatus');
  String get modelStatus => _t('modelStatus');
  String get cancel => _t('cancel');
  String get ok => _t('ok');
  String get allModelsDownloaded => _t('allModelsDownloaded');
  String get deleteModel => _t('deleteModel');
  String get deleteModelConfirm => _t('deleteModelConfirm');
  String get delete => _t('delete');
  String get modelAlreadyInstalled => _t('modelAlreadyInstalled');
  String get sourceText => _t('sourceText');
  String get clearText => _t('clearText');
  String get inputToTranslate => _t('inputToTranslate');
  String get translating => _t('translating');
  String get translate => _t('translate');
  String get translationResultWillAppear => _t('translationResultWillAppear');
  String get detailedDefinition => _t('detailedDefinition');
  String get phonetic => _t('phonetic');
  String get definition => _t('definition');
  String get example => _t('example');
  String get copyAll => _t('copyAll');
  String get copy => _t('copy');
  String get copiedToClipboard => _t('copiedToClipboard');
  String get translationResult => _t('translationResult');
  String get swapLanguages => _t('swapLanguages');
  String get addToFavorites => _t('addToFavorites');
  String get removeFromFavorites => _t('removeFromFavorites');
  String get lookupDictionary => _t('lookupDictionary');
  String get translationSource => _t('translationSource');
  String get sourceDictionary => _t('sourceDictionary');
  String get sourceOpusMt => _t('sourceOpusMt');
  String get sourceTextLang => _t('sourceTextLang');
  String get targetTextLang => _t('targetTextLang');
  String get noSearchHistory => _t('noSearchHistory');
  String get noFavoritesYet => _t('noFavoritesYet');
  String get tapStarToFavorite => _t('tapStarToFavorite');
  String get initializing => _t('initializing');
  String get loadingModelManager => _t('loadingModelManager');
  String get loadingDictionaryManager => _t('loadingDictionaryManager');
  String get initComplete => _t('initComplete');
  String get initFailed => _t('initFailed');
  String get loadingDictionary => _t('loadingDictionary');
  String get firstTimeGuideTitle => _t('firstTimeGuideTitle');
  String get firstTimeGuideMessage => _t('firstTimeGuideMessage');
  String get goToSettings => _t('goToSettings');
  String get noDictionaryOrModel => _t('noDictionaryOrModel');
  String get copySource => _t('copySource');
  String get copyTarget => _t('copyTarget');
  String get reTranslate => _t('reTranslate');
  String get removeFavoriteTitle => _t('removeFavoriteTitle');
  String get removeFavoriteConfirm => _t('removeFavoriteConfirm');
  String get translateNav => _t('translateNav');
  String get speak => _t('speak');
  String get share => _t('share');
  String get selectModelFolder => _t('selectModelFolder');
  String get modelImportedSuccess => _t('modelImportedSuccess');
  String get modelScopeUnavailable => _t('modelScopeUnavailable');
  String get huggingFaceUnavailableToast => _t('huggingFaceUnavailableToast');
  String get downloadError => _t('downloadError');
  String get modelScopeModelUnavailable => _t('modelScopeModelUnavailable');
  String get modelScopeConnectionUnavailable => _t('modelScopeConnectionUnavailable');
  String get huggingFaceConnectionUnavailable => _t('huggingFaceConnectionUnavailable');
  String get noDownloadSourceAvailable => _t('noDownloadSourceAvailable');
  String get allSourcesUnavailable => _t('allSourcesUnavailable');
  String get wordNotFound => _t('wordNotFound');
  String get queryError => _t('queryError');
  String get addedToFavorites => _t('addedToFavorites');
  String get removedFromFavorites => _t('removedFromFavorites');
  String get favoriteTooltip => _t('favoriteTooltip');
  String get noDictionaryEntryFound => _t('noDictionaryEntryFound');
  String get wordExample => _t('wordExample');
  String get modelNotDirectlyDownloadable => _t('modelNotDirectlyDownloadable');
  String get downloadFailedRetry => _t('downloadFailedRetry');
  String get downloadCancelled => _t('downloadCancelled');
  String get dictionaryNotDirectlyDownloadable => _t('dictionaryNotDirectlyDownloadable');
  String get modelScopeModelUnavailableToast => _t('modelScopeModelUnavailableToast');
  String get huggingFaceModelUnavailableToast => _t('huggingFaceModelUnavailableToast');
  String get noDownloadSourceAvailableToast => _t('noDownloadSourceAvailableToast');
  String get noTranslationModel => _t('noTranslationModel');
  String get ctranslate2LibraryNotFound => _t('ctranslate2LibraryNotFound');
  String get allModelsTranslationFailed => _t('allModelsTranslationFailed');
  String get selectMdictFile => _t('selectMdictFile');
  String get mdictImportSuccess => _t('mdictImportSuccess');
  String get mdictImportFailed => _t('mdictImportFailed');
  String get selectStarDictFolder => _t('selectStarDictFolder');
  String get noIfoFileFound => _t('noIfoFileFound');
  String get starDictImported => _t('starDictImported');
  String get dictsGroupedByLangDesc => _t('dictsGroupedByLangDesc');
  String get installedCountDesc => _t('installedCountDesc');
  String get selectInstalledDicts => _t('selectInstalledDicts');
  String get selectDictsToUse => _t('selectDictsToUse');
  String get deleteDictTooltip => _t('deleteDictTooltip');
  String get mdictFormatImported => _t('mdictFormatImported');
  String get importDictionaryTitle => _t('importDictionaryTitle');
  String get importDictionaryDesc => _t('importDictionaryDesc');
  String get selectMdxFile => _t('selectMdxFile');
  String get selectStarDictFolderBtn => _t('selectStarDictFolderBtn');
  String get availableLanguagePairs => _t('availableLanguagePairs');
  String get pleaseSelectDictsFirst => _t('pleaseSelectDictsFirst');
  String get statusAvailable => _t('statusAvailable');
  String get statusUnavailable => _t('statusUnavailable');
  String get modelDownloadCompletedToast => _t('modelDownloadCompletedToast');
  String get refreshSources => _t('refreshSources');
  String get translationModelsTitle => _t('translationModelsTitle');
  String get modelsGroupedByLangDesc => _t('modelsGroupedByLangDesc');
  String get localOnlyLabel => _t('localOnlyLabel');
  String get selectToDownloadTooltip => _t('selectToDownloadTooltip');
  String get downloadSourceTitle => _t('downloadSourceTitle');
  String get autoDetectOption => _t('autoDetectOption');
  String get autoDetectOptionDesc => _t('autoDetectOptionDesc');
  String get huggingfaceOption => _t('huggingfaceOption');
  String get huggingfaceOptionDesc => _t('huggingfaceOptionDesc');
  String get modelscopeOption => _t('modelscopeOption');
  String get modelscopeOptionDesc => _t('modelscopeOptionDesc');
  String get localImportTitle => _t('localImportTitle');
  String get localImportDescription => _t('localImportDescription');
  String get importedCustomModelsTitle => _t('importedCustomModelsTitle');
  String get downloadingTitle => _t('downloadingTitle');
  String get closeButton => _t('closeButton');
  String get installedModelsTitle => _t('installedModelsTitle');
  String get installedModelsDesc => _t('installedModelsDesc');
  String get installedCount => _t('installedCount');
  String get architectureOverviewText => _t('architectureOverviewText');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  throw UnimplementedError('Must be initialized with SharedPreferences');
});

class SettingsState {
  final UIStyle uiStyle;
  final ThemeModeOption themeModeOption;
  final LanguageOption languageOption;
  final int currentIndex;
  final Color seedColor;

  SettingsState({
    required this.uiStyle,
    required this.themeModeOption,
    required this.languageOption,
    this.currentIndex = 0,
    this.seedColor = const Color(0xFFE8002D),
  });

  SettingsState copyWith({
    UIStyle? uiStyle,
    ThemeModeOption? themeModeOption,
    LanguageOption? languageOption,
    int? currentIndex,
    Color? seedColor,
  }) {
    return SettingsState(
      uiStyle: uiStyle ?? this.uiStyle,
      themeModeOption: themeModeOption ?? this.themeModeOption,
      languageOption: languageOption ?? this.languageOption,
      currentIndex: currentIndex ?? this.currentIndex,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          uiStyle: UIStyle.values.byName(_prefs.getString(_kUIStyleKey) ?? 'fluent'),
          themeModeOption: ThemeModeOption.values.byName(_prefs.getString(_kThemeModeKey) ?? 'system'),
          languageOption: LanguageOption.values.byName(_prefs.getString(_kLanguageKey) ?? 'system'),
          currentIndex: _prefs.getInt(_kCurrentIndexKey) ?? 0,
          seedColor: Color(_prefs.getInt(_kSeedColorKey) ?? 0xFFE8002D),
        ),);

  Future<void> setUIStyle(UIStyle style) async {
    state = state.copyWith(uiStyle: style);
    await _prefs.setString(_kUIStyleKey, style.name);
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    state = state.copyWith(themeModeOption: mode);
    await _prefs.setString(_kThemeModeKey, mode.name);
  }

  Future<void> setLanguage(LanguageOption lang) async {
    state = state.copyWith(languageOption: lang);
    await _prefs.setString(_kLanguageKey, lang.name);
  }

  Future<void> setCurrentIndex(int index) async {
    state = state.copyWith(currentIndex: index);
    await _prefs.setInt(_kCurrentIndexKey, index);
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    await _prefs.setInt(_kSeedColorKey, color.toARGB32());
  }

  ThemeMode get effectiveThemeMode {
    return switch (state.themeModeOption) {
      ThemeModeOption.system => ThemeMode.system,
      ThemeModeOption.light => ThemeMode.light,
      ThemeModeOption.dark => ThemeMode.dark,
    };
  }

  Locale? get effectiveLocale {
    return switch (state.languageOption) {
      LanguageOption.system => null,
      LanguageOption.zh => const Locale('zh'),
      LanguageOption.en => const Locale('en'),
    };
  }

  bool get useMaterial3 {
    return switch (state.uiStyle) {
      UIStyle.material3 => true,
      UIStyle.fluent => false,
      UIStyle.adaptive => false,
    };
  }
}

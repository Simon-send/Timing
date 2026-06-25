import 'dart:ui';

import '../../../app/app_theme.dart';

class UserSettings {
  const UserSettings({
    required this.localeCode,
    required this.defaultEventId,
    required this.defaultClassId,
    required this.preferredSplitId,
    required this.tableDensity,
    required this.themeVariant,
  });

  factory UserSettings.defaults() {
    return const UserSettings(
      localeCode: 'nb',
      defaultEventId: null,
      defaultClassId: null,
      preferredSplitId: null,
      tableDensity: TableDensity.comfortable,
      themeVariant: AppThemeVariant.nordicDark,
    );
  }

  factory UserSettings.fromMap(Map<String, dynamic> data) {
    return UserSettings(
      localeCode: _normalizeLocale(data['localeCode']?.toString() ?? 'nb'),
      defaultEventId: _emptyToNull(data['defaultEventId']?.toString()),
      defaultClassId: _emptyToNull(data['defaultClassId']?.toString()),
      preferredSplitId: _emptyToNull(data['preferredSplitId']?.toString()),
      tableDensity: TableDensity.fromName(data['tableDensity']?.toString()),
      themeVariant: AppThemeVariant.fromName(data['themeVariant']?.toString()),
    );
  }

  final String localeCode;
  final String? defaultEventId;
  final String? defaultClassId;
  final String? preferredSplitId;
  final TableDensity tableDensity;
  final AppThemeVariant themeVariant;

  Locale get locale => Locale(_normalizeLocale(localeCode));

  UserSettings copyWith({
    String? localeCode,
    String? defaultEventId,
    String? defaultClassId,
    String? preferredSplitId,
    TableDensity? tableDensity,
    AppThemeVariant? themeVariant,
    bool clearDefaultEventId = false,
    bool clearDefaultClassId = false,
    bool clearPreferredSplitId = false,
  }) {
    return UserSettings(
      localeCode: _normalizeLocale(localeCode ?? this.localeCode),
      defaultEventId: clearDefaultEventId
          ? null
          : defaultEventId ?? this.defaultEventId,
      defaultClassId: clearDefaultClassId
          ? null
          : defaultClassId ?? this.defaultClassId,
      preferredSplitId: clearPreferredSplitId
          ? null
          : preferredSplitId ?? this.preferredSplitId,
      tableDensity: tableDensity ?? this.tableDensity,
      themeVariant: themeVariant ?? this.themeVariant,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'localeCode': _normalizeLocale(localeCode),
      'defaultEventId': defaultEventId,
      'defaultClassId': defaultClassId,
      'preferredSplitId': preferredSplitId,
      'tableDensity': tableDensity.name,
      'themeVariant': themeVariant.name,
    };
  }
}

enum TableDensity {
  comfortable,
  compact;

  static TableDensity fromName(String? name) {
    return TableDensity.values.firstWhere(
      (density) => density.name == name,
      orElse: () => TableDensity.comfortable,
    );
  }
}

String _normalizeLocale(String code) {
  final normalized = code.trim().toLowerCase();
  return normalized == 'no' ? 'nb' : normalized;
}

String? _emptyToNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

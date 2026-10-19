class AppSettings {
  final String currency;
  final String currencySymbol;
  final int lowStockThreshold;
  final String apiBaseUrl;
  final bool isOfflineMode;

  AppSettings({
    this.currency = 'INR',
    this.currencySymbol = '₹',
    this.lowStockThreshold = 100,
    this.apiBaseUrl = 'http://localhost:5050/api/v1',
    this.isOfflineMode = true,
  });

  AppSettings copyWith({
    String? currency,
    String? currencySymbol,
    int? lowStockThreshold,
    String? apiBaseUrl,
    bool? isOfflineMode,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currency': currency,
      'currencySymbol': currencySymbol,
      'lowStockThreshold': lowStockThreshold,
      'apiBaseUrl': apiBaseUrl,
      'isOfflineMode': isOfflineMode,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      currency: (map['currency'] as String?) ?? 'INR',
      currencySymbol: (map['currencySymbol'] as String?) ?? '₹',
      lowStockThreshold: (map['lowStockThreshold'] as int?) ?? 100,
      apiBaseUrl:
          (map['apiBaseUrl'] as String?) ?? 'http://localhost:5050/api/v1',
      isOfflineMode: (map['isOfflineMode'] as bool?) ?? true,
    );
  }
}

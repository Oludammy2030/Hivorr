import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// Image quality levels recommended by the payload optimizer.
///
/// Mapped from [NetworkType] + [NetworkConfig] thresholds (EP-01-13 §5.8).
enum ImageQuality {
  low,
  medium,
  high,
}

/// Immutable network management configuration for the Hivorr client.
///
/// Carries only non-secret, deployment-sourced network parameters: the
/// connectivity debounce interval and payload optimization defaults. All
/// values are sourced exclusively from [EnvironmentConfig] (EP-01-03);
/// nothing here is a hardcoded secret (EP-01-13 §5.9).
///
/// When not supplied via environment variables, safe defaults apply so the
/// network layer remains operational out-of-the-box.
class NetworkConfig {
  const NetworkConfig({
    required this.debounceIntervalMs,
    required this.enablePayloadOptimization,
    required this.mobileImageQuality,
    required this.wifiImageQuality,
    required this.mobilePageSize,
    required this.wifiPageSize,
    required this.maxUploadSizeMbMobile,
    required this.maxUploadSizeMbWifi,
  });

  /// Connectivity change debounce interval in milliseconds.
  ///
  /// `0` means no debounce — emissions are immediate. Non-zero values
  /// collapse rapid connectivity oscillation into a single emission
  /// (EP-01-13 §5.5).
  final int debounceIntervalMs;

  /// Whether payload optimization advisories are enabled.
  final bool enablePayloadOptimization;

  /// Default image quality string on mobile connections (`low`/`medium`/`high`).
  final String mobileImageQuality;

  /// Default image quality string on WiFi connections (`low`/`medium`/`high`).
  final String wifiImageQuality;

  /// Default pagination page size on mobile connections.
  final int mobilePageSize;

  /// Default pagination page size on WiFi connections.
  final int wifiPageSize;

  /// Advisory maximum upload size in MB on mobile connections.
  final double maxUploadSizeMbMobile;

  /// Advisory maximum upload size in MB on WiFi connections.
  final double maxUploadSizeMbWifi;

  /// Builds [NetworkConfig] from an [EnvironmentValueSource].
  ///
  /// Missing values fall back to safe defaults so the loader stays
  /// fail-closed on the core Supabase/schema contract while network
  /// management remains opt-in.
  static NetworkConfig fromSource(EnvironmentValueSource source) {
    return NetworkConfig(
      debounceIntervalMs: _parseInt(
        source,
        AppConstants.envNetworkDebounceMs,
        AppConstants.defaultNetworkDebounceMs,
      ),
      enablePayloadOptimization: _parseBool(
        source,
        AppConstants.featureEnablePayloadOptimization,
      ),
      mobileImageQuality: source.read(AppConstants.envNetworkMobileImageQuality) ??
          AppConstants.defaultNetworkMobileImageQuality,
      wifiImageQuality: source.read(AppConstants.envNetworkWifiImageQuality) ??
          AppConstants.defaultNetworkWifiImageQuality,
      mobilePageSize: _parseInt(
        source,
        AppConstants.envNetworkMobilePageSize,
        AppConstants.defaultNetworkMobilePageSize,
      ),
      wifiPageSize: _parseInt(
        source,
        AppConstants.envNetworkWifiPageSize,
        AppConstants.defaultNetworkWifiPageSize,
      ),
      maxUploadSizeMbMobile: _parseDouble(
        source,
        AppConstants.envNetworkMaxUploadMbMobile,
        AppConstants.defaultNetworkMaxUploadMbMobile,
      ),
      maxUploadSizeMbWifi: _parseDouble(
        source,
        AppConstants.envNetworkMaxUploadMbWifi,
        AppConstants.defaultNetworkMaxUploadMbWifi,
      ),
    );
  }

  /// Parses an [ImageQuality] from the mobile image quality string.
  ImageQuality get mobileImageQualityEnum =>
      _parseImageQuality(mobileImageQuality);

  /// Parses an [ImageQuality] from the WiFi image quality string.
  ImageQuality get wifiImageQualityEnum =>
      _parseImageQuality(wifiImageQuality);

  /// Strict boolean parse; absent → `false`, malformed → throws.
  static bool _parseBool(EnvironmentValueSource source, String key) {
    final raw = source.read(key);
    if (raw == null) {
      return false;
    }
    return switch (raw) {
      'true' => true,
      'false' => false,
      _ => throw EnvironmentConfigException(
          variableName: key,
          reason:
              'Malformed network feature flag. Accepted values: true, false.',
        ),
    };
  }

  /// Integer parse with a safe fallback; malformed → throws.
  static int _parseInt(
    EnvironmentValueSource source,
    String key,
    int fallback,
  ) {
    final raw = source.read(key);
    if (raw == null) {
      return fallback;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Network configuration value must be an integer.',
      );
    }
    if (parsed < 0) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Network configuration value must be non-negative.',
      );
    }
    return parsed;
  }

  /// Double parse with a safe fallback; malformed → throws.
  static double _parseDouble(
    EnvironmentValueSource source,
    String key,
    double fallback,
  ) {
    final raw = source.read(key);
    if (raw == null) {
      return fallback;
    }
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Network configuration value must be a number.',
      );
    }
    if (parsed < 0) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Network configuration value must be non-negative.',
      );
    }
    return parsed;
  }

  static ImageQuality _parseImageQuality(String value) {
    return switch (value) {
      'low' => ImageQuality.low,
      'medium' => ImageQuality.medium,
      'high' => ImageQuality.high,
      _ => ImageQuality.medium,
    };
  }

  @override
  String toString() {
    return 'NetworkConfig('
        'debounceIntervalMs: $debounceIntervalMs, '
        'enablePayloadOptimization: $enablePayloadOptimization, '
        'mobileImageQuality: $mobileImageQuality, '
        'wifiImageQuality: $wifiImageQuality, '
        'mobilePageSize: $mobilePageSize, '
        'wifiPageSize: $wifiPageSize, '
        'maxUploadSizeMbMobile: $maxUploadSizeMbMobile, '
        'maxUploadSizeMbWifi: $maxUploadSizeMbWifi)';
  }
}

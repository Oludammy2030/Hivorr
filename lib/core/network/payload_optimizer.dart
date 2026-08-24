import 'package:hivorr/core/network/network_config.dart';
import 'package:hivorr/core/network/network_type.dart';

/// Stateless advisory payload optimization utilities (EP-01-13 §5.8).
///
/// Provides recommendations for image quality, pagination page size,
/// compression, and max upload size based on [NetworkType]. All methods
/// are pure functions — no I/O, no side effects, no stored state.
///
/// Recommendations are advisory only; downstream consumers decide whether
/// to act on them. Server-side validation (RLS + RPC) remains authoritative
/// on accepted payload sizes and formats (AGENT.md Rule 4).
class PayloadOptimizer {
  const PayloadOptimizer(this._config);

  final NetworkConfig _config;

  /// Recommends image quality level based on [NetworkType] (EP-01-13 §5.8).
  ///
  /// - `mobile` / `bluetooth` → [ImageQuality.low]
  /// - `wifi` → [ImageQuality.medium] (configurable)
  /// - `ethernet` / `vpn` → [ImageQuality.high]
  /// - `none` / `other` → most conservative
  ImageQuality recommendedImageQuality(NetworkType type) {
    return switch (type) {
      NetworkType.mobile => ImageQuality.low,
      NetworkType.bluetooth => ImageQuality.low,
      NetworkType.wifi => _config.wifiImageQualityEnum,
      NetworkType.ethernet => ImageQuality.high,
      NetworkType.vpn => ImageQuality.high,
      NetworkType.none => ImageQuality.low,
      NetworkType.other => _config.mobileImageQualityEnum,
    };
  }

  /// Recommends a pagination page size based on [NetworkType].
  ///
  /// Metered connections get a smaller page size to reduce data usage.
  int recommendedPageSize(NetworkType type) {
    return switch (type) {
      NetworkType.mobile => _config.mobilePageSize,
      NetworkType.bluetooth => _config.mobilePageSize,
      NetworkType.wifi => _config.wifiPageSize,
      NetworkType.ethernet => _config.wifiPageSize,
      NetworkType.vpn => _config.wifiPageSize,
      NetworkType.none => _config.mobilePageSize,
      NetworkType.other => _config.mobilePageSize,
    };
  }

  /// Recommends whether payload compression should be enabled.
  ///
  /// `true` for metered connections (mobile, bluetooth); `false` for
  /// unmetered connections (wifi, ethernet, vpn).
  bool shouldCompressPayload(NetworkType type) {
    return isMeteredConnection(type);
  }

  /// Returns `true` if the [NetworkType] represents a metered connection.
  ///
  /// `mobile` and `bluetooth` are considered metered; `wifi`, `ethernet`,
  /// `vpn`, `none`, and `other` are not.
  bool isMeteredConnection(NetworkType type) {
    return type == NetworkType.mobile || type == NetworkType.bluetooth;
  }

  /// Recommends a maximum upload size in MB based on [NetworkType].
  ///
  /// Metered connections get a lower ceiling to avoid excessive data usage.
  double recommendedMaxUploadSizeMb(NetworkType type) {
    return switch (type) {
      NetworkType.mobile => _config.maxUploadSizeMbMobile,
      NetworkType.bluetooth => _config.maxUploadSizeMbMobile,
      NetworkType.wifi => _config.maxUploadSizeMbWifi,
      NetworkType.ethernet => _config.maxUploadSizeMbWifi,
      NetworkType.vpn => _config.maxUploadSizeMbWifi,
      NetworkType.none => _config.maxUploadSizeMbMobile,
      NetworkType.other => _config.maxUploadSizeMbMobile,
    };
  }
}

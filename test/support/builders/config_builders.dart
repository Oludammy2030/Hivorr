import 'package:hivorr/core/api/api_config.dart';

/// Builds valid [ApiConfig] instances with a conservative default profile.
class ApiConfigBuilder {
  Duration _connectTimeout = const Duration(seconds: 15);
  Duration _receiveTimeout = const Duration(seconds: 30);
  Duration _sendTimeout = const Duration(seconds: 30);
  int _maxRetries = 3;
  Duration _baseRetryDelay = const Duration(milliseconds: 500);
  Duration _maxRetryDelay = const Duration(seconds: 8);

  ApiConfigBuilder withConnectTimeout(Duration value) =>
      this.._connectTimeout = value;
  ApiConfigBuilder withReceiveTimeout(Duration value) =>
      this.._receiveTimeout = value;
  ApiConfigBuilder withSendTimeout(Duration value) => this.._sendTimeout = value;
  ApiConfigBuilder withMaxRetries(int value) => this.._maxRetries = value;
  ApiConfigBuilder withBaseRetryDelay(Duration value) =>
      this.._baseRetryDelay = value;
  ApiConfigBuilder withMaxRetryDelay(Duration value) =>
      this.._maxRetryDelay = value;

  ApiConfig build() => ApiConfig(
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        maxRetries: _maxRetries,
        baseRetryDelay: _baseRetryDelay,
        maxRetryDelay: _maxRetryDelay,
      );
}

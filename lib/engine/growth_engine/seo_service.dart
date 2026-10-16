library;

/// Web-guarded head writer (EP-03-19 §7.4).
///
/// The `package:web` implementation is compiled only when
/// `dart.library.js_interop` is available (browser builds) — VM unit/widget
/// tests resolve the no-op stub, mirroring
/// `lib/core/authentication/services/clear_auth_url_parameters.dart`.
export 'seo_service_stub.dart'
    if (dart.library.js_interop) 'seo_service_web.dart';

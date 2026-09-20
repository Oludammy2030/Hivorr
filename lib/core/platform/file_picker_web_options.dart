/// Platform-resolved web file-pick options for [FilePicker.pickFile].
///
/// Web compiles to [FilePickerWebOptions] (which carries the
/// `cancelUploadOnWindowBlur` opt-out); every other platform compiles to an
/// inert [WebOptions] that the platform plugins ignore. Keeps `file_picker_web`
/// (web-only, `dart:js_interop`) out of the VM/build-graph for mobile.
library;

export 'file_picker_web_options_stub.dart'
    if (dart.library.js_interop) 'file_picker_web_options_web.dart';

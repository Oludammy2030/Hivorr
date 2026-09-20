import 'package:file_picker_web/file_picker_web.dart';

/// Web pick options that keep a successfully chosen file when the window
/// regains focus after the dialog closes (the default blur-cancel can silently
/// drop an otherwise completed pick).
const FilePickerWebOptions platformFilePickerWebOptions = FilePickerWebOptions(
  cancelUploadOnWindowBlur: false,
);

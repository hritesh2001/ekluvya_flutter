/// Describes the render type of a single row in the Edit Profile form.
enum ProfileFieldType {
  /// User-editable free-text input.
  editableText,

  /// Display-only, no verification indicator.
  readOnly,

  /// Display-only with a green verified checkmark (mobile, email).
  readOnlyVerified,

  /// Tappable — opens the system date picker.
  datePicker,

  /// Tappable — opens the gender selection dialog.
  genderPicker,
}

/// Metadata for one row in the Edit Profile form.
///
/// [key] maps 1-to-1 with the backend API field name so the ViewModel can
/// serve the live value via [EditProfileViewModel.fieldValue].
class ProfileFieldConfig {
  const ProfileFieldConfig({
    required this.key,
    required this.label,
    required this.type,
  });

  final String key;
  final String label;
  final ProfileFieldType type;

  bool get isEditable =>
      type == ProfileFieldType.editableText ||
      type == ProfileFieldType.datePicker ||
      type == ProfileFieldType.genderPicker;
}

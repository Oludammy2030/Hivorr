import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Builds valid [IndustryDto] instances with sensible defaults. Each call to
/// [build] returns an independent instance.
class IndustryDtoBuilder {
  String _id = 'industry-001';
  String _slug = 'technology';
  String _name = 'Technology';
  String? _description = 'Software, hardware, IT, and digital services';
  bool _isActive = true;
  int _sortOrder = 10;
  DateTime? _createdAt;
  String? _createdBy;

  IndustryDtoBuilder withId(String value) => this.._id = value;
  IndustryDtoBuilder withSlug(String value) => this.._slug = value;
  IndustryDtoBuilder withName(String value) => this.._name = value;
  IndustryDtoBuilder withDescription(String? value) => this.._description = value;
  IndustryDtoBuilder withIsActive(bool value) => this.._isActive = value;
  IndustryDtoBuilder withSortOrder(int value) => this.._sortOrder = value;
  IndustryDtoBuilder withCreatedAt(DateTime? value) => this.._createdAt = value;
  IndustryDtoBuilder withCreatedBy(String? value) => this.._createdBy = value;

  IndustryDto build() => IndustryDto(
        id: _id,
        slug: _slug,
        name: _name,
        description: _description,
        isActive: _isActive,
        sortOrder: _sortOrder,
        createdAt: _createdAt,
        createdBy: _createdBy,
      );

  /// Serializes to the snake_case `industries` column contract with all keys
  /// present (nulls included).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': _id,
        'slug': _slug,
        'name': _name,
        'description': _description,
        'is_active': _isActive,
        'sort_order': _sortOrder,
        'created_at': _createdAt?.toIso8601String(),
        'created_by': _createdBy,
      };
}

/// Builds valid [ProfessionDto] instances with sensible defaults. Each call to
/// [build] returns an independent instance.
class ProfessionDtoBuilder {
  String _id = 'profession-001';
  String _industryId = 'industry-001';
  String _slug = 'software-engineer';
  String _name = 'Software Engineer';
  String? _description = 'Designs and builds software';
  bool _isActive = true;
  int _sortOrder = 10;
  DateTime? _createdAt;
  String? _createdBy;

  ProfessionDtoBuilder withId(String value) => this.._id = value;
  ProfessionDtoBuilder withIndustryId(String value) => this.._industryId = value;
  ProfessionDtoBuilder withSlug(String value) => this.._slug = value;
  ProfessionDtoBuilder withName(String value) => this.._name = value;
  ProfessionDtoBuilder withDescription(String? value) => this.._description = value;
  ProfessionDtoBuilder withIsActive(bool value) => this.._isActive = value;
  ProfessionDtoBuilder withSortOrder(int value) => this.._sortOrder = value;
  ProfessionDtoBuilder withCreatedAt(DateTime? value) => this.._createdAt = value;
  ProfessionDtoBuilder withCreatedBy(String? value) => this.._createdBy = value;

  ProfessionDto build() => ProfessionDto(
        id: _id,
        industryId: _industryId,
        slug: _slug,
        name: _name,
        description: _description,
        isActive: _isActive,
        sortOrder: _sortOrder,
        createdAt: _createdAt,
        createdBy: _createdBy,
      );

  /// Serializes to the snake_case `professions` column contract with all keys
  /// present (nulls included).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': _id,
        'industry_id': _industryId,
        'slug': _slug,
        'name': _name,
        'description': _description,
        'is_active': _isActive,
        'sort_order': _sortOrder,
        'created_at': _createdAt?.toIso8601String(),
        'created_by': _createdBy,
      };
}

/// Builds [Industry] entity instances with sensible defaults. Each call to
/// [build] returns an independent instance.
class IndustryBuilder {
  String _id = 'industry-001';
  String _slug = 'technology';
  String _name = 'Technology';
  String? _description = 'Software, hardware, IT, and digital services';
  bool _isActive = true;
  int _sortOrder = 10;
  DateTime? _createdAt;

  IndustryBuilder withId(String value) => this.._id = value;
  IndustryBuilder withSlug(String value) => this.._slug = value;
  IndustryBuilder withName(String value) => this.._name = value;
  IndustryBuilder withDescription(String? value) => this.._description = value;
  IndustryBuilder withIsActive(bool value) => this.._isActive = value;
  IndustryBuilder withSortOrder(int value) => this.._sortOrder = value;
  IndustryBuilder withCreatedAt(DateTime? value) => this.._createdAt = value;

  Industry build() => Industry(
        id: _id,
        slug: _slug,
        name: _name,
        description: _description,
        isActive: _isActive,
        sortOrder: _sortOrder,
        createdAt: _createdAt,
      );
}

/// Builds [Profession] entity instances with sensible defaults. Each call to
/// [build] returns an independent instance.
class ProfessionBuilder {
  String _id = 'profession-001';
  String _industryId = 'industry-001';
  String _slug = 'software-engineer';
  String _name = 'Software Engineer';
  String? _description = 'Designs and builds software';
  bool _isActive = true;
  int _sortOrder = 10;
  DateTime? _createdAt;

  ProfessionBuilder withId(String value) => this.._id = value;
  ProfessionBuilder withIndustryId(String value) => this.._industryId = value;
  ProfessionBuilder withSlug(String value) => this.._slug = value;
  ProfessionBuilder withName(String value) => this.._name = value;
  ProfessionBuilder withDescription(String? value) =>
      this.._description = value;
  ProfessionBuilder withIsActive(bool value) => this.._isActive = value;
  ProfessionBuilder withSortOrder(int value) => this.._sortOrder = value;
  ProfessionBuilder withCreatedAt(DateTime? value) => this.._createdAt = value;

  Profession build() => Profession(
        id: _id,
        industryId: _industryId,
        slug: _slug,
        name: _name,
        description: _description,
        isActive: _isActive,
        sortOrder: _sortOrder,
        createdAt: _createdAt,
      );
}

/// Data Transfer Object for a `service_listing_media` row.
///
/// Mirrors the `service_listing_get` media projection
/// (`20260921090001_service_marketplace_schema.sql:1061`):
/// `{id, storage_path, mime_type, sort_order, created_at}` ordered by
/// `sort_order ASC, created_at ASC`. Server-decided order is preserved
/// verbatim by the mapper.
class ListingMediaDto {
  const ListingMediaDto({
    required this.id,
    required this.storagePath,
    required this.mimeType,
    required this.sortOrder,
    this.createdAt,
  });

  factory ListingMediaDto.fromJson(Map<String, dynamic> json) {
    int parseSort(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ListingMediaDto(
      id: json['id'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      sortOrder: parseSort(json['sort_order']),
      createdAt: parseDate(json['created_at']),
    );
  }

  final String id;
  final String storagePath;
  final String mimeType;
  final int sortOrder;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'storage_path': storagePath,
        'mime_type': mimeType,
        'sort_order': sortOrder,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

/// DTO wrapper for the `service_listing_list_mine` envelope
/// `data:{items, has_more, next_cursor(uuid)}`.
class MyListingPageDto {
  const MyListingPageDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  factory MyListingPageDto.fromJson(Map<String, dynamic> data) {
    final List<dynamic> rawItems = data['items'] as List<dynamic>? ?? <dynamic>[];
    final List<Map<String, dynamic>> items = rawItems
        .map((Object? e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
    return MyListingPageDto(
      items: items,
      hasMore: data['has_more'] as bool? ?? false,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final String? nextCursor;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items,
        if (hasMore) 'has_more': hasMore,
        if (nextCursor != null) 'next_cursor': nextCursor,
      };
}

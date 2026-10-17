import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/engine/growth_engine/listing_seo_meta.dart';

ServiceListing _ranked({
  String id = 'listing-1',
  String slug = 'fix-leaky-tap',
  String title = 'Fix leaky tap fast',
  String description = 'I fix leaky taps same-day with genuine parts and a tidy finish.',
  String? professionSlug = 'plumber',
  String? professionName = 'Plumber',
}) =>
    ServiceListing(
      id: id,
      entityId: 'entity-1',
      professionId: 'prof-1',
      industryId: 'ind-1',
      slug: slug,
      title: title,
      description: description,
      pricingType: 'fixed',
      priceMin: 5000,
      currencyCode: 'NGN',
      avgRating: 4.8,
      reviewCount: 12,
      isTradeVerifiedCache: true,
      professionSlug: professionSlug,
      professionName: professionName,
      industrySlug: 'home-services',
      industryName: 'Home Services',
    );

MyServiceListing _owner({
  String id = 'listing-1',
  String slug = 'fix-leaky-tap',
}) =>
    MyServiceListing(
      id: id,
      entityId: 'entity-1',
      professionId: 'prof-1',
      industryId: 'ind-1',
      slug: slug,
      title: 'Fix leaky tap fast',
      description: 'I fix leaky taps same-day with genuine parts.',
      status: 'published',
      pricingType: 'fixed',
      priceMin: 5000,
      currencyCode: 'NGN',
      avgRating: 4.8,
      reviewCount: 12,
      isTradeVerifiedCache: true,
      professionSlug: 'plumber',
      professionName: 'Plumber',
    );

void main() {
  group('ListingSeoMetaBuilder', () {
    test('derives title/description/canonical from payload + origin', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildFromListing(
        _ranked(),
        baseUrl: 'https://hivorr.com/',
        routeSlug: 'plumber',
        coverImageUrl: 'https://cdn.hivorr.com/cover.jpg',
      );

      expect(meta.title, 'Fix leaky tap fast · Plumber');
      expect(meta.description,
          'I fix leaky taps same-day with genuine parts and a tidy finish.');
      expect(meta.canonicalUrl, 'https://hivorr.com/s/plumber/listing-1');
      expect(meta.ogImage, 'https://cdn.hivorr.com/cover.jpg');
    });

    test('payload profession slug wins over the cosmetic route slug', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildFromListing(
        _ranked(),
        baseUrl: 'https://hivorr.com',
        routeSlug: 'different-slug',
      );

      expect(meta.canonicalUrl, 'https://hivorr.com/s/plumber/listing-1');
    });

    test('falls back to route slug, then listing slug, then id', () {
      final ListingSeoMeta viaRoute = ListingSeoMetaBuilder.buildFromListing(
        _ranked(professionSlug: null),
        baseUrl: 'https://hivorr.com',
        routeSlug: 'fallback-slug',
      );
      expect(viaRoute.canonicalUrl,
          'https://hivorr.com/s/fallback-slug/listing-1');

      final ListingSeoMeta viaListing = ListingSeoMetaBuilder.buildFromListing(
        _ranked(professionSlug: null),
        baseUrl: 'https://hivorr.com',
      );
      expect(viaListing.canonicalUrl,
          'https://hivorr.com/s/fix-leaky-tap/listing-1');

      final ListingSeoMeta viaId = ListingSeoMetaBuilder.build(
        listingId: 'listing-1',
        title: 'T',
        description: 'D',
        baseUrl: 'https://hivorr.com',
      );
      expect(viaId.canonicalUrl, 'https://hivorr.com/s/listing-1/listing-1');
    });

    test('supports owner rows and falls back to title-only', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildFromOwner(
        _owner(),
        baseUrl: 'https://hivorr.com',
      );

      expect(meta.title, 'Fix leaky tap fast · Plumber');
      expect(meta.canonicalUrl, 'https://hivorr.com/s/plumber/listing-1');
    });

    test('truncates long descriptions to 160 chars', () {
      final String long = 'd' * 300;
      final ListingSeoMeta meta = ListingSeoMetaBuilder.build(
        listingId: 'l1',
        title: 'Title here',
        description: long,
        baseUrl: 'https://hivorr.com',
        professionSlug: 'plumber',
        professionName: 'Plumber',
      );

      expect(meta.description.length, lessThanOrEqualTo(161));
    });

    test('uses fallback copy when description is blank', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.build(
        listingId: 'l1',
        title: 'Title here',
        description: '   ',
        baseUrl: 'https://hivorr.com',
        professionSlug: 'plumber',
        professionName: 'Plumber',
      );

      expect(meta.description, contains('Plumber'));
    });

    test('falls back to the brand logo when no cover is available', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildFromListing(
        _ranked(),
        baseUrl: 'https://hivorr.com',
      );

      expect(meta.ogImage,
          'https://hivorr.com/${ListingSeoMetaBuilder.logoFallbackPath}');
    });

    test('relative canonical when origin is empty (portfolio parity)', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildFromListing(
        _ranked(),
        baseUrl: '',
        routeSlug: 'plumber',
      );

      expect(meta.canonicalUrl, '/s/plumber/listing-1');
      expect(meta.ogImage, ListingSeoMetaBuilder.logoFallbackPath);
    });

    test('never echoes legal_name or viewer identity', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildFromOwner(
        _owner(),
        baseUrl: 'https://hivorr.com',
        coverImageUrl: 'https://cdn.hivorr.com/cover.jpg',
      );
      final String joined =
          '${meta.title} ${meta.description} ${meta.canonicalUrl} ${meta.ogImage}';

      expect(joined, isNot(contains('legal_name')));
      expect(joined, isNot(contains('entity-1')));
    });

    test('browse meta carries industry title and canonical', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildBrowse(
        baseUrl: 'https://hivorr.com/',
        industrySlug: 'technology',
        industryName: 'Technology',
      );

      expect(meta.title, 'Technology services on Hivorr');
      expect(meta.canonicalUrl, 'https://hivorr.com/s/technology');
      expect(meta.description.length, lessThanOrEqualTo(161));
      expect(meta.ogImage, contains('logo_icon.png'));
    });

    test('browse meta falls back without an industry', () {
      final ListingSeoMeta meta = ListingSeoMetaBuilder.buildBrowse(
        baseUrl: '',
      );

      expect(meta.title, 'Services on Hivorr');
      expect(meta.canonicalUrl, '/s/services');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/data/local/entry_state_store.dart';

void main() {
  group('EntryStateProvider', () {
    test('defaults to intro-not-seen and no pending redirect', () async {
      final provider = EntryStateProvider(store: InMemoryEntryStateStore());
      await provider.hydrate();

      expect(provider.isHydrated, isTrue);
      expect(provider.introSeen, isFalse);
      expect(provider.pendingRedirect, isNull);
      expect(provider.hasPendingRedirect, isFalse);
    });

    test('hydrate loads the persisted intro flag and pending redirect',
        () async {
      final store = InMemoryEntryStateStore(
        introSeen: true,
        pendingRedirect: '/p/acme/1',
      );
      final provider = EntryStateProvider(store: store);
      await provider.hydrate();

      expect(provider.introSeen, isTrue);
      expect(provider.pendingRedirect, '/p/acme/1');
      expect(provider.hasPendingRedirect, isTrue);
    });

    test('markIntroSeen persists the one-time flag', () async {
      final store = InMemoryEntryStateStore();
      final provider = EntryStateProvider(store: store);
      await provider.hydrate();

      expect(provider.introSeen, isFalse);
      await provider.markIntroSeen();
      expect(provider.introSeen, isTrue);
      expect(await store.readIntroSeen(), isTrue);
    });

    test('pending redirect can be set, read and consumed', () async {
      final store = InMemoryEntryStateStore();
      final provider = EntryStateProvider(store: store);
      await provider.hydrate();

      await provider.setPendingRedirect('/p/acme/1');
      expect(provider.pendingRedirect, '/p/acme/1');
      expect(await store.readPendingRedirect(), '/p/acme/1');

      final String? consumed = await provider.consumePendingRedirect();
      expect(consumed, '/p/acme/1');
      expect(provider.hasPendingRedirect, isFalse);
      expect(await store.readPendingRedirect(), isNull);
    });

    test('hydrate without a stored value keeps defaults', () async {
      final provider = EntryStateProvider(store: InMemoryEntryStateStore());
      await provider.hydrate();

      expect(provider.introSeen, isFalse);
      expect(provider.pendingRedirect, isNull);
    });
  });
}
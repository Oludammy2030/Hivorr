import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/providers/admin_config_provider.dart';

import '../../test_helpers.dart';

void main() {
  late FakeStorageEngine storage;

  setUp(() {
    storage = FakeStorageEngine();
  });

  AdminConfigProvider build() => AdminConfigProvider(storage: storage);

  group('AdminConfigProvider.load', () {
    test('exposes reference defaults when nothing is stored', () async {
      final AdminConfigProvider provider = build();
      await provider.load();

      expect(provider.isHydrated, isTrue);
      expect(provider.platformFeePercent, 3);
      expect(provider.escrowReleaseDays, 3);
      expect(provider.maxJobBudgetUsd, 50000);
      expect(provider.minJobBudgetUsd, 10);
      expect(provider.registrationsEnabled, isTrue);
      expect(provider.jobPostingEnabled, isTrue);
      expect(provider.autoKycApprovalEnabled, isFalse);
      expect(provider.maintenanceModeEnabled, isFalse);
    });

    test('restores previously saved values on a new instance', () async {
      final AdminConfigProvider writer = build();
      await writer.load();
      expect(
        await writer.saveConfig(
          platformFeePercent: 5,
          escrowReleaseDays: 7,
          maxJobBudgetUsd: 100000,
          minJobBudgetUsd: 25,
        ),
        isNull,
      );
      expect(await writer.setToggle(AdminConfigToggle.maintenanceMode, true),
          isNull);

      final AdminConfigProvider reader = build();
      await reader.load();

      expect(reader.platformFeePercent, 5);
      expect(reader.escrowReleaseDays, 7);
      expect(reader.maxJobBudgetUsd, 100000);
      expect(reader.minJobBudgetUsd, 25);
      expect(reader.maintenanceModeEnabled, isTrue);
    });
  });

  group('AdminConfigProvider.saveConfig', () {
    test('rejects out-of-range fees and writes nothing', () async {
      final AdminConfigProvider provider = build();
      await provider.load();

      expect(
        await provider.saveConfig(
          platformFeePercent: 101,
          escrowReleaseDays: 3,
          maxJobBudgetUsd: 50000,
          minJobBudgetUsd: 10,
        ),
        isNotNull,
      );
      expect(provider.platformFeePercent, 3);
    });

    test('rejects min budget above max budget', () async {
      final AdminConfigProvider provider = build();
      await provider.load();

      expect(
        await provider.saveConfig(
          platformFeePercent: 3,
          escrowReleaseDays: 3,
          maxJobBudgetUsd: 10,
          minJobBudgetUsd: 50,
        ),
        isNotNull,
      );
      expect(provider.maxJobBudgetUsd, 50000);
    });

    test('rejects zero escrow release period', () async {
      final AdminConfigProvider provider = build();
      await provider.load();

      expect(
        await provider.saveConfig(
          platformFeePercent: 3,
          escrowReleaseDays: 0,
          maxJobBudgetUsd: 50000,
          minJobBudgetUsd: 10,
        ),
        isNotNull,
      );
      expect(provider.escrowReleaseDays, 3);
    });
  });

  group('AdminConfigProvider.setToggle', () {
    test('flips and persists toggles', () async {
      final AdminConfigProvider provider = build();
      await provider.load();

      expect(
          await provider.setToggle(
              AdminConfigToggle.registrations, false),
          isNull);
      expect(provider.registrationsEnabled, isFalse);

      final AdminConfigProvider reader = build();
      await reader.load();
      expect(reader.registrationsEnabled, isFalse);
    });
  });
}

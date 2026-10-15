import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/business_provider.dart';
import 'package:hivorr/data/repositories/business_repository.dart';
import 'package:hivorr/systems/business/screens/business_detail_screen.dart';
import 'package:hivorr/systems/business/screens/business_form_screen.dart';
import 'package:hivorr/systems/business/screens/business_list_screen.dart';
import 'package:hivorr/systems/business/services/business_service.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/widget_harness.dart';

/// In-memory [BusinessRepository] for screen tests.
class FakeBusinessRepository implements BusinessRepository {
  FakeBusinessRepository({List<Business>? businesses})
    : _businesses = <Business>[...?businesses];

  final List<Business> _businesses;
  ApiException? nextError;
  int createCalls = 0;

  @override
  Future<List<Business>> myBusinesses({required String entityId}) async {
    if (nextError != null) {
      final ApiException e = nextError!;
      nextError = null;
      throw e;
    }
    return List<Business>.unmodifiable(_businesses);
  }

  @override
  Future<Business> createBusiness({
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  }) async {
    createCalls++;
    final Business created = Business(
      id: 'biz-${_businesses.length + 1}',
      tradingName: tradingName,
      registeredLegalName: registeredLegalName,
      cacNumber: cacNumber,
      status: 'pending',
      membership: const BusinessMembership(
        businessId: 'biz-new',
        entityId: 'entity-1',
        role: 'representative',
        isAuthorized: false,
      ),
    );
    _businesses.add(created);
    return created;
  }

  @override
  Future<void> joinBusiness({
    required String businessId,
    required String entityId,
  }) async {}

  @override
  Future<void> leaveBusiness({
    required String businessId,
    required String entityId,
  }) async {}

  @override
  Future<VerificationSubmission> submitDocument({
    required String businessId,
    required String title,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async => VerificationSubmission(
    id: 'sub-1',
    entityId: 'entity-1',
    credentialId: 'cred-1',
    documentType: DocumentType.nationalId,
    status: VerificationStatusKind.pending,
    submittedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  );
}

Business businessRow({
  required String id,
  required String status,
  bool authorized = false,
}) => Business(
  id: id,
  tradingName: 'Amara Foods',
  registeredLegalName: 'Amara Foods Ltd',
  cacNumber: 'CAC-001',
  status: status,
  membership: BusinessMembership(
    businessId: id,
    entityId: 'entity-1',
    role: 'representative',
    isAuthorized: authorized,
  ),
);

FakeAuthProvider sessionAuth() {
  final FakeAuthProvider auth = FakeAuthProvider(
    initialStatus: AuthStatus.authenticated,
  );
  auth.sessionOverride = const AuthSession(
    entityId: 'entity-1',
    email: 'amara@example.com',
    firstName: 'Amara',
    lastName: 'Diallo',
  );
  return auth;
}

BusinessProvider providerWith({List<Business>? businesses}) {
  final FakeBusinessRepository repo = FakeBusinessRepository(
    businesses: businesses,
  );
  return BusinessProvider(
    service: BusinessService(repository: repo),
  );
}

List<SingleChildWidget> providers(
  BusinessProvider provider, {
  FakeAuthProvider? auth,
}) => <SingleChildWidget>[
  ChangeNotifierProvider<BusinessProvider>.value(value: provider),
  ChangeNotifierProvider<AuthProvider>.value(value: auth ?? sessionAuth()),
];

void main() {
  group('BusinessListScreen', () {
    testWidgets('renders rows with status badges', (tester) async {
      final BusinessProvider provider = providerWith(
        businesses: <Business>[
          businessRow(id: 'biz-1', status: 'pending'),
          businessRow(id: 'biz-2', status: 'approved', authorized: true),
        ],
      );
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const BusinessListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Businesses'), findsOneWidget);
      expect(find.text('Amara Foods'), findsNWidgets(2));
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('empty state offers creation', (tester) async {
      final BusinessProvider provider = providerWith();
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const BusinessListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('No businesses yet'), findsOneWidget);
      expect(find.text('Add business'), findsOneWidget);
    });

    testWidgets('failure surfaces error state', (tester) async {
      final FakeBusinessRepository repo = FakeBusinessRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        );
      final BusinessProvider provider = BusinessProvider(
        service: BusinessService(repository: repo),
      );
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const BusinessListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load businesses'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
    });
  });

  group('BusinessFormScreen', () {
    testWidgets('empty save shows inline guidance', (tester) async {
      final BusinessProvider provider = providerWith();
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const BusinessFormScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('Business / trading name'), findsOneWidget);
      expect(find.text('Registered legal name'), findsOneWidget);
      await tester.ensureVisible(find.text('Save business'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save business'));
      await tester.pumpAndSettle();
      expect(
        find.text('Business name is required (120 characters or fewer).'),
        findsOneWidget,
      );
    });
  });

  group('BusinessDetailScreen', () {
    testWidgets('renders header and verification section', (tester) async {
      final BusinessProvider provider = providerWith(
        businesses: <Business>[
          businessRow(id: 'biz-1', status: 'pending'),
        ],
      );
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const BusinessDetailScreen(businessId: 'biz-1'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amara Foods Ltd'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Upload & submit'), findsOneWidget);
    });

    testWidgets('unknown id renders not-found empty state', (tester) async {
      final BusinessProvider provider = providerWith();
      addTearDown(provider.dispose);
      await pumpApp(
        tester,
        const BusinessDetailScreen(businessId: 'missing'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      expect(find.text('Business not found'), findsOneWidget);
    });

    testWidgets('visual identity uses the brand primary token', (
      tester,
    ) async {
      expect(AppTheme.lightTheme.colorScheme.primary, const Color(0xFF2D3FE7));
    });
  });
}

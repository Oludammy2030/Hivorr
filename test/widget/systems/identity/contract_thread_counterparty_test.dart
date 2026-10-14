import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/models/public_profession_dto.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/identity/widgets/counterparty_identity.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_portfolio.dart';
import '../../../support/harnesses/widget_harness.dart';
import '../../../support/portfolio/portfolio_test_support.dart';

/// Minimal [JobRepository] stub serving one canned detail.
class _StubJobRepository implements JobRepository {
  _StubJobRepository(this.detail);

  final JobDetail detail;

  @override
  Future<JobDetail> getJob(String jobId) async => detail;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Job _job() => Job(
  id: 'job-1',
  clientEntityId: 'client-1',
  title: 'Fix my sink',
  description: 'A description that is definitely longer than fifty characters.',
  currencyCode: 'NGN',
  status: 'awarded',
  businessId: 'biz-1',
  clientDisplayName: 'Amara Diallo',
  clientBusinessName: 'Amara Foods',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

JobProvider _jobProvider() => JobProvider(
  service: JobService(
    repository: _StubJobRepository(
      JobDetail(job: _job(), applications: const []),
    ),
  ),
);

const ServiceContract _contract = ServiceContract(
  id: 'contract-1',
  serviceListingId: '',
  jobId: 'job-1',
  clientEntityId: 'client-1',
  professionalEntityId: 'pro-1',
  status: 'active',
  totalAmount: 10000,
  currencyCode: 'NGN',
);

final Hire _hire = Hire(
  id: 'hire-1',
  jobId: 'job-1',
  applicationId: 'app-1',
  clientEntityId: 'client-1',
  professionalEntityId: 'pro-1',
  status: 'active',
  hiredAt: DateTime(2026),
);

Future<void> pumpCounterparty(
  WidgetTester tester,
  Widget child,
  List<SingleChildWidget> providers,
) {
  return pumpApp(
    tester,
    Scaffold(body: child),
    providers: providers,
  );
}

void main() {
  group('ContractCounterparty', () {
    testWidgets('client viewer sees the approved professional name', (
      tester,
    ) async {
      final PortfolioTestStack portfolio = buildPortfolioStack(
        result: seedPublicProfileDto(
          entityId: 'pro-1',
          displayName: 'Adaeze Okafor',
          professions: <PublicProfessionDto>[
            seedPublicProfessionDto(professionalDisplayName: 'Adaeze Fixes It'),
          ],
        ),
      );
      final JobProvider jobs = _jobProvider();
      addTearDown(() {
        jobs.dispose();
        portfolio.provider.dispose();
      });
      await pumpCounterparty(
        tester,
        const ContractCounterparty(
          contract: _contract,
          viewerId: 'client-1',
        ),
        <SingleChildWidget>[
          ...portfolio.buildProviders(),
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Adaeze Fixes It'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('professional viewer sees the frozen business identity', (
      tester,
    ) async {
      final PortfolioTestStack portfolio = buildPortfolioStack();
      final JobProvider jobs = _jobProvider();
      addTearDown(() {
        jobs.dispose();
        portfolio.provider.dispose();
      });
      await pumpCounterparty(
        tester,
        const ContractCounterparty(
          contract: _contract,
          viewerId: 'pro-1',
        ),
        <SingleChildWidget>[
          ...portfolio.buildProviders(),
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Amara Foods'), findsOneWidget);
      expect(find.text('Hiring as a business'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stranger renders nothing', (tester) async {
      await pumpCounterparty(
        tester,
        const ContractCounterparty(
          contract: _contract,
          viewerId: 'stranger',
        ),
        const <SingleChildWidget>[],
      );
      await tester.pumpAndSettle();
      expect(find.text('Client'), findsNothing);
      expect(find.text('Professional'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ThreadCounterparty', () {
    testWidgets('professional viewer sees the hiring business', (
      tester,
    ) async {
      final JobProvider jobs = _jobProvider();
      addTearDown(jobs.dispose);
      await pumpCounterparty(
        tester,
        ThreadCounterparty(
          hire: _hire,
          viewerEntityId: 'pro-1',
          fallbackPeer: 'Professional …0001',
        ),
        <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Amara Foods'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('client viewer sees the approved professional name', (
      tester,
    ) async {
      final PortfolioTestStack portfolio = buildPortfolioStack(
        result: seedPublicProfileDto(
          entityId: 'pro-1',
          displayName: 'Adaeze Okafor',
          professions: <PublicProfessionDto>[
            seedPublicProfessionDto(professionalDisplayName: 'Adaeze Fixes It'),
          ],
        ),
      );
      final JobProvider jobs = _jobProvider();
      addTearDown(() {
        jobs.dispose();
        portfolio.provider.dispose();
      });
      await pumpCounterparty(
        tester,
        ThreadCounterparty(
          hire: _hire,
          viewerEntityId: 'client-1',
          fallbackPeer: 'Professional …0001',
        ),
        <SingleChildWidget>[
          ...portfolio.buildProviders(),
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Adaeze Fixes It'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing hire keeps the fallback peer', (tester) async {
      await pumpCounterparty(
        tester,
        const ThreadCounterparty(
          hire: null,
          viewerEntityId: 'client-1',
          fallbackPeer: 'Professional …0001',
        ),
        const <SingleChildWidget>[],
      );
      await tester.pumpAndSettle();
      expect(find.text('Professional …0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

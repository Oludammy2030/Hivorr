// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';

/// Notification channel used for jobs lifecycle events (EP-04-01).
abstract final class JobNotificationChannel {
  const JobNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the jobs provider (EP-04-01).
enum JobLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing jobs discovery, own jobs, detail, and applications state
/// to the widget tree (EP-04-01).
///
/// Depends only on the [JobService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized discovery list, the posted /
/// applied lists, the selection (job, applications, own application, events),
/// a [WidgetsBindingObserver] lifecycle gate (no background refreshes), and a
/// local "job published"/"application submitted" [HivorrNotification] hook
/// (mirrors `DisputeProvider`).
class JobProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the jobs notification hook; [logger]
  /// enables PII-safe structured logging; [clock] is injectable for
  /// deterministic tests.
  JobProvider({
    required JobService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
  }) : _service = service,
       _logger = logger,
       _notificationProvider = notificationProvider,
       _clock = clock ?? DateTime.now {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final JobService _service;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final DateTime Function() _clock;

  List<Job> _discovery = const <Job>[];
  bool _discoveryHasMore = false;
  String? _discoveryCursor;
  List<Job> _posted = const <Job>[];
  List<Job> _applied = const <Job>[];
  List<JobApplication> _myApplications = const <JobApplication>[];
  Job? _selected;
  List<JobApplication> _applications = const <JobApplication>[];
  JobApplication? _myApplication;
  List<Map<String, dynamic>> _events = const <Map<String, dynamic>>[];
  JobLoadState _loadState = JobLoadState.idle;
  ApiException? _error;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Open jobs from discovery.
  List<Job> get discovery => _discovery;

  /// Whether further discovery pages exist.
  bool get discoveryHasMore => _discoveryHasMore;

  /// Jobs posted by the current client.
  List<Job> get posted => _posted;

  /// Jobs the current professional applied to.
  List<Job> get applied => _applied;

  /// The current professional's applications (loaded via [loadApplications]).
  List<JobApplication> get myApplications => _myApplications;

  /// The selected job, or `null` before [select].
  Job? get selected => _selected;

  /// Applications on the selected job (owner only, else empty).
  List<JobApplication> get applications => _applications;

  /// The caller's application on the selected job, when an applicant.
  JobApplication? get myApplication => _myApplication;

  /// Lifecycle events of the selected job.
  List<Map<String, dynamic>> get events => _events;

  /// The load lifecycle state.
  JobLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == JobLoadState.loading;

  /// Whether the latest load/refresh succeeded.
  bool get isLoaded => _loadState == JobLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Loads open-job discovery, resetting when [refresh] is true.
  Future<void> loadDiscovery({
    String? professionId,
    String? search,
    bool refresh = false,
  }) async {
    if (isLoading) return;
    _loadState = JobLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final JobPage page = await _service.listJobs(
        professionId: professionId,
        search: search,
        cursor: refresh ? null : _discoveryCursor,
      );
      _discovery = refresh ? page.jobs : <Job>[..._discovery, ...page.jobs];
      _discoveryHasMore = page.hasMore;
      _discoveryCursor = page.nextCursor;
      _loadState = JobLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = JobLoadState.error;
      _logger?.warning('Job discovery load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads own jobs for [role] (`posted` or `applied`).
  Future<void> loadMine({String role = 'posted'}) async {
    if (isLoading) return;
    _loadState = JobLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final JobPage page = await _service.listMyJobs(role: role);
      if (role == 'applied') {
        _applied = page.jobs;
      } else {
        _posted = page.jobs;
      }
      _loadState = JobLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = JobLoadState.error;
      _logger?.warning('Own jobs load failed', <String, Object?>{
        'role': role,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the detail (job + applications + events) for [jobId] in one RPC.
  Future<void> select(String jobId) async {
    if (isLoading) return;
    if (_selected?.id == jobId && isLoaded) return;
    _loadState = JobLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final JobDetail detail = await _service.getJob(jobId);
      _applyDetail(detail);
      _loadState = JobLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = JobLoadState.error;
      _logger?.warning('Job detail load failed', <String, Object?>{
        'jobId': jobId,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current selection (pull-to-refresh / lifecycle resume).
  Future<void> refresh() async {
    final Job? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      _applyDetail(await _service.getJob(current.id));
      _loadState = JobLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = JobLoadState.error;
      _logger?.warning('Job refresh failed', <String, Object?>{
        'jobId': current.id,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Lists the professional's own applications (screen-local paging).
  Future<ApplicationPage> listApplications({String? status}) =>
      _service.listMyApplications(status: status);

  /// Loads and memoizes the professional's own applications (activity feed).
  Future<void> loadApplications({String? status}) async {
    if (isLoading) return;
    _loadState = JobLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final ApplicationPage page = await _service.listMyApplications(
        status: status,
      );
      _myApplications = page.applications;
      _loadState = JobLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = JobLoadState.error;
      _logger?.warning('Applications load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Creates a draft job and selects it.
  Future<Job> create({
    required String title,
    required String description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String currencyCode = 'NGN',
    String? location,
  }) async {
    final Job job = await _service.createJob(
      title: title,
      description: description,
      professionId: professionId,
      industryId: industryId,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      currencyCode: currencyCode,
      location: location,
    );
    _posted = <Job>[job, ..._posted];
    _selected = job;
    _applications = const <JobApplication>[];
    _myApplication = null;
    _events = const <Map<String, dynamic>>[];
    if (!_disposed) notifyListeners();
    return job;
  }

  /// Runs a job lifecycle transition and refreshes the selection.
  ///
  /// [action] is one of [publish]/[pause]/[resume]/[cancel]/[complete]/[update].
  Future<Job> _transition(Future<Job> Function() action) async {
    final Job job = await action();
    _selected = job;
    _upsertMine(job);
    _maybeNotify(job);
    if (!_disposed) notifyListeners();
    return job;
  }

  /// Updates a draft/open/paused job. Only non-null fields are sent.
  Future<Job> update({
    required String jobId,
    String? title,
    String? description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String? currencyCode,
    String? location,
  }) => _transition(
    () => _service.updateJob(
      jobId: jobId,
      title: title,
      description: description,
      professionId: professionId,
      industryId: industryId,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      currencyCode: currencyCode,
      location: location,
    ),
  );

  /// Publishes a draft job.
  Future<Job> publish(String jobId) =>
      _transition(() => _service.publishJob(jobId));

  /// Pauses an open job.
  Future<Job> pause(String jobId) =>
      _transition(() => _service.pauseJob(jobId));

  /// Resumes a paused job.
  Future<Job> resume(String jobId) =>
      _transition(() => _service.resumeJob(jobId));

  /// Cancels a draft/open/paused job.
  Future<Job> cancel(String jobId, {String? reason}) =>
      _transition(() => _service.cancelJob(jobId, reason: reason));

  /// Completes an awarded job.
  Future<Job> complete(String jobId) =>
      _transition(() => _service.completeJob(jobId));

  /// Submits an application and records it as the own application.
  Future<JobApplication> apply({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  }) async {
    final JobApplication application = await _service.submitApplication(
      jobId: jobId,
      coverNote: coverNote,
      quotedAmount: quotedAmount,
      currencyCode: currencyCode,
      durationDays: durationDays,
    );
    _myApplication = application;
    _maybeNotifyApplication(application);
    if (!_disposed) notifyListeners();
    return application;
  }

  /// Withdraws an application and updates local state.
  Future<JobApplication> withdrawApplication(String applicationId) async {
    final JobApplication updated = await _service.withdrawApplication(
      applicationId,
    );
    _replaceApplication(updated);
    if (_myApplication?.id == applicationId) _myApplication = updated;
    if (!_disposed) notifyListeners();
    return updated;
  }

  /// Shortlists an application and updates local state (owner).
  Future<JobApplication> shortlistApplication(String applicationId) async {
    final JobApplication updated = await _service.shortlistApplication(
      applicationId,
    );
    _replaceApplication(updated);
    if (!_disposed) notifyListeners();
    return updated;
  }

  /// Rejects an application and updates local state (owner).
  Future<JobApplication> rejectApplication(String applicationId) async {
    final JobApplication updated = await _service.rejectApplication(
      applicationId,
    );
    _replaceApplication(updated);
    if (!_disposed) notifyListeners();
    return updated;
  }

  void _applyDetail(JobDetail detail) {
    _selected = detail.job;
    _applications = detail.applications;
    _myApplication = detail.myApplication;
    _events = detail.events;
  }

  void _replaceApplication(JobApplication updated) {
    _applications = _applications
        .map((JobApplication a) => a.id == updated.id ? updated : a)
        .toList(growable: false);
  }

  void _upsertMine(Job job) {
    _posted = <Job>[job, ..._posted.where((Job j) => j.id != job.id)];
    _discovery = _discovery
        .map((Job j) => j.id == job.id ? job : j)
        .toList(growable: false);
  }

  void _maybeNotify(Job job) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    final String? title = switch (job.status) {
      'open' => 'Job published',
      'paused' => 'Job paused',
      'cancelled' => 'Job cancelled',
      'completed' => 'Job completed',
      _ => null,
    };
    if (title == null) return;
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: job.id.hashCode & 0x7fffffff,
          title: title,
          body: 'Your job is now ${job.status}.',
          channelId: JobNotificationChannel.system,
          priority: NotificationPriority.normal,
          timestamp: _clock(),
          actionRoute: '/dashboard/jobs/${job.id}',
        ),
      ),
    );
  }

  void _maybeNotifyApplication(JobApplication application) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: application.id.hashCode & 0x7fffffff,
          title: 'Application submitted',
          body: 'Your application is now under review.',
          channelId: JobNotificationChannel.system,
          priority: NotificationPriority.normal,
          timestamp: _clock(),
          actionRoute: '/dashboard/jobs/${application.jobId}',
        ),
      ),
    );
  }

  /// Pauses background refreshes (lifecycle gate).
  void pausePolling() {
    _paused = true;
  }

  /// Resumes background refreshes (lifecycle gate).
  void resumePolling() {
    _paused = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause refreshes while backgrounded; no wasted RPCs (EP-04-01).
    _paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } on Object {
      // Observer was never attached (no live binding).
    }
    super.dispose();
  }
}

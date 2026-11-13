import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/local_workshop_admin_store.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/commerce/commerce_models.dart';
import '../../core/commerce/commerce_store.dart';
import '../../core/owner/owner_control_service.dart';
import '../../core/networking/api_client.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/workshops/local_workshop_directory_store.dart';
import '../../core/workshops/workshop_repository.dart';
import '../../core/workshops/workshop.dart';
import '../../core/workshops/workshop_data_purge_service.dart';
import '../../core/workshops/workshop_identity.dart';
import '../access/role_access_screen.dart';

Color _accent = const Color(0xFFFF6500);
const _bg = Color(0xFF0B0D10);
const _panel = Color(0xEB15181D);
const _panelHigh = Color(0xF21D2127);
const _border = Color(0xFF30353D);
const _muted = Color(0xFFAAB0B9);
const _success = Color(0xFF39D98A);
const _warning = Color(0xFFFFBF3C);
const _danger = Color(0xFFFF5C65);
const _workshopFilters = <String>[
  'Todos',
  'Nuevos / Prueba',
  'Activos permanentes',
  'Suspendidos',
];

enum _Section {
  summary,
  workshops,
  sales,
  trash,
  incidents,
  users,
  documents,
  audit,
  appearance,
  settings,
}

class _Workshop {
  _Workshop(
    this.name,
    this.location,
    this.plan,
    this.status,
    this.activity, {
    this.id,
    this.createdAt,
    this.trialEndsAt,
    this.deletedAt,
    this.purgeAfter,
    this.administratorCount = 0,
    this.clientCount = 0,
    this.isLocalRecord = false,
  });
  final String? id;
  final DateTime? createdAt;
  final String name;
  final String location;
  String plan;
  String status;
  final String activity;
  DateTime? trialEndsAt;
  DateTime? deletedAt;
  DateTime? purgeAfter;
  final int administratorCount;
  final int clientCount;
  final bool isLocalRecord;
  String? previousPlan;
  String? previousStatus;
  String? extensionRequestId;
  String? requestAccountEmail;
  int? requestedDays;
  String? requestReason;

  bool get hasPendingExtension =>
      extensionRequestId != null || requestAccountEmail != null;
  bool get isDeleted => deletedAt != null || status == 'Eliminado';
  bool get isNew {
    final registered = createdAt;
    if (registered == null || isDeleted) return false;
    return registered.isAfter(DateTime.now().subtract(const Duration(days: 7)));
  }

  bool get needsAttention => !isDeleted && (isNew || status == 'Prueba');
  bool get isVisibleToClients =>
      !isDeleted && (status == 'Activo' || status == 'Prueba');
}

class _Issue {
  _Issue(this.title, this.workshop, this.priority, this.time);
  final String title;
  final String workshop;
  final String priority;
  final String time;
  bool resolved = false;
}

class _PlatformAccount {
  _PlatformAccount(this.name, this.role, this.detail, {this.active = true});

  final String name;
  final String role;
  final String detail;
  bool active;
}

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({
    super.key,
    required this.authController,
    required this.tenantContext,
    required this.brandController,
  });
  final AdminAuthController authController;
  final TenantContext tenantContext;
  final WorkshopBrandController brandController;

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _ownerService = OwnerControlService();
  final _localAdminStore = LocalWorkshopAdminStore();
  _Section _section = _Section.summary;
  int _settingsInitialTab = 0;
  final _search = TextEditingController();
  String _filter = 'Todos';
  final _workshops = <_Workshop>[];
  final _issues = <_Issue>[];
  final _accounts = <_PlatformAccount>[];
  bool _usingCloudData = false;
  bool _loadingCloudData = false;
  bool _cloudReloadQueued = false;
  bool _notificationsRead = false;
  Timer? _refreshTimer;
  RealtimeChannel? _workshopChannel;

  String get _sectionBackground => switch (_section) {
    _Section.summary => 'assets/images/owner_motorcycle_background_v1.png',
    _Section.workshops ||
    _Section.sales ||
    _Section.trash ||
    _Section.users => 'assets/images/owner_service_bays_background_v1.png',
    _Section.incidents ||
    _Section.audit => 'assets/images/owner_tools_background_v1.png',
    _Section.documents ||
    _Section.settings => 'assets/images/owner_motorcycle_background_v1.png',
    _Section.appearance => 'assets/images/owner_tools_background_v1.png',
  };

  @override
  void initState() {
    super.initState();
    LocalWorkshopDirectoryStore.revision.addListener(_directoryChanged);
    if (ApiClient.cloudEnabled) {
      _workshopChannel = ApiClient().client
          .channel('owner-complete-workshop-directory')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'workshops',
            callback: (_) => _loadCloudData(silent: true),
          )
          .subscribe();
    }
    _loadCloudData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadCloudData(silent: true),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _refreshTimer?.cancel();
    final channel = _workshopChannel;
    if (channel != null) {
      unawaited(ApiClient().client.removeChannel(channel));
    }
    LocalWorkshopDirectoryStore.revision.removeListener(_directoryChanged);
    super.dispose();
  }

  void _directoryChanged() {
    if (mounted) _loadCloudData();
  }

  Future<void> _loadCloudData({bool silent = false}) async {
    if (_loadingCloudData) {
      _cloudReloadQueued = true;
      return;
    }
    _loadingCloudData = true;
    if (!_ownerService.hasCloudSession) {
      try {
        await _loadLocalTrialRequests();
      } finally {
        _loadingCloudData = false;
        if (_cloudReloadQueued && mounted) {
          _cloudReloadQueued = false;
          scheduleMicrotask(() => _loadCloudData(silent: true));
        }
      }
      return;
    }
    if (!silent && mounted) setState(() {});
    try {
      final records = await _ownerService.listWorkshops();
      List<OwnerTrialExtensionRequest> requests = const [];
      List<OwnerAccountRecord> cloudAccounts = const [];
      try {
        requests = await _ownerService.listPendingTrialExtensionRequests();
      } catch (_) {}
      try {
        cloudAccounts = await _ownerService.listAccounts();
      } catch (_) {}
      final localAccounts = await _localAdminStore.listAccounts();
      final localDirectoryStore = LocalWorkshopDirectoryStore();
      await localDirectoryStore.syncRegisteredAccounts(localAccounts);
      final localDirectory = await localDirectoryStore.listAll();
      var connectedDirectory = <Workshop>[];
      try {
        connectedDirectory = await WorkshopRepository().listActive();
      } catch (_) {
        // The owner RPC and local directory still keep the control center usable.
      }
      if (!mounted) return;
      setState(() {
        _usingCloudData = true;
        _workshops
          ..clear()
          ..addAll(
            records.map(
              (record) => _Workshop(
                record.name,
                record.location,
                record.plan,
                record.isDeleted
                    ? 'Eliminado'
                    : record.status == 'suspended'
                    ? 'Suspendido'
                    : switch (record.accessStatus) {
                        'trial' => 'Prueba',
                        'active' => 'Activo',
                        'expired' => 'Vencido',
                        'suspended' => 'Suspendido',
                        _ => 'En revisión',
                      },
                record.updatedAt == null ? 'Sin actividad' : 'Actualizado',
                id: record.id,
                createdAt: record.createdAt,
                trialEndsAt: record.trialEndsAt,
                deletedAt: record.deletedAt,
                purgeAfter: record.purgeAfter,
                administratorCount: record.administratorCount,
                clientCount: record.clientCount,
              ),
            ),
          );
        final cloudIds = records.map((record) => record.id).toSet();
        final localAccountsByTenant = {
          for (final account in localAccounts.where((item) => item.hasWorkshop))
            account.tenantId: account,
        };
        final completeDirectory = <String, Workshop>{
          for (final workshop in connectedDirectory) workshop.id: workshop,
          for (final workshop in localDirectory) workshop.id: workshop,
        };
        for (final workshop in completeDirectory.values) {
          if (cloudIds.contains(workshop.id)) continue;
          final account = localAccountsByTenant.remove(workshop.id);
          _workshops.add(
            _Workshop(
              workshop.name,
              workshop.locationLine.isEmpty
                  ? 'Ubicación pendiente'
                  : workshop.locationLine,
              account?.accessState == WorkshopAccessState.active ||
                      (account == null && workshop.permanentAccess)
                  ? 'Acceso permanente'
                  : 'Prueba gratuita',
              account == null
                  ? _directoryStatus(workshop)
                  : account.deletedAt != null
                  ? 'Eliminado'
                  : switch (account.accessState) {
                      WorkshopAccessState.active => 'Activo',
                      WorkshopAccessState.trial => 'Prueba',
                      WorkshopAccessState.expired => 'Vencido',
                      WorkshopAccessState.suspended => 'Suspendido',
                    },
              'Registro local sincronizado',
              id: workshop.id,
              createdAt: account?.trialStartedAt ?? workshop.trialStartedAt,
              trialEndsAt: account?.trialEndsAt ?? workshop.trialEndsAt,
              deletedAt: account?.deletedAt,
              purgeAfter: account?.purgeAfter,
              administratorCount: account == null ? 0 : 1,
              isLocalRecord: true,
            ),
          );
        }
        for (final account in localAccountsByTenant.values) {
          if (cloudIds.contains(account.tenantId)) continue;
          _workshops.add(
            _Workshop(
              account.tenantName,
              'Registro local',
              account.accessState == WorkshopAccessState.active
                  ? 'Acceso permanente'
                  : 'Prueba gratuita',
              account.deletedAt != null
                  ? 'Eliminado'
                  : switch (account.accessState) {
                      WorkshopAccessState.active => 'Activo',
                      WorkshopAccessState.trial => 'Prueba',
                      WorkshopAccessState.expired => 'Vencido',
                      WorkshopAccessState.suspended => 'Suspendido',
                    },
              'Cuenta local',
              id: account.tenantId,
              createdAt: account.trialStartedAt,
              trialEndsAt: account.trialEndsAt,
              deletedAt: account.deletedAt,
              purgeAfter: account.purgeAfter,
              administratorCount: 1,
              isLocalRecord: true,
            ),
          );
        }
        _workshops.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        _accounts
          ..clear()
          ..addAll(
            cloudAccounts.map(
              (account) => _PlatformAccount(
                account.fullName,
                account.role,
                [
                  account.workshopName,
                  if (account.email.isNotEmpty) account.email,
                  if (account.phone.isNotEmpty) account.phone,
                ].join(' · '),
                active: account.isActive,
              ),
            ),
          )
          ..addAll(
            localAccounts
                .where(
                  (local) => !cloudAccounts.any(
                    (cloud) =>
                        cloud.email.toLowerCase() == local.email.toLowerCase(),
                  ),
                )
                .map(
                  (account) => _PlatformAccount(
                    account.fullName.isEmpty
                        ? account.username
                        : account.fullName,
                    'Administrador',
                    '${account.tenantName} · ${account.email} · Registro local',
                    active: account.deletedAt == null && account.canEnter,
                  ),
                ),
          );
        for (final request in requests) {
          final workshop = _workshops
              .where((item) => item.id == request.workshopId)
              .firstOrNull;
          if (workshop == null) continue;
          workshop.extensionRequestId = request.id;
          workshop.requestedDays = request.requestedDays;
          workshop.requestReason = request.reason;
        }
        _deduplicateWorkshopRecords();
      });
    } catch (error) {
      await _loadLocalTrialRequests();
      if (mounted && !silent) {
        _toast('No fue posible validar la sesión propietaria en la nube.');
      }
    } finally {
      _loadingCloudData = false;
      if (mounted && !silent) setState(() {});
      if (_cloudReloadQueued && mounted) {
        _cloudReloadQueued = false;
        scheduleMicrotask(() => _loadCloudData(silent: true));
      }
    }
  }

  Future<void> _loadLocalTrialRequests() async {
    final accounts = await _localAdminStore.listAccounts();
    final requests = await _localAdminStore.listPendingTrialExtensionRequests();
    final localDirectoryStore = LocalWorkshopDirectoryStore();
    await localDirectoryStore.syncRegisteredAccounts(accounts);
    final directoryById = <String, Workshop>{
      for (final workshop in await localDirectoryStore.listAll())
        workshop.id: workshop,
    };
    try {
      for (final workshop in await WorkshopRepository().listActive()) {
        directoryById[workshop.id] = workshop;
      }
    } catch (_) {
      // El registro compartido conserva lo que el cliente ya pudo consultar.
    }
    final directory = directoryById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _usingCloudData = false;
      _accounts
        ..clear()
        ..addAll(
          accounts.map(
            (account) => _PlatformAccount(
              account.fullName.isEmpty ? account.username : account.fullName,
              'Administrador',
              '${account.tenantName} · ${account.email}',
              active: account.deletedAt == null && account.canEnter,
            ),
          ),
        );
      final workshopAccounts = accounts.where((account) => account.hasWorkshop);
      final accountsByTenant = {
        for (final account in workshopAccounts) account.tenantId: account,
      };
      _workshops
        ..clear()
        ..addAll(
          directory.map((workshop) {
            final account = accountsByTenant.remove(workshop.id);
            return _Workshop(
              workshop.name,
              workshop.locationLine.isEmpty
                  ? 'Ubicación pendiente'
                  : workshop.locationLine,
              account?.accessState == WorkshopAccessState.active ||
                      (account == null && workshop.permanentAccess)
                  ? 'Acceso permanente'
                  : 'Prueba gratuita',
              account == null
                  ? _directoryStatus(workshop)
                  : switch (account.accessState) {
                      WorkshopAccessState.active => 'Activo',
                      WorkshopAccessState.trial => 'Prueba',
                      WorkshopAccessState.expired => 'Vencido',
                      WorkshopAccessState.suspended => 'Suspendido',
                    },
              'Directorio sincronizado',
              id: workshop.id,
              createdAt: account?.trialStartedAt,
              trialEndsAt: account?.trialEndsAt,
              isLocalRecord: true,
            );
          }),
        )
        ..addAll(
          accountsByTenant.values.map(
            (account) => _Workshop(
              account.tenantName,
              'Registro local',
              account.deletedAt != null
                  ? 'En papelera'
                  : account.accessState == WorkshopAccessState.active
                  ? 'Acceso permanente'
                  : 'Prueba gratuita',
              account.deletedAt != null
                  ? 'Eliminado'
                  : switch (account.accessState) {
                      WorkshopAccessState.active => 'Activo',
                      WorkshopAccessState.trial => 'Prueba',
                      WorkshopAccessState.expired => 'Vencido',
                      WorkshopAccessState.suspended => 'Suspendido',
                    },
              'Cuenta local',
              id: account.tenantId,
              createdAt: account.trialStartedAt,
              trialEndsAt: account.trialEndsAt,
              deletedAt: account.deletedAt,
              purgeAfter: account.purgeAfter,
              isLocalRecord: true,
            ),
          ),
        );
      for (final request in requests) {
        var workshop = _workshops
            .where((item) => item.id == request.tenantId)
            .firstOrNull;
        if (workshop == null) {
          workshop = _Workshop(
            request.tenantName,
            'Registro local',
            'Prueba gratuita',
            'Vencido',
            'Solicitud reciente',
            id: request.tenantId,
            isLocalRecord: true,
          );
          _workshops.insert(0, workshop);
        }
        workshop.requestAccountEmail = request.accountEmail;
        workshop.requestedDays = request.requestedDays;
        workshop.requestReason = request.reason;
      }
      _deduplicateWorkshopRecords();
    });
  }

  String _directoryStatus(Workshop workshop) {
    if (workshop.accessStatus == 'suspended') return 'Suspendido';
    if (!workshop.hasPlatformAccess) return 'Vencido';
    if (workshop.accessStatus == 'trial' && !workshop.permanentAccess) {
      return 'Prueba';
    }
    return 'Activo';
  }

  void _deduplicateWorkshopRecords() {
    final unique = <String, _Workshop>{};
    for (final workshop in _workshops) {
      final key = normalizeWorkshopIdentity(workshop.name);
      if (key.isEmpty) continue;
      final current = unique[key];
      final candidatePriority = _ownerWorkshopPriority(workshop);
      final currentPriority = current == null
          ? -1
          : _ownerWorkshopPriority(current);
      final candidateDate = workshop.createdAt;
      final currentDate = current?.createdAt;
      if (current == null ||
          candidatePriority > currentPriority ||
          (candidatePriority == currentPriority &&
              candidateDate != null &&
              (currentDate == null || candidateDate.isAfter(currentDate)))) {
        unique[key] = workshop;
      }
    }
    _workshops
      ..clear()
      ..addAll(unique.values)
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  int _ownerWorkshopPriority(_Workshop workshop) {
    var score = 0;
    if (workshop.isVisibleToClients) score += 1000;
    if (workshop.status == 'Activo') score += 300;
    if (workshop.plan == 'Acceso permanente') score += 200;
    if (!workshop.isLocalRecord) score += 20;
    if (workshop.location != 'Ubicación pendiente' &&
        workshop.location != 'Registro local') {
      score += 10;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.authController,
    builder: (context, _) {
      _accent = Color(widget.authController.ownerAccentColorValue);
      final backgroundIntensity = widget.authController.ownerBackgroundOpacity
          .clamp(.2, 1.0);
      final themed = Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: _accent, secondary: _accent),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xF022262C),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          labelStyle: const TextStyle(color: _muted),
          hintStyle: const TextStyle(color: Color(0xFF7F858D)),
          prefixIconColor: const Color(0xFFB9BEC5),
          suffixIconColor: const Color(0xFFB9BEC5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF454B54)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: _accent, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _danger, width: 1.4),
          ),
        ),
        sliderTheme: SliderTheme.of(
          context,
        ).copyWith(activeTrackColor: _accent),
        visualDensity: widget.authController.ownerCompactMode
            ? VisualDensity.compact
            : VisualDensity.standard,
      );
      return Theme(
        data: themed,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(widget.authController.ownerTextScale),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final fullNav = box.maxWidth >= 1080;
              final rail = box.maxWidth >= 760 && !fullNav;
              return Scaffold(
                backgroundColor: _bg,
                drawer: fullNav || rail
                    ? null
                    : Drawer(
                        backgroundColor: _panel,
                        child: SafeArea(child: _navigation(true)),
                      ),
                appBar: fullNav || rail
                    ? null
                    : AppBar(
                        backgroundColor: _panel,
                        title: const Text(
                          'Centro de control',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        actions: [
                          IconButton(
                            tooltip: 'Actualizar datos desde la nube',
                            onPressed: _loadingCloudData
                                ? null
                                : () => _loadCloudData(),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          IconButton(
                            tooltip: 'Notificaciones',
                            onPressed: _showNotifications,
                            icon: Badge(
                              isLabelVisible: !_notificationsRead,
                              smallSize: 7,
                              backgroundColor: _accent,
                              child: const Icon(
                                Icons.notifications_none_rounded,
                              ),
                            ),
                          ),
                          _profileMenu(34),
                          const SizedBox(width: 14),
                        ],
                      ),
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.authController.ownerBackgroundEnabled)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        child: Image.asset(
                          _sectionBackground,
                          key: ValueKey(_sectionBackground),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ColoredBox(
                      color: Color.fromRGBO(
                        7,
                        10,
                        13,
                        widget.authController.ownerBackgroundEnabled
                            ? .68 - (backgroundIntensity * .42)
                            : .96,
                      ),
                    ),
                    SafeArea(
                      child: Row(
                        children: [
                          if (fullNav || rail)
                            SizedBox(
                              width: fullNav ? 230 : 76,
                              child: _navigation(fullNav),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                if (fullNav || rail) _topBar(),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.all(
                                      box.maxWidth >= 760 ? 26 : 12,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 980,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            box.maxWidth >= 760
                                                ? (widget
                                                          .authController
                                                          .ownerCompactMode
                                                      ? 16
                                                      : 22)
                                                : 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0x8F0C0F13),
                                            border: Border.all(
                                              color: _accent.withValues(
                                                alpha: .78,
                                              ),
                                              width: 1.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: .46,
                                                ),
                                                blurRadius: 28,
                                                offset: const Offset(0, 14),
                                              ),
                                            ],
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, contentBox) =>
                                                _content(contentBox.maxWidth),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );

  Widget _navigation(bool expanded) {
    const items = [
      (_Section.summary, Icons.home_outlined, 'Resumen'),
      (_Section.workshops, Icons.storefront_outlined, 'Talleres'),
      (_Section.sales, Icons.payments_outlined, 'Ventas y comisiones'),
      (_Section.trash, Icons.delete_outline_rounded, 'Papelera'),
      (_Section.incidents, Icons.warning_amber_rounded, 'Incidencias'),
      (_Section.users, Icons.group_outlined, 'Usuarios'),
      (_Section.documents, Icons.description_outlined, 'Documentos'),
      (_Section.audit, Icons.history_rounded, 'Auditoría'),
      (_Section.appearance, Icons.palette_outlined, 'Personalización'),
      (_Section.settings, Icons.manage_accounts_outlined, 'Mi perfil'),
    ];
    return ColoredBox(
      color: _panel,
      child: Column(
        children: [
          SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (expanded) const SizedBox(width: 18),
                Icon(Icons.build_circle_outlined, color: _accent, size: 34),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  const Text(
                    'CONTROL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Material(
                        color: _section == item.$1
                            ? _accent.withValues(alpha: .16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: expanded ? 14 : 0,
                          ),
                          leading: expanded
                              ? Icon(
                                  item.$2,
                                  color: _section == item.$1 ? _accent : _muted,
                                )
                              : null,
                          title: expanded
                              ? Text(
                                  item.$3,
                                  style: TextStyle(
                                    color: _section == item.$1
                                        ? Colors.white
                                        : _muted,
                                  ),
                                )
                              : Tooltip(
                                  message: item.$3,
                                  child: Icon(
                                    item.$2,
                                    color: _section == item.$1
                                        ? _accent
                                        : _muted,
                                  ),
                                ),
                          onTap: () {
                            setState(() {
                              _section = item.$1;
                              if (item.$1 == _Section.settings) {
                                _settingsInitialTab = 0;
                              }
                            });
                            if (Scaffold.maybeOf(context)?.isDrawerOpen ??
                                false) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: expanded
                ? OutlinedButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: _muted,
                    ),
                  )
                : IconButton(
                    tooltip: 'Cerrar sesión',
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: _panel,
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centro de control',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              Text(
                'Supervisión general de la plataforma',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: _showNotifications,
          icon: Badge(
            isLabelVisible: !_notificationsRead,
            smallSize: 7,
            backgroundColor: _accent,
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        const SizedBox(width: 8),
        _profileMenu(38),
        const SizedBox(width: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            widget.authController.fullName.isEmpty
                ? 'Propietario principal'
                : widget.authController.fullName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _avatar(double size) {
    Uint8List? bytes;
    try {
      if (widget.authController.avatarBase64.isNotEmpty) {
        bytes = base64Decode(widget.authController.avatarBase64);
      }
    } catch (_) {
      bytes = null;
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _panelHigh,
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes == null
          ? Icon(Icons.person_outline_rounded, color: _accent)
          : null,
    );
  }

  Widget _profileMenu(double size) => PopupMenuButton<String>(
    tooltip: 'Mi perfil',
    offset: const Offset(0, 46),
    color: _panelHigh,
    onSelected: (value) {
      if (value == 'logout') {
        _confirmLogout();
        return;
      }
      setState(() {
        _section = _Section.settings;
        _settingsInitialTab = value == 'security' ? 1 : 0;
      });
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'profile',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_outline),
          title: Text('Datos personales'),
        ),
      ),
      PopupMenuItem(
        value: 'security',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.shield_outlined),
          title: Text('Usuario y contraseña'),
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem(
        value: 'logout',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.logout_rounded),
          title: Text('Cerrar sesión'),
        ),
      ),
    ],
    child: _avatar(size),
  );

  Widget _content(double width) => switch (_section) {
    _Section.summary => _summary(width),
    _Section.workshops => _workshopsPage(),
    _Section.sales => _salesPage(),
    _Section.trash => _trashPage(),
    _Section.incidents => _incidentsPage(),
    _Section.users => _usersPage(),
    _Section.documents => _OwnerSettings(
      authController: widget.authController,
      documentsOnly: true,
    ),
    _Section.audit => _auditPage(),
    _Section.appearance => _AppearanceSettings(
      authController: widget.authController,
    ),
    _Section.settings => _OwnerSettings(
      key: ValueKey(_settingsInitialTab),
      authController: widget.authController,
      initialTab: _settingsInitialTab,
    ),
  };

  Widget _summary(double width) {
    final active = _workshops.where((w) => w.isVisibleToClients).length;
    final suspended = _workshops.where((w) => w.status == 'Suspendido').length;
    final openIssues = _issues.where((i) => !i.resolved).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Resumen general',
          _usingCloudData
              ? 'Datos sincronizados con la plataforma en la nube.'
              : 'Datos reales disponibles en este dispositivo. Conecta la cuenta propietaria para administrar toda la plataforma.',
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: _loadingCloudData ? null : _loadCloudData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        if (_loadingCloudData) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(
              'Talleres activos',
              '$active',
              Icons.storefront_outlined,
              _success,
            ),
            _metric(
              'Suspendidos',
              '$suspended',
              Icons.pause_circle_outline,
              _danger,
            ),
            _metric(
              'Usuarios',
              '${_accounts.length}',
              Icons.group_outlined,
              Colors.lightBlueAccent,
            ),
            _metric(
              'Incidencias abiertas',
              '$openIssues',
              Icons.warning_amber_rounded,
              _warning,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CardPanel(
          title: 'Acciones rápidas',
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _section = _Section.settings;
                  _settingsInitialTab = 0;
                }),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _section = _Section.settings;
                  _settingsInitialTab = 1;
                }),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Usuario y contraseña'),
              ),
              OutlinedButton.icon(
                onPressed: _showAccessPolicy,
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('Pruebas y pagos'),
              ),
              Badge.count(
                count: _attentionWorkshops.length,
                isLabelVisible: _attentionWorkshops.isNotEmpty,
                backgroundColor: _warning,
                textColor: Colors.black,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _filter = 'Nuevos / Prueba';
                    _section = _Section.workshops;
                  }),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Revisar nuevos'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportAudit,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Exportar auditoría'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (width >= 1000)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _workshopPanel()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _issuePanel()),
            ],
          )
        else ...[
          _workshopPanel(),
          const SizedBox(height: 16),
          _issuePanel(),
        ],
        const SizedBox(height: 16),
        const _CardPanel(
          title: 'Estado del sistema',
          child: Wrap(
            spacing: 22,
            runSpacing: 14,
            children: [
              _Service('Autenticación', Icons.shield_outlined),
              _Service('Base de datos', Icons.storage_outlined),
              _Service('Mensajería', Icons.send_outlined),
              _Service('Documentos', Icons.description_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _salesPage() => FutureBuilder<List<Object>>(
    future: Future.wait<Object>([
      CommerceStore().listOrders(),
      CommerceStore().commissionPercent,
    ]),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Center(child: CircularProgressIndicator(color: _accent));
      }
      final orders = snapshot.data![0] as List<CommerceOrder>;
      final commission = snapshot.data![1] as double;
      final paid = orders.where((item) => item.paid).toList();
      final gross = paid.fold<int>(0, (sum, item) => sum + item.subtotalCents);
      final fees = paid.fold<int>(
        0,
        (sum, item) => sum + item.platformFeeCents,
      );
      final activeWorkshops = paid
          .map((item) => item.workshopId)
          .toSet()
          .length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ventas y comisiones',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Conciliación general de las compras de repuestos.',
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _configureCommission,
                icon: const Icon(Icons.percent_rounded),
                label: Text('Comisión ${commission.toStringAsFixed(1)}%'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _salesMetric(
                'Ventas brutas',
                commerceMoney(gross),
                Icons.point_of_sale_outlined,
              ),
              _salesMetric(
                'Tu comisión',
                commerceMoney(fees),
                Icons.account_balance_wallet_outlined,
              ),
              _salesMetric(
                'Pedidos pagados',
                '${paid.length}',
                Icons.shopping_bag_outlined,
              ),
              _salesMetric(
                'Talleres vendiendo',
                '$activeWorkshops',
                Icons.storefront_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panelHigh,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Movimientos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Aún no hay ventas registradas.',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  )
                else
                  for (final order in orders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _accent.withValues(alpha: .14),
                        foregroundColor: _accent,
                        child: const Icon(Icons.receipt_long_outlined),
                      ),
                      title: Text(
                        order.productName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${order.workshopName} · ${order.clientName} · ${commerceStatusLabel(order.status)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            commerceMoney(order.subtotalCents),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Comisión ${commerceMoney(order.platformFeeCents)}',
                            style: TextStyle(color: _accent, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _salesMetric(String label, String value, IconData icon) => Container(
    width: 205,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _panelHigh,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, color: _accent),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _configureCommission() async {
    final store = CommerceStore();
    final current = await store.commissionPercent;
    final controller = TextEditingController(text: current.toStringAsFixed(1));
    if (!mounted) return;
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comisión de la plataforma'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Porcentaje',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await store.setCommissionPercent(value);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _workshopsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Talleres de la plataforma',
        'Historial completo para revisar, activar, ampliar, suspender o eliminar talleres.',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Badge.count(
              count: _attentionWorkshops.length,
              isLabelVisible: _attentionWorkshops.isNotEmpty,
              backgroundColor: _warning,
              textColor: Colors.black,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _filter = 'Nuevos / Prueba'),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Nuevos y en prueba'),
              ),
            ),
            FilledButton.icon(
              onPressed: _showAccessPolicy,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Administrar accesos'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _WorkshopCommandSummary(
        total: _workshops.where((item) => !item.isDeleted).length,
        attention: _attentionWorkshops.length,
        active: _workshops
            .where(
              (item) =>
                  item.status == 'Activo' &&
                  item.plan == 'Acceso permanente' &&
                  !item.isDeleted,
            )
            .length,
        suspended: _workshops
            .where((item) => item.status == 'Suspendido')
            .length,
        deleted: _workshops.where((item) => item.isDeleted).length,
      ),
      const SizedBox(height: 14),
      _CardPanel(
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o ubicación',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.manage_search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _workshopFilters
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: _filter == value,
                        showCheckmark: false,
                        avatar: Icon(
                          _filterIcon(value),
                          size: 17,
                          color: _filter == value ? Colors.black : _muted,
                        ),
                        selectedColor: _accent,
                        backgroundColor: _panelHigh,
                        side: BorderSide(
                          color: _filter == value ? _accent : _border,
                        ),
                        labelStyle: TextStyle(
                          color: _filter == value ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _filter = value),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            _workshopRows(_filtered),
          ],
        ),
      ),
    ],
  );

  List<_Workshop> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _workshops.where((w) {
      final matchText =
          q.isEmpty ||
          w.name.toLowerCase().contains(q) ||
          w.location.toLowerCase().contains(q);
      final matchFilter = switch (_filter) {
        'Todos' => !w.isDeleted,
        'Nuevos / Prueba' => w.needsAttention,
        'Activos permanentes' =>
          !w.isDeleted && w.status == 'Activo' && w.plan == 'Acceso permanente',
        'Suspendidos' => !w.isDeleted && w.status == 'Suspendido',
        _ => !w.isDeleted,
      };
      return matchText && matchFilter;
    }).toList();
  }

  List<_Workshop> get _attentionWorkshops =>
      _workshops.where((item) => item.needsAttention).toList();

  IconData _filterIcon(String value) => switch (value) {
    'Nuevos / Prueba' => Icons.fiber_new_rounded,
    'Activos permanentes' => Icons.verified_outlined,
    'Suspendidos' => Icons.pause_circle_outline_rounded,
    _ => Icons.apps_rounded,
  };

  Widget _trashPage() {
    final deleted = _workshops.where((item) => item.isDeleted).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Papelera de talleres',
          'Aquí permanecen los talleres eliminados hasta que decidas restaurarlos.',
          OutlinedButton.icon(
            onPressed: () => setState(() => _section = _Section.workshops),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Volver a talleres'),
          ),
        ),
        const SizedBox(height: 20),
        _CardPanel(
          title:
              '${deleted.length} ${deleted.length == 1 ? 'taller eliminado' : 'talleres eliminados'}',
          child: deleted.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 34),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          size: 36,
                          color: _muted,
                        ),
                        SizedBox(height: 10),
                        Text('La papelera está vacía.'),
                      ],
                    ),
                  ),
                )
              : _workshopRows(deleted),
        ),
      ],
    );
  }

  Widget _workshopPanel() => _CardPanel(
    title: 'Talleres de la plataforma',
    trailing: TextButton(
      onPressed: () => setState(() => _section = _Section.workshops),
      child: const Text('Ver todos'),
    ),
    child: _workshopRows(_workshops.where((item) => !item.isDeleted).toList()),
  );

  Widget _workshopRows(List<_Workshop> list) => list.isEmpty
      ? const Padding(
          padding: EdgeInsets.all(30),
          child: Text('No hay resultados.'),
        )
      : Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              _WorkshopRow(
                workshop: list[i],
                onAction: () => _openWorkshopActions(list[i]),
              ),
              if (i < list.length - 1) const Divider(height: 1, color: _border),
            ],
          ],
        );

  Widget _issuePanel() => _CardPanel(
    title: 'Incidencias prioritarias',
    trailing: TextButton(
      onPressed: () => setState(() => _section = _Section.incidents),
      child: const Text('Ver todas'),
    ),
    child: _issues.where((i) => !i.resolved).isEmpty
        ? const Padding(
            padding: EdgeInsets.all(22),
            child: Text('No hay incidencias registradas.'),
          )
        : Column(
            children: [
              for (final issue in _issues.where((i) => !i.resolved))
                _IssueRow(issue: issue, onTap: () => _toggleIssue(issue)),
            ],
          ),
  );

  Widget _incidentsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Centro de incidencias',
        'Da seguimiento a problemas técnicos y solicitudes de administradores.',
        OutlinedButton.icon(
          onPressed: _runDiagnostic,
          icon: const Icon(Icons.monitor_heart_outlined),
          label: const Text('Ejecutar diagnóstico'),
        ),
      ),
      const SizedBox(height: 20),
      _CardPanel(
        child: Column(
          children: [
            for (final issue in _issues)
              _IssueRow(issue: issue, onTap: () => _toggleIssue(issue)),
          ],
        ),
      ),
    ],
  );

  Widget _usersPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Usuarios y permisos',
        'Supervisa administradores, colaboradores y clientes.',
        null,
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric(
            'Administradores',
            '${_accounts.where((item) => item.role == 'Administrador').length}',
            Icons.admin_panel_settings_outlined,
            _accent,
          ),
          _metric(
            'Colaboradores',
            '${_accounts.where((item) => item.role != 'Administrador' && item.role != 'Cliente').length}',
            Icons.engineering_outlined,
            _warning,
          ),
          _metric(
            'Clientes',
            '${_accounts.where((item) => item.role == 'Cliente').length}',
            Icons.person_outline,
            Colors.lightBlueAccent,
          ),
        ],
      ),
      const SizedBox(height: 18),
      _CardPanel(
        title: 'Actividad de cuentas',
        child: _accounts.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay cuentas visibles. Inicia una sesión propietaria verificada para consultar los usuarios registrados.',
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < _accounts.length; i++) ...[
                    _InfoRow(
                      _accounts[i].role == 'Administrador'
                          ? Icons.verified_user_outlined
                          : _accounts[i].role == 'Técnico'
                          ? Icons.engineering_outlined
                          : Icons.person_outline,
                      '${_accounts[i].name} · ${_accounts[i].role}',
                      '${_accounts[i].detail} · ${_accounts[i].active ? 'Activo' : 'Restringido'}',
                      action: IconButton(
                        tooltip: 'Administrar cuenta',
                        onPressed: () => _manageAccount(_accounts[i]),
                        icon: const Icon(Icons.manage_accounts_outlined),
                      ),
                    ),
                    if (i < _accounts.length - 1)
                      const Divider(height: 1, color: _border),
                  ],
                ],
              ),
      ),
    ],
  );

  Widget _auditPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Auditoría de la plataforma',
        'Cada acción sensible queda registrada con fecha, usuario y detalle.',
        OutlinedButton.icon(
          onPressed: _exportAudit,
          icon: const Icon(Icons.download),
          label: const Text('Exportar'),
        ),
      ),
      const SizedBox(height: 20),
      const _CardPanel(
        child: Column(
          children: [
            _AuditRow(
              'Hoy, 10:24',
              'Propietario',
              'Inicio de sesión seguro',
              'Cuenta propietaria',
            ),
            Divider(height: 1, color: _border),
            _AuditRow(
              'Hoy, 09:17',
              'Soporte',
              'Incidencia creada',
              'Speed Garage',
            ),
            Divider(height: 1, color: _border),
            _AuditRow(
              'Ayer, 18:32',
              'Propietario',
              'Taller reactivado',
              'Moto Elite',
            ),
            Divider(height: 1, color: _border),
            _AuditRow(
              'Ayer, 16:11',
              'Sistema',
              'Documento enviado',
              'Factura PDF',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _heading(String title, String subtitle, Widget? action) =>
      LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 620;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 23 : 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted)),
            ],
          );
          return box.maxWidth >= 620
              ? Row(
                  children: [
                    Expanded(child: text),
                    ?action,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text,
                    if (action != null) ...[const SizedBox(height: 14), action],
                  ],
                );
        },
      );

  Widget _metric(String label, String value, IconData icon, Color color) =>
      SizedBox(
        width: 245,
        child: _CardPanel(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: _muted)),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _showNotifications() async {
    setState(() => _notificationsRead = true);
    final pending = _issues.where((issue) => !issue.resolved).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newToday = _workshops
        .where(
          (workshop) =>
              !workshop.isDeleted &&
              workshop.createdAt != null &&
              !workshop.createdAt!.isBefore(today),
        )
        .toList();
    final trials =
        _workshops
            .where(
              (workshop) =>
                  !workshop.isDeleted &&
                  workshop.status == 'Prueba' &&
                  workshop.trialEndsAt != null,
            )
            .toList()
          ..sort((a, b) => a.trialEndsAt!.compareTo(b.trialEndsAt!));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _panelHigh,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notificaciones',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (newToday.isNotEmpty) ...[
                Text(
                  'Talleres creados hoy (${newToday.length})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                for (final workshop in newToday)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.storefront_outlined,
                      color: _success,
                    ),
                    title: Text(workshop.name),
                    subtitle: Text(
                      '${workshop.location.isEmpty ? 'Ubicación pendiente' : workshop.location} · nuevo registro',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() => _section = _Section.workshops);
                    },
                  ),
                const Divider(),
              ],
              if (trials.isNotEmpty) ...[
                Text(
                  'Talleres en prueba (${trials.length})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                for (final workshop in trials)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.hourglass_bottom_rounded,
                      color:
                          workshop.trialEndsAt!.isBefore(
                            now.add(const Duration(days: 2)),
                          )
                          ? _danger
                          : _warning,
                    ),
                    title: Text(workshop.name),
                    subtitle: Text(
                      'Prueba vence ${_trialTimeRemaining(workshop.trialEndsAt!, now)}',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() => _section = _Section.workshops);
                    },
                  ),
                const Divider(),
              ],
              if (pending.isEmpty && newToday.isEmpty && trials.isEmpty)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle_outline, color: _success),
                  title: Text('Todo está al día'),
                  subtitle: Text('No existen incidencias pendientes.'),
                )
              else
                for (final issue in pending)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: issue.priority == 'Alta' ? _danger : _warning,
                    ),
                    title: Text(issue.title),
                    subtitle: Text('${issue.workshop} · ${issue.time}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() => _section = _Section.incidents);
                    },
                  ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Marcar como revisadas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _trialTimeRemaining(DateTime endsAt, DateTime now) {
    final remaining = endsAt.difference(now);
    if (remaining.isNegative) return 'hoy; requiere decisión';
    final days = remaining.inDays;
    if (days >= 1) {
      return 'en $days día${days == 1 ? '' : 's'}';
    }
    return 'en ${remaining.inHours.clamp(1, 24)} horas';
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Tus datos guardados permanecerán protegidos en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.tenantContext.clear();
    widget.brandController.value = WorkshopBrand.defaultBrand;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => RoleAccessScreen(
          tenantContext: widget.tenantContext,
          brandController: widget.brandController,
          authController: widget.authController,
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _openWorkshopActions(_Workshop workshop) async {
    final statusColor = workshop.isDeleted
        ? _muted
        : workshop.status == 'Activo'
        ? _success
        : workshop.status == 'Suspendido'
        ? _danger
        : _warning;
    final trialEnd = workshop.trialEndsAt;
    final trialRemaining = trialEnd?.difference(DateTime.now());
    final trialText = trialEnd == null
        ? 'Sin fecha de prueba registrada'
        : trialRemaining != null && trialRemaining.isNegative
        ? 'Venció ${_formatDateTime(trialEnd)}'
        : 'Vence ${_formatDateTime(trialEnd)}';
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _panelHigh,
      constraints: const BoxConstraints(maxWidth: 580),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .86,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _accent.withValues(alpha: .12),
                      child: Text(
                        workshop.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workshop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            workshop.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        workshop.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bg.withValues(alpha: .55),
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _CompactInfo(
                        icon: Icons.calendar_today_outlined,
                        label: 'Creado',
                        value: workshop.createdAt == null
                            ? 'Fecha no disponible'
                            : _formatDateTime(workshop.createdAt!),
                      ),
                      const SizedBox(height: 9),
                      _CompactInfo(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Plan',
                        value: workshop.plan,
                      ),
                      if (workshop.plan != 'Acceso permanente') ...[
                        const SizedBox(height: 9),
                        _CompactInfo(
                          icon: Icons.schedule_outlined,
                          label: 'Prueba',
                          value: trialText,
                          valueColor: trialRemaining?.isNegative == true
                              ? _danger
                              : _warning,
                        ),
                      ],
                      const SizedBox(height: 9),
                      _CompactInfo(
                        icon: Icons.history_rounded,
                        label: 'Actividad',
                        value: workshop.activity,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  workshop.isDeleted
                      ? 'Acciones disponibles'
                      : 'Administrar acceso',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, box) {
                    final buttonWidth = box.maxWidth >= 440
                        ? (box.maxWidth - 10) / 2
                        : box.maxWidth;
                    Widget actionButton({
                      required String label,
                      required IconData icon,
                      required String action,
                      required Color color,
                    }) => SizedBox(
                      width: buttonWidth,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, action),
                        icon: Icon(icon, color: color, size: 19),
                        label: Text(label),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 13,
                          ),
                          side: BorderSide(color: color.withValues(alpha: .55)),
                        ),
                      ),
                    );
                    return Wrap(
                      spacing: 10,
                      runSpacing: 9,
                      children: workshop.isDeleted
                          ? [
                              actionButton(
                                label: 'Restaurar taller',
                                icon: Icons.restore_from_trash_outlined,
                                action: 'restore',
                                color: _success,
                              ),
                              actionButton(
                                label: 'Ver información',
                                icon: Icons.info_outline,
                                action: 'details',
                                color: _muted,
                              ),
                              actionButton(
                                label: 'Eliminar definitivamente',
                                icon: Icons.delete_forever_rounded,
                                action: 'purge',
                                color: _danger,
                              ),
                            ]
                          : [
                              if (workshop.status != 'Activo' ||
                                  workshop.plan != 'Acceso permanente')
                                actionButton(
                                  label: 'Activar permanente',
                                  icon: Icons.verified_outlined,
                                  action: 'permanent',
                                  color: _success,
                                ),
                              if (workshop.plan != 'Acceso permanente') ...[
                                actionButton(
                                  label: 'Agregar 24 horas',
                                  icon: Icons.add_alarm_outlined,
                                  action: 'extend_1',
                                  color: _warning,
                                ),
                                actionButton(
                                  label: 'Elegir más días',
                                  icon: Icons.more_time_rounded,
                                  action: 'extend',
                                  color: _warning,
                                ),
                              ],
                              if (workshop.hasPendingExtension)
                                actionButton(
                                  label: 'Revisar solicitud',
                                  icon: Icons.mark_email_unread_outlined,
                                  action: 'review_extension',
                                  color: _warning,
                                ),
                              actionButton(
                                label: workshop.status == 'Suspendido'
                                    ? 'Reactivar taller'
                                    : 'Suspender taller',
                                icon: workshop.status == 'Suspendido'
                                    ? Icons.play_circle_outline
                                    : Icons.pause_circle_outline,
                                action: 'status',
                                color: workshop.status == 'Suspendido'
                                    ? _success
                                    : _danger,
                              ),
                              actionButton(
                                label: 'Eliminar taller',
                                icon: Icons.delete_outline_rounded,
                                action: 'delete',
                                color: _danger,
                              ),
                              actionButton(
                                label: 'Más información',
                                icon: Icons.info_outline_rounded,
                                action: 'details',
                                color: _muted,
                              ),
                            ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'details':
        await _showWorkshopDetails(workshop);
      case 'support':
        await _createSupportIssue(workshop);
      case 'review_extension':
        await _reviewTrialExtension(workshop);
      case 'permanent':
        await _activatePermanentAccess(workshop);
      case 'extend':
        await _extendWorkshopTrial(workshop);
      case 'extend_1':
        await _extendWorkshopTrialQuick(workshop, 1);
      case 'status':
        await _controlWorkshop(workshop);
      case 'delete':
        await _deleteWorkshop(workshop);
      case 'restore':
        await _restoreWorkshop(workshop);
      case 'purge':
        await _purgeWorkshop(workshop);
    }
  }

  Future<void> _showWorkshopDetails(_Workshop workshop) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(workshop.name),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(
                Icons.location_on_outlined,
                'Ubicación',
                workshop.location,
              ),
              const Divider(color: _border),
              _InfoRow(Icons.workspace_premium_outlined, 'Plan', workshop.plan),
              const Divider(color: _border),
              _InfoRow(Icons.circle_outlined, 'Estado', workshop.status),
              if (workshop.trialEndsAt != null) ...[
                const Divider(color: _border),
                _InfoRow(
                  Icons.schedule_outlined,
                  'Fin de la prueba',
                  _formatDateTime(workshop.trialEndsAt!),
                ),
              ],
              if (workshop.deletedAt != null) ...[
                const Divider(color: _border),
                _InfoRow(
                  Icons.delete_outline,
                  'En papelera desde',
                  _formatDateTime(workshop.deletedAt!),
                ),
              ],
              if (workshop.purgeAfter != null) ...[
                const Divider(color: _border),
                _InfoRow(
                  Icons.event_busy_outlined,
                  'Recuperable hasta',
                  _formatDateTime(workshop.purgeAfter!),
                ),
              ],
              const Divider(color: _border),
              _InfoRow(
                Icons.schedule_outlined,
                'Última actividad',
                workshop.activity,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSupportIssue(_Workshop workshop) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva solicitud de soporte'),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Describe el problema',
              hintText: 'Indica qué necesita revisar el equipo de soporte.',
              prefixIcon: const Icon(Icons.edit_note_outlined),
              helperText: workshop.name,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (controller.text.trim().length < 8) {
                _toast('Describe el problema con un poco más de detalle.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Crear incidencia'),
          ),
        ],
      ),
    );
    final description = controller.text.trim();
    controller.dispose();
    if (created != true || !mounted) return;
    setState(() {
      _issues.insert(0, _Issue(description, workshop.name, 'Media', 'Ahora'));
      _section = _Section.incidents;
      _notificationsRead = false;
    });
    _toast('Solicitud de soporte registrada.');
  }

  Future<void> _runDiagnostic() async {
    final checkedAt = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.monitor_heart_outlined, color: _success),
        title: const Text('Diagnóstico completado'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Service('Interfaz y navegación', Icons.web_outlined),
              const SizedBox(height: 12),
              const _Service('Preferencias locales', Icons.settings_outlined),
              const SizedBox(height: 12),
              _Service(
                _ownerService.hasCloudSession
                    ? 'Conexión con la nube'
                    : 'Modo local de demostración',
                Icons.cloud_outlined,
              ),
              const SizedBox(height: 16),
              Text(
                'Comprobado: ${_formatDateTime(checkedAt)}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageAccount(_PlatformAccount account) async {
    final change = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(account.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(Icons.badge_outlined, 'Rol', account.role),
              const Divider(color: _border),
              _InfoRow(Icons.history_outlined, 'Actividad', account.detail),
              const SizedBox(height: 12),
              Text(
                account.active
                    ? 'La cuenta puede ingresar normalmente.'
                    : 'La cuenta tiene el acceso restringido.',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            style: account.active
                ? FilledButton.styleFrom(backgroundColor: _danger)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: Icon(account.active ? Icons.block : Icons.lock_open),
            label: Text(account.active ? 'Restringir acceso' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (change != true || !mounted) return;
    setState(() => account.active = !account.active);
    _toast(account.active ? 'Cuenta reactivada.' : 'Acceso restringido.');
  }

  Future<void> _exportAudit() async {
    const rows = [
      ['Fecha', 'Usuario', 'Acción', 'Detalle'],
      [
        'Hoy 10:24',
        'Propietario',
        'Inicio de sesión seguro',
        'Cuenta propietaria',
      ],
      ['Hoy 09:17', 'Soporte', 'Incidencia creada', 'Speed Garage'],
      ['Ayer 18:32', 'Propietario', 'Taller reactivado', 'Moto Elite'],
      ['Ayer 16:11', 'Sistema', 'Documento enviado', 'Factura PDF'],
    ];
    final csv = rows
        .map(
          (row) =>
              row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
        )
        .join('\r\n');
    try {
      await FileSaver.instance.saveFile(
        name: 'auditoria-${_fileDate(DateTime.now())}',
        bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      _toast('Auditoría exportada correctamente.');
    } catch (_) {
      _toast('No fue posible exportar la auditoría.');
    }
  }

  Future<void> _controlWorkshop(_Workshop workshop) async {
    final suspend = workshop.status != 'Suspendido';
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          suspend ? 'Suspender ${workshop.name}' : 'Reactivar ${workshop.name}',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suspend
                    ? 'Se impedirán nuevos accesos, pero toda la información permanecerá protegida.'
                    : 'El administrador y su equipo recuperarán el acceso inmediatamente.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reason,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: suspend
                      ? 'Motivo de la suspensión'
                      : 'Observaciones',
                  hintText: 'La acción quedará registrada en auditoría.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: suspend
                ? FilledButton.styleFrom(backgroundColor: _danger)
                : null,
            onPressed: () {
              if (suspend && reason.text.trim().isEmpty) {
                _toast('Escribe el motivo de la suspensión.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            icon: Icon(suspend ? Icons.block : Icons.play_arrow),
            label: Text(suspend ? 'Confirmar suspensión' : 'Reactivar taller'),
          ),
        ],
      ),
    );
    final changeReason = reason.text.trim();
    reason.dispose();
    if (confirmed != true) return;
    if (_usingCloudData && !workshop.isLocalRecord && workshop.id != null) {
      try {
        await _ownerService.setWorkshopAvailability(
          workshopId: workshop.id!,
          enabled: !suspend,
          reason: changeReason.isEmpty
              ? 'Reactivación autorizada'
              : changeReason,
        );
      } catch (error) {
        _toast('No fue posible actualizar el taller en la nube.');
        return;
      }
    }
    if (workshop.id != null) {
      await _mirrorWorkshopAvailability(workshop.id!, enabled: !suspend);
      if (mounted) {
        setState(() {
          workshop.status = suspend ? 'Suspendido' : 'Activo';
          if (!suspend) workshop.plan = 'Acceso permanente';
        });
      }
    }
    await _loadCloudData(silent: true);
    if (!mounted) return;
    _toast(
      suspend
          ? '${workshop.name} fue desactivado sin eliminar su información.'
          : '${workshop.name} fue reactivado con toda su información.',
    );
  }

  Future<void> _activatePermanentAccess(_Workshop workshop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_outlined, color: _success),
        title: const Text('Confirmar acceso permanente'),
        content: Text(
          'Confirma que el pago único de ${workshop.name} fue recibido. '
          'El taller podrá usar la plataforma sin límite de tiempo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Activar definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (workshop.id == null) {
      _toast('No encontramos el identificador de este taller.');
      return;
    }
    if (_usingCloudData && !workshop.isLocalRecord) {
      try {
        await _ownerService.setWorkshopAccess(
          workshopId: workshop.id!,
          accessStatus: 'active',
          reason: 'Pago único confirmado por el propietario',
        );
      } catch (_) {
        _toast('No fue posible activar el acceso en la nube.');
        return;
      }
    }
    await _mirrorWorkshopAvailability(workshop.id!, enabled: true);
    if (mounted) {
      setState(() {
        workshop.status = 'Activo';
        workshop.plan = 'Acceso permanente';
      });
    }
    await _loadCloudData(silent: true);
    if (!mounted) return;
    _toast('${workshop.name} tiene acceso permanente.');
  }

  Future<void> _mirrorWorkshopAvailability(
    String workshopId, {
    required bool enabled,
  }) async {
    await _localAdminStore.setWorkshopAvailability(
      tenantId: workshopId,
      enabled: enabled,
    );
    await LocalWorkshopDirectoryStore().setAccessStatus(
      workshopId,
      enabled ? 'active' : 'suspended',
    );
  }

  Future<void> _extendWorkshopTrial(_Workshop workshop) async {
    var selectedDays = 3;
    final reason = TextEditingController();
    final days = TextEditingController(text: '$selectedDays');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.more_time_rounded, color: _warning),
          title: Text('Ampliar prueba de ${workshop.name}'),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Los días se sumarán desde la fecha de vencimiento actual. '
                  'Si la prueba ya venció, se contarán desde hoy.',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [1, 3, 7, 14, 30]
                      .map(
                        (value) => ChoiceChip(
                          label: Text(value == 1 ? '24 horas' : '$value días'),
                          selected: selectedDays == value,
                          onSelected: (_) => setDialogState(() {
                            selectedDays = value;
                            days.text = '$value';
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: days,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cantidad manual de días',
                    helperText: 'Entre 1 y 90 días',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  onChanged: (value) => setDialogState(() {
                    selectedDays = int.tryParse(value) ?? 0;
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la ampliación',
                    hintText:
                        'Ejemplo: necesitó más tiempo para probar facturación',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                ),
                if (workshop.trialEndsAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Vencimiento actual: ${_formatDateTime(workshop.trialEndsAt!)}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (selectedDays < 1 || selectedDays > 90) {
                  _toast('Elige entre 1 y 90 días.');
                  return;
                }
                if (reason.text.trim().length < 5) {
                  _toast('Escribe el motivo de la ampliación.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.add_rounded),
              label: Text('Agregar $selectedDays días'),
            ),
          ],
        ),
      ),
    );
    final changeReason = reason.text.trim();
    reason.dispose();
    days.dispose();
    if (confirmed != true || !mounted) return;
    await _applyTrialExtension(
      workshop,
      additionalDays: selectedDays,
      reason: changeReason,
    );
  }

  Future<void> _extendWorkshopTrialQuick(_Workshop workshop, int days) =>
      _applyTrialExtension(
        workshop,
        additionalDays: days,
        reason: 'Ampliación manual de 24 horas desde el centro de control',
      );

  Future<void> _applyTrialExtension(
    _Workshop workshop, {
    required int additionalDays,
    required String reason,
  }) async {
    if (workshop.id == null) {
      _toast('No encontramos el identificador de este taller.');
      return;
    }
    final currentEnd = workshop.trialEndsAt;
    final base = currentEnd != null && currentEnd.isAfter(DateTime.now())
        ? currentEnd
        : DateTime.now();
    var newEnd = base.add(Duration(days: additionalDays));
    if (_usingCloudData && !workshop.isLocalRecord) {
      try {
        newEnd = await _ownerService.extendWorkshopTrial(
          workshopId: workshop.id!,
          additionalDays: additionalDays,
          reason: reason,
        );
      } catch (_) {
        _toast('No fue posible ampliar la prueba en la nube.');
        return;
      }
    } else {
      final storedEnd = await _localAdminStore.extendWorkshopTrial(
        tenantId: workshop.id!,
        additionalDays: additionalDays,
      );
      if (storedEnd == null) {
        _toast('No fue posible guardar la ampliación de la prueba.');
        return;
      }
      newEnd = storedEnd;
      await LocalWorkshopDirectoryStore().setAccessStatus(
        workshop.id!,
        WorkshopAccessState.trial.name,
      );
    }
    if (!mounted) return;
    setState(() {
      workshop.trialEndsAt = newEnd;
      workshop.status = 'Prueba';
      workshop.plan = 'Prueba gratuita';
    });
    _toast('Prueba ampliada hasta ${_formatDateTime(newEnd)}.');
  }

  Future<void> _reviewTrialExtension(_Workshop workshop) async {
    var grantedDays = workshop.requestedDays ?? 1;
    final decisionReason = TextEditingController();
    final decision = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.mark_email_unread_outlined, color: _warning),
          title: Text('Solicitud de ${workshop.name}'),
          content: SizedBox(
            width: 490,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  Icons.calendar_month_outlined,
                  'Tiempo solicitado',
                  '${workshop.requestedDays ?? 1} día(s)',
                ),
                const Divider(color: _border),
                _InfoRow(
                  Icons.chat_bubble_outline,
                  'Motivo del administrador',
                  workshop.requestReason ?? 'Sin detalle',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: [1, 3, 7, 14, 30].contains(grantedDays)
                      ? grantedDays
                      : 1,
                  decoration: const InputDecoration(
                    labelText: 'Tiempo que deseas aprobar',
                    prefixIcon: Icon(Icons.more_time_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 día')),
                    DropdownMenuItem(value: 3, child: Text('3 días')),
                    DropdownMenuItem(value: 7, child: Text('7 días')),
                    DropdownMenuItem(value: 14, child: Text('14 días')),
                    DropdownMenuItem(value: 30, child: Text('30 días')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => grantedDays = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: decisionReason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de tu decisión',
                    hintText: 'Este comentario quedará en auditoría',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Decidir después'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _danger),
              onPressed: () {
                if (decisionReason.text.trim().length < 5) {
                  _toast('Escribe el motivo de la decisión.');
                  return;
                }
                Navigator.pop(dialogContext, false);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Rechazar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (decisionReason.text.trim().length < 5) {
                  _toast('Escribe el motivo de la decisión.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aprobar tiempo'),
            ),
          ],
        ),
      ),
    );
    final reason = decisionReason.text.trim();
    decisionReason.dispose();
    if (decision == null || !mounted) return;

    DateTime? newEnd;
    String? error;
    if (_usingCloudData &&
        !workshop.isLocalRecord &&
        workshop.extensionRequestId != null) {
      try {
        newEnd = await _ownerService.decideTrialExtension(
          requestId: workshop.extensionRequestId!,
          approve: decision,
          grantedDays: grantedDays,
          reason: reason,
        );
      } catch (_) {
        error = 'No fue posible guardar la decisión en la nube.';
      }
    } else if (workshop.requestAccountEmail != null) {
      error = await _localAdminStore.decideTrialExtension(
        accountEmail: workshop.requestAccountEmail!,
        approve: decision,
        grantedDays: grantedDays,
        decisionReason: reason,
      );
      if (decision && error == null) {
        final now = DateTime.now();
        final base =
            workshop.trialEndsAt != null && workshop.trialEndsAt!.isAfter(now)
            ? workshop.trialEndsAt!
            : now;
        newEnd = base.add(Duration(days: grantedDays));
      }
    }
    if (!mounted) return;
    if (error != null) {
      _toast(error);
      return;
    }
    setState(() {
      workshop.extensionRequestId = null;
      workshop.requestAccountEmail = null;
      workshop.requestedDays = null;
      workshop.requestReason = null;
      if (decision) {
        workshop.status = 'Prueba';
        workshop.plan = 'Prueba gratuita';
        workshop.trialEndsAt = newEnd;
      }
    });
    _toast(
      decision
          ? 'Tiempo adicional aprobado. Los datos del taller siguen intactos.'
          : 'Solicitud rechazada. Los datos del taller permanecen guardados.',
    );
  }

  Future<void> _deleteWorkshop(_Workshop workshop) async {
    final confirmation = TextEditingController();
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matches =
              confirmation.text.trim().toLowerCase() ==
              workshop.name.trim().toLowerCase();
          return AlertDialog(
            icon: const Icon(Icons.delete_forever_outlined, color: _danger),
            title: const Text('Mover taller a la papelera'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${workshop.name} quedará bloqueado. Sus integrantes, '
                    'productos, citas, órdenes, conversaciones y personalización '
                    'se conservarán para recuperarlos durante al menos 30 días.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de eliminación',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmation,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Escribe “${workshop.name}” para confirmar',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Conservar taller'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _danger),
                onPressed: matches
                    ? () {
                        if (reason.text.trim().length < 8) {
                          _toast(
                            'Explica el motivo con al menos 8 caracteres.',
                          );
                          return;
                        }
                        Navigator.pop(dialogContext, true);
                      }
                    : null,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Mover a la papelera'),
              ),
            ],
          );
        },
      ),
    );
    final deletionReason = reason.text.trim();
    confirmation.dispose();
    reason.dispose();
    if (confirmed != true || !mounted) return;

    if (_usingCloudData && !workshop.isLocalRecord && workshop.id != null) {
      try {
        await _ownerService.deleteWorkshop(
          workshopId: workshop.id!,
          confirmationName: workshop.name,
          reason: deletionReason,
        );
      } catch (_) {
        _toast('No fue posible mover el taller a la papelera.');
        return;
      }
    }
    if (workshop.id != null) {
      final error = await _localAdminStore.moveWorkshopToTrash(
        tenantId: workshop.id!,
        reason: deletionReason,
      );
      if (error != null && !(_usingCloudData && !workshop.isLocalRecord)) {
        _toast(error);
        return;
      }
      await LocalWorkshopDirectoryStore().setAccessStatus(
        workshop.id!,
        'deleted',
      );
    }
    if (!mounted) return;
    setState(() {
      workshop.previousPlan = workshop.plan;
      workshop.previousStatus = workshop.status;
      workshop.status = 'Eliminado';
      workshop.plan = 'En papelera';
      workshop.deletedAt = DateTime.now();
      workshop.purgeAfter = DateTime.now().add(const Duration(days: 30));
    });
    // Reload from Supabase so the paperera shows the same persisted record
    // after a browser refresh or when opening the section on another device.
    await _loadCloudData(silent: true);
    if (!mounted) return;
    _toast('${workshop.name} está en la papelera y puede recuperarse.');
  }

  Future<void> _restoreWorkshop(_Workshop workshop) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore_from_trash_outlined, color: _success),
        title: Text('Recuperar ${workshop.name}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Se recuperarán el taller, clientes vinculados, equipo, '
                'productos, órdenes, conversaciones y personalización.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reason,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo de recuperación',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (reason.text.trim().length < 5) {
                _toast('Escribe el motivo de la recuperación.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Recuperar información'),
          ),
        ],
      ),
    );
    final restoreReason = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    if (_usingCloudData && !workshop.isLocalRecord && workshop.id != null) {
      try {
        await _ownerService.restoreWorkshop(
          workshopId: workshop.id!,
          reason: restoreReason,
        );
      } catch (_) {
        _toast('No fue posible recuperar el taller en la nube.');
        return;
      }
    }
    if (workshop.id != null) {
      final error = await _localAdminStore.restoreWorkshop(
        tenantId: workshop.id!,
      );
      if (error != null && !(_usingCloudData && !workshop.isLocalRecord)) {
        _toast(error);
        return;
      }
      final localAccounts = await _localAdminStore.listAccounts();
      await LocalWorkshopDirectoryStore().syncRegisteredAccounts(localAccounts);
    }
    if (!mounted) return;
    final trialActive =
        workshop.trialEndsAt != null &&
        workshop.trialEndsAt!.isAfter(DateTime.now());
    setState(() {
      workshop.deletedAt = null;
      workshop.purgeAfter = null;
      workshop.status =
          workshop.previousStatus ?? (trialActive ? 'Prueba' : 'Vencido');
      if (workshop.status == 'Prueba' && !trialActive) {
        workshop.status = 'Vencido';
      }
      workshop.plan =
          workshop.previousPlan ??
          (trialActive ? 'Prueba gratuita' : 'Acceso restringido');
      workshop.previousPlan = null;
      workshop.previousStatus = null;
    });
    _toast('La información de ${workshop.name} fue recuperada correctamente.');
  }

  Future<void> _purgeWorkshop(_Workshop workshop) async {
    if (!workshop.isDeleted || workshop.id == null) {
      _toast('Primero mueve el taller a la papelera.');
      return;
    }
    final confirmation = TextEditingController();
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matches =
              confirmation.text.trim().toLowerCase() ==
              workshop.name.trim().toLowerCase();
          return AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: _danger),
            title: const Text('Eliminar definitivamente'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta acción no se puede deshacer. Se eliminarán el taller, '
                    'sus administradores, clientes vinculados, motos, citas, '
                    'órdenes, productos, inventario, mecánicos, conversaciones, '
                    'calificaciones y personalización.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de eliminación definitiva',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmation,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Escribe “${workshop.name}” para confirmar',
                      prefixIcon: const Icon(Icons.security_rounded),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _danger),
                onPressed: matches
                    ? () {
                        if (reason.text.trim().length < 8) {
                          _toast(
                            'Explica el motivo con al menos 8 caracteres.',
                          );
                          return;
                        }
                        Navigator.pop(dialogContext, true);
                      }
                    : null,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Eliminar para siempre'),
              ),
            ],
          );
        },
      ),
    );
    final purgeReason = reason.text.trim();
    confirmation.dispose();
    reason.dispose();
    if (confirmed != true || !mounted) return;

    if (_usingCloudData && !workshop.isLocalRecord) {
      try {
        await _ownerService.purgeWorkshop(
          workshopId: workshop.id!,
          confirmationName: workshop.name,
          reason: purgeReason,
        );
      } catch (_) {
        _toast('No fue posible eliminar definitivamente el taller en la nube.');
        return;
      }
    }
    final error = await WorkshopDataPurgeService().purge(workshop.id!);
    if (error != null) {
      _toast(error);
      return;
    }
    if (!mounted) return;
    setState(() => _workshops.removeWhere((item) => item.id == workshop.id));
    _toast('${workshop.name} fue eliminado definitivamente.');
  }

  void _toggleIssue(_Issue issue) {
    setState(() => issue.resolved = !issue.resolved);
    _toast(
      issue.resolved
          ? 'Incidencia marcada como resuelta.'
          : 'Incidencia reabierta.',
    );
  }

  Future<void> _showAccessPolicy() async {
    final editable = _workshops.where((item) => !item.isDeleted).toList();
    final selections = <_Workshop, bool>{
      for (final workshop in editable)
        workshop: workshop.status == 'Activo' || workshop.status == 'Prueba',
    };
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(Icons.admin_panel_settings_outlined, color: _accent),
          title: const Text('Administrar accesos'),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Los talleres activos pueden ingresar y aparecen a los clientes. '
                  'Al desactivar, toda su información permanece guardada.',
                  style: TextStyle(color: _muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => setDialogState(() {
                              for (final workshop in editable) {
                                selections[workshop] = true;
                              }
                            }),
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Activar todos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => setDialogState(() {
                              for (final workshop in editable) {
                                selections[workshop] = false;
                              }
                            }),
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Desactivar todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (editable.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Text('No hay talleres para administrar.'),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: editable.length,
                      separatorBuilder: (_, _) => const Divider(color: _border),
                      itemBuilder: (context, index) {
                        final workshop = editable[index];
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selections[workshop] ?? false,
                          onChanged: saving
                              ? null
                              : (value) => setDialogState(
                                  () => selections[workshop] = value,
                                ),
                          title: Text(
                            workshop.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            selections[workshop] == true
                                ? 'Acceso activo y visible para clientes'
                                : 'Acceso bloqueado; datos conservados',
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: saving || editable.isEmpty
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      final failures = await _saveWorkshopAccessChanges(
                        selections,
                      );
                      if (!dialogContext.mounted) return;
                      if (failures == 0) {
                        Navigator.pop(dialogContext);
                        _toast('Cambios de acceso guardados correctamente.');
                      } else {
                        setDialogState(() => saving = false);
                        _toast(
                          'No fue posible actualizar $failures taller(es).',
                        );
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _saveWorkshopAccessChanges(
    Map<_Workshop, bool> selections,
  ) async {
    var failures = 0;
    for (final entry in selections.entries) {
      final workshop = entry.key;
      final wasEnabled =
          workshop.status == 'Activo' || workshop.status == 'Prueba';
      if (entry.value == wasEnabled || workshop.id == null) continue;
      try {
        if (_usingCloudData && !workshop.isLocalRecord) {
          await _ownerService.setWorkshopAvailability(
            workshopId: workshop.id!,
            enabled: entry.value,
            reason: 'Cambio guardado desde administrar accesos',
          );
        } else {
          final state = await _localAdminStore.setWorkshopAvailability(
            tenantId: workshop.id!,
            enabled: entry.value,
          );
          if (state == null) throw StateError('Taller local no encontrado');
          await LocalWorkshopDirectoryStore().setAccessStatus(
            workshop.id!,
            state.name,
          );
        }
      } catch (_) {
        failures++;
      }
    }
    await _loadCloudData(silent: true);
    return failures;
  }

  @Deprecated(
    'El flujo de códigos fue retirado; se conserva temporalmente para migraciones antiguas.',
  )
  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _fileDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _AppearanceSettings extends StatefulWidget {
  const _AppearanceSettings({required this.authController});
  final AdminAuthController authController;

  @override
  State<_AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<_AppearanceSettings> {
  static const _colors = <int>[
    0xFFFF6500,
    0xFF00A6A6,
    0xFF2979FF,
    0xFFE83E8C,
    0xFF20B96B,
    0xFFFFB000,
  ];

  late int _colorValue;
  late double _textScale;
  late bool _backgroundEnabled;
  late double _backgroundOpacity;
  late bool _compactMode;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _colorValue = auth.ownerAccentColorValue;
    _textScale = auth.ownerTextScale;
    _backgroundEnabled = auth.ownerBackgroundEnabled;
    _backgroundOpacity = auth.ownerBackgroundOpacity.clamp(.2, 1.0);
    _compactMode = auth.ownerCompactMode;
  }

  @override
  Widget build(BuildContext context) {
    final selected = Color(_colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final title = const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalización',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Adapta la apariencia del centro de control a tu forma de trabajar.',
                  style: TextStyle(color: _muted),
                ),
              ],
            );
            final save = FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _saved ? Icons.check_circle_outline : Icons.save_outlined,
                    ),
              label: Text(_saved ? 'Cambios guardados' : 'Guardar cambios'),
            );
            return box.maxWidth >= 620
                ? Row(
                    children: [
                      Expanded(child: title),
                      save,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 14), save],
                  );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) {
            final controls = Column(
              children: [
                _CardPanel(
                  title: 'Color principal',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Se aplicará a botones, navegación, indicadores y acciones.',
                        style: TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final value in _colors)
                            Tooltip(
                              message: 'Usar este color',
                              child: InkWell(
                                onTap: () => _update(() => _colorValue = value),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Color(value),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _colorValue == value
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: _colorValue == value
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CardPanel(
                  title: 'Lectura y densidad',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_fields_rounded),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Tamaño del texto')),
                          Text(
                            '${(_textScale * 100).round()}%',
                            style: TextStyle(
                              color: selected,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _textScale,
                        min: .8,
                        max: 1.4,
                        divisions: 12,
                        label: '${(_textScale * 100).round()}%',
                        activeColor: selected,
                        onChanged: (value) => _update(() => _textScale = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _compactMode,
                        onChanged: (value) =>
                            _update(() => _compactMode = value),
                        title: const Text('Vista compacta'),
                        subtitle: const Text(
                          'Muestra más información en computadores.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CardPanel(
                  title: 'Fondo de motocicletas',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _backgroundEnabled,
                        onChanged: (value) =>
                            _update(() => _backgroundEnabled = value),
                        title: const Text('Mostrar imagen de fondo'),
                        subtitle: const Text(
                          'La capa oscura mantiene legible la información.',
                        ),
                      ),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Intensidad de la imagen'),
                          ),
                          Text(
                            '${(_backgroundOpacity * 100).round()}%',
                            style: TextStyle(
                              color: selected,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _backgroundOpacity,
                        min: .2,
                        max: 1,
                        divisions: 8,
                        activeColor: selected,
                        onChanged: _backgroundEnabled
                            ? (value) =>
                                  _update(() => _backgroundOpacity = value)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final preview = _CardPanel(
              title: 'Vista previa en tiempo real',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 430,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_backgroundEnabled)
                        Image.asset(
                          'assets/images/owner_tools_background_v1.png',
                          fit: BoxFit.cover,
                        ),
                      ColoredBox(
                        color: Color.fromRGBO(
                          7,
                          10,
                          13,
                          _backgroundEnabled
                              ? .68 - (_backgroundOpacity * .42)
                              : .96,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: selected.withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.dashboard_outlined,
                                    color: selected,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Centro de control',
                                  style: TextStyle(
                                    fontSize: 20 * _textScale,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Resumen de operaciones',
                              style: TextStyle(
                                fontSize: 18 * _textScale,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _PreviewMetric(
                                    color: selected,
                                    value: '28',
                                    label: 'Talleres activos',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: _PreviewMetric(
                                    color: _success,
                                    value: '7',
                                    label: 'Incidencias',
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: selected,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Guardar estilo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return box.maxWidth >= 950
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: controls),
                      const SizedBox(width: 16),
                      Expanded(child: preview),
                    ],
                  )
                : Column(
                    children: [controls, const SizedBox(height: 16), preview],
                  );
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await widget.authController.saveOwnerAppearance(
      accentColorValue: _colorValue,
      textScale: _textScale,
      backgroundEnabled: _backgroundEnabled,
      backgroundOpacity: _backgroundOpacity,
      compactMode: _compactMode,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = error == null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'Personalización aplicada correctamente.'),
        ),
      );
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _saved = false;
    });
    widget.authController.previewOwnerAppearance(
      accentColorValue: _colorValue,
      textScale: _textScale,
      backgroundEnabled: _backgroundEnabled,
      backgroundOpacity: _backgroundOpacity,
      compactMode: _compactMode,
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.color,
    required this.value,
    required this.label,
  });
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(color: _muted)),
      ],
    ),
  );
}

class _OwnerSettings extends StatefulWidget {
  const _OwnerSettings({
    super.key,
    required this.authController,
    this.documentsOnly = false,
    this.initialTab = 0,
  });
  final AdminAuthController authController;
  final bool documentsOnly;
  final int initialTab;

  @override
  State<_OwnerSettings> createState() => _OwnerSettingsState();
}

class _OwnerSettingsState extends State<_OwnerSettings> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _document;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _title;
  late final TextEditingController _contact;
  late final TextEditingController _newUsername;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  Uint8List? _avatar;
  bool _credit = true;
  bool _twoFactor = true;
  late Set<String> _formats;
  bool _saving = false;
  late int _settingsTab;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _settingsTab = widget.initialTab.clamp(0, 2);
    _name = TextEditingController(text: auth.fullName);
    _document = TextEditingController(text: auth.document);
    _email = TextEditingController(text: auth.email);
    _phone = TextEditingController(text: auth.phone);
    _title = TextEditingController(text: auth.professionalTitle);
    _contact = TextEditingController(
      text: auth.publicContact.isEmpty ? auth.email : auth.publicContact,
    );
    _newUsername = TextEditingController(text: auth.username);
    _credit = auth.documentCreditEnabled;
    _twoFactor = auth.ownerTwoFactorEnabled;
    _formats = auth.ownerDocumentFormats.toSet();
    try {
      if (auth.avatarBase64.isNotEmpty) {
        _avatar = base64Decode(auth.avatarBase64);
      }
    } catch (_) {
      _avatar = null;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _document,
      _email,
      _phone,
      _title,
      _contact,
      _newUsername,
      _currentPassword,
      _newPassword,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.documentsOnly ? 680 : 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _settingsHeader(),
            const SizedBox(height: 18),
            if (!widget.documentsOnly) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.person_outline),
                      label: Text('Datos personales'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.shield_outlined),
                      label: Text('Acceso y seguridad'),
                    ),
                    ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.description_outlined),
                      label: Text('Documentos'),
                    ),
                  ],
                  selected: {_settingsTab},
                  onSelectionChanged: (selection) =>
                      setState(() => _settingsTab = selection.first),
                ),
              ),
              const SizedBox(height: 16),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(widget.documentsOnly ? 2 : _settingsTab),
                child: widget.documentsOnly
                    ? _documents()
                    : switch (_settingsTab) {
                        0 => _profilePanel(),
                        1 => _securityPanel(),
                        _ => _documents(),
                      },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _settingsHeader() => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 620;
      final title = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: .12),
              border: Border.all(color: _accent.withValues(alpha: .48)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              widget.documentsOnly
                  ? Icons.description_outlined
                  : Icons.manage_accounts_outlined,
              color: _accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.documentsOnly ? 'Documentos y firma' : 'Mi perfil',
                  style: TextStyle(
                    fontSize: compact ? 22 : 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.documentsOnly
                      ? 'Configura tu crédito profesional al final de los documentos.'
                      : 'Actualiza tus datos, recuperación, usuario y contraseña.',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ],
      );
      final button = FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('Guardar cambios'),
      );
      return box.maxWidth >= 620
          ? Row(
              children: [
                Expanded(child: title),
                button,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 14), button],
            );
    },
  );

  Widget _profilePanel() => _CardPanel(
    title: 'Tu información',
    child: LayoutBuilder(
      builder: (context, box) {
        final avatar = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: _panelHigh,
                  backgroundImage: _avatar == null
                      ? null
                      : MemoryImage(_avatar!),
                  child: _avatar == null
                      ? const Icon(Icons.person_outline, size: 38)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: 'Cambiar foto',
                    onPressed: _pickAvatar,
                    icon: const Icon(Icons.camera_alt_outlined, size: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Text(
              'Foto de perfil',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        );
        final fields = Column(
          children: [
            _field(_name, 'Nombre completo', Icons.person_outline),
            const SizedBox(height: 12),
            _field(
              _document,
              'Documento de identidad',
              Icons.badge_outlined,
              optional: true,
            ),
            const SizedBox(height: 12),
            _field(_email, 'Correo de recuperación', Icons.email_outlined),
            const SizedBox(height: 12),
            _field(_phone, 'Celular de recuperación', Icons.phone_outlined),
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: _muted, size: 17),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'El correo y el celular se utilizarán para recuperar el acceso a la cuenta.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        );
        if (box.maxWidth < 440) {
          return Column(children: [avatar, const SizedBox(height: 18), fields]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 118, child: avatar),
            const SizedBox(width: 20),
            Expanded(child: fields),
          ],
        );
      },
    ),
  );

  Widget _securityPanel() => _CardPanel(
    title: 'Usuario y contraseña',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _twoFactor,
              onChanged: (value) => setState(() => _twoFactor = value),
              title: const Text('Verificación en dos pasos'),
              subtitle: const Text('Protege la cuenta con correo o celular.'),
            ),
            const Divider(color: _border),
            _field(
              _currentPassword,
              'Contraseña actual',
              Icons.lock_outline,
              obscure: !_showCurrentPassword,
              onToggleVisibility: () =>
                  setState(() => _showCurrentPassword = !_showCurrentPassword),
            ),
            const SizedBox(height: 12),
            _field(_newUsername, 'Usuario propietario', Icons.badge_outlined),
            const SizedBox(height: 7),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Deja la nueva contraseña vacía si solo deseas cambiar el usuario.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            _field(
              _newPassword,
              'Nueva contraseña',
              Icons.password,
              obscure: !_showNewPassword,
              optional: true,
              onToggleVisibility: () =>
                  setState(() => _showNewPassword = !_showNewPassword),
            ),
            const SizedBox(height: 12),
            _field(
              _confirmPassword,
              'Confirmar contraseña',
              Icons.password,
              obscure: !_showConfirmPassword,
              optional: true,
              onToggleVisibility: () =>
                  setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _changeCredentials,
              icon: const Icon(Icons.security_update_good),
              label: const Text('Guardar acceso'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _documents() => Column(
    children: [
      _CardPanel(
        title: 'Identidad en documentos',
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _credit,
              onChanged: (value) => setState(() => _credit = value),
              title: const Text('Incluir crédito del desarrollador'),
              subtitle: const Text(
                'Aparecerá discretamente en facturas y recibos.',
              ),
            ),
            _field(
              _title,
              'Título profesional',
              Icons.workspace_premium_outlined,
            ),
            const SizedBox(height: 12),
            _field(
              _contact,
              'Correo o teléfono público',
              Icons.alternate_email,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: .09),
                border: Border.all(color: _accent.withValues(alpha: .45)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'El crédito complementa los datos fiscales del taller; nunca reemplaza al emisor legal.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _CardPanel(
        title: 'Formatos y envíos',
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _format(Icons.picture_as_pdf_outlined, 'PDF'),
            _format(Icons.article_outlined, 'Word (.docx)'),
            _format(Icons.email_outlined, 'Correo'),
            _format(Icons.chat_outlined, 'WhatsApp'),
            _format(Icons.receipt_long_outlined, 'Facturas'),
            _format(Icons.request_quote_outlined, 'Recibos'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _CardPanel(
        title: 'Vista previa del pie documental',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: const Color(0xFFF4F4F4),
          child: Column(
            children: [
              const Divider(color: Color(0xFFB7B7B7)),
              const SizedBox(height: 10),
              Text(
                _credit
                    ? 'Aplicación desarrollada por ${_name.text.trim().isEmpty ? 'el propietario' : _name.text.trim()}'
                    : 'Crédito desactivado',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_credit)
                Text(
                  '${_title.text} · ${_contact.text}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    bool optional = false,
    VoidCallback? onToggleVisibility,
  }) => TextFormField(
    controller: controller,
    obscureText: obscure,
    onChanged: (_) => setState(() {}),
    validator: optional
        ? null
        : (value) => value == null || value.trim().isEmpty
              ? 'Campo obligatorio.'
              : null,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: onToggleVisibility == null
          ? null
          : IconButton(
              tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: onToggleVisibility,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
    ),
  );

  Widget _format(IconData icon, String label) => _Format(
    icon,
    label,
    selected: _formats.contains(label),
    onSelected: (selected) => setState(() {
      if (selected) {
        _formats.add(label);
      } else {
        _formats.remove(label);
      }
    }),
  );

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty || !mounted) return;
    if (bytes.length > 2 * 1024 * 1024) {
      _toast('La foto debe pesar menos de 2 MB.');
      return;
    }
    setState(() => _avatar = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await widget.authController.saveOwnerPresentation(
      fullName: _name.text,
      document: _document.text,
      email: _email.text,
      phone: _phone.text,
      professionalTitle: _title.text,
      publicContact: _contact.text,
      documentCreditEnabled: _credit,
      twoFactorEnabled: _twoFactor,
      documentFormats: _formats.toList(),
      avatarBase64: _avatar == null ? null : base64Encode(_avatar!),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(error ?? 'Configuración guardada correctamente.');
  }

  Future<void> _changeCredentials() async {
    if (_newPassword.text != _confirmPassword.text) {
      _toast('Las contraseñas nuevas no coinciden.');
      return;
    }
    if (_newPassword.text.isEmpty &&
        _newUsername.text.trim() == widget.authController.username) {
      _toast('No hay cambios de usuario o contraseña para guardar.');
      return;
    }
    final error = await widget.authController.changeCredentials(
      currentPassword: _currentPassword.text,
      newUsername: _newUsername.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    _toast(error ?? 'Usuario y contraseña actualizados.');
    if (error == null) {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _CardPanel extends StatelessWidget {
  const _CardPanel({required this.child, this.title, this.trailing});
  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _accent.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: compact ? 16 : 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _WorkshopCommandSummary extends StatelessWidget {
  const _WorkshopCommandSummary({
    required this.total,
    required this.attention,
    required this.active,
    required this.suspended,
    required this.deleted,
  });

  final int total;
  final int attention;
  final int active;
  final int suspended;
  final int deleted;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _item('Historial total', total, Icons.inventory_2_outlined, _accent),
      _item(
        'Nuevos / En prueba',
        attention,
        Icons.notifications_active_outlined,
        _warning,
      ),
      _item('Activos permanentes', active, Icons.verified_outlined, _success),
      _item('Suspendidos', suspended, Icons.block_outlined, _danger),
      _item('Eliminados', deleted, Icons.delete_outline_rounded, _muted),
    ],
  );

  Widget _item(
    String label,
    int value,
    IconData icon,
    Color color,
  ) => Container(
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: color.withValues(alpha: .45)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ],
    ),
  );
}

class _WorkshopRow extends StatelessWidget {
  const _WorkshopRow({required this.workshop, required this.onAction});
  final _Workshop workshop;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = workshop.isDeleted
        ? _muted
        : workshop.status == 'Activo'
        ? _success
        : workshop.status == 'Suspendido'
        ? _danger
        : _warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _panelHigh,
            child: Text(
              workshop.name.substring(0, 1),
              style: TextStyle(color: _accent, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workshop.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (workshop.isNew)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'NUEVO',
                      style: TextStyle(
                        color: _warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                Text(
                  workshop.location,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (workshop.administratorCount > 0 || workshop.clientCount > 0)
                  Text(
                    '${workshop.administratorCount} administrador(es) · ${workshop.clientCount} cliente(s)',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                if (workshop.createdAt != null)
                  Text(
                    'Registrado ${_shortDate(workshop.createdAt!)}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 650)
            Expanded(
              flex: 2,
              child: Text(workshop.plan, style: const TextStyle(color: _muted)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              workshop.status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Administrar taller',
            onPressed: onAction,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.onTap});
  final _Issue issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = issue.resolved
        ? _success
        : issue.priority == 'Alta'
        ? _danger
        : issue.priority == 'Media'
        ? _warning
        : Colors.lightBlueAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            issue.resolved ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: issue.resolved
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  '${issue.workshop} · ${issue.time}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(issue.resolved ? 'Reabrir' : 'Resolver'),
          ),
        ],
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: _accent),
      const SizedBox(width: 9),
      SizedBox(
        width: 66,
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.title, this.subtitle, {this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Icon(icon, color: _accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _AuditRow extends StatelessWidget {
  const _AuditRow(this.date, this.user, this.action, this.detail);
  final String date;
  final String user;
  final String action;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        SizedBox(
          width: 120,
          child: Text(date, style: const TextStyle(color: _muted)),
        ),
        SizedBox(width: 110, child: Text(user)),
        SizedBox(
          width: 190,
          child: Text(
            action,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(detail, style: const TextStyle(color: _muted)),
      ],
    ),
  );
}

class _Service extends StatelessWidget {
  const _Service(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Row(
      children: [
        Icon(icon, color: _muted),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
        const Icon(Icons.circle, color: _success, size: 10),
        const SizedBox(width: 5),
        const Text(
          'Operativo',
          style: TextStyle(color: _success, fontSize: 12),
        ),
      ],
    ),
  );
}

class _Format extends StatelessWidget {
  const _Format(
    this.icon,
    this.label, {
    required this.selected,
    required this.onSelected,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    selected: selected,
    onSelected: onSelected,
    avatar: Icon(icon, size: 18),
    label: Text(label),
  );
}

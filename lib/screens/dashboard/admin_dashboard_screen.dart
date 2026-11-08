import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/auth/admin_access_service.dart';
import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/branding/workshop_dashboard_preferences.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/chat/local_chat_store.dart';
import '../../core/client/client_service_store.dart';
import '../../core/commerce/commerce_models.dart';
import '../../core/commerce/commerce_receipt_service.dart';
import '../../core/commerce/commerce_store.dart';
import '../../core/commerce/inventory_models.dart';
import '../../core/networking/api_client.dart';
import '../../core/staff/workshop_mechanic_store.dart';
import '../../core/auth/local_workshop_admin_store.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/workshops/trial_extension_service.dart';
import '../../core/workshops/workshop_clients_service.dart';
import '../../core/workshops/workshop_feedback_store.dart';
import '../admin_customization/admin_customization_screen.dart';
import '../settings/credential_settings_screen.dart';
import '../access/role_access_screen.dart';

/// Panel administrativo asociado al taller activo de la sesión.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.brandController,
    required this.userName,
    required this.tenantContext,
    this.localAdminStore,
  });

  final WorkshopBrandController brandController;
  final String userName;
  final TenantContext tenantContext;
  final LocalWorkshopAdminStore? localAdminStore;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkshopBrand>(
      valueListenable: brandController,
      builder: (context, brand, _) => _TrialAccessGate(
        store: localAdminStore,
        brand: brand,
        tenantContext: tenantContext,
        child: _DashboardScaffold(
          brand: brand,
          brandController: brandController,
          tenantContext: tenantContext,
          title: 'Panel administrativo',
          greeting: 'Hola, $userName',
          workshopId: tenantContext.currentTenantId,
          localAdminStore: localAdminStore,
          onLogout: () => _signOut(context),
          items: const [
            (
              Icons.calendar_month_outlined,
              'Agenda',
              'Organiza tus citas y servicios',
            ),
            (
              Icons.groups_2_outlined,
              'Equipo',
              'Administra técnicos y permisos',
            ),
            (
              Icons.inventory_2_outlined,
              'Inventario',
              'Controla repuestos y existencias',
            ),
            (
              Icons.insights_outlined,
              'Reportes',
              'Consulta el rendimiento del taller',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await localAdminStore?.signOut();
    await tenantContext.clear();
    brandController.value = WorkshopBrand.defaultBrand;
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => RoleAccessScreen(
          tenantContext: tenantContext,
          brandController: brandController,
          authController: AdminAuthController(),
        ),
      ),
      (_) => false,
    );
  }
}

class _TrialAccessGate extends StatefulWidget {
  const _TrialAccessGate({
    required this.store,
    required this.brand,
    required this.tenantContext,
    required this.child,
  });

  final LocalWorkshopAdminStore? store;
  final WorkshopBrand brand;
  final TenantContext tenantContext;
  final Widget child;

  @override
  State<_TrialAccessGate> createState() => _TrialAccessGateState();
}

class _TrialAccessGateState extends State<_TrialAccessGate> {
  final _trialExtensionService = TrialExtensionService();
  LocalWorkshopAdminAccount? _account;
  AdminAccessRole? _cloudAccessRole;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (widget.store != null) {
      final account = await widget.store!.loadAccount();
      if (mounted) setState(() => _account = account);
      return;
    }
    try {
      final role = await AdminAccessService().resolveRole();
      if (mounted) setState(() => _cloudAccessRole = role);
    } catch (_) {
      // Una falla temporal de red no debe reemplazar el último estado validado.
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final cloudSuspended =
        widget.store == null &&
        _cloudAccessRole == AdminAccessRole.workshopSuspended;
    final cloudExpired =
        widget.store == null &&
        _cloudAccessRole == AdminAccessRole.workshopExpired;
    final localBlocked = account != null && !account.canEnter;
    if (!cloudSuspended && !cloudExpired && !localBlocked) {
      return widget.child;
    }
    final suspended =
        cloudSuspended || account?.accessState == WorkshopAccessState.suspended;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/workshop_login_background_v1.png',
            fit: BoxFit.cover,
          ),
          const ColoredBox(color: Color(0xD9080A0D)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xF21A1D22),
                  border: Border.all(color: widget.brand.accentColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      suspended
                          ? Icons.block_outlined
                          : Icons.workspace_premium_outlined,
                      color: widget.brand.accentColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      suspended ? 'Acceso suspendido' : 'Prueba finalizada',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      suspended
                          ? 'El propietario de la plataforma debe reactivar este taller.'
                          : 'Los 3 días de prueba terminaron. Tus datos siguen protegidos; activa el acceso definitivo mediante un pago único.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    if (!suspended) ...[
                      OutlinedButton.icon(
                        onPressed: _requestMoreTime,
                        icon: const Icon(Icons.more_time_rounded),
                        label: const Text('Solicitar más tiempo de prueba'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          icon: const Icon(Icons.payments_outlined),
                          title: const Text('Activación definitiva'),
                          content: const Text(
                            'La cuenta está lista para conectarse a la pasarela de pagos. '
                            'Hasta configurar el proveedor, solicita al propietario la activación manual después del pago.',
                          ),
                          actions: [
                            FilledButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Entendido'),
                            ),
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Activar acceso definitivo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestMoreTime() async {
    var requestedDays = 1;
    final reason = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(Icons.more_time_rounded, color: widget.brand.accentColor),
          title: const Text('Solicitar más tiempo'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'La solicitud llegará al propietario. Tu taller y toda su '
                  'información permanecerán guardados mientras esperas.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: requestedDays,
                  decoration: const InputDecoration(
                    labelText: 'Tiempo solicitado',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
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
                      setDialogState(() => requestedDays = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '¿Por qué necesitas más tiempo?',
                    hintText:
                        'Cuéntanos qué funciones deseas terminar de probar',
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
                if (reason.text.trim().length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Explica un poco más el motivo.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    );
    final requestReason = reason.text.trim();
    reason.dispose();
    if (sent != true || !mounted) return;

    String? error;
    if (widget.store != null) {
      error = await widget.store!.requestTrialExtension(
        requestedDays: requestedDays,
        reason: requestReason,
      );
    } else {
      try {
        final workshopId = widget.tenantContext.currentTenantId;
        if (workshopId.isEmpty) {
          throw StateError('No hay un taller activo.');
        }
        await _trialExtensionService.request(
          workshopId: workshopId,
          requestedDays: requestedDays,
          reason: requestReason,
        );
      } catch (_) {
        error = 'No fue posible enviar la solicitud.';
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Solicitud enviada. El propietario decidirá si aprueba el tiempo adicional.',
        ),
      ),
    );
  }
}

class _DashboardScaffold extends StatefulWidget {
  const _DashboardScaffold({
    required this.brand,
    required this.brandController,
    required this.tenantContext,
    required this.title,
    required this.greeting,
    required this.workshopId,
    required this.items,
    this.localAdminStore,
    required this.onLogout,
  });

  final WorkshopBrand brand;
  final WorkshopBrandController brandController;
  final TenantContext tenantContext;
  final String title;
  final String greeting;
  final String workshopId;
  final List<(IconData, String, String)> items;
  final LocalWorkshopAdminStore? localAdminStore;
  final VoidCallback onLogout;

  @override
  State<_DashboardScaffold> createState() => _DashboardScaffoldState();
}

class _DashboardScaffoldState extends State<_DashboardScaffold> {
  static const _sections = [
    (Icons.dashboard_rounded, 'Resumen', 'Vista general del taller'),
    (Icons.calendar_month_rounded, 'Agenda', 'Citas y estado de servicios'),
    (Icons.forum_rounded, 'Chat', 'Conversaciones con clientes'),
    (Icons.groups_2_rounded, 'Clientes', 'Directorio e historial'),
    (Icons.engineering_rounded, 'Mecánicos', 'Equipo y disponibilidad'),
    (Icons.category_rounded, 'Repuestos', 'Catálogo publicado para clientes'),
    (Icons.inventory_2_rounded, 'Inventario', 'Existencias, ventas y facturas'),
    (Icons.star_rounded, 'Calificaciones', 'Experiencia del cliente'),
  ];

  final _preferencesStore = const WorkshopDashboardPreferencesStore();
  WorkshopDashboardPreferences _preferences =
      const WorkshopDashboardPreferences();
  int _selected = 0;

  WorkshopBrand get brand => widget.brand;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final value = await _preferencesStore.load(widget.workshopId);
    if (mounted) setState(() => _preferences = value);
  }

  Future<void> _openPersonalization() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminCustomizationScreen(
          brandController: widget.brandController,
          tenantContext: widget.tenantContext,
        ),
      ),
    );
    await _loadPreferences();
  }

  Future<void> _openAccessSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CredentialSettingsScreen(
          brand: brand,
          localAdminStore: widget.localAdminStore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(_preferences.textScale));
    return MediaQuery(
      data: media,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF151619),
          title: Row(
            children: [
              SizedBox.square(
                dimension: 36,
                child: brand.hasCustomLogo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          brand.customLogoBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: brand.accentColor.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(brand.logoIcon, color: brand.accentColor),
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'Centro operativo',
                      style: TextStyle(color: Color(0xFF9EA3AA), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Notificaciones',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No tienes notificaciones pendientes.'),
                ),
              ),
              icon: Badge(
                backgroundColor: brand.accentColor,
                smallSize: 7,
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            IconButton(
              tooltip: 'Personalización del taller',
              onPressed: _openPersonalization,
              icon: const Icon(Icons.palette_outlined),
            ),
            IconButton(
              tooltip: 'Configuración de acceso',
              onPressed: _openAccessSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'Cuenta del administrador',
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (value) {
                if (value == 'logout') _confirmLogout();
                if (value == 'settings') _openAccessSettings();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.manage_accounts_outlined),
                    title: Text('Mi cuenta y seguridad'),
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout_rounded),
                    title: Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: .34,
              child: Image.asset(
                'assets/images/workshop_login_background_v1.png',
                fit: BoxFit.cover,
              ),
            ),
            const ColoredBox(color: Color(0xAA080A0D)),
            if (_preferences.brightness < 1)
              ColoredBox(
                color: Colors.black.withValues(
                  alpha: (1 - _preferences.brightness).clamp(0, .28),
                ),
              )
            else if (_preferences.brightness > 1)
              ColoredBox(
                color: Colors.white.withValues(
                  alpha: ((_preferences.brightness - 1) * .16).clamp(0, .05),
                ),
              ),
            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 980;
                  return Row(
                    children: [
                      if (desktop)
                        _WorkshopNavigation(
                          brand: brand,
                          selected: _selected,
                          sections: _sections,
                          onSelected: (index) =>
                              setState(() => _selected = index),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            if (!desktop)
                              _CompactWorkshopNavigation(
                                brand: brand,
                                selected: _selected,
                                sections: _sections,
                                onSelected: (index) =>
                                    setState(() => _selected = index),
                              ),
                            Expanded(child: _selectedPage()),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Podrás volver a entrar con tu usuario y contraseña. Los datos del taller permanecerán guardados.',
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
    if (confirmed == true) widget.onLogout();
  }

  Widget _selectedPage() {
    final content = switch (_selected) {
      0 => _WorkshopOverview(
        workshopId: widget.workshopId,
        brand: brand,
        greeting: widget.greeting,
        localAdminStore: widget.localAdminStore,
        onOpenSection: (index) => setState(() => _selected = index),
        onPersonalization: _openPersonalization,
      ),
      1 => _WorkshopServicePanel(workshopId: widget.workshopId, brand: brand),
      2 => _WorkshopChatPanel(workshopId: widget.workshopId, brand: brand),
      3 => _WorkshopClientsPanel(workshopId: widget.workshopId, brand: brand),
      4 => _WorkshopMechanicsPanel(workshopId: widget.workshopId, brand: brand),
      5 => _WorkshopCommercePanel(
        workshopId: widget.workshopId,
        brand: brand,
        catalogOnly: true,
      ),
      6 => _WorkshopCommercePanel(workshopId: widget.workshopId, brand: brand),
      _ => _WorkshopFeedbackPanel(workshopId: widget.workshopId, brand: brand),
    };
    final padding = _preferences.compactMode ? 14.0 : 24.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: content,
        ),
      ),
    );
  }
}

class _WorkshopNavigation extends StatelessWidget {
  const _WorkshopNavigation({
    required this.brand,
    required this.selected,
    required this.sections,
    required this.onSelected,
  });

  final WorkshopBrand brand;
  final int selected;
  final List<(IconData, String, String)> sections;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 244,
    decoration: BoxDecoration(
      color: const Color(0xF015171B),
      border: Border(
        right: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: brand.accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'GESTIÓN DEL TALLER',
                  style: TextStyle(
                    color: Color(0xFFAEB3BA),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: sections.length,
            itemBuilder: (_, index) {
              final active = index == selected;
              final section = sections[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Material(
                  color: active
                      ? brand.accentColor.withValues(alpha: .17)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            section.$1,
                            color: active
                                ? brand.accentColor
                                : const Color(0xFFB7BCC3),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.$2,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFFD1D4D8),
                                  ),
                                ),
                                Text(
                                  section.$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF838990),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    ),
  );
}

class _CompactWorkshopNavigation extends StatelessWidget {
  const _CompactWorkshopNavigation({
    required this.brand,
    required this.selected,
    required this.sections,
    required this.onSelected,
  });

  final WorkshopBrand brand;
  final int selected;
  final List<(IconData, String, String)> sections;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    color: const Color(0xF015171B),
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: sections.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, index) {
        final active = index == selected;
        return Material(
          color: active
              ? brand.accentColor.withValues(alpha: .18)
              : const Color(0xFF22252A),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    sections[index].$1,
                    color: active ? brand.accentColor : Colors.white70,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sections[index].$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: active ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _WorkshopOverview extends StatefulWidget {
  const _WorkshopOverview({
    required this.workshopId,
    required this.brand,
    required this.greeting,
    required this.localAdminStore,
    required this.onOpenSection,
    required this.onPersonalization,
  });

  final String workshopId;
  final WorkshopBrand brand;
  final String greeting;
  final LocalWorkshopAdminStore? localAdminStore;
  final ValueChanged<int> onOpenSection;
  final VoidCallback onPersonalization;

  @override
  State<_WorkshopOverview> createState() => _WorkshopOverviewState();
}

class _WorkshopOverviewState extends State<_WorkshopOverview> {
  late Future<_WorkshopOverviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WorkshopOverviewData> _load() async {
    final appointments = await ClientServiceStore().listWorkshopAppointments(
      widget.workshopId,
    );
    final mechanics = await WorkshopMechanicStore().list(widget.workshopId);
    final products = await CommerceStore().listProducts(widget.workshopId);
    final orders = await CommerceStore().listOrders(
      workshopId: widget.workshopId,
    );
    final feedback = await WorkshopFeedbackStore().list(widget.workshopId);
    final activeAppointments = appointments
        .where((item) => !item.isCancelled && item.serviceStage != 'Entregada')
        .toList();
    final clientIds = appointments
        .map((item) => item.clientId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final paidOrders = orders.where((order) => order.paid).toList();
    final salesCents = paidOrders.fold<int>(
      0,
      (total, order) => total + order.workshopNetBeforeGatewayCents,
    );
    final rating = feedback.isEmpty
        ? 0.0
        : feedback.fold<int>(0, (total, item) => total + item.rating) /
              feedback.length;
    activeAppointments.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _WorkshopOverviewData(
      activeAppointments: activeAppointments,
      mechanics: mechanics.length,
      availableMechanics: mechanics.where((item) => item.available).length,
      products: products.length,
      lowStock: products.where((item) => item.stock <= 3).length,
      clients: clientIds.length,
      pendingOrders: orders
          .where(
            (order) =>
                order.status == CommerceOrderStatus.paid ||
                order.status == CommerceOrderStatus.preparing ||
                order.status == CommerceOrderStatus.readyForPickup,
          )
          .length,
      salesCents: salesCents,
      rating: rating,
      ratingCount: feedback.length,
    );
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_WorkshopOverviewData>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data ?? const _WorkshopOverviewData();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.greeting,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Este es el estado actual de ${widget.brand.name}.',
                      style: const TextStyle(color: Color(0xFFADB2B9)),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Actualizar información',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.localAdminStore != null)
            FutureBuilder<LocalWorkshopAdminAccount?>(
              future: widget.localAdminStore!.loadAccount(),
              builder: (context, accountSnapshot) {
                final account = accountSnapshot.data;
                if (account == null ||
                    account.accessState != WorkshopAccessState.trial) {
                  return const SizedBox.shrink();
                }
                return _TrialBanner(
                  brand: widget.brand,
                  remaining: account.trialRemaining,
                );
              },
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final cards = [
                _OverviewMetric(
                  icon: Icons.event_available_rounded,
                  label: 'Servicios activos',
                  value: '${data.activeAppointments.length}',
                  detail: 'Citas y motos en proceso',
                  color: widget.brand.accentColor,
                  onTap: () => widget.onOpenSection(1),
                ),
                _OverviewMetric(
                  icon: Icons.payments_rounded,
                  label: 'Ventas netas',
                  value: commerceMoney(data.salesCents),
                  detail: '${data.pendingOrders} pedidos por atender',
                  color: const Color(0xFF20C77A),
                  onTap: () => widget.onOpenSection(6),
                ),
                _OverviewMetric(
                  icon: Icons.groups_2_rounded,
                  label: 'Clientes',
                  value: '${data.clients}',
                  detail: 'Con historial en este taller',
                  color: const Color(0xFF4AA8FF),
                  onTap: () => widget.onOpenSection(3),
                ),
                _OverviewMetric(
                  icon: Icons.star_rounded,
                  label: 'Calificación',
                  value: data.ratingCount == 0
                      ? 'Sin datos'
                      : data.rating.toStringAsFixed(1),
                  detail: '${data.ratingCount} opiniones recibidas',
                  color: const Color(0xFFFFB020),
                  onTap: () => widget.onOpenSection(7),
                ),
              ];
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 2.7 : 2.15,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final operational = _OperationsSummary(
                brand: widget.brand,
                data: data,
                onOpenSection: widget.onOpenSection,
              );
              final quickActions = _QuickActions(
                brand: widget.brand,
                onOpenSection: widget.onOpenSection,
                onPersonalization: widget.onPersonalization,
              );
              if (constraints.maxWidth < 820) {
                return Column(
                  children: [
                    operational,
                    const SizedBox(height: 16),
                    quickActions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: operational),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: quickActions),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.brand, required this.remaining});
  final WorkshopBrand brand;
  final Duration remaining;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: brand.accentColor.withValues(alpha: .12),
      border: Border.all(color: brand.accentColor.withValues(alpha: .55)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(Icons.schedule_rounded, color: brand.accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Prueba activa: ${remaining.inHours} h ${remaining.inMinutes % 60} min restantes. Toda tu información permanecerá protegida.',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xEE1B1E23),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFFADB2B9))),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF858B93),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF737981)),
          ],
        ),
      ),
    ),
  );
}

class _OperationsSummary extends StatelessWidget {
  const _OperationsSummary({
    required this.brand,
    required this.data,
    required this.onOpenSection,
  });
  final WorkshopBrand brand;
  final _WorkshopOverviewData data;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) => _DashboardSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardSectionHeader(
          icon: Icons.monitor_heart_outlined,
          title: 'Operación del taller',
          subtitle: 'Información sincronizada con tus clientes',
          color: brand.accentColor,
        ),
        const SizedBox(height: 16),
        _OperationRow(
          icon: Icons.engineering_rounded,
          title: 'Mecánicos disponibles',
          value: '${data.availableMechanics} de ${data.mechanics}',
          color: const Color(0xFF4AA8FF),
          onTap: () => onOpenSection(4),
        ),
        _OperationRow(
          icon: Icons.inventory_2_outlined,
          title: 'Repuestos publicados',
          value: '${data.products}',
          color: brand.accentColor,
          onTap: () => onOpenSection(5),
        ),
        _OperationRow(
          icon: Icons.warning_amber_rounded,
          title: 'Productos con bajo stock',
          value: '${data.lowStock}',
          color: const Color(0xFFFFB020),
          onTap: () => onOpenSection(6),
        ),
        _OperationRow(
          icon: Icons.forum_outlined,
          title: 'Chat conectado',
          value: 'Disponible',
          color: const Color(0xFF20C77A),
          onTap: () => onOpenSection(2),
        ),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.brand,
    required this.onOpenSection,
    required this.onPersonalization,
  });
  final WorkshopBrand brand;
  final ValueChanged<int> onOpenSection;
  final VoidCallback onPersonalization;

  @override
  Widget build(BuildContext context) => _DashboardSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardSectionHeader(
          icon: Icons.bolt_rounded,
          title: 'Acciones rápidas',
          subtitle: 'Gestiona lo importante en menos pasos',
          color: brand.accentColor,
        ),
        const SizedBox(height: 14),
        _QuickActionButton(
          icon: Icons.calendar_month_rounded,
          label: 'Revisar agenda',
          color: brand.accentColor,
          onTap: () => onOpenSection(1),
        ),
        _QuickActionButton(
          icon: Icons.add_box_outlined,
          label: 'Publicar repuesto',
          color: const Color(0xFF20C77A),
          onTap: () => onOpenSection(5),
        ),
        _QuickActionButton(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Agregar mecánico',
          color: const Color(0xFF4AA8FF),
          onTap: () => onOpenSection(4),
        ),
        _QuickActionButton(
          icon: Icons.palette_outlined,
          label: 'Personalizar mi taller',
          color: const Color(0xFFB071FF),
          onTap: onPersonalization,
        ),
      ],
    ),
  );
}

class _DashboardSurface extends StatelessWidget {
  const _DashboardSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xEE1B1E23),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
    ),
    child: child,
  );
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF8F959D), fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: .13),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 18),
      ],
    ),
  );
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        alignment: Alignment.centerLeft,
        side: BorderSide(color: color.withValues(alpha: .5)),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, color: color),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class _WorkshopOverviewData {
  const _WorkshopOverviewData({
    this.activeAppointments = const [],
    this.mechanics = 0,
    this.availableMechanics = 0,
    this.products = 0,
    this.lowStock = 0,
    this.clients = 0,
    this.pendingOrders = 0,
    this.salesCents = 0,
    this.rating = 0,
    this.ratingCount = 0,
  });
  final List<ClientAppointment> activeAppointments;
  final int mechanics;
  final int availableMechanics;
  final int products;
  final int lowStock;
  final int clients;
  final int pendingOrders;
  final int salesCents;
  final double rating;
  final int ratingCount;
}

class _WorkshopServicePanel extends StatefulWidget {
  const _WorkshopServicePanel({required this.workshopId, required this.brand});

  final String workshopId;
  final WorkshopBrand brand;

  @override
  State<_WorkshopServicePanel> createState() => _WorkshopServicePanelState();
}

class _WorkshopServicePanelState extends State<_WorkshopServicePanel> {
  final _store = ClientServiceStore();
  List<ClientAppointment> _appointments = const [];

  @override
  void initState() {
    super.initState();
    ClientServiceStore.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ClientServiceStore.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _store.listWorkshopAppointments(widget.workshopId);
    if (mounted) setState(() => _appointments = items);
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xE91A1C20),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF363940)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.route_outlined, color: widget.brand.accentColor),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seguimiento de servicios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Actualiza el avance que verá el cliente en tiempo real',
                    style: TextStyle(color: Color(0xFF9EA2AA), fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_appointments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Las nuevas citas aparecerán aquí para iniciar su seguimiento.',
              style: TextStyle(color: Color(0xFFB2B5BB)),
            ),
          )
        else
          for (final item in _appointments.reversed) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF202328),
                borderRadius: BorderRadius.circular(7),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.serviceType,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${item.motorcycleName} · ${item.clientId}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFADB1B8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item.date.day.toString().padLeft(2, '0')}/'
                        '${item.date.month.toString().padLeft(2, '0')}/'
                        '${item.date.year} · ${item.time}',
                        style: TextStyle(
                          color: widget.brand.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171A1E),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFF343941)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: widget.brand.accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Motivo indicado por el cliente',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.notes,
                                      style: const TextStyle(
                                        color: Color(0xFFC3C7CD),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                  final picker = DropdownButton<String>(
                    value: clientServiceStages.contains(item.serviceStage)
                        ? item.serviceStage
                        : clientServiceStages.first,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      for (final stage in clientServiceStages)
                        DropdownMenuItem(value: stage, child: Text(stage)),
                    ],
                    onChanged: (stage) async {
                      if (stage == null) return;
                      await _store.updateAppointmentStage(item, stage);
                    },
                  );
                  if (constraints.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [info, const SizedBox(height: 8), picker],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: info),
                      const SizedBox(width: 12),
                      picker,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    ),
  );
}

class _WorkshopMechanicsPanel extends StatefulWidget {
  const _WorkshopMechanicsPanel({
    required this.workshopId,
    required this.brand,
  });

  final String workshopId;
  final WorkshopBrand brand;

  @override
  State<_WorkshopMechanicsPanel> createState() =>
      _WorkshopMechanicsPanelState();
}

class _WorkshopMechanicsPanelState extends State<_WorkshopMechanicsPanel> {
  final _store = WorkshopMechanicStore();
  final _feedbackStore = WorkshopFeedbackStore();
  List<WorkshopMechanic> _mechanics = const [];
  List<WorkshopFeedback> _feedback = const [];

  @override
  void initState() {
    super.initState();
    WorkshopMechanicStore.revision.addListener(_load);
    WorkshopFeedbackStore.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WorkshopMechanicStore.revision.removeListener(_load);
    WorkshopFeedbackStore.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final mechanics = await _store.list(
      widget.workshopId,
      includeInactive: true,
    );
    final feedback = await _feedbackStore.list(widget.workshopId);
    if (!mounted) return;
    setState(() {
      _mechanics = mechanics;
      _feedback = feedback;
    });
  }

  (double, int) _ratingFor(String mechanicName) {
    final ratings = _feedback
        .where(
          (item) =>
              item.mechanicName.trim().toLowerCase() ==
              mechanicName.trim().toLowerCase(),
        )
        .toList();
    if (ratings.isEmpty) return (0, 0);
    final average =
        ratings.fold<int>(0, (sum, item) => sum + item.rating) / ratings.length;
    return (average, ratings.length);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => _editMechanic(),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Agregar mecánico'),
        ),
      ),
      const SizedBox(height: 10),
      if (_mechanics.isEmpty)
        const Center(
          child: Text(
            'Aún no has registrado mecánicos.',
            style: TextStyle(color: Color(0xFFBFC2C7)),
          ),
        )
      else
        for (var index = 0; index < _mechanics.length; index++) ...[
          _mechanicRow(_mechanics[index]),
          if (index < _mechanics.length - 1)
            const Divider(height: 1, color: Color(0xFF30343A)),
        ],
    ],
  );

  Widget _mechanicRow(WorkshopMechanic mechanic) {
    final rating = _ratingFor(mechanic.name);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      leading: _mechanicAvatar(mechanic, 52),
      title: Text(
        mechanic.name,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mechanic.active ? mechanic.specialty : 'Mecánico retirado',
            style: const TextStyle(color: Color(0xFFBFC2C7), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < rating.$1.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 15,
                  color: const Color(0xFFFFB547),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                rating.$2 == 0
                    ? 'Sin calificaciones'
                    : '${rating.$1.toStringAsFixed(1)} (${rating.$2})',
                style: const TextStyle(color: Color(0xFFAEB3BA), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mechanic.active)
            Tooltip(
              message: mechanic.available ? 'Disponible' : 'No disponible',
              child: Switch.adaptive(
                value: mechanic.available,
                onChanged: (value) =>
                    _store.save(mechanic.copyWith(available: value)),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Opciones del mecánico',
            onSelected: (action) {
              if (action == 'edit') _editMechanic(mechanic);
              if (action == 'archive') _archive(mechanic);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar información'),
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: Colors.redAccent,
                  ),
                  title: Text('Retirar mecánico'),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _showMechanicDetails(mechanic, rating),
    );
  }

  Widget _mechanicAvatar(WorkshopMechanic mechanic, double size) => ClipOval(
    child: SizedBox.square(
      dimension: size,
      child: mechanic.photoBytes == null
          ? ColoredBox(
              color: widget.brand.accentColor.withValues(alpha: .16),
              child: Center(
                child: Text(
                  mechanic.name.isEmpty ? '?' : mechanic.name[0].toUpperCase(),
                  style: TextStyle(
                    color: widget.brand.accentColor,
                    fontSize: size * .36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          : Image.memory(mechanic.photoBytes!, fit: BoxFit.cover),
    ),
  );

  Future<void> _showMechanicDetails(
    WorkshopMechanic mechanic,
    (double, int) rating,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(mechanic.name),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _mechanicAvatar(mechanic, 88),
            const SizedBox(height: 12),
            Text(
              mechanic.specialty,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (mechanic.experienceYears > 0)
              Text(
                '${mechanic.experienceYears} años de experiencia',
                style: const TextStyle(color: Color(0xFFBFC2C7)),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFB547)),
                const SizedBox(width: 5),
                Text(
                  rating.$2 == 0
                      ? 'Sin calificaciones todavía'
                      : '${rating.$1.toStringAsFixed(1)} de 5 · ${rating.$2} opiniones',
                ),
              ],
            ),
            if (mechanic.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(mechanic.bio, textAlign: TextAlign.center),
            ],
            if (mechanic.phone.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                mechanic.phone,
                style: const TextStyle(color: Color(0xFFBFC2C7)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _editMechanic(mechanic);
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
      ],
    ),
  );

  Future<void> _archive(WorkshopMechanic mechanic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar mecánico'),
        content: Text(
          '${mechanic.name} dejará de aparecer disponible para los clientes. Su historial y calificaciones se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.archive(mechanic);
  }

  Future<void> _editMechanic([WorkshopMechanic? current]) async {
    final name = TextEditingController(text: current?.name ?? '');
    final specialty = TextEditingController(
      text: current?.specialty ?? 'Mecánica general',
    );
    final phone = TextEditingController(text: current?.phone ?? '');
    final bio = TextEditingController(text: current?.bio ?? '');
    final experience = TextEditingController(
      text: current == null || current.experienceYears == 0
          ? ''
          : current.experienceYears.toString(),
    );
    Uint8List? photoBytes = current?.photoBytes;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(current == null ? 'Agregar mecánico' : 'Editar mecánico'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 86,
                      child: photoBytes == null
                          ? ColoredBox(
                              color: widget.brand.accentColor.withValues(
                                alpha: .16,
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: widget.brand.accentColor,
                              ),
                            )
                          : Image.memory(photoBytes!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          final bytes = result?.files.single.bytes;
                          if (bytes == null) return;
                          if (bytes.lengthInBytes > 2 * 1024 * 1024) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'La foto debe pesar menos de 2 MB.',
                                ),
                              ),
                            );
                            return;
                          }
                          setDialog(() => photoBytes = bytes);
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(
                          photoBytes == null ? 'Agregar foto' : 'Cambiar foto',
                        ),
                      ),
                      if (photoBytes != null)
                        IconButton(
                          tooltip: 'Quitar foto',
                          onPressed: () => setDialog(() => photoBytes = null),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: specialty,
                    decoration: const InputDecoration(
                      labelText: 'Especialidad',
                      prefixIcon: Icon(Icons.build_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: experience,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Años de experiencia',
                            prefixIcon: Icon(Icons.workspace_premium_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Celular',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bio,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Presentación profesional',
                      hintText:
                          'Experiencia, fortalezas y tipo de motos que atiende',
                      prefixIcon: Icon(Icons.badge_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (save == true && name.text.trim().isNotEmpty) {
      await _store.save(
        WorkshopMechanic(
          id:
              current?.id ??
              '${widget.workshopId}-${DateTime.now().microsecondsSinceEpoch}',
          workshopId: widget.workshopId,
          name: name.text.trim(),
          specialty: specialty.text.trim().isEmpty
              ? 'Mecánica general'
              : specialty.text.trim(),
          phone: phone.text.trim(),
          bio: bio.text.trim(),
          experienceYears: int.tryParse(experience.text.trim()) ?? 0,
          photoBytes: photoBytes,
          available: current?.available ?? true,
          active: true,
        ),
      );
    }
    name.dispose();
    specialty.dispose();
    phone.dispose();
    bio.dispose();
    experience.dispose();
  }
}

class _WorkshopChatPanel extends StatelessWidget {
  const _WorkshopChatPanel({required this.workshopId, required this.brand});

  final String workshopId;
  final WorkshopBrand brand;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xE8191B1F),
      border: Border.all(color: brand.accentColor.withValues(alpha: .45)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined, color: brand.accentColor),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat con clientes',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Solo aparecen conversaciones iniciadas con este taller.',
                    style: TextStyle(color: Color(0xFFBFC2C7), fontSize: 12),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: const Icon(Icons.lock_outline_rounded, size: 16),
              label: const Text('Privado por taller'),
              side: BorderSide(color: brand.accentColor.withValues(alpha: .5)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<int>(
          valueListenable: LocalChatStore.revision,
          builder: (context, _, _) =>
              FutureBuilder<List<LocalChatConversation>>(
                future: LocalChatStore().listConversations(workshopId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return LinearProgressIndicator(color: brand.accentColor);
                  }
                  final conversations = snapshot.data!;
                  if (conversations.isEmpty) {
                    return const Text(
                      'Todavía no hay conversaciones con clientes.',
                      style: TextStyle(color: Color(0xFFBFC2C7)),
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final conversation in conversations)
                        SizedBox(
                          width: 320,
                          child: ListTile(
                            tileColor: const Color(0xFF22252A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFF3A3E45)),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: brand.accentColor.withValues(
                                alpha: .15,
                              ),
                              foregroundColor: brand.accentColor,
                              child: Text(
                                conversation.clientName.trim().isEmpty
                                    ? 'C'
                                    : conversation.clientName
                                          .trim()[0]
                                          .toUpperCase(),
                              ),
                            ),
                            title: Text(
                              conversation.clientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                _openLocalConversation(context, conversation),
                          ),
                        ),
                    ],
                  );
                },
              ),
        ),
        if (ApiClient.cloudEnabled) ...[
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ChatRepository().watchWorkshopConversations(workshopId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'No fue posible cargar los mensajes en este momento.',
                  style: TextStyle(color: Color(0xFFFF8589)),
                );
              }
              if (!snapshot.hasData) {
                return LinearProgressIndicator(color: brand.accentColor);
              }
              final conversations = snapshot.data!;
              if (conversations.isEmpty) {
                return const Text(
                  'Todavía no hay conversaciones con clientes.',
                  style: TextStyle(color: Color(0xFFBFC2C7)),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final conversation in conversations)
                    SizedBox(
                      width: 300,
                      child: ListTile(
                        tileColor: const Color(0xFF22252A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF3A3E45)),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: brand.accentColor.withValues(
                            alpha: .15,
                          ),
                          foregroundColor: brand.accentColor,
                          child: const Icon(Icons.person_outline_rounded),
                        ),
                        title: const Text(
                          'Cliente del taller',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Conversación ${conversation['client_id'].toString().substring(0, 8)}',
                          maxLines: 1,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openConversation(
                          context,
                          conversation['id'].toString(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );

  Future<void> _openLocalConversation(
    BuildContext context,
    LocalChatConversation conversation,
  ) async {
    final controller = TextEditingController();
    final store = LocalChatStore();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conversación con ${conversation.clientName}'),
        content: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: LocalChatStore.revision,
                  builder: (context, _, _) =>
                      FutureBuilder<List<LocalChatMessage>>(
                        future: store.listMessages(
                          workshopId: workshopId,
                          clientEmail: conversation.clientEmail,
                        ),
                        builder: (context, snapshot) {
                          final messages = snapshot.data ?? const [];
                          if (!snapshot.hasData) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: brand.accentColor,
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final mine = message.sentByWorkshop;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 390,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? brand.accentColor
                                        : const Color(0xFF292C31),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    message.body,
                                    style: TextStyle(
                                      color: mine ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) =>
                          _sendLocalReply(store, conversation, controller),
                      decoration: const InputDecoration(
                        hintText: 'Escribe una respuesta...',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: () =>
                        _sendLocalReply(store, conversation, controller),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _sendLocalReply(
    LocalChatStore store,
    LocalChatConversation conversation,
    TextEditingController controller,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    await store.sendWorkshopMessage(
      workshopId: workshopId,
      workshopName: brand.name,
      clientName: conversation.clientName,
      clientEmail: conversation.clientEmail,
      body: text,
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    String conversationId,
  ) async {
    final repository = ChatRepository();
    await repository.markConversationRead(conversationId);
    if (!context.mounted) return;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conversación con el cliente'),
        content: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repository.watchMessages(conversationId),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? const [];
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: brand.accentColor,
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final mine =
                            message['sender_id'] == repository.currentUserId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 390),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: mine
                                  ? brand.accentColor
                                  : const Color(0xFF292C31),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message['body']?.toString().isNotEmpty == true
                                  ? message['body'].toString()
                                  : 'Archivo adjunto',
                              style: TextStyle(
                                color: mine ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribe una respuesta...',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      await repository.sendMessage(
                        conversationId: conversationId,
                        body: text,
                      );
                      controller.clear();
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _WorkshopClientsPanel extends StatefulWidget {
  const _WorkshopClientsPanel({required this.workshopId, required this.brand});

  final String workshopId;
  final WorkshopBrand brand;

  @override
  State<_WorkshopClientsPanel> createState() => _WorkshopClientsPanelState();
}

class _WorkshopClientsPanelState extends State<_WorkshopClientsPanel> {
  final _service = WorkshopClientsService();
  final _chatStore = LocalChatStore();
  late Future<List<WorkshopClientRecord>> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant _WorkshopClientsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workshopId != widget.workshopId) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<List<WorkshopClientRecord>> _load() async {
    if (widget.workshopId.isEmpty) return const [];
    return _service.list(widget.workshopId);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<WorkshopClientRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final clients = snapshot.data ?? const <WorkshopClientRecord>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: widget.brand.accentColor),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'No fue posible consultar tus clientes.',
                style: TextStyle(color: Color(0xFFFF9A9A)),
              ),
            );
          }
          if (clients.isEmpty) {
            return const Center(
              child: Text(
                'Aún no tienes clientes en tu lista.',
                style: TextStyle(color: Color(0xFFBFC2C7)),
              ),
            );
          }
          return Column(
            children: [
              for (var index = 0; index < clients.length; index++) ...[
                _WorkshopClientRow(
                  client: clients[index],
                  accent: widget.brand.accentColor,
                  onOpenChat: () => _openClientChat(clients[index]),
                  onRemove: () => _removeClient(clients[index]),
                ),
                if (index < clients.length - 1)
                  const Divider(height: 1, color: Color(0xFF30343A)),
              ],
            ],
          );
        },
      );

  Future<void> _openClientChat(WorkshopClientRecord client) async {
    final localMessages = await _chatStore.listMessages(
      workshopId: widget.workshopId,
      clientEmail: client.email,
    );
    if (!mounted) return;
    if (localMessages.isNotEmpty || !ApiClient.cloudEnabled) {
      await _openLocalClientChat(client);
      return;
    }
    try {
      final repository = ChatRepository();
      final conversationId = await repository.openWorkshopConversation(
        workshopId: widget.workshopId,
        clientId: client.userId,
      );
      if (!mounted) return;
      await _openCloudClientChat(client, repository, conversationId);
    } catch (_) {
      if (!mounted) return;
      await _openLocalClientChat(client);
    }
  }

  Future<void> _openLocalClientChat(WorkshopClientRecord client) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(client.fullName),
        content: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: LocalChatStore.revision,
                  builder: (_, _, _) => FutureBuilder<List<LocalChatMessage>>(
                    future: _chatStore.listMessages(
                      workshopId: widget.workshopId,
                      clientEmail: client.email,
                    ),
                    builder: (context, snapshot) {
                      final messages =
                          snapshot.data ?? const <LocalChatMessage>[];
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: widget.brand.accentColor,
                          ),
                        );
                      }
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'Inicia la conversación con este cliente.',
                            style: TextStyle(color: Color(0xFFBFC2C7)),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final mine = message.sentByWorkshop;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 390),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: mine
                                    ? widget.brand.accentColor
                                    : const Color(0xFF292C31),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                message.body,
                                style: TextStyle(
                                  color: mine ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) =>
                          _sendLocalClientMessage(client, controller),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: () =>
                        _sendLocalClientMessage(client, controller),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _sendLocalClientMessage(
    WorkshopClientRecord client,
    TextEditingController controller,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    await _chatStore.sendWorkshopMessage(
      workshopId: widget.workshopId,
      workshopName: widget.brand.name,
      clientName: client.fullName,
      clientEmail: client.email,
      body: text,
    );
  }

  Future<void> _openCloudClientChat(
    WorkshopClientRecord client,
    ChatRepository repository,
    String conversationId,
  ) async {
    await repository.markConversationRead(conversationId);
    if (!mounted) return;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(client.fullName),
        content: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repository.watchMessages(conversationId),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? const [];
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: widget.brand.accentColor,
                        ),
                      );
                    }
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'Inicia la conversación con este cliente.',
                          style: TextStyle(color: Color(0xFFBFC2C7)),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final mine =
                            message['sender_id'] == repository.currentUserId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 390),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: mine
                                  ? widget.brand.accentColor
                                  : const Color(0xFF292C31),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message['body']?.toString().isNotEmpty == true
                                  ? message['body'].toString()
                                  : 'Archivo adjunto',
                              style: TextStyle(
                                color: mine ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) async {
                        await _sendCloudClientMessage(
                          repository,
                          conversationId,
                          controller,
                        );
                      },
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: () => _sendCloudClientMessage(
                      repository,
                      conversationId,
                      controller,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _sendCloudClientMessage(
    ChatRepository repository,
    String conversationId,
    TextEditingController controller,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    await repository.sendMessage(conversationId: conversationId, body: text);
  }

  Future<void> _removeClient(WorkshopClientRecord client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar cliente'),
        content: Text(
          '¿Quieres quitar a ${client.fullName} de tu lista de clientes? El historial del chat no se borrará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.removeFromList(
        workshopId: widget.workshopId,
        clientId: client.userId,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${client.fullName} fue retirado de la lista.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible quitar al cliente. Intenta nuevamente.',
          ),
        ),
      );
    }
  }
}

class _WorkshopClientRow extends StatelessWidget {
  const _WorkshopClientRow({
    required this.client,
    required this.accent,
    required this.onOpenChat,
    required this.onRemove,
  });

  final WorkshopClientRecord client;
  final Color accent;
  final VoidCallback onOpenChat;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final initial = client.fullName.trim().isEmpty
        ? 'C'
        : client.fullName.trim()[0].toUpperCase();
    final phone = client.phone.trim().isEmpty
        ? 'Número de contacto no registrado'
        : client.phone.trim();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      leading: ClipOval(
        child: SizedBox.square(
          dimension: 46,
          child: client.avatarUrl == null
              ? ColoredBox(
                  color: accent.withValues(alpha: .16),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                )
              : Image.network(
                  client.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: accent.withValues(alpha: .16),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
      title: Text(
        client.fullName,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        phone,
        style: const TextStyle(color: Color(0xFFBFC2C7), fontSize: 13),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opciones del cliente',
        onSelected: (value) {
          if (value == 'chat') onOpenChat();
          if (value == 'remove') onRemove();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'chat',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.chat_bubble_outline_rounded),
              title: Text('Enviar mensaje'),
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.person_remove_outlined,
                color: Colors.redAccent,
              ),
              title: Text('Quitar de la lista'),
            ),
          ),
        ],
      ),
      onTap: onOpenChat,
    );
  }
}

class _WorkshopFeedbackPanel extends StatelessWidget {
  const _WorkshopFeedbackPanel({required this.workshopId, required this.brand});

  final String workshopId;
  final WorkshopBrand brand;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xF21B1D21),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF3D4148)),
    ),
    child: ValueListenableBuilder<int>(
      valueListenable: WorkshopFeedbackStore.revision,
      builder: (_, _, _) => FutureBuilder<List<WorkshopFeedback>>(
        future: WorkshopFeedbackStore().list(workshopId),
        builder: (context, snapshot) {
          final feedback = snapshot.data ?? const <WorkshopFeedback>[];
          final average = feedback.isEmpty
              ? 0.0
              : feedback.fold<int>(0, (sum, item) => sum + item.rating) /
                    feedback.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star_rounded, color: brand.accentColor),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Calificaciones del servicio',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (feedback.isNotEmpty)
                    Text(
                      '${average.toStringAsFixed(1)} / 5',
                      style: TextStyle(
                        color: brand.accentColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                feedback.isEmpty
                    ? 'Aún no has recibido valoraciones.'
                    : '${feedback.length} reporte(s) recibido(s)',
                style: const TextStyle(color: Color(0xFFBFC2C7)),
              ),
              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (var index = 0; index < feedback.length; index++) ...[
                  _FeedbackRow(
                    feedback: feedback[index],
                    accent: brand.accentColor,
                  ),
                  if (index < feedback.length - 1)
                    const Divider(color: Color(0xFF34383E)),
                ],
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.feedback, required this.accent});

  final WorkshopFeedback feedback;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final date = feedback.createdAt.toLocal();
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: accent.withValues(alpha: .16),
            foregroundColor: accent,
            child: Text('${feedback.rating}★'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.clientName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${feedback.serviceType} · ${feedback.mechanicName}',
                  style: const TextStyle(
                    color: Color(0xFFC3C6CA),
                    fontSize: 12,
                  ),
                ),
                if (feedback.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(feedback.comment),
                ],
                const SizedBox(height: 3),
                Text(
                  formatted,
                  style: const TextStyle(
                    color: Color(0xFF989DA4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopCommercePanel extends StatefulWidget {
  const _WorkshopCommercePanel({
    required this.workshopId,
    required this.brand,
    this.catalogOnly = false,
  });
  final String workshopId;
  final WorkshopBrand brand;
  final bool catalogOnly;

  @override
  State<_WorkshopCommercePanel> createState() => _WorkshopCommercePanelState();
}

class _WorkshopCommercePanelState extends State<_WorkshopCommercePanel> {
  final _store = CommerceStore();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<CommerceProduct> _products = const [];
  List<CommerceOrder> _orders = const [];
  List<PointOfSaleTicket> _sales = const [];
  List<InventoryMovement> _movements = const [];
  bool _loading = true;
  String _query = '';
  String _category = 'Todos';
  int _section = 0;

  @override
  void initState() {
    super.initState();
    CommerceStore.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    CommerceStore.revision.removeListener(_load);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await _store.listProducts(widget.workshopId);
    final orders = await _store.listOrders(workshopId: widget.workshopId);
    final sales = await _store.listPointOfSaleTickets(widget.workshopId);
    final movements = await _store.listInventoryMovements(widget.workshopId);
    if (!mounted) return;
    setState(() {
      _products = products;
      _orders = orders;
      _sales = sales;
      _movements = movements;
      _loading = false;
    });
  }

  List<CommerceProduct> get _filteredProducts {
    final query = _query.trim().toLowerCase();
    return _products.where((product) {
      final categoryMatches = switch (_category) {
        'Todos' => true,
        'Aceites y filtros' => {
          'Aceites y filtros',
          'Filtros',
          'Aceites',
        }.contains(product.category),
        _ => product.category == _category,
      };
      final value =
          '${product.name} ${product.brand} ${product.barcode} '
                  '${product.sku} ${product.category}'
              .toLowerCase();
      return categoryMatches && (query.isEmpty || value.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) => widget.catalogOnly
      ? _partsCatalog()
      : Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xE8191B1F),
            border: Border.all(
              color: widget.brand.accentColor.withValues(alpha: .45),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final heading = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        color: widget.brand.accentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Inventario, ventas y facturación',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Controla existencias, registra ventas, pedidos y movimientos.',
                              style: TextStyle(
                                color: Color(0xFFBFC2C7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final addProduct = FilledButton.icon(
                    onPressed: () => _addProduct(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registrar producto'),
                  );
                  final newSale = OutlinedButton.icon(
                    onPressed: _openPointOfSale,
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: const Text('Nueva venta'),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [addProduct, newSale],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: heading),
                      addProduct,
                      const SizedBox(width: 8),
                      newSale,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_loading)
                LinearProgressIndicator(color: widget.brand.accentColor)
              else ...[
                _inventorySummary(),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.inventory_2_outlined),
                        label: Text('Inventario'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.point_of_sale_outlined),
                        label: Text('Ventas'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.shopping_bag_outlined),
                        label: Text('Pedidos web'),
                      ),
                      ButtonSegment(
                        value: 3,
                        icon: Icon(Icons.history_rounded),
                        label: Text('Movimientos'),
                      ),
                    ],
                    selected: {_section},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        setState(() => _section = value.first),
                  ),
                ),
                const SizedBox(height: 16),
                if (_section == 0) _inventorySection(),
                if (_section == 1) _salesSection(),
                if (_section == 2) _onlineOrdersSection(),
                if (_section == 3) _movementsSection(),
              ],
            ],
          ),
        );

  Widget _partsCatalog() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xF216181B),
      border: Border.all(
        color: widget.brand.accentColor.withValues(alpha: .42),
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catálogo de Repuestos',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_products.length} ${_products.length == 1 ? 'repuesto' : 'repuestos'} en el catálogo',
                    style: const TextStyle(
                      color: Color(0xFF9CA2AA),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: 'Agregar repuesto',
              onPressed: () => _addProduct(),
              style: IconButton.styleFrom(
                backgroundColor: widget.brand.accentColor,
                foregroundColor: Colors.black,
                fixedSize: const Size(58, 58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 34),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final search = TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: _handleBarcodeSearch,
              decoration: InputDecoration(
                hintText: 'Buscar repuesto por nombre, marca o código...',
                prefixIcon: const Icon(Icons.search_rounded, size: 28),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: const Color(0xFF202328),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF3A3E45)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF3A3E45)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: widget.brand.accentColor,
                    width: 1.5,
                  ),
                ),
              ),
            );
            final scanner = OutlinedButton.icon(
              onPressed: _focusBarcodeScanner,
              icon: const Icon(Icons.barcode_reader),
              label: const Text('Leer código'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(compact ? double.infinity : 150, 56),
                side: BorderSide(color: widget.brand.accentColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
            return compact
                ? Column(
                    children: [
                      search,
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: scanner),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      scanner,
                    ],
                  );
          },
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in const [
                'Todos',
                'Motor',
                'Frenos',
                'Suspensión',
                'Eléctrico',
                'Llantas',
                'Accesorios',
                'Aceites y filtros',
                'Otros',
              ]) ...[
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  selectedColor: widget.brand.accentColor,
                  checkmarkColor: Colors.black,
                  labelStyle: TextStyle(
                    color: _category == category ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: Color(0xFF44484F)),
                  onSelected: (_) => setState(() => _category = category),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          LinearProgressIndicator(color: widget.brand.accentColor)
        else if (_filteredProducts.isEmpty)
          _InventoryEmptyState(
            query: _query,
            accent: widget.brand.accentColor,
            onAdd: () => _addProduct(
              null,
              RegExp(r'^\d{6,}$').hasMatch(_query.trim()) ? _query.trim() : '',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1080
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 480
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final product in _filteredProducts)
                    _catalogProductCard(product, width),
                ],
              );
            },
          ),
      ],
    ),
  );

  Widget _catalogProductCard(CommerceProduct product, double width) =>
      Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F22),
          border: Border.all(color: const Color(0xFF383C42)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.45,
              child: Container(
                color: const Color(0xFF101214),
                child: product.imageBytes != null
                    ? Image.memory(product.imageBytes!, fit: BoxFit.contain)
                    : Center(
                        child: Icon(
                          _catalogIcon(product.category),
                          color: widget.brand.accentColor,
                          size: 58,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    style: TextStyle(
                      color: widget.brand.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (product.brand.isNotEmpty)
                    Text(
                      product.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFA8ADB4)),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    commerceMoney(product.priceCents),
                    style: TextStyle(
                      color: widget.brand.accentColor,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addProduct(product),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 7),
                      IconButton.outlined(
                        tooltip: product.active
                            ? 'Ocultar a clientes'
                            : 'Publicar para clientes',
                        onPressed: () => _store.saveProduct(
                          product.copyWith(active: !product.active),
                        ),
                        color: product.active
                            ? const Color(0xFF39D98A)
                            : Colors.white54,
                        icon: Icon(
                          product.active
                              ? Icons.check_rounded
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      const SizedBox(width: 7),
                      IconButton.outlined(
                        tooltip: 'Eliminar',
                        onPressed: () => _deleteProduct(product),
                        color: const Color(0xFFFF6B72),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  IconData _catalogIcon(String category) => switch (category) {
    'Llantas' => Icons.tire_repair_outlined,
    'Frenos' => Icons.disc_full_outlined,
    'Eléctrico' => Icons.battery_charging_full_rounded,
    'Suspensión' => Icons.settings_input_component_outlined,
    'Accesorios' => Icons.sports_motorsports_outlined,
    'Aceites y filtros' || 'Filtros' => Icons.oil_barrel_outlined,
    _ => Icons.build_outlined,
  };

  Widget _inventorySummary() {
    final inventoryValue = _products.fold<int>(
      0,
      (total, product) => total + product.costPriceCents * product.stock,
    );
    final lowStock = _products.where((product) => product.lowStock).length;
    final units = _products.fold<int>(0, (total, item) => total + item.stock);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _CommerceSummaryChip(
          icon: Icons.category_outlined,
          label: '${_products.length} productos',
          color: widget.brand.accentColor,
        ),
        _CommerceSummaryChip(
          icon: Icons.layers_outlined,
          label: '$units unidades',
          color: const Color(0xFF4AA8FF),
        ),
        _CommerceSummaryChip(
          icon: Icons.warning_amber_rounded,
          label: '$lowStock con bajo stock',
          color: const Color(0xFFFFB020),
        ),
        _CommerceSummaryChip(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Costo ${commerceMoney(inventoryValue)}',
          color: const Color(0xFF20C77A),
        ),
      ],
    );
  }

  Widget _inventorySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (value) => setState(() => _query = value),
          onSubmitted: _handleBarcodeSearch,
          decoration: InputDecoration(
            hintText: 'Buscar por producto, marca, referencia o código...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                IconButton(
                  tooltip: 'Leer con escáner USB o Bluetooth',
                  onPressed: _focusBarcodeScanner,
                  icon: const Icon(Icons.barcode_reader),
                ),
              ],
            ),
            filled: true,
            fillColor: const Color(0xFF23262B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'El lector de códigos USB/Bluetooth escribe el código aquí y confirma con Enter.',
        style: TextStyle(color: Color(0xFF9399A1), fontSize: 11),
      ),
      const SizedBox(height: 16),
      if (_filteredProducts.isEmpty)
        _InventoryEmptyState(
          query: _query,
          accent: widget.brand.accentColor,
          onAdd: () => _addProduct(
            null,
            RegExp(r'^\d{6,}$').hasMatch(_query.trim()) ? _query.trim() : '',
          ),
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 1050
                ? (constraints.maxWidth - 36) / 4
                : constraints.maxWidth >= 720
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth >= 450
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final product in _filteredProducts)
                  _productCard(product, width),
              ],
            );
          },
        ),
    ],
  );

  Widget _productCard(CommerceProduct product, double width) => Container(
    width: width,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF22252A),
      border: Border.all(
        color: product.lowStock
            ? const Color(0xFFFFB020).withValues(alpha: .65)
            : const Color(0xFF3A3E45),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _addProduct(product);
                if (value == 'delete') _deleteProduct(product);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar producto')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
        if (product.brand.isNotEmpty)
          Text(
            product.brand,
            style: TextStyle(
              color: widget.brand.accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          commerceMoney(product.priceCents),
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: product.lowStock
                  ? const Color(0xFFFFB020)
                  : const Color(0xFF20C77A),
            ),
            const SizedBox(width: 6),
            Text(
              '${product.stock} disponibles',
              style: TextStyle(
                color: product.lowStock
                    ? const Color(0xFFFFB020)
                    : const Color(0xFF20C77A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (product.barcode.isNotEmpty) ...[
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.barcode_reader, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  product.barcode,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 22),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Visible para clientes'),
          value: product.active,
          onChanged: (value) =>
              _store.saveProduct(product.copyWith(active: value)),
        ),
      ],
    ),
  );

  Widget _salesSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Ventas presenciales',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          FilledButton.icon(
            onPressed: _openPointOfSale,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Abrir caja'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_sales.isEmpty)
        const _CommerceEmptyMessage(
          icon: Icons.point_of_sale_outlined,
          message: 'Aún no hay ventas presenciales registradas.',
        )
      else
        for (final sale in _sales) _saleRow(sale),
    ],
  );

  Widget _onlineOrdersSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Pedidos de clientes (${_orders.length})',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      if (_orders.isEmpty)
        const _CommerceEmptyMessage(
          icon: Icons.shopping_bag_outlined,
          message: 'Aún no hay compras en línea registradas.',
        )
      else
        for (final order in _orders) _orderRow(order),
    ],
  );

  Widget _movementsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Historial de inventario',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      if (_movements.isEmpty)
        const _CommerceEmptyMessage(
          icon: Icons.history_rounded,
          message:
              'Los movimientos aparecerán al registrar o vender productos.',
        )
      else
        for (final movement in _movements.take(100))
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: CircleAvatar(
              backgroundColor:
                  (movement.quantityDelta >= 0
                          ? const Color(0xFF20C77A)
                          : const Color(0xFFFF6268))
                      .withValues(alpha: .15),
              child: Icon(
                movement.quantityDelta >= 0
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: movement.quantityDelta >= 0
                    ? const Color(0xFF20C77A)
                    : const Color(0xFFFF6268),
              ),
            ),
            title: Text(
              movement.productName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${inventoryMovementLabel(movement.type)} · ${movement.reason}',
            ),
            trailing: Text(
              '${movement.quantityDelta > 0 ? '+' : ''}${movement.quantityDelta}\nSaldo ${movement.balanceAfter}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
    ],
  );

  Widget _saleRow(PointOfSaleTicket sale) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF22252A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF3A3E45)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF20C77A).withValues(alpha: .15),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF20C77A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${sale.invoiceNumber} · ${sale.customerName}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '${sale.totalUnits} unidades · ${sale.paymentMethod}',
                style: const TextStyle(color: Color(0xFFBFC2C7), fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          commerceMoney(sale.totalCents),
          style: TextStyle(
            color: widget.brand.accentColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        IconButton(
          tooltip: 'Imprimir comprobante',
          onPressed: () => _printPointOfSale(sale),
          icon: const Icon(Icons.print_outlined),
        ),
      ],
    ),
  );

  Widget _orderRow(CommerceOrder order) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF22252A),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xFF3A3E45)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: widget.brand.accentColor.withValues(alpha: .15),
          foregroundColor: widget.brand.accentColor,
          child: const Icon(Icons.shopping_bag_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.productName} × ${order.quantity}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${order.clientName} · ${commerceMoney(order.subtotalCents)} · ${commerceStatusLabel(order.status)}',
                style: const TextStyle(color: Color(0xFFBFC2C7), fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Imprimir factura o recibo',
          onPressed: () => _printReceipt(order),
          icon: const Icon(Icons.print_outlined),
        ),
        PopupMenuButton<CommerceOrderStatus>(
          tooltip: 'Actualizar pedido',
          onSelected: (status) => status == CommerceOrderStatus.delivered
              ? _deliver(order)
              : _store.updateOrderStatus(order.id, status),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: CommerceOrderStatus.preparing,
              child: Text('Preparando'),
            ),
            PopupMenuItem(
              value: CommerceOrderStatus.readyForPickup,
              child: Text('Listo para recoger'),
            ),
            PopupMenuItem(
              value: CommerceOrderStatus.delivered,
              child: Text('Validar retiro'),
            ),
            PopupMenuItem(
              value: CommerceOrderStatus.refunded,
              child: Text('Reembolsado'),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _deliver(CommerceOrder order) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validar retiro'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Código del cliente'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Entregar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null) return;
    try {
      await _store.updateOrderStatus(
        order.id,
        CommerceOrderStatus.delivered,
        pickupCode: code,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _printReceipt(CommerceOrder order) async {
    final bytes = await CommerceReceiptService().build(order);
    await Printing.layoutPdf(
      name: 'Factura-${order.receiptNumber}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _deleteProduct(CommerceProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar repuesto'),
        content: Text(
          '¿Eliminar ${product.name}? Dejará de aparecer inmediatamente en la pantalla de los clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.deleteProduct(product.id);
  }

  Future<void> _addProduct([
    CommerceProduct? current,
    String initialBarcode = '',
  ]) async {
    var productImages = current?.photos.toList() ?? <Uint8List>[];
    Uint8List? imageBytes = productImages.isNotEmpty
        ? productImages.first
        : current?.imageBytes;
    final name = TextEditingController(text: current?.name ?? '');
    final brand = TextEditingController(text: current?.brand ?? '');
    final barcode = TextEditingController(
      text: current?.barcode ?? initialBarcode,
    );
    final sku = TextEditingController(text: current?.sku ?? '');
    final description = TextEditingController(text: current?.description ?? '');
    final cost = TextEditingController(
      text: current == null ? '' : (current.costPriceCents ~/ 100).toString(),
    );
    final price = TextEditingController(
      text: current == null ? '' : (current.priceCents ~/ 100).toString(),
    );
    final stock = TextEditingController(text: current?.stock.toString() ?? '');
    final minimumStock = TextEditingController(
      text: current?.minimumStock.toString() ?? '3',
    );
    final supplier = TextEditingController(text: current?.supplier ?? '');
    final location = TextEditingController(text: current?.location ?? '');
    var category = switch (current?.category) {
      'Filtros' || 'Aceites' => 'Aceites y filtros',
      'Transmisión' => 'Otros',
      final value? => value,
      null => 'Motor',
    };
    var visibleForClients = current?.active ?? true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          icon: Icon(
            Icons.inventory_2_outlined,
            color: widget.brand.accentColor,
          ),
          title: Text(
            current == null ? 'Registrar producto' : 'Editar producto',
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: true,
                        withData: true,
                      );
                      final photos =
                          picked?.files
                              .map((file) => file.bytes)
                              .whereType<Uint8List>()
                              .take(4)
                              .toList() ??
                          const <Uint8List>[];
                      if (photos.isEmpty) return;
                      setDialogState(() {
                        productImages = photos;
                        imageBytes = photos.first;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 190,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF15181B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF454A51),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: imageBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.upload_rounded, size: 38),
                                SizedBox(height: 8),
                                Text(
                                  'Subir hasta 4 fotos del repuesto',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'JPG, PNG o WEBP · selecciona la fotografía del producto',
                                  style: TextStyle(
                                    color: Color(0xFF969CA4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                // Muestra la foto completa, sin recortar la
                                // llanta ni cualquier otro repuesto.
                                Image.memory(
                                  imageBytes!,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                ),
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: IconButton.filled(
                                    tooltip: 'Quitar imagen',
                                    onPressed: () => setDialogState(() {
                                      imageBytes = null;
                                      productImages = <Uint8List>[];
                                    }),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xDD111317),
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del producto *',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: brand,
                          decoration: const InputDecoration(
                            labelText: 'Marca *',
                            prefixIcon: Icon(Icons.verified_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcode,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Código de barras',
                            prefixIcon: Icon(Icons.barcode_reader),
                            helperText: 'Escanea o escríbelo manualmente',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: sku,
                          decoration: const InputDecoration(
                            labelText: 'Referencia / SKU',
                            prefixIcon: Icon(Icons.tag_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items:
                        const [
                              'Motor',
                              'Frenos',
                              'Suspensión',
                              'Llantas',
                              'Eléctrico',
                              'Accesorios',
                              'Aceites y filtros',
                              'Otros',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setDialogState(() => category = value ?? category),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio de venta COP *',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción para el cliente',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: visibleForClients,
                    title: const Text(
                      'Publicar para clientes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Aparecerá en la pantalla de repuestos del taller.',
                    ),
                    onChanged: (value) =>
                        setDialogState(() => visibleForClients = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar producto'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      final productName = name.text.trim();
      final productBrand = brand.text.trim();
      final salePrice = int.tryParse(price.text) ?? 0;
      if (productName.isEmpty || productBrand.isEmpty || salePrice <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Completa nombre, marca y precio de venta.'),
            ),
          );
        }
      } else {
        final normalizedBarcode = barcode.text.trim();
        final duplicate = normalizedBarcode.isEmpty
            ? null
            : await _store.findByBarcode(widget.workshopId, normalizedBarcode);
        if (duplicate != null && duplicate.id != current?.id) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'El código de barras ya pertenece a ${duplicate.name}.',
                ),
              ),
            );
          }
        } else {
          await _store.saveProduct(
            CommerceProduct(
              id: current?.id ?? CommerceStore.newProductId(),
              workshopId: widget.workshopId,
              name: productName,
              brand: productBrand,
              barcode: normalizedBarcode,
              sku: sku.text.trim(),
              category: category,
              description: description.text.trim(),
              costPriceCents: current?.costPriceCents ?? 0,
              priceCents: salePrice * 100,
              // El catálogo público no obliga a administrar bodega. Los
              // productos nuevos se publican con una unidad disponible.
              stock: current?.stock ?? 1,
              minimumStock: current?.minimumStock ?? 0,
              supplier: current?.supplier ?? '',
              location: current?.location ?? '',
              active: visibleForClients,
              imagePath: current?.imagePath,
              imageBytes: imageBytes,
              imageGallery: productImages,
            ),
            movementReason: current == null
                ? 'Registro inicial del producto'
                : 'Actualización manual del producto',
          );
        }
      }
    }
    name.dispose();
    brand.dispose();
    barcode.dispose();
    sku.dispose();
    description.dispose();
    cost.dispose();
    price.dispose();
    stock.dispose();
    minimumStock.dispose();
    supplier.dispose();
    location.dispose();
  }

  void _focusBarcodeScanner() {
    _searchController.clear();
    setState(() => _query = '');
    _searchFocusNode.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Lector listo: escanea el producto y el código aparecerá en la búsqueda.',
        ),
      ),
    );
  }

  Future<void> _handleBarcodeSearch(String value) async {
    final product = await _store.findByBarcode(widget.workshopId, value.trim());
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value.trim().isEmpty
                ? 'Escribe o escanea un código.'
                : 'No existe un producto con el código ${value.trim()}.',
          ),
          action: value.trim().isEmpty
              ? null
              : SnackBarAction(
                  label: 'REGISTRAR',
                  onPressed: () => _addProduct(null, value.trim()),
                ),
        ),
      );
      return;
    }
    _searchController.text = product.barcode;
    setState(() => _query = product.barcode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} · ${product.brand} · ${commerceMoney(product.priceCents)} · ${product.stock} disponibles',
        ),
      ),
    );
  }

  Future<void> _printPointOfSale(PointOfSaleTicket sale) async {
    final bytes = await CommerceReceiptService().buildPointOfSale(sale);
    await Printing.layoutPdf(
      name: 'Venta-${sale.invoiceNumber}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _openPointOfSale() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero registra un producto.')),
      );
      return;
    }
    final quantities = <String, int>{};
    final search = TextEditingController();
    final customerName = TextEditingController();
    final customerDocument = TextEditingController();
    final customerPhone = TextEditingController();
    final discount = TextEditingController(text: '0');
    var paymentMethod = 'Efectivo';
    var productQuery = '';
    var processing = false;
    final sale = await showDialog<PointOfSaleTicket>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final available = _products.where((item) {
            if (item.stock <= 0) return false;
            final query = productQuery.trim().toLowerCase();
            if (query.isEmpty) return true;
            return '${item.name} ${item.brand} ${item.barcode} ${item.sku}'
                .toLowerCase()
                .contains(query);
          }).toList();
          final total = _products.fold<int>(
            0,
            (sum, item) => sum + item.priceCents * (quantities[item.id] ?? 0),
          );
          final units = quantities.values.fold<int>(0, (a, b) => a + b);
          final discountCents = (int.tryParse(discount.text) ?? 0) * 100;
          final payable = (total - discountCents).clamp(0, total);
          void addScanned(String value) {
            final scanned = _products.where(
              (item) => item.barcode.isNotEmpty && item.barcode == value.trim(),
            );
            if (scanned.isEmpty) {
              setDialogState(() => productQuery = value);
              return;
            }
            final product = scanned.first;
            if ((quantities[product.id] ?? 0) < product.stock) {
              setDialogState(() {
                quantities[product.id] = (quantities[product.id] ?? 0) + 1;
                search.clear();
                productQuery = '';
              });
            }
          }

          return AlertDialog(
            icon: Icon(
              Icons.point_of_sale_rounded,
              color: widget.brand.accentColor,
            ),
            title: const Text('Venta presencial'),
            content: SizedBox(
              width: 820,
              height: 620,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        TextField(
                          controller: search,
                          autofocus: true,
                          onChanged: (value) =>
                              setDialogState(() => productQuery = value),
                          onSubmitted: addScanned,
                          decoration: const InputDecoration(
                            hintText: 'Escanea o busca producto o marca...',
                            prefixIcon: Icon(Icons.barcode_reader),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: available.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No se encontró el producto en el inventario.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: available.length,
                                  separatorBuilder: (_, _) => const Divider(),
                                  itemBuilder: (_, index) {
                                    final product = available[index];
                                    final quantity =
                                        quantities[product.id] ?? 0;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${product.brand} · ${commerceMoney(product.priceCents)} · ${product.stock} disponibles',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: quantity > 0
                                                ? () => setDialogState(
                                                    () =>
                                                        quantities[product.id] =
                                                            quantity - 1,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 25,
                                            child: Text(
                                              '$quantity',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: quantity < product.stock
                                                ? () => setDialogState(
                                                    () =>
                                                        quantities[product.id] =
                                                            quantity + 1,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 28),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Datos de la venta',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: customerName,
                            decoration: const InputDecoration(
                              labelText: 'Cliente',
                              hintText: 'Consumidor final',
                            ),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: customerDocument,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Documento (opcional)',
                            ),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: customerPhone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Celular (opcional)',
                            ),
                          ),
                          const SizedBox(height: 9),
                          DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Medio de pago',
                            ),
                            items:
                                const [
                                      'Efectivo',
                                      'Nequi',
                                      'Daviplata',
                                      'Tarjeta',
                                      'Transferencia',
                                      'Mercado Pago',
                                      'Otro',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) => setDialogState(
                              () => paymentMethod = value ?? paymentMethod,
                            ),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: discount,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Descuento COP',
                            ),
                          ),
                          const Divider(height: 28),
                          Text('$units unidades'),
                          const SizedBox(height: 5),
                          Text('Subtotal: ${commerceMoney(total)}'),
                          if (discountCents > 0)
                            Text('Descuento: -${commerceMoney(discountCents)}'),
                          const SizedBox(height: 8),
                          Text(
                            'TOTAL ${commerceMoney(payable)}',
                            style: TextStyle(
                              color: widget.brand.accentColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: units == 0 || processing
                    ? null
                    : () async {
                        setDialogState(() => processing = true);
                        try {
                          final ticket = await _store.completePointOfSale(
                            workshopId: widget.workshopId,
                            workshopName: widget.brand.name,
                            quantities: quantities,
                            customerName: customerName.text,
                            customerDocument: customerDocument.text,
                            customerPhone: customerPhone.text,
                            paymentMethod: paymentMethod,
                            discountCents: discountCents,
                          );
                          if (context.mounted) Navigator.pop(context, ticket);
                        } catch (error) {
                          setDialogState(() => processing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                icon: processing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(processing ? 'Registrando...' : 'Cobrar y guardar'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    customerName.dispose();
    customerDocument.dispose();
    customerPhone.dispose();
    discount.dispose();
    if (sale == null || !mounted) return;
    setState(() => _section = 1);
    final print = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF20C77A)),
        title: const Text('Venta registrada'),
        content: Text(
          '${sale.invoiceNumber}\n${sale.totalUnits} unidades · ${commerceMoney(sale.totalCents)}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir comprobante'),
          ),
        ],
      ),
    );
    if (print == true) await _printPointOfSale(sale);
  }
}

class _CommerceSummaryChip extends StatelessWidget {
  const _CommerceSummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({
    required this.query,
    required this.accent,
    required this.onAdd,
  });
  final String query;
  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xFF22252A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF3A3E45)),
    ),
    child: Column(
      children: [
        Icon(Icons.search_off_rounded, size: 42, color: accent),
        const SizedBox(height: 10),
        Text(
          query.trim().isEmpty
              ? 'Aún no hay productos registrados'
              : 'No se encontró “${query.trim()}”',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Puedes registrar el producto y asignarle marca, precio, existencias y código de barras.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFAEB3BA)),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Registrar producto'),
        ),
      ],
    ),
  );
}

class _CommerceEmptyMessage extends StatelessWidget {
  const _CommerceEmptyMessage({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF22252A),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, size: 36, color: const Color(0xFF8F959D)),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFBFC2C7)),
        ),
      ],
    ),
  );
}

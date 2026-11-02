import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/client/client_profile.dart';
import '../../core/location/colombia_locations.dart';
import '../../core/networking/api_client.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/tenant/tenant_model.dart';
import '../../core/workshops/workshop.dart';
import '../../core/workshops/client_workshop_history_store.dart';
import '../../core/workshops/client_workshop_search.dart';
import '../../core/workshops/local_workshop_directory_store.dart';
import '../../core/workshops/workshop_repository.dart';
import '../../core/workshops/workshop_identity.dart';
import '../dashboard/client_dashboard_screen.dart';

const _orange = Color(0xFFFF6500);
const _panel = Color(0xF21B1D20);

class ClientWorkshopSelectionScreen extends StatefulWidget {
  const ClientWorkshopSelectionScreen({
    super.key,
    required this.profile,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
  });
  final ClientProfile profile;
  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<ClientWorkshopSelectionScreen> createState() => _ScreenState();
}

class _ScreenState extends State<ClientWorkshopSelectionScreen> {
  final _repository = WorkshopRepository();
  final _history = ClientWorkshopHistoryStore();
  final _search = TextEditingController();
  final _municipalitySearch = TextEditingController();
  late Future<List<Workshop>> _future;
  String? _department;
  String? _entering;
  List<String> _historyIds = const [];
  List<String> _hiddenIds = const [];
  List<Workshop> _lastItems = const [];
  bool _showSuggestions = true;
  bool _loadInProgress = false;
  bool _reloadQueued = false;
  Timer? _refreshTimer;
  RealtimeChannel? _workshopChannel;

  @override
  void initState() {
    super.initState();
    _future = _requestDirectory();
    _search.addListener(_changed);
    _municipalitySearch.addListener(_changed);
    LocalWorkshopDirectoryStore.revision.addListener(_directoryChanged);
    if (ApiClient.cloudEnabled) {
      _workshopChannel = ApiClient().client
          .channel('client-workshop-directory')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'workshops',
            callback: (_) => _reload(),
          )
          .subscribe();
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _entering == null) _reload();
    });
  }

  @override
  void dispose() {
    _search.removeListener(_changed);
    _search.dispose();
    _municipalitySearch.removeListener(_changed);
    _municipalitySearch.dispose();
    LocalWorkshopDirectoryStore.revision.removeListener(_directoryChanged);
    _refreshTimer?.cancel();
    final channel = _workshopChannel;
    if (channel != null) {
      unawaited(ApiClient().client.removeChannel(channel));
    }
    super.dispose();
  }

  void _changed() => setState(() => _showSuggestions = true);
  void _reload() {
    if (_loadInProgress) {
      _reloadQueued = true;
      return;
    }
    setState(() => _future = _requestDirectory());
  }

  Future<List<Workshop>> _requestDirectory() {
    _loadInProgress = true;
    return _loadDirectory().whenComplete(() {
      _loadInProgress = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        scheduleMicrotask(_reload);
      }
    });
  }

  void _directoryChanged() {
    if (mounted) _reload();
  }

  Future<List<Workshop>> _loadDirectory() async {
    final results = await Future.wait([
      _repository.listActive(),
      _history.list(widget.profile.email),
      _history.listHidden(widget.profile.email),
    ]);
    // Only keep workshops selected explicitly by this client in this app.
    // Cloud links created by older versions must not surface as if the client
    // had searched for them.
    _historyIds = results[1] as List<String>;
    _hiddenIds = results[2] as List<String>;
    final workshops = _uniqueWorkshops(results[0] as List<Workshop>);
    _lastItems = workshops;
    return workshops;
  }

  List<String> get _departments => colombiaLocations.keys.toList()..sort();

  bool get _locationSearchReady =>
      _department != null && _municipalitySearch.text.trim().isNotEmpty;

  bool get _searchReady =>
      _locationSearchReady || _search.text.trim().isNotEmpty;

  List<Workshop> _uniqueWorkshops(List<Workshop> items) {
    return canonicalWorkshops(items, preferredIds: _historyIds.toSet());
  }

  List<Workshop> _filter(List<Workshop> items) {
    return filterWorkshopsForClientSearch(
      workshops: items,
      department: _department,
      municipality: _municipalitySearch.text,
      query: _search.text,
      hiddenIds: _hiddenIds,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/workshop_login_background_v1.png',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x85000000), Color(0x4D000000), Color(0xB8000000)],
            ),
          ),
        ),
        SafeArea(
          child: FutureBuilder<List<Workshop>>(
            future: _future,
            initialData: _lastItems,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Workshop>[];
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    sliver: SliverToBoxAdapter(child: Center(child: _topBar())),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 34, 22, 42),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1160),
                          child: _content(snapshot, items),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _topBar() {
    final firstName = widget.profile.fullName.trim().split(' ').first;
    final compact = MediaQuery.sizeOf(context).width < 620;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1320),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xF217191C),
          border: Border.all(color: const Color(0xFF3A3D41)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Volver a tipos de acceso',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.handyman_rounded, color: _orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                compact ? 'Talleres' : 'DIRECTORIO DE TALLERES',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!compact) ...[
              const Text(
                'Elige tu taller',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 18),
            ],
            _Avatar(profile: widget.profile),
            const SizedBox(width: 9),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 62 : 130),
              child: Text(firstName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    AsyncSnapshot<List<Workshop>> snapshot,
    List<Workshop> items,
  ) {
    final shown = _filter(items);
    final suggestions = _search.text.trim().isEmpty
        ? const <Workshop>[]
        : shown.take(5).toList();
    // The quick-access list is useful only before searching. Once the client
    // provides a location or text query, show exclusively the matching public
    // directory results; a saved workshop from another city must not appear.
    final remembered = _searchReady
        ? const <Workshop>[]
        : _historyIds
              .map((id) => items.where((item) => item.id == id).firstOrNull)
              .whereType<Workshop>()
              .where((item) => !_hiddenIds.contains(item.id))
              .toList();
    final registered = shown
        .where((item) => !remembered.any((saved) => saved.id == item.id))
        .toList();
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige tu taller',
          style: TextStyle(
            fontSize: compact ? 32 : 40,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecciona el taller donde deseas gestionar tu moto.',
          style: TextStyle(color: Color(0xFFD1D2D4), fontSize: 17),
        ),
        const SizedBox(height: 26),
        Stack(
          clipBehavior: Clip.none,
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, departamento, municipio o barrio',
                prefixIcon: const Icon(Icons.search_rounded, size: 29),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: const Color(0xF2222428),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                border: _inputBorder(),
                enabledBorder: _inputBorder(),
                focusedBorder: _inputBorder(_orange),
              ),
            ),
            if (_showSuggestions && suggestions.isNotEmpty)
              Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: _WorkshopSuggestions(
                  workshops: suggestions,
                  onSelected: _selectSuggestion,
                ),
              ),
          ],
        ),
        if (_showSuggestions && suggestions.isNotEmpty)
          SizedBox(height: suggestions.length * 68.0 + 12),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final filtersWidth = constraints.maxWidth >= 760
                ? 660.0
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: filtersWidth,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _clearFilters,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xEF222428),
                            side: const BorderSide(color: Color(0xFF4B4E53)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Todos',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: _FilterButton(
                          width: double.infinity,
                          label: _department ?? 'Departamento',
                          active: _department != null,
                          enabled: true,
                          onPressed: () => _pick(
                            title: 'Selecciona el departamento',
                            values: _departments,
                            selected: _department,
                            onSelected: (value) => setState(() {
                              _department = value;
                              _municipalitySearch.clear();
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            controller: _municipalitySearch,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Municipio',
                              hintStyle: const TextStyle(
                                color: Color(0xFF909399),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              suffixIcon: _municipalitySearch.text.isEmpty
                                  ? const Icon(
                                      Icons.edit_outlined,
                                      color: Color(0xFF9A9DA2),
                                    )
                                  : IconButton(
                                      tooltip: 'Limpiar municipio',
                                      onPressed: _municipalitySearch.clear,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              filled: true,
                              fillColor: const Color(0xF225272B),
                              border: _inputBorder(),
                              enabledBorder: _inputBorder(),
                              focusedBorder: _inputBorder(_orange),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        if (remembered.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.bookmark_added_outlined, color: _orange),
              SizedBox(width: 9),
              Text(
                'Tus talleres',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Accede rápidamente a los talleres que elegiste anteriormente.',
            style: TextStyle(color: Color(0xFFBFC1C5)),
          ),
          const SizedBox(height: 12),
          _workshopCards(remembered),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Resultados de búsqueda',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            if (snapshot.hasData && _searchReady)
              Text(
                '${shown.length} ${shown.length == 1 ? 'taller' : 'talleres'}',
                style: const TextStyle(color: Color(0xFFD0D1D3)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (snapshot.connectionState != ConnectionState.done && items.isEmpty)
          const _StatePanel.loading()
        else if (snapshot.hasError && items.isEmpty)
          _StatePanel.error(onAction: _reload)
        else if (items.isEmpty)
          const _StatePanel.empty('Todavía no hay talleres disponibles.')
        else if (!_searchReady)
          const _StatePanel.empty(
            'Selecciona el departamento y escribe el municipio, o busca por nombre, ubicación o barrio.',
          )
        else if (shown.isEmpty)
          _StatePanel.empty(
            _municipalitySearch.text.trim().isEmpty
                ? 'No encontramos talleres con esos filtros.'
                : 'No se encontraron talleres registrados en ${_municipalitySearch.text.trim()}, ${_department ?? ''}.',
            onAction: _clearFilters,
          )
        else if (registered.isEmpty)
          const _StatePanel.empty(
            'Los talleres disponibles ya aparecen en Tus talleres.',
          )
        else
          _workshopCards(registered),
      ],
    );
  }

  Widget _workshopCards(List<Workshop> workshops) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900 ? 2 : 1;
      final cardWidth = columns == 2
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth > 580
          ? 580.0
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final workshop in workshops)
            SizedBox(
              width: cardWidth,
              child: _WorkshopRow(
                workshop: workshop,
                loading: _entering == workshop.id,
                onPressed: () => _open(workshop),
                onHide: () => _removeFromHistory(workshop),
              ),
            ),
        ],
      );
    },
  );

  OutlineInputBorder _inputBorder([Color color = const Color(0xFF4A4D52)]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  void _clearFilters() {
    _search.clear();
    _municipalitySearch.clear();
    setState(() {
      _department = null;
    });
  }

  void _selectSuggestion(Workshop workshop) {
    _search.value = TextEditingValue(
      text: workshop.name,
      selection: TextSelection.collapsed(offset: workshop.name.length),
    );
    _municipalitySearch.text = workshop.municipality;
    setState(() {
      _department = workshop.department;
      _showSuggestions = false;
    });
  }

  Future<void> _pick({
    required String title,
    required List<String> values,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) =>
          _FilterDialog(title: title, values: values, selected: selected),
    );
    if (!mounted || result == _FilterDialog.cancelled) return;
    onSelected(result as String?);
  }

  Future<void> _open(Workshop workshop) async {
    if (_entering != null) return;
    final isLocalProfile = widget.profile.userId?.startsWith('local:') ?? false;
    if (!_repository.isAuthenticated && !isLocalProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirma tu correo e inicia sesión para entrar al taller.',
          ),
        ),
      );
      return;
    }
    setState(() => _entering = workshop.id);
    try {
      try {
        await _repository.joinAsClient(workshop.id);
      } catch (_) {
        // Local access must not be blocked while cloud synchronization is
        // temporarily unavailable. The selection remains stored on-device.
      }
      await _history.remember(widget.profile.email, workshop.id);
      if (!_historyIds.contains(workshop.id)) {
        _historyIds = [workshop.id, ..._historyIds];
      }
      await widget.tenantContext.setTenant(
        Tenant(tenantId: workshop.id, name: workshop.name),
      );
      final brand = WorkshopBrand(
        name: workshop.name,
        tagline: workshop.tagline,
        logoIndex: workshop.logoIndex,
        accentColorValue: workshop.accentColorValue,
        customLogoBytes: workshop.logoBytes,
        customLogoFileName: workshop.logoBytes == null ? null : 'logo_taller',
      );
      widget.brandController.value = brand;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClientDashboardScreen(
            brand: brand,
            workshop: workshop,
            profile: widget.profile,
            tenantContext: widget.tenantContext,
            brandController: widget.brandController,
            authController: widget.authController,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible entrar al taller.')),
        );
      }
    } finally {
      if (mounted) setState(() => _entering = null);
    }
  }

  Future<void> _removeFromHistory(Workshop workshop) async {
    await _history.remove(widget.profile.email, workshop.id);
    await _history.hide(widget.profile.email, workshop.id);
    if (!mounted) return;
    setState(() {
      _historyIds = _historyIds.where((id) => id != workshop.id).toList();
      _hiddenIds = {..._hiddenIds, workshop.id}.toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${workshop.name} se quitó de Tus talleres.')),
    );
    try {
      await _repository.leaveAsClient(workshop.id);
    } catch (_) {
      // The local choice is immediate; the next connected refresh retries the
      // remote state without putting the workshop back on screen.
    }
  }
}

class _WorkshopSuggestions extends StatelessWidget {
  const _WorkshopSuggestions({
    required this.workshops,
    required this.onSelected,
  });

  final List<Workshop> workshops;
  final ValueChanged<Workshop> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF202328),
        border: Border.all(color: const Color(0xFF55595F)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < workshops.length; index++) ...[
            ListTile(
              dense: true,
              leading: const Icon(Icons.storefront_outlined, color: _orange),
              title: Text(
                workshops[index].name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${workshops[index].municipality}, ${workshops[index].department}'
                '${workshops[index].neighborhood.isEmpty ? '' : ' · ${workshops[index].neighborhood}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.north_west_rounded, size: 18),
              onTap: () => onSelected(workshops[index]),
            ),
            if (index != workshops.length - 1)
              const Divider(height: 1, color: Color(0xFF3B3E43)),
          ],
        ],
      ),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    this.width = 270,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });
  final double width;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 50,
    child: OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? const Color(0xFFFF7A22) : Colors.white,
        backgroundColor: const Color(0xEF222428),
        side: BorderSide(color: active ? _orange : const Color(0xFF4B4E53)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    ),
  );
}

class _WorkshopRow extends StatelessWidget {
  const _WorkshopRow({
    required this.workshop,
    required this.loading,
    required this.onPressed,
    required this.onHide,
  });
  final Workshop workshop;
  final bool loading;
  final VoidCallback onPressed;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final narrow = constraints.maxWidth < 480;
        final available = workshop.hasPlatformAccess;
        final scheduled = workshop.openingHours.isNotEmpty;
        final open = scheduled && workshop.isOpenNow;
        final canEnter = available && (!scheduled || open);
        final status = !available
            ? 'Acceso desactivado'
            : scheduled
            ? (open ? 'Abierto ahora' : 'Cerrado por horario')
            : 'Horario no configurado';
        final statusColor = !available
            ? const Color(0xFFFFBF3C)
            : !scheduled
            ? const Color(0xFFB8BBC0)
            : open
            ? const Color(0xFF2DDB7F)
            : const Color(0xFFFF4D45);
        final button = _EnterButton(
          loading: loading,
          label: !available
              ? 'No disponible'
              : scheduled && !open
              ? 'No disponible por horario'
              : 'Entrar al taller',
          onPressed: canEnter ? onPressed : null,
          compact: compact,
        );
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: const Color(0xF51A1D21),
            border: Border.all(
              color: workshop.accentColor.withValues(alpha: .52),
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: workshop.accentColor.withValues(alpha: .08),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Logo(workshop: workshop, size: 48),
                        const SizedBox(width: 10),
                        Expanded(child: _Identity(workshop: workshop)),
                        _WorkshopMenu(
                          canEnter: canEnter,
                          onEnter: onPressed,
                          onHide: onHide,
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFF35383D)),
                    if (narrow) ...[
                      _Status(label: status, color: statusColor),
                      const SizedBox(height: 9),
                      _Location(workshop: workshop),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: button),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _Location(workshop: workshop)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 180,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _Status(
                                    label: status,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                button,
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                )
              : Row(
                  children: [
                    _Logo(workshop: workshop, size: 62),
                    const SizedBox(width: 15),
                    SizedBox(width: 210, child: _Identity(workshop: workshop)),
                    const SizedBox(width: 15),
                    Expanded(child: _Location(workshop: workshop)),
                    const SizedBox(width: 15),
                    SizedBox(
                      width: 150,
                      child: _Status(label: status, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(width: 184, child: button),
                    const SizedBox(width: 4),
                    _WorkshopMenu(
                      canEnter: canEnter,
                      onEnter: onPressed,
                      onHide: onHide,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _WorkshopMenu extends StatelessWidget {
  const _WorkshopMenu({
    required this.canEnter,
    required this.onEnter,
    required this.onHide,
  });

  final bool canEnter;
  final VoidCallback onEnter;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Opciones del taller',
    icon: const Icon(Icons.more_vert_rounded),
    onSelected: (value) {
      if (value == 'enter') {
        onEnter();
      } else if (value == 'hide') {
        onHide();
      }
    },
    itemBuilder: (context) => [
      PopupMenuItem<String>(
        value: 'enter',
        enabled: canEnter,
        child: const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.login_rounded, color: _orange),
          title: Text('Entrar al taller'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'hide',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.visibility_off_outlined),
          title: Text('Quitar'),
        ),
      ),
    ],
  );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.workshop});
  final Workshop workshop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        workshop.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        workshop.rating > 0
            ? '★ ${workshop.rating.toStringAsFixed(1)} (${workshop.reviewCount})'
            : workshop.tagline.trim().isEmpty
            ? 'Taller registrado'
            : workshop.tagline,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: workshop.rating > 0
              ? const Color(0xFFFF7108)
              : const Color(0xFFC7C9CC),
        ),
      ),
    ],
  );
}

class _Location extends StatelessWidget {
  const _Location({required this.workshop});
  final Workshop workshop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ContactLine(
        icon: Icons.location_on_outlined,
        text: workshop.locationLine.isEmpty
            ? 'Ubicación pendiente'
            : workshop.locationLine,
      ),
      const SizedBox(height: 5),
      _ContactLine(
        icon: Icons.phone_outlined,
        text: workshop.phone.isEmpty ? 'Teléfono pendiente' : workshop.phone,
        emphasized: workshop.phone.isNotEmpty,
      ),
      const SizedBox(height: 5),
      _ContactLine(
        icon: Icons.route_outlined,
        text: workshop.address.isEmpty
            ? 'Dirección pendiente'
            : workshop.address,
      ),
      if (workshop.email.isNotEmpty) ...[
        const SizedBox(height: 5),
        _ContactLine(icon: Icons.alternate_email_rounded, text: workshop.email),
      ],
    ],
  );
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });
  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: emphasized ? _orange : const Color(0xFFB5B7BB),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: emphasized ? Colors.white : const Color(0xFFD1D2D4),
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      border: Border.all(color: color.withValues(alpha: .42)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EnterButton extends StatelessWidget {
  const _EnterButton({
    required this.loading,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });
  final bool loading;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 40 : 42,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _orange,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
          : Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({required this.workshop, required this.size});
  final Workshop workshop;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF0D0E10),
      shape: BoxShape.circle,
      border: Border.all(color: workshop.accentColor, width: 2),
    ),
    child: workshop.logoBytes != null
        ? Image.memory(workshop.logoBytes!, fit: BoxFit.cover)
        : workshop.logoUrl == null
        ? Icon(
            workshopLogoOptions[workshop.logoIndex.clamp(
              0,
              workshopLogoOptions.length - 1,
            )],
            color: workshop.accentColor,
            size: size * .45,
          )
        : Image.network(
            workshop.logoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              Icons.handyman_rounded,
              color: workshop.accentColor,
              size: size * .45,
            ),
          ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});
  final ClientProfile profile;
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: _orange, width: 2),
    ),
    child: ClipOval(
      child: profile.profilePhotoBytes != null
          ? Image.memory(profile.profilePhotoBytes!, fit: BoxFit.cover)
          : const ColoredBox(
              color: Color(0xFF2A2C30),
              child: Icon(Icons.person_rounded, color: Colors.white),
            ),
    ),
  );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel.loading()
    : message = 'Cargando talleres...',
      onAction = null,
      loading = true;
  const _StatePanel.error({required this.onAction})
    : message = 'No fue posible cargar los talleres.',
      loading = false;
  const _StatePanel.empty(this.message, {this.onAction}) : loading = false;
  final String message;
  final VoidCallback? onAction;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: const Color(0xFF3C3F43)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        if (loading)
          const CircularProgressIndicator(color: _orange)
        else
          const Icon(Icons.storefront_outlined, color: _orange, size: 40),
        const SizedBox(height: 12),
        Text(message),
        if (onAction != null) ...[
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: onAction,
            child: const Text('Reintentar o limpiar filtros'),
          ),
        ],
      ],
    ),
  );
}

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({
    required this.title,
    required this.values,
    required this.selected,
  });
  static const cancelled = Object();
  final String title;
  final List<String> values;
  final String? selected;
  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final shown = widget.values.where(
      (value) => value.toLowerCase().contains(query),
    );
    return Dialog(
      backgroundColor: const Color(0xFF1A1C1F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF4B4E53)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () =>
                        Navigator.pop(context, _FilterDialog.cancelled),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Escribe para buscar',
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: const Text('Todos'),
                      selected: widget.selected == null,
                      onTap: () => Navigator.pop(context),
                    ),
                    for (final value in shown)
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(value),
                        selected: value == widget.selected,
                        selectedColor: _orange,
                        onTap: () => Navigator.pop(context, value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

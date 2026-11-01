import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/local_workshop_admin_store.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/branding/workshop_dashboard_preferences.dart';
import '../../core/location/colombia_locations.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/tenant/tenant_model.dart';
import '../../core/workshops/local_workshop_directory_store.dart';
import '../../core/workshops/workshop.dart';
import '../../core/workshops/workshop_repository.dart';
import '../dashboard/admin_dashboard_screen.dart';

/// Personalización protegida: solo se muestra después de validar la sesión del
/// administrador del taller.
class AdminCustomizationScreen extends StatefulWidget {
  const AdminCustomizationScreen({
    super.key,
    required this.brandController,
    this.authController,
    required this.tenantContext,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController? authController;
  final TenantContext tenantContext;

  @override
  State<AdminCustomizationScreen> createState() =>
      _AdminCustomizationScreenState();
}

class _AdminCustomizationScreenState extends State<AdminCustomizationScreen> {
  static const _colors = [
    0xFFFF6200,
    0xFF00B8D9,
    0xFF8E5BFF,
    0xFF20C77A,
    0xFFE83E8C,
  ];
  static const _maxLogoBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late final TextEditingController _municipalityController;
  late final TextEditingController _neighborhoodController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _opensController;
  late final TextEditingController _closesController;
  String? _department;
  late int _logoIndex;
  late int _colorValue;
  Uint8List? _logoBytes;
  String? _logoFileName;
  bool _isPickingLogo = false;
  bool _isSaving = false;
  double _textScale = 1;
  double _dashboardBrightness = 1;
  bool _compactMode = false;

  @override
  void initState() {
    super.initState();
    final brand = widget.brandController.value;
    _nameController = TextEditingController(text: brand.name);
    _taglineController = TextEditingController(text: brand.tagline);
    _municipalityController = TextEditingController();
    _neighborhoodController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _opensController = TextEditingController(text: '08:00');
    _closesController = TextEditingController(text: '18:00');
    _logoIndex = brand.logoIndex;
    _colorValue = brand.accentColorValue;
    _logoBytes = brand.customLogoBytes;
    _logoFileName = brand.customLogoFileName;
    _loadWorkshopDetails();
    _loadDashboardPreferences();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _municipalityController.dispose();
    _neighborhoodController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _opensController.dispose();
    _closesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_colorValue);
    return Scaffold(
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
                colors: [Color(0xE8000000), Color(0xC9000000)],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth >= 800 ? 48 : 20,
                  18,
                  constraints.maxWidth >= 800 ? 48 : 20,
                  32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 50,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: const Color(0xE8191A1E),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: accent.withValues(alpha: .75),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 28,
                                  offset: Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Volver',
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Personaliza tu taller',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Configura la identidad que verán tus clientes.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: .72,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _AdminPill(accent: accent),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  LayoutBuilder(
                                    builder: (context, layout) {
                                      final wide = layout.maxWidth >= 720;
                                      final details = _detailsForm(
                                        accent: accent,
                                      );
                                      final identity = _identityPicker(
                                        accent: accent,
                                      );
                                      return wide
                                          ? Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: details),
                                                const SizedBox(width: 28),
                                                Expanded(child: identity),
                                              ],
                                            )
                                          : Column(
                                              children: [
                                                details,
                                                const SizedBox(height: 28),
                                                identity,
                                              ],
                                            );
                                    },
                                  ),
                                  const SizedBox(height: 28),
                                  _LivePreview(accent: accent),
                                  const SizedBox(height: 28),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: _continueWithoutSaving,
                                        child: const Text('Omitir por ahora'),
                                      ),
                                      const Spacer(),
                                      FilledButton.icon(
                                        onPressed: _isSaving
                                            ? null
                                            : _saveAndContinue,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: accent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 16,
                                          ),
                                        ),
                                        icon: _isSaving
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: Colors.black,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
                                              ),
                                        label: Text(
                                          _isSaving
                                              ? 'Guardando...'
                                              : 'Guardar y continuar',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsForm({required Color accent}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          icon: Icons.storefront_outlined,
          title: 'Datos del negocio',
        ),
        const SizedBox(height: 16),
        _BrandTextField(
          controller: _nameController,
          label: 'Nombre del taller',
          icon: Icons.storefront_outlined,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Ingresa el nombre de tu taller.'
              : null,
        ),
        const SizedBox(height: 20),
        const _SectionLabel(
          icon: Icons.location_on_outlined,
          title: 'Ubicación y contacto',
        ),
        const SizedBox(height: 14),
        _SelectionField(
          label: 'Departamento',
          value: _department,
          icon: Icons.map_outlined,
          values: colombiaLocations.keys.toList()..sort(),
          onChanged: (value) => setState(() {
            _department = value;
            _municipalityController.clear();
          }),
        ),
        const SizedBox(height: 12),
        _BrandTextField(
          controller: _municipalityController,
          label: 'Ciudad o municipio',
          icon: Icons.location_city_outlined,
          validator: _required('Escribe la ciudad o el municipio.'),
        ),
        const SizedBox(height: 12),
        _BrandTextField(
          controller: _neighborhoodController,
          label: 'Barrio',
          icon: Icons.holiday_village_outlined,
          validator: _required('Ingresa el barrio.'),
        ),
        const SizedBox(height: 12),
        _BrandTextField(
          controller: _addressController,
          label: 'Dirección',
          icon: Icons.signpost_outlined,
          validator: _required('Ingresa la dirección.'),
        ),
        const SizedBox(height: 12),
        _BrandTextField(
          controller: _phoneController,
          label: 'Teléfono o celular del taller',
          icon: Icons.phone_outlined,
          validator: _required('Ingresa un teléfono de contacto.'),
        ),
        const SizedBox(height: 12),
        _BrandTextField(
          controller: _emailController,
          label: 'Correo del taller (opcional)',
          icon: Icons.alternate_email_rounded,
          validator: (value) {
            final email = value?.trim() ?? '';
            return email.isNotEmpty && !email.contains('@')
                ? 'Ingresa un correo válido.'
                : null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _WorkshopTimeField(
                label: 'Abre',
                value: _formatTime12h(_opensController.text),
                onTap: () => _pickWorkshopTime(_opensController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _WorkshopTimeField(
                label: 'Cierra',
                value: _formatTime12h(_closesController.text),
                onTap: () => _pickWorkshopTime(_closesController),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BrandTextField(
          controller: _taglineController,
          label: 'Descripción corta',
          icon: Icons.short_text_rounded,
        ),
        const SizedBox(height: 24),
        const _SectionLabel(
          icon: Icons.palette_outlined,
          title: 'Color principal',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final colorValue in _colors)
              _ColorChoice(
                colorValue: colorValue,
                selected: _colorValue == colorValue,
                onTap: () => setState(() => _colorValue = colorValue),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Este color se aplica a botones, bordes y elementos destacados.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .58),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 26),
        const _SectionLabel(
          icon: Icons.tune_rounded,
          title: 'Comodidad visual del panel',
        ),
        const SizedBox(height: 14),
        _AppearanceSlider(
          icon: Icons.format_size_rounded,
          title: 'Tamaño de letra',
          valueLabel: '${(_textScale * 100).round()} %',
          value: _textScale,
          min: .85,
          max: 1.25,
          divisions: 8,
          accent: accent,
          onChanged: (value) => setState(() => _textScale = value),
        ),
        const SizedBox(height: 12),
        _AppearanceSlider(
          icon: Icons.brightness_6_outlined,
          title: 'Brillo del panel',
          valueLabel: '${(_dashboardBrightness * 100).round()} %',
          value: _dashboardBrightness,
          min: .72,
          max: 1.15,
          divisions: 9,
          accent: accent,
          onChanged: (value) => setState(() => _dashboardBrightness = value),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          value: _compactMode,
          activeThumbColor: accent,
          activeTrackColor: accent.withValues(alpha: .42),
          title: const Text(
            'Vista compacta',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Muestra más información en pantallas pequeñas.',
          ),
          secondary: Icon(Icons.view_compact_alt_outlined, color: accent),
          onChanged: (value) => setState(() => _compactMode = value),
        ),
      ],
    );
  }

  Widget _identityPicker({required Color accent}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          icon: Icons.image_outlined,
          title: 'Logo del taller',
        ),
        const SizedBox(height: 16),
        Center(
          child: _LogoPreview(
            accent: accent,
            logoBytes: _logoBytes,
            icon: workshopLogoOptions[_logoIndex],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isPickingLogo ? null : _pickLogo,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _isPickingLogo
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: Text(
              _isPickingLogo
                  ? 'Abriendo archivos...'
                  : 'Cargar logo desde archivos',
            ),
          ),
        ),
        if (_logoFileName != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _logoFileName!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'O elige uno de los logos incluidos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < workshopLogoOptions.length; index++)
              ChoiceChip(
                label: Icon(
                  workshopLogoOptions[index],
                  color: _logoIndex == index
                      ? Colors.white
                      : const Color(0xFFC4C4C4),
                ),
                selected: _logoIndex == index && _logoBytes == null,
                selectedColor: accent,
                backgroundColor: const Color(0xFF292B30),
                onSelected: (_) => setState(() {
                  _logoIndex = index;
                  _logoBytes = null;
                  _logoFileName = null;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickLogo() async {
    setState(() => _isPickingLogo = true);
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || selection == null) return;
      final file = selection.files.single;
      if (file.bytes == null) {
        _showMessage(
          'No fue posible leer el logo seleccionado. Intenta nuevamente.',
        );
        return;
      }
      if (file.bytes!.lengthInBytes > _maxLogoBytes) {
        _showMessage('El logo debe pesar menos de 5 MB.');
        return;
      }
      setState(() {
        _logoBytes = file.bytes;
        _logoFileName = file.name;
      });
    } catch (_) {
      if (mounted) _showMessage('No se pudo abrir el selector de archivos.');
    } finally {
      if (mounted) setState(() => _isPickingLogo = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_timeValidator(_opensController.text) != null ||
        _timeValidator(_closesController.text) != null) {
      _showMessage('Selecciona una hora válida de apertura y cierre.');
      return;
    }
    if (_department == null || _municipalityController.text.trim().isEmpty) {
      _showMessage('Selecciona el departamento y escribe el municipio.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final creatingWorkshop = widget.tenantContext.currentTenantId.isEmpty;
      if (creatingWorkshop) {
        final repository = WorkshopRepository();
        final workshop = await repository.create(
          name: _nameController.text,
          slug: _slugify(_nameController.text),
          tagline: _taglineController.text,
          accentColor: _colorValue,
          logoIndex: _logoIndex,
          department: _department!,
          municipality: _municipalityController.text.trim(),
          neighborhood: _neighborhoodController.text,
          address: _addressController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          openingHours: _openingHours,
        );
        await widget.tenantContext.setTenant(
          Tenant(tenantId: workshop.id, name: workshop.name),
        );
      }
      if (creatingWorkshop) {
        final associationError = await LocalWorkshopAdminStore()
            .attachWorkshopToActiveAccount(
              tenantId: widget.tenantContext.currentTenantId,
              tenantName: _nameController.text,
            );
        if (associationError != null && AuthService().currentUser == null) {
          throw StateError(associationError);
        }
      }
      await widget.brandController.updateBrand(
        tenantId: widget.tenantContext.currentTenantId,
        name: _nameController.text,
        tagline: _taglineController.text,
        logoIndex: _logoIndex,
        accentColorValue: _colorValue,
        customLogoBytes: _logoBytes,
        customLogoFileName: _logoFileName,
        clearCustomLogo: _logoBytes == null,
      );
      await const WorkshopDashboardPreferencesStore().save(
        widget.tenantContext.currentTenantId,
        WorkshopDashboardPreferences(
          textScale: _textScale,
          brightness: _dashboardBrightness,
          compactMode: _compactMode,
        ),
      );
      final directory = LocalWorkshopDirectoryStore();
      final previous = await directory.find(
        widget.tenantContext.currentTenantId,
      );
      final now = DateTime.now();
      await WorkshopRepository().save(
        Workshop(
          id: widget.tenantContext.currentTenantId,
          name: _nameController.text.trim(),
          slug: previous?.slug ?? _slugify(_nameController.text),
          tagline: _taglineController.text.trim(),
          accentColorValue: _colorValue,
          logoIndex: _logoIndex,
          logoBytes: _logoBytes,
          logoFileName: _logoFileName,
          department: _department!,
          municipality: _municipalityController.text.trim(),
          neighborhood: _neighborhoodController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          openingHours: _openingHours,
          accessStatus: previous?.accessStatus ?? 'trial',
          trialStartedAt: previous?.trialStartedAt ?? now,
          trialEndsAt:
              previous?.trialEndsAt ?? now.add(const Duration(days: 3)),
          permanentAccess: previous?.permanentAccess ?? false,
        ),
      );
      await _openDashboard();
    } catch (error) {
      if (!mounted) return;
      _showMessage(_saveErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _saveErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('papelera')) {
      return 'Este taller está en la papelera. Restáuralo desde el panel del propietario.';
    }
    if (message.contains('failed to fetch') ||
        message.contains('network') ||
        message.contains('socketexception')) {
      return 'No pudimos conectar con la base de datos. Revisa tu conexión e inténtalo de nuevo.';
    }
    if (message.contains('auth') || message.contains('sesion')) {
      return 'Tu sesión venció. Inicia sesión nuevamente para guardar el taller.';
    }
    return 'No fue posible guardar el taller. Tus datos no se perdieron; inténtalo nuevamente.';
  }

  Map<String, dynamic> get _openingHours => {
    for (final day in const [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ])
      day: {
        'open': _opensController.text.trim(),
        'close': _closesController.text.trim(),
      },
    'sunday': {'closed': true},
  };

  String? Function(String?) _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

  String? _timeValidator(String? value) =>
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Usa HH:MM';

  Future<void> _pickWorkshopTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts.first) ?? 8,
            minute: int.tryParse(parts.last) ?? 0,
          )
        : const TimeOfDay(hour: 8, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Selecciona la hora',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    controller.text =
        '${selected.hour.toString().padLeft(2, '0')}:'
        '${selected.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  String _formatTime12h(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return value;
    final hour = int.tryParse(parts.first);
    final minute = int.tryParse(parts.last);
    if (hour == null || minute == null) return value;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'a. m.' : 'p. m.';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _loadWorkshopDetails() async {
    final id = widget.tenantContext.currentTenantId;
    if (id.isEmpty) return;
    final workshop = await LocalWorkshopDirectoryStore().find(id);
    if (workshop == null || !mounted) return;
    setState(() {
      _department = workshop.department.isEmpty ? null : workshop.department;
      _municipalityController.text = workshop.municipality;
      _neighborhoodController.text = workshop.neighborhood;
      _addressController.text = workshop.address;
      _phoneController.text = workshop.phone;
      _emailController.text = workshop.email;
      final monday = workshop.openingHours['monday'];
      if (monday is Map) {
        _opensController.text = monday['open']?.toString() ?? '08:00';
        _closesController.text = monday['close']?.toString() ?? '18:00';
      }
    });
  }

  Future<void> _loadDashboardPreferences() async {
    final id = widget.tenantContext.currentTenantId;
    if (id.isEmpty) return;
    final preferences = await const WorkshopDashboardPreferencesStore().load(
      id,
    );
    if (!mounted) return;
    setState(() {
      _textScale = preferences.textScale;
      _dashboardBrightness = preferences.brightness;
      _compactMode = preferences.compactMode;
    });
  }

  String _slugify(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '$normalized-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _continueWithoutSaving() async {
    if (widget.tenantContext.currentTenantId.isEmpty) {
      await _saveAndContinue();
      return;
    }
    _openDashboard();
  }

  Future<void> _openDashboard() async {
    final localAccount = await LocalWorkshopAdminStore().loadAccount();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminDashboardScreen(
          brandController: widget.brandController,
          userName:
              AuthService().currentUser?.email ??
              localAccount?.fullName ??
              'Administrador del taller',
          tenantContext: widget.tenantContext,
          localAdminStore: LocalWorkshopAdminStore(),
        ),
      ),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _AdminPill extends StatelessWidget {
  const _AdminPill({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_outlined, color: accent, size: 18),
        const SizedBox(width: 6),
        const Text(
          'Administrador',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 9),
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _WorkshopTimeField extends StatelessWidget {
  const _WorkshopTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.schedule_rounded),
        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        filled: true,
        fillColor: const Color(0xFF292B30),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF44484E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF44484E)),
        ),
      ),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class _BrandTextField extends StatelessWidget {
  const _BrandTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    textCapitalization: TextCapitalization.words,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFF292B30),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final IconData icon;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value:${values.length}'),
    initialValue: values.contains(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFF292B30),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    items: values
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: values.isEmpty ? null : onChanged,
    validator: (selected) =>
        selected == null || selected.isEmpty ? 'Selecciona una opción.' : null,
  );
}

class _AppearanceSlider extends StatelessWidget {
  const _AppearanceSlider({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accent,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    decoration: BoxDecoration(
      color: const Color(0xFF24262B),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                valueLabel,
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: accent,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });
  final int colorValue;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: 3,
        ),
      ),
      child: selected ? const Icon(Icons.check, color: Colors.white) : null,
    ),
  );
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.accent,
    required this.logoBytes,
    required this.icon,
  });
  final Color accent;
  final Uint8List? logoBytes;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 112,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF121317),
      border: Border.all(color: accent, width: 2),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: .40), blurRadius: 20),
      ],
    ),
    child: ClipOval(
      child: logoBytes == null
          ? Icon(icon, color: Colors.white, size: 55)
          : Image.memory(logoBytes!, fit: BoxFit.cover),
    ),
  );
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xA6111215),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 48,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vista previa',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'Los cambios se aplicarán a la bienvenida y al panel.',
                style: TextStyle(color: Color(0xFFCFCFCF), fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.visibility_outlined, color: accent),
      ],
    ),
  );
}

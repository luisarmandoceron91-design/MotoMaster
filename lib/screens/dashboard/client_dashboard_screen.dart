import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/chat/chat_attachment_actions.dart';
import '../../core/chat/local_chat_store.dart';
import '../../core/client/client_profile.dart';
import '../../core/client/client_profile_repository.dart';
import '../../core/client/appointment_calendar.dart';
import '../../core/client/client_service_store.dart';
import '../../core/client/local_client_profile_store.dart';
import '../../core/commerce/commerce_models.dart';
import '../../core/commerce/product_gallery.dart';
import '../../core/commerce/commerce_receipt_service.dart';
import '../../core/commerce/commerce_store.dart';
import '../../core/networking/api_client.dart';
import '../../core/staff/workshop_mechanic_store.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/workshops/workshop.dart';
import '../access/role_access_screen.dart';
import '../../core/workshops/workshop_feedback_store.dart';
import '../auth/account_recovery_screen.dart';
import '../auth/client_registration/client_registration_screen.dart';
import '../settings/credential_settings_screen.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({
    super.key,
    required this.brand,
    required this.workshop,
    required this.profile,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
  });

  final WorkshopBrand brand;
  final Workshop workshop;
  final ClientProfile profile;
  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientSettingsScreen extends StatefulWidget {
  const _ClientSettingsScreen({
    required this.profile,
    required this.workshop,
    required this.brand,
    required this.onEdit,
    required this.onChangePassword,
    required this.onRecovery,
  });

  final ClientProfile profile;
  final Workshop workshop;
  final WorkshopBrand brand;
  final VoidCallback onEdit;
  final VoidCallback onChangePassword;
  final VoidCallback onRecovery;

  @override
  State<_ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<_ClientSettingsScreen> {
  bool notifications = true;

  @override
  Widget build(BuildContext context) {
    final accent = widget.brand.accentColor;
    return Scaffold(
      backgroundColor: const Color(0xFF090C0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151A1F),
        titleSpacing: 0,
        title: Row(
          children: [
            _Logo(workshop: widget.workshop, brand: widget.brand, size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.workshop.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Perfil y configuración',
                  style: TextStyle(color: accent, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Badge(
              smallSize: 7,
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: .42,
            child: Image.asset(
              'assets/images/workshop_login_background_v1.png',
              fit: BoxFit.cover,
            ),
          ),
          const ColoredBox(color: Color(0x99070A0D)),
          SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mi perfil y configuración',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Gestiona tu cuenta, seguridad y preferencias',
                      style: TextStyle(color: Color(0xFFC0C5CB)),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: _settingsDecoration(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 650;
                          final avatar = Column(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: accent.withValues(alpha: .16),
                                backgroundImage:
                                    widget.profile.profilePhotoBytes != null
                                    ? MemoryImage(
                                        widget.profile.profilePhotoBytes!,
                                      )
                                    : (widget.profile.avatarUrl?.trim().isNotEmpty ?? false)
                                    ? NetworkImage(widget.profile.avatarUrl!)
                                    : null,
                                child: widget.profile.profilePhotoBytes == null &&
                                        !(widget.profile.avatarUrl?.trim().isNotEmpty ?? false)
                                    ? Icon(
                                        Icons.person_rounded,
                                        color: accent,
                                        size: 48,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: widget.onEdit,
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 18,
                                ),
                                label: const Text('Cambiar foto'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accent,
                                ),
                              ),
                            ],
                          );
                          final fields = Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _SettingsField(
                                label: 'Nombre completo',
                                value: widget.profile.fullName,
                                width: compact
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 170) / 2,
                              ),
                              _SettingsField(
                                label: 'Usuario',
                                value: widget.profile.email.split('@').first,
                                width: compact
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 170) / 2,
                              ),
                              _SettingsField(
                                label: 'Correo electrónico',
                                value: widget.profile.email,
                                width: compact
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 170) / 2,
                                verified: true,
                              ),
                              _SettingsField(
                                label: 'Celular',
                                value: widget.profile.phone,
                                width: compact
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 170) / 2,
                              ),
                            ],
                          );
                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label('INFORMACIÓN DE PERFIL'),
                                const SizedBox(height: 14),
                                Center(child: avatar),
                                const SizedBox(height: 14),
                                fields,
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Label('INFORMACIÓN DE PERFIL'),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 145, child: avatar),
                                  const SizedBox(width: 18),
                                  Expanded(child: fields),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: _settingsDecoration(),
                      child: SwitchListTile(
                        value: notifications,
                        onChanged: (value) =>
                            setState(() => notifications = value),
                        secondary: const Icon(Icons.notifications_none_rounded),
                        activeThumbColor: accent,
                        title: const Text(
                          'Preferencias',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Recibe notificaciones sobre citas, servicios y novedades del taller.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: _settingsDecoration(),
                      child: Column(
                        children: [
                          const ListTile(
                            leading: Icon(Icons.shield_outlined),
                            title: Text(
                              'Seguridad y acceso',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              'Mantén tu cuenta segura y administra el acceso.',
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFF343A40)),
                          ListTile(
                            onTap: widget.onChangePassword,
                            leading: const Icon(Icons.key_outlined),
                            title: const Text('Cambiar contraseña'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                          ListTile(
                            leading: const Icon(Icons.mark_email_read_outlined),
                            title: const Text('Verificación de correo'),
                            trailing: const _VerifiedBadge(),
                          ),
                          ListTile(
                            onTap: widget.onRecovery,
                            leading: const Icon(Icons.restart_alt_rounded),
                            title: const Text('Recuperar cuenta'),
                            subtitle: Text(widget.profile.email),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                          const ListTile(
                            leading: Icon(Icons.devices_outlined),
                            title: Text('Dispositivos con sesión abierta'),
                            trailing: Text('1 dispositivo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar cambios'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Para eliminar la cuenta debes confirmar tu identidad con soporte.',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Eliminar mi cuenta'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5D67),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: 0,
        onDestinationSelected: (_) => Navigator.pop(context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Citas',
          ),
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            label: 'Mi moto',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Repuestos',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Soporte',
          ),
        ],
      ),
    );
  }

  BoxDecoration _settingsDecoration() => BoxDecoration(
    color: const Color(0xF0171C20),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFF363C43)),
  );
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.label,
    required this.value,
    required this.width,
    this.verified = false,
  });
  final String label;
  final String value;
  final double width;
  final bool verified;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB0B5BC), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF20262B),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF414850)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? 'Pendiente' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (verified)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF31DB75),
                  size: 18,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF0B6B4A),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Verificado',
      style: TextStyle(
        color: Color(0xFF65F2BA),
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PartsPage extends StatefulWidget {
  const _PartsPage({
    required this.accent,
    required this.workshop,
    required this.clientId,
    required this.clientName,
    required this.onOpenSupport,
  });
  final Color accent;
  final Workshop workshop;
  final String clientId;
  final String clientName;
  final ValueChanged<CommerceProduct> onOpenSupport;

  @override
  State<_PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends State<_PartsPage> {
  final _store = CommerceStore();
  final _search = TextEditingController();
  var _category = 'Todos';
  List<CommerceProduct> _products = const [];
  List<CommerceOrder> _orders = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    CommerceStore.revision.addListener(_reload);
    _reload();
  }

  Future<void> _reload() async {
    final products = await _store.listProducts(widget.workshop.id);
    final orders = await _store.listOrders(
      workshopId: widget.workshop.id,
      clientId: widget.clientId,
    );
    if (!mounted) return;
    setState(() {
      _products = products;
      _orders = orders;
      _loading = false;
    });
  }

  @override
  void dispose() {
    CommerceStore.revision.removeListener(_reload);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _products.where((item) {
      final searchable =
          '${item.name} ${item.brand} ${item.sku} ${item.barcode} ${item.description}'
              .toLowerCase();
      final categoryMatches = switch (_category) {
        'Todos' => true,
        'Aceites y filtros' => {
          'Aceites y filtros',
          'Filtros',
          'Aceites',
        }.contains(item.category),
        _ => item.category == _category,
      };
      return item.active &&
          categoryMatches &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
    return _Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 170),
            padding: const EdgeInsets.all(24),
            alignment: Alignment.bottomLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF343A40)),
              image: const DecorationImage(
                image: AssetImage(
                  'assets/images/workshop_login_background_v1.png',
                ),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                colorFilter: ColorFilter.mode(
                  Color(0x66000000),
                  BlendMode.darken,
                ),
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repuestos',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Catálogo disponible en este taller',
                  style: TextStyle(color: Color(0xFFD2D6DA)),
                ),
              ],
            ),
          ),
          if (_orders.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mis pedidos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${_orders.length}',
                  style: TextStyle(color: widget.accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final order in _orders.take(3)) _orderCard(order),
          ],
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, marca o referencia',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: const Color(0xF21B2025),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF414850)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF414850)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.accent, width: 1.5),
                ),
              ),
            ),
          ),
          if (query.isNotEmpty && visible.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF20252B),
                  border: Border.all(color: const Color(0xFF414850)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (final suggestion in visible.take(5))
                      ListTile(
                        dense: true,
                        leading: Icon(
                          _productIcon(suggestion.category),
                          color: widget.accent,
                        ),
                        title: Text(
                          suggestion.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          suggestion.brand.isEmpty
                              ? suggestion.category
                              : '${suggestion.brand} · ${suggestion.category}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          commerceMoney(suggestion.priceCents),
                          style: TextStyle(
                            color: widget.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onTap: () => _showProductDetails(suggestion),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in const [
                  'Todos',
                  'Motor',
                  'Frenos',
                  'Suspensión',
                  'Llantas',
                  'Eléctrico',
                  'Accesorios',
                  'Aceites y filtros',
                  'Otros',
                ]) ...[
                  ChoiceChip(
                    label: Text(item),
                    selected: _category == item,
                    onSelected: (_) => setState(() => _category = item),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            Center(child: CircularProgressIndicator(color: widget.accent))
          else if (visible.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
              decoration: BoxDecoration(
                color: const Color(0xEF171C20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF363C43)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: widget.accent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aún no hay repuestos publicados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cuando el taller agregue productos a su inventario aparecerán aquí automáticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFA8ADB4)),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (_, constraints) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 560
                      ? 2
                      : 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth > 900
                      ? .70
                      : constraints.maxWidth > 560
                      ? .82
                      : .68,
                ),
                itemBuilder: (_, index) {
                  final part = visible[index];
                  final previewPhoto = part.photos.isEmpty
                      ? null
                      : part.photos.first;
                  return Material(
                    color: const Color(0xEE191B1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF363940)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showProductDetails(part),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: SizedBox(
                                width: double.infinity,
                                child: previewPhoto != null
                                    ? GestureDetector(
                                        onTap: () => showProductGallery(
                                          context,
                                          photos: part.photos,
                                          accent: widget.accent,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: ColoredBox(
                                            color: const Color(0xFF101317),
                                            child: Image.memory(
                                              previewPhoto,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.high,
                                              errorBuilder: (_, _, _) => Icon(
                                                _productIcon(part.category),
                                                color: widget.accent,
                                                size: 52,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          _productIcon(part.category),
                                          color: widget.accent,
                                          size: 52,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    part.category.toUpperCase(),
                                    style: TextStyle(
                                      color: widget.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    part.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (part.brand.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      part.brand,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFB8BDC4),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 5),
                                  Text(
                                    commerceMoney(part.priceCents),
                                    style: TextStyle(
                                      color: widget.accent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    part.stock > 0
                                        ? '${part.stock} disponibles'
                                        : 'Agotado',
                                    style: TextStyle(
                                      color: part.stock > 0
                                          ? const Color(0xFF43D99B)
                                          : const Color(0xFFFF6670),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: part.available
                                          ? () => _checkout(part)
                                          : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: widget.accent,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: const Text('Comprar'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  IconData _productIcon(String category) => switch (category) {
    'Llantas' => Icons.tire_repair_outlined,
    'Frenos' => Icons.disc_full_outlined,
    'Eléctrico' => Icons.battery_charging_full_rounded,
    'Suspensión' => Icons.settings_input_component_outlined,
    'Accesorios' => Icons.sports_motorsports_outlined,
    'Aceites y filtros' || 'Filtros' => Icons.oil_barrel_outlined,
    _ => Icons.build_outlined,
  };

  Future<void> _showProductDetails(CommerceProduct product) async {
    final photos = product.photos;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171B20),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .9,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _Handle(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GestureDetector(
                      onTap: () => showProductGallery(
                        sheetContext,
                        photos: photos,
                        accent: widget.accent,
                      ),
                      child: SizedBox(
                      height: 310,
                      child: photos.isEmpty
                          ? Center(
                              child: Icon(
                                _productIcon(product.category),
                                color: widget.accent,
                                size: 92,
                              ),
                            )
                          : Image.memory(
                              photos.first,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                    ),
                    ),
                    if (photos.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${photos.length} fotos publicadas',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB7BBC2)),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (product.brand.isNotEmpty)
                      Text(
                        'Marca: ${product.brand}',
                        style: const TextStyle(color: Color(0xFFB7BBC2)),
                      ),
                    if (product.sku.isNotEmpty)
                      Text(
                        'Referencia: ${product.sku}',
                        style: const TextStyle(color: Color(0xFFB7BBC2)),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      commerceMoney(product.priceCents),
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product.description.isEmpty
                          ? 'Sin descripción adicional.'
                          : product.description,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _showFullProductDetails(
                        sheetContext,
                        product,
                      ),
                      icon: const Icon(Icons.article_outlined),
                      label: const Text('Ver detalles del producto'),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onOpenSupport(product);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Preguntar al taller'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: product.available
                          ? () {
                              Navigator.pop(sheetContext);
                              _checkout(product);
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accent,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: const Text('Elegir cantidad y comprar'),
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

  Future<void> _showFullProductDetails(
    BuildContext context,
    CommerceProduct product,
  ) async {
    final rows = <(String, String)>[
      ('Marca', product.brand.isEmpty ? 'No especificada' : product.brand),
      if (product.partNumber.isNotEmpty)
        ('Número de pieza', product.partNumber),
      if (product.sku.isNotEmpty) ('Referencia / SKU', product.sku),
      if (product.packageWeight.isNotEmpty)
        ('Peso del paquete', product.packageWeight),
      ('Condición', product.productCondition),
      if (product.origin.isNotEmpty) ('Origen', product.origin),
      if (product.oemCode.isNotEmpty) ('Código OEM', product.oemCode),
      ('Incluye pistones', product.includesPistons ? 'Sí' : 'No'),
      ('Incluye aros', product.includesRings ? 'Sí' : 'No'),
      ('Es kit', product.isKit ? 'Sí' : 'No'),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1E23),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const _Handle(),
              const SizedBox(height: 18),
              const Text('Detalles del producto', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(product.description.isEmpty ? 'El taller no agregó una descripción adicional.' : product.description),
              const SizedBox(height: 24),
              const Text('Características principales', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3E454D)), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    for (var index = 0; index < rows.length; index++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        color: index.isOdd ? const Color(0xFF22272D) : null,
                        child: Row(children: [
                          Expanded(child: Text(rows[index].$1, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Expanded(child: Text(rows[index].$2, textAlign: TextAlign.right)),
                        ]),
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

  Widget _orderCard(CommerceOrder order) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xEE191B1E),
      border: Border.all(color: const Color(0xFF363940)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.receipt_long_outlined, color: widget.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.productName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                commerceStatusLabel(order.status),
                style: const TextStyle(color: Color(0xFFB7BBC2), fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _shareReceipt(order),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Comprobante'),
        ),
      ],
    ),
  );

  Future<void> _checkout(CommerceProduct product) async {
    var quantity = 1;
    var method = 'Mercado Pago';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1E22),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Handle(),
                  const SizedBox(height: 16),
                  Text(
                    'Comprar ${product.name}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Retiro en ${widget.workshop.name}',
                    style: const TextStyle(color: Color(0xFFB7BBC2)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cantidad',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${product.stock} disponibles',
                              style: const TextStyle(
                                color: Color(0xFFB7BBC2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Restar una unidad',
                        onPressed: quantity > 1
                            ? () => setModalState(() => quantity--)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Sumar una unidad',
                        onPressed: () => setModalState(() => quantity++),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                    ),
                    items:
                        const [
                              'Mercado Pago',
                              'PSE / bancos',
                              'Efecty',
                              'Tarjeta débito o crédito',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => method = value ?? method,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total a pagar'),
                              Text(
                                '$quantity × ${commerceMoney(product.priceCents)}',
                                style: const TextStyle(
                                  color: Color(0xFFB7BBC2),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          commerceMoney(product.priceCents * quantity),
                          style: TextStyle(
                            color: widget.accent,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Pagar de forma segura'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Modo de pruebas: no se realizará un cobro real hasta conectar las credenciales productivas.',
                    style: TextStyle(color: Color(0xFF9EA3AA), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      final order = await _store.createSandboxPurchase(
        product: product,
        workshopName: widget.workshop.name,
        clientId: widget.clientId,
        clientName: widget.clientName,
        quantity: quantity,
        paymentMethod: method,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pago de prueba aprobado. Código de retiro: ${order.pickupCode}',
          ),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _shareReceipt(CommerceOrder order) async {
    final bytes = await CommerceReceiptService().build(order);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${order.receiptNumber}.pdf',
    );
  }
}

class _SupportPage extends StatefulWidget {
  const _SupportPage({
    required this.workshop,
    required this.accent,
    required this.profile,
    this.productQuestion,
  });
  final Workshop workshop;
  final Color accent;
  final ClientProfile profile;
  final CommerceProduct? productQuestion;

  @override
  State<_SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<_SupportPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatEntry>[];
  final _chatRepository = ChatRepository();
  final _localChatStore = LocalChatStore();
  List<LocalChatMessage> _localMessages = const [];
  String? _conversationId;
  bool _connecting = false;
  String? _sentProductQuestionId;

  @override
  void initState() {
    super.initState();
    LocalChatStore.revision.addListener(_localChatChanged);
    _loadLocalMessages();
    _connectConversation();
  }

  @override
  void didUpdateWidget(covariant _SupportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.productQuestion?.id != oldWidget.productQuestion?.id) {
      _sendProductQuestionWhenReady();
    }
  }

  @override
  void dispose() {
    LocalChatStore.revision.removeListener(_localChatChanged);
    _controller.dispose();
    super.dispose();
  }

  void _localChatChanged() => _loadLocalMessages();

  Future<void> _loadLocalMessages() async {
    final messages = await _localChatStore.listMessages(
      workshopId: widget.workshop.id,
      clientEmail: widget.profile.email,
    );
    if (mounted) setState(() => _localMessages = messages);
  }

  Future<void> _connectConversation() async {
    if (!ApiClient.cloudEnabled || _chatRepository.currentUserId == null) {
      return;
    }
    setState(() => _connecting = true);
    try {
      final id = await _chatRepository.openConversation(
        workshopId: widget.workshop.id,
      );
      if (mounted) {
        setState(() => _conversationId = id);
        _sendProductQuestionWhenReady();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El chat seguirá disponible localmente hasta recuperar la conexión.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _sendProductQuestionWhenReady() async {
    final product = widget.productQuestion;
    final conversationId = _conversationId;
    if (product == null || conversationId == null || _sentProductQuestionId == product.id) {
      return;
    }
    _sentProductQuestionId = product.id;
    final reference = product.partNumber.isNotEmpty
        ? product.partNumber
        : product.sku.isNotEmpty
        ? product.sku
        : product.barcode;
    final text = 'Tengo una pregunta sobre el producto: ${product.name}'
        '${product.brand.isEmpty ? '' : ' · ${product.brand}'}'
        '${reference.isEmpty ? '' : ' · Referencia: $reference'}.';
    _controller.text = text;
    await _send();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showPhoto = constraints.maxWidth >= 760;
            final conversation = Container(
              decoration: BoxDecoration(
                color: const Color(0xF20E1216),
                border: Border.all(color: const Color(0xFF353B42)),
              ),
              child: Column(
                children: [
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF171C21),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF343A40)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.handyman_outlined,
                            color: widget.accent,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.workshop.name.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: Color(0xFF31DB75),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'En línea',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFB6BBC2),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        const Center(child: _DayChip()),
                        if (_connecting)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_conversationId != null)
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _chatRepository.watchMessages(
                              _conversationId!,
                            ),
                            builder: (context, snapshot) {
                              final messages = snapshot.data ?? const [];
                              if (messages.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 28),
                                  child: Text(
                                    'Inicia la conversación con el taller.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF9DA3AA)),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  for (final message in messages)
                                    _RemoteChatEntry(
                                      message: message,
                                      repository: _chatRepository,
                                      own:
                                          message['sender_id'] ==
                                          _chatRepository.currentUserId,
                                    ),
                                  for (final message in _localMessages.where(
                                    (message) => !message.sentByClient,
                                  ))
                                    _Bubble(text: message.body, own: false),
                                ],
                              );
                            },
                          )
                        else ...[
                          if (_localMessages.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Text(
                                'Escribe tu mensaje para iniciar la conversación.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF9DA3AA)),
                              ),
                            ),
                          for (final message in _localMessages)
                            _Bubble(
                              text: message.body,
                              own: message.sentByClient,
                            ),
                          for (final message in _messages) ...[
                            if (message.bytes != null)
                              _LocalChatAttachment(
                                message: message,
                                onDelete: () => setState(
                                  () => _messages.remove(message),
                                ),
                              ),
                            if (message.text.isNotEmpty)
                              _Bubble(text: message.text, own: true),
                          ],
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF171C21),
                      border: Border(top: BorderSide(color: Color(0xFF343A40))),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Cámara o galería',
                          onPressed: _showAttachmentMenu,
                          icon: Icon(
                            Icons.add_a_photo_outlined,
                            color: widget.accent,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFF20262C),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: Color(0xFF414850),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Enviar mensaje',
                          onPressed: _send,
                          style: IconButton.styleFrom(
                            backgroundColor: widget.accent,
                          ),
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  if (showPhoto)
                    Expanded(
                      flex: 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/workshop_login_background_v1.png',
                            fit: BoxFit.cover,
                          ),
                          const ColoredBox(color: Color(0x22000000)),
                        ],
                      ),
                    ),
                  Expanded(flex: showPhoto ? 6 : 1, child: conversation),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Future<void> _showAttachmentMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1F24),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: widget.accent),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: widget.accent),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: widget.accent),
              title: const Text('Enviar documento'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _controller.clear();
    await _localChatStore.sendClientMessage(
      workshopId: widget.workshop.id,
      workshopName: widget.workshop.name,
      clientName: widget.profile.fullName,
      clientEmail: widget.profile.email,
      body: value,
    );
    final conversationId = _conversationId;
    if (conversationId != null) {
      try {
        await _chatRepository.sendMessage(
          conversationId: conversationId,
          body: value,
        );
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo enviar. El mensaje quedó en este equipo.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (!mounted || file == null || bytes == null) return;
    final conversationId = _conversationId;
    if (conversationId != null) {
      try {
        await _chatRepository.sendAttachment(
          conversationId: conversationId,
          bytes: bytes,
          fileName: file.name,
          mimeType: _mimeTypeForFile(file.name, image: true),
        );
      } catch (_) {
        if (!mounted) return;
        setState(
          () => _messages.add(_ChatEntry(bytes: bytes, fileName: file.name)),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La imagen quedó pendiente hasta recuperar conexión.',
            ),
          ),
        );
        return;
      }
    } else {
      setState(
        () => _messages.add(_ChatEntry(bytes: bytes, fileName: file.name)),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Imagen enviada al taller.')));
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || photo == null) return;
    final bytes = await photo.readAsBytes();
    final fileName = 'foto-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final conversationId = _conversationId;
    if (conversationId != null) {
      try {
        await _chatRepository.sendAttachment(
          conversationId: conversationId,
          bytes: bytes,
          fileName: fileName,
          mimeType: 'image/jpeg',
        );
      } catch (_) {
        if (!mounted) return;
        setState(
          () => _messages.add(_ChatEntry(bytes: bytes, fileName: fileName)),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La foto quedó pendiente hasta recuperar conexión.'),
          ),
        );
        return;
      }
    } else {
      setState(
        () => _messages.add(_ChatEntry(bytes: bytes, fileName: fileName)),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Foto enviada al taller.')));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (!mounted || file == null || bytes == null) return;
    final conversationId = _conversationId;
    if (conversationId != null) {
      try {
        await _chatRepository.sendAttachment(
          conversationId: conversationId,
          bytes: bytes,
          fileName: file.name,
          mimeType: _mimeTypeForFile(file.name),
        );
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El documento no pudo enviarse y quedó pendiente en este equipo.',
            ),
          ),
        );
      }
    }
    if (mounted) {
      setState(
        () => _messages.add(
          _ChatEntry(
            text: 'Documento: ${file.name}',
            bytes: bytes,
            fileName: file.name,
          ),
        ),
      );
    }
  }

  String _mimeTypeForFile(String name, {bool image = false}) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => image ? 'image/jpeg' : 'application/octet-stream',
    };
  }
}

class _LocalChatAttachment extends StatelessWidget {
  const _LocalChatAttachment({required this.message, required this.onDelete});

  final _ChatEntry message;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fileName = message.fileName ?? 'Archivo adjunto';
    final isImage = _isImageFile(fileName);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF20262C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF414850)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            isImage
                ? InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () => ChatAttachmentActions.openImageBytes(
                  context,
                  bytes: message.bytes!,
                  fileName: fileName,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.memory(
                    message.bytes!,
                    width: 280,
                    height: 155,
                    fit: BoxFit.cover,
                  ),
                ),
                  )
                : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined),
                    const SizedBox(width: 8),
                    Flexible(child: Text(fileName)),
                  ],
                ),
                  ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Eliminar archivo'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteChatEntry extends StatelessWidget {
  const _RemoteChatEntry({
    required this.message,
    required this.repository,
    required this.own,
  });

  final Map<String, dynamic> message;
  final ChatRepository repository;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final body = message['body']?.toString().trim() ?? '';
    final attachmentPath = message['attachment_path']?.toString() ?? '';
    final storedName = attachmentPath.split('/').last;
    final fileName = storedName.replaceFirst(RegExp(r'^\d+_'), '');
    return Column(
      crossAxisAlignment: own
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (attachmentPath.isNotEmpty)
          Align(
            alignment: own ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              margin: const EdgeInsets.only(top: 9),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF20262C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF414850)),
              ),
              child: _isImageFile(fileName)
                  ? FutureBuilder<String>(
                      future: repository.signedAttachmentUrl(attachmentPath),
                      builder: (context, snapshot) {
                        final url = snapshot.data;
                        if (url == null) {
                          return const SizedBox(
                            width: 280,
                            height: 155,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () => ChatAttachmentActions.openImage(
                            context,
                            url: url,
                            fileName: fileName,
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Image.network(
                                  url,
                                  width: 280,
                                  height: 155,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _AttachmentLabel(fileName: fileName),
                                ),
                              ),
                              const Positioned(
                                right: 6,
                                bottom: 6,
                                child: Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : FutureBuilder<String>(
                      future: repository.signedAttachmentUrl(attachmentPath),
                      builder: (context, snapshot) => InkWell(
                        onTap: snapshot.hasData
                            ? () => ChatAttachmentActions.download(
                                context,
                                url: snapshot.data!,
                                fileName: fileName,
                              )
                            : null,
                        child: _AttachmentLabel(fileName: fileName),
                      ),
                    ),
            ),
          ),
        if (own && attachmentPath.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _confirmDeleteMessage(context, attachmentPath),
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Eliminar archivo'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ),
        if (body.isNotEmpty) ...[
          _Bubble(text: body, own: own),
          if (own)
            TextButton.icon(
              onPressed: () => _confirmDeleteMessage(context, null),
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Eliminar mensaje'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
        ],
      ],
    );
  }

  Future<void> _confirmDeleteMessage(
    BuildContext context,
    String? attachmentPath,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar mensaje?'),
        content: const Text('Se eliminará para ambas personas del chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteOwnMessage(
        messageId: message['id'].toString(),
        attachmentPath: attachmentPath,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible eliminar el mensaje.')),
        );
      }
    }
  }
}

class _AttachmentLabel extends StatelessWidget {
  const _AttachmentLabel({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.description_outlined),
        const SizedBox(width: 8),
        Flexible(child: Text(fileName.isEmpty ? 'Archivo adjunto' : fileName)),
      ],
    ),
  );
}

bool _isImageFile(String fileName) =>
    RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).hasMatch(fileName);

class _DayChip extends StatelessWidget {
  const _DayChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF252B31),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text('Hoy', style: TextStyle(fontSize: 11)),
  );
}

class _ChatEntry {
  const _ChatEntry({this.text = '', this.bytes, this.fileName});
  final String text;
  final Uint8List? bytes;
  final String? fileName;
}

class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: child,
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF34373C)),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            Text(subtitle, style: const TextStyle(color: Color(0xFF979BA2))),
          ],
        ),
      ),
    ],
  );
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 118,
    child: Material(
      color: const Color(0xF01B1E22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF34373C)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: .34)),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFA4A8AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      backgroundColor: color,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.action,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
    decoration: BoxDecoration(
      color: const Color(0xE9191B1E),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF363940)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: const Color(0xFF656B75)),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9EA2AA)),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.item,
    required this.accent,
    required this.onRate,
    this.onCancel,
  });
  final ClientAppointment item;
  final Color accent;
  final VoidCallback onRate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xEE191B1E),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF363940)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.build_outlined, color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.serviceType,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.motorcycleName,
                    style: const TextStyle(
                      color: Color(0xFFC1C4C9),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${_date(item.date)} · ${_formatTime12h(item.time)}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        if (item.isCancelled)
          const _StatusPill(
            label: 'Cita cancelada · horario liberado',
            color: Color(0xFFFF5B61),
          )
        else
          _ServiceProgress(stage: item.serviceStage, accent: accent),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                item.updatedAt == null
                    ? 'El taller confirmará el avance'
                    : 'Actualizado ${_date(item.updatedAt!)}',
                style: const TextStyle(color: Color(0xFF92969E), fontSize: 11),
              ),
            ),
            if (onCancel != null)
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.event_busy_outlined, size: 18),
                label: const Text('Cancelar cita'),
              )
            else if (item.serviceStage == 'Entregada')
              TextButton.icon(
                onPressed: onRate,
                icon: const Icon(Icons.star_outline_rounded, size: 18),
                label: const Text('Calificar'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ServiceProgress extends StatelessWidget {
  const _ServiceProgress({required this.stage, required this.accent});
  final String stage;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final index = clientServiceStages
        .indexOf(stage)
        .clamp(0, clientServiceStages.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.route_outlined, color: accent, size: 17),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                stage,
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${index + 1}/${clientServiceStages.length}',
              style: const TextStyle(color: Color(0xFF92969E), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (index + 1) / clientServiceStages.length,
            minHeight: 5,
            color: accent,
            backgroundColor: const Color(0xFF32353A),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .45)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_busy_outlined, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _QuickBookingPanel extends StatefulWidget {
  const _QuickBookingPanel({
    required this.accent,
    required this.enabled,
    required this.onBook,
    required this.openingHours,
  });

  final Color accent;
  final bool enabled;
  final void Function(String service, DateTime date, String time) onBook;
  final Map<String, dynamic> openingHours;

  @override
  State<_QuickBookingPanel> createState() => _QuickBookingPanelState();
}

class _QuickBookingPanelState extends State<_QuickBookingPanel> {
  String service = 'Mantenimiento';
  String time = '10:00';
  int month = DateTime.now().month;
  DateTime? selectedDate;

  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final availableTimes = _workshopTimeSlots(
      widget.openingHours,
      date: selectedDate,
    );
    if (availableTimes.isNotEmpty && !availableTimes.contains(time)) {
      time = availableTimes.first;
    }
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xF0171C20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF363C43)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: widget.accent),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agendar nueva cita',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Completa los datos para reservar tu servicio',
                      style: TextStyle(color: Color(0xFF9EA4AB), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BookingStep(
            number: '1',
            label: 'Tipo de servicio',
            accent: widget.accent,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final item in const [
                'Mantenimiento',
                'Frenos',
                'Llantas',
                'Motor',
                'Eléctrico',
                'Filtros',
                'Otro / No estoy seguro',
              ])
                ChoiceChip(
                  label: Text(item),
                  selected: service == item,
                  onSelected: (_) => setState(() => service = item),
                ),
            ],
          ),
          const SizedBox(height: 17),
          _BookingStep(
            number: '2',
            label: 'Selecciona fecha',
            accent: widget.accent,
          ),
          const SizedBox(height: 9),
          InkWell(
            onTap: _selectMonth,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF20262B),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF414850)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, color: widget.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? _months[month - 1]
                          : '${selectedDate!.day} de ${_months[selectedDate!.month - 1]}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: widget.accent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 17),
          _BookingStep(
            number: '3',
            label: 'Horarios disponibles',
            accent: widget.accent,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final item in availableTimes)
                ChoiceChip(
                  label: Text(_formatTime12h(item)),
                  selected: time == item,
                  onSelected: (_) => setState(() => time = item),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  widget.enabled && selectedDate != null && time.isNotEmpty
                  ? () => widget.onBook(service, selectedDate!, time)
                  : null,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                !widget.enabled
                    ? 'Primero registra tu moto'
                    : selectedDate == null
                    ? 'Selecciona el día de la cita'
                    : 'Confirmar cita',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectMonth() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2025),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF414850)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: widget.accent),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Selecciona el mes',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _months.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 50,
                ),
                itemBuilder: (_, index) {
                  final value = index + 1;
                  final selected = value == month;
                  return OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, value),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selected ? widget.accent : null,
                      foregroundColor: selected ? Colors.black : Colors.white,
                      side: BorderSide(
                        color: selected
                            ? widget.accent
                            : const Color(0xFF4A5158),
                      ),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: Text(
                      _months[index],
                      maxLines: 1,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final chosenDate = await _pickDateForMonth(selected);
    if (chosenDate == null || !mounted) return;
    setState(() {
      month = chosenDate.month;
      selectedDate = chosenDate;
      final dateTimes = _workshopTimeSlots(
        widget.openingHours,
        date: chosenDate,
      );
      time = dateTimes.contains(time) ? time : dateTimes.firstOrNull ?? '';
    });
  }

  Future<DateTime?> _pickDateForMonth(int selectedMonth) {
    final systemNow = DateTime.now();
    final today = appointmentToday(systemNow);
    final lastDate = appointmentCalendarLastDate(systemNow);
    final monthStart = appointmentInitialDateForMonth(systemNow, selectedMonth);
    final initialDate = _nextBookableDate(
      monthStart,
      lastDate,
      widget.openingHours,
    );
    if (initialDate == null) return Future<DateTime?>.value();
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      currentDate: today,
      firstDate: today,
      lastDate: lastDate,
      selectableDayPredicate: (day) =>
          _workshopTimeSlots(widget.openingHours, date: day).isNotEmpty,
      helpText: 'Selecciona el día de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Elegir día',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: widget.accent,
            onPrimary: Colors.black,
            surface: const Color(0xFF1B2025),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF1B2025),
          ),
        ),
        child: child!,
      ),
    );
  }
}

class _BookingStep extends StatelessWidget {
  const _BookingStep({
    required this.number,
    required this.label,
    required this.accent,
  });
  final String number;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 10,
        backgroundColor: accent,
        foregroundColor: Colors.black,
        child: Text(
          number,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    ],
  );
}

class _MotorcycleCard extends StatelessWidget {
  const _MotorcycleCard({required this.item, required this.accent});
  final ClientMotorcycle item;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xEE191B1E),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF373A40)),
    ),
    child: Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.two_wheeler_rounded, color: accent, size: 34),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                [
                  item.plate,
                  item.year,
                  item.color,
                ].where((value) => value.isNotEmpty).join(' · '),
                style: const TextStyle(color: Color(0xFFABB0B6)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({
    required this.workshop,
    required this.brand,
    required this.size,
  });
  final Workshop workshop;
  final WorkshopBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: brand.accentColor.withValues(alpha: .12),
      child: Center(
        child: Icon(brand.logoIcon, color: brand.accentColor, size: size * .58),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: workshop.logoBytes != null
            ? Image.memory(workshop.logoBytes!, fit: BoxFit.cover)
            : workshop.logoUrl?.isNotEmpty == true
            ? Image.network(
                workshop.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _Selection extends StatelessWidget {
  const _Selection({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    decoration: BoxDecoration(
      color: const Color(0xFF202226),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF404349)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 11),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.own});
  final String text;
  final bool own;
  @override
  Widget build(BuildContext context) => Align(
    alignment: own ? Alignment.centerRight : Alignment.centerLeft,
    child: GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Mensaje copiado.')));
        }
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: own
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFF1C1E21),
          borderRadius: BorderRadius.circular(8),
          border: own ? null : Border.all(color: const Color(0xFF363940)),
        ),
        child: Text(
          text,
          style: TextStyle(color: own ? Colors.black : Colors.white),
        ),
      ),
    ),
  );
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF8D929A),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFFB2B6BD),
      fontSize: 13,
      fontWeight: FontWeight.w900,
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

List<String> _workshopTimeSlots(
  Map<String, dynamic> openingHours, {
  DateTime? date,
}) {
  const weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  int? openingMinutes;
  int? closingMinutes;
  final daysToInspect = date == null
      ? weekdays
      : <String>[weekdays[date.weekday - 1]];
  for (final day in daysToInspect) {
    final rawSchedule = openingHours[day];
    if (rawSchedule is! Map || rawSchedule['closed'] == true) continue;
    final open = _minutesFromTime(rawSchedule['open']?.toString());
    final close = _minutesFromTime(rawSchedule['close']?.toString());
    if (open != null && close != null && close > open) {
      openingMinutes = open;
      closingMinutes = close;
      break;
    }
  }

  if (date != null && openingHours.isNotEmpty && openingMinutes == null) {
    return const [];
  }
  openingMinutes ??= 8 * 60;
  closingMinutes ??= 18 * 60;
  final slots = <String>[];
  for (
    var cursor = openingMinutes;
    cursor + 60 <= closingMinutes;
    cursor += 60
  ) {
    slots.add(_timeFromMinutes(cursor));
  }
  if (slots.isEmpty) slots.add(_timeFromMinutes(openingMinutes));
  return slots;
}

DateTime? _nextBookableDate(
  DateTime start,
  DateTime lastDate,
  Map<String, dynamic> openingHours,
) {
  var candidate = DateTime(start.year, start.month, start.day);
  while (!candidate.isAfter(lastDate)) {
    if (_workshopTimeSlots(openingHours, date: candidate).isNotEmpty) {
      return candidate;
    }
    candidate = candidate.add(const Duration(days: 1));
  }
  return null;
}

int? _minutesFromTime(String? value) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value ?? '');
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

String _timeFromMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatTime12h(String value) {
  final minutes = _minutesFromTime(value);
  if (minutes == null) return value;
  final hour24 = minutes ~/ 60;
  final minute = (minutes % 60).toString().padLeft(2, '0');
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 < 12 ? 'a. m.' : 'p. m.';
  return '$hour12:$minute $period';
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  final _store = ClientServiceStore();
  final _feedback = WorkshopFeedbackStore();
  late ClientProfile _profile;
  List<ClientMotorcycle> _motorcycles = const [];
  List<ClientAppointment> _appointments = const [];
  var _tab = 0;
  CommerceProduct? _productQuestion;
  var _loading = true;

  String get _clientId =>
      _profile.userId?.isNotEmpty == true ? _profile.userId! : _profile.email;

  List<ClientAppointment> get _upcomingAppointments {
    final now = DateTime.now();
    final items = _appointments
        .where((item) => !item.isCancelled && item.startsAt.isAfter(now))
        .toList();
    items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return items;
  }

  ClientAppointment? get _nextAppointment =>
      _upcomingAppointments.isEmpty ? null : _upcomingAppointments.first;

  bool get _hasAppointmentReminder => _upcomingAppointments.any(
    (item) =>
        item.startsAt.difference(DateTime.now()) <= const Duration(days: 7),
  );

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    ClientServiceStore.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    ClientServiceStore.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final motorcycles = await _store.listMotorcycles(
      widget.workshop.id,
      _clientId,
    );
    final appointments = await _store.listAppointments(
      widget.workshop.id,
      _clientId,
    );
    if (!mounted) return;
    setState(() {
      _motorcycles = motorcycles;
      _appointments = appointments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.brand.accentColor;
    return Scaffold(
      backgroundColor: const Color(0xFF090A0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15171A),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Volver a talleres',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _Logo(workshop: widget.workshop, brand: widget.brand, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.workshop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: widget.workshop.isOpenNow
                            ? const Color(0xFF31DB75)
                            : const Color(0xFFFFB84D),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.workshop.isOpenNow
                            ? 'Abierto ahora'
                            : 'Fuera de horario',
                        style: const TextStyle(
                          color: Color(0xFFB4B9C0),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: _showAppointmentNotifications,
            icon: Badge(
              isLabelVisible: _hasAppointmentReminder,
              smallSize: 7,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Cuenta',
            icon: _headerProfileAvatar(),
            onSelected: (value) {
              if (value == 'profile') _openSettings();
              if (value == 'recovery') _openRecovery();
              if (value == 'logout') _confirmSignOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.manage_accounts_outlined),
                  title: Text('Perfil y configuración'),
                  subtitle: Text('Foto, datos, correo y celular'),
                ),
              ),
              PopupMenuItem(
                value: 'recovery',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_reset_rounded),
                  title: Text('Seguridad y recuperación'),
                  subtitle: Text('Recupera el acceso a tu cuenta'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: .52,
            child: Image.asset(
              'assets/images/workshop_login_background_v1.png',
              fit: BoxFit.cover,
            ),
          ),
          const ColoredBox(color: Color(0xA808090A)),
          if (_loading)
            Center(child: CircularProgressIndicator(color: accent))
          else
            IndexedStack(
              index: _tab,
              children: [
                _home(),
                _appointmentsPage(),
                _motorcyclesPage(),
                _PartsPage(
                  accent: accent,
                  workshop: widget.workshop,
                  clientId: _clientId,
                  clientName: _profile.fullName,
                  onOpenSupport: (product) => setState(() {
                    _productQuestion = product;
                    _tab = 4;
                  }),
                ),
                _SupportPage(
                  workshop: widget.workshop,
                  accent: accent,
                  profile: _profile,
                  productQuestion: _productQuestion,
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? accent
                  : const Color(0xFFE2E5E8),
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? accent
                  : const Color(0xFFE2E5E8),
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ),
        child: NavigationBar(
          height: 72,
          selectedIndex: _tab,
          backgroundColor: const Color(0xFF17191C),
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Citas',
            ),
            NavigationDestination(
              icon: Icon(Icons.two_wheeler_outlined),
              selectedIcon: Icon(Icons.two_wheeler_rounded),
              label: 'Mi moto',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Repuestos',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Soporte',
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerProfileAvatar() {
    final hasPhotoBytes = _profile.profilePhotoBytes != null;
    final hasPhotoUrl = _profile.avatarUrl?.trim().isNotEmpty ?? false;
    return CircleAvatar(
      radius: 17,
      backgroundColor: widget.brand.accentColor.withValues(alpha: .18),
      backgroundImage: hasPhotoBytes
          ? MemoryImage(_profile.profilePhotoBytes!)
          : hasPhotoUrl
          ? NetworkImage(_profile.avatarUrl!)
          : null,
      child: hasPhotoBytes || hasPhotoUrl
          ? null
          : Icon(
              Icons.person_rounded,
              color: widget.brand.accentColor,
              size: 22,
            ),
    );
  }

  Widget _home() => _Page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xED171A1E),
            image: const DecorationImage(
              image: AssetImage(
                'assets/images/workshop_login_background_v1.png',
              ),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              colorFilter: ColorFilter.mode(
                Color(0x77030709),
                BlendMode.srcOver,
              ),
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.brand.accentColor.withValues(alpha: .46),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .32),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final identity = Row(
                children: [
                  _Logo(
                    workshop: widget.workshop,
                    brand: widget.brand,
                    size: compact ? 58 : 70,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.workshop.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 18 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.workshop.tagline.isEmpty
                              ? 'Taller especializado'
                              : widget.workshop.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFADB1B8)),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _HeroBadge(
                              icon: Icons.verified_outlined,
                              label: 'Taller verificado',
                              color: const Color(0xFF42D6A4),
                            ),
                            _HeroBadge(
                              icon: Icons.schedule_rounded,
                              label: widget.workshop.isOpenNow
                                  ? 'Abierto ahora'
                                  : 'Fuera de horario',
                              color: widget.workshop.isOpenNow
                                  ? const Color(0xFF42D6A4)
                                  : const Color(0xFFFFC14D),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final greeting = Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  const Text(
                    'BIENVENIDO DE NUEVO',
                    style: TextStyle(
                      color: Color(0xFF979CA4),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profile.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: compact ? TextAlign.start : TextAlign.end,
                    style: TextStyle(
                      fontSize: compact ? 23 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _showBooking,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Agendar servicio'),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.brand.accentColor,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const Divider(height: 30, color: Color(0xFF34383E)),
                    greeting,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 6, child: identity),
                  Container(
                    width: 1,
                    height: 92,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: const Color(0xFF34383E),
                  ),
                  Expanded(flex: 4, child: greeting),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(width: 3, height: 18, color: widget.brand.accentColor),
            const SizedBox(width: 9),
            const _Label('SERVICIOS DEL TALLER'),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, constraints) {
            final columns = constraints.maxWidth >= 820
                ? 4
                : constraints.maxWidth >= 600
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionTile(
                  width: width,
                  icon: Icons.calendar_month_outlined,
                  title: 'Agendar cita',
                  subtitle: 'Reserva tu servicio',
                  accent: widget.brand.accentColor,
                  onTap: () => setState(() => _tab = 1),
                ),
                _ActionTile(
                  width: width,
                  icon: Icons.two_wheeler_outlined,
                  title: 'Mi moto',
                  subtitle: 'Vehículos y servicios',
                  accent: widget.brand.accentColor,
                  onTap: () => setState(() => _tab = 2),
                ),
                _ActionTile(
                  width: width,
                  icon: Icons.inventory_2_outlined,
                  title: 'Repuestos',
                  subtitle: 'Catálogo disponible',
                  accent: widget.brand.accentColor,
                  onTap: () => setState(() => _tab = 3),
                ),
                _ActionTile(
                  width: width,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Soporte',
                  subtitle: 'Habla con el taller',
                  accent: widget.brand.accentColor,
                  onTap: () => setState(() => _tab = 4),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xE9191C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF34383E)),
          ),
          child: ListTile(
            onTap: _showFeedback,
            leading: Icon(
              Icons.star_outline_rounded,
              color: widget.brand.accentColor,
            ),
            title: const Text(
              '¿Ya recibiste tu moto?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Califica el servicio y al mecánico que te atendió',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: _Label('PRÓXIMA CITA')),
            TextButton(
              onPressed: () => setState(() => _tab = 1),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_nextAppointment == null)
          _Empty(
            icon: Icons.calendar_today_outlined,
            title: 'No tienes citas programadas',
            action: 'Agendar ahora',
            onTap: _showBooking,
          )
        else
          _AppointmentCard(
            item: _nextAppointment!,
            accent: widget.brand.accentColor,
            onRate: () => _showFeedback(_nextAppointment),
            onCancel: _nextAppointment!.canBeCancelled()
                ? () => _cancelAppointment(_nextAppointment!)
                : null,
          ),
      ],
    ),
  );

  Widget _appointmentsPage() => _Page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 180,
          padding: const EdgeInsets.all(24),
          alignment: Alignment.bottomLeft,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/images/workshop_login_background_v1.png',
              ),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              colorFilter: ColorFilter.mode(
                Color(0x55000000),
                BlendMode.srcOver,
              ),
            ),
            borderRadius: BorderRadius.all(Radius.circular(8)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFF3A4047))),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Citas y seguimiento',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              Text(
                'Consulta tus reservas y el estado de tu moto.',
                style: TextStyle(color: Color(0xFFD1D5DA)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: _Label('SERVICIO ACTUAL')),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Ver detalle'),
                    ),
                  ],
                ),
                if (_nextAppointment == null)
                  _Empty(
                    icon: Icons.calendar_today_outlined,
                    title: _motorcycles.isEmpty
                        ? 'Primero registra tu moto'
                        : 'No tienes citas aún',
                    action: _motorcycles.isEmpty
                        ? 'Agregar moto'
                        : 'Agendar ahora',
                    onTap: _motorcycles.isEmpty
                        ? () => setState(() => _tab = 2)
                        : _showBooking,
                  )
                else
                  _AppointmentCard(
                    item: _nextAppointment!,
                    accent: widget.brand.accentColor,
                    onRate: () => _showFeedback(_nextAppointment),
                    onCancel: _nextAppointment!.canBeCancelled()
                        ? () => _cancelAppointment(_nextAppointment!)
                        : null,
                  ),
                const SizedBox(height: 18),
                const _Label('HISTORIAL DE CITAS'),
                const SizedBox(height: 10),
                if (_appointments.length <= 1)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xEC171C20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF363C43)),
                    ),
                    child: const Text(
                      'Tu historial aparecerá aquí después de completar el primer servicio.',
                      style: TextStyle(color: Color(0xFFAEB3BA)),
                    ),
                  )
                else
                  for (final item in _appointments.reversed.skip(1)) ...[
                    _AppointmentCard(
                      item: item,
                      accent: widget.brand.accentColor,
                      onRate: () => _showFeedback(item),
                      onCancel: item.canBeCancelled()
                          ? () => _cancelAppointment(item)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            );
            final booking = _QuickBookingPanel(
              accent: widget.brand.accentColor,
              enabled: _motorcycles.isNotEmpty,
              onBook: (service, date, time) =>
                  _showBooking(service, date, time),
              openingHours: widget.workshop.openingHours,
            );
            if (constraints.maxWidth < 780) {
              return Column(
                children: [left, const SizedBox(height: 16), booking],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                Expanded(child: booking),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _motorcyclesPage() => _Page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title(
          icon: Icons.two_wheeler_outlined,
          title: 'Mi moto',
          subtitle: 'Gestiona tus motos y servicios',
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Agregar moto',
          icon: Icons.add_rounded,
          color: widget.brand.accentColor,
          onPressed: _showMotorcycle,
        ),
        const SizedBox(height: 18),
        if (_motorcycles.isEmpty)
          _Empty(
            icon: Icons.two_wheeler_outlined,
            title: 'No tienes motos registradas',
            action: 'Agregar mi primera moto',
            onTap: _showMotorcycle,
          )
        else
          for (final item in _motorcycles) ...[
            _MotorcycleCard(item: item, accent: widget.brand.accentColor),
            const SizedBox(height: 12),
          ],
      ],
    ),
  );

  Future<void> _showMotorcycle() async {
    final brand = TextEditingController();
    final model = TextEditingController();
    final plate = TextEditingController();
    final year = TextEditingController();
    final color = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            // El diálogo ya se desplaza por encima del teclado. Agregar el
            // alto del teclado aquí hacía que los campos quedaran ocultos.
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF191E23),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B4249)),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 30),
              ],
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.brand.accentColor.withValues(
                            alpha: .13,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.two_wheeler_outlined,
                          color: widget.brand.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agregar moto',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Datos principales del vehículo',
                              style: TextStyle(
                                color: Color(0xFFA5ABB2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (_, constraints) {
                      final twoColumns = constraints.maxWidth >= 430;
                      final fieldWidth = twoColumns
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: _field(
                              brand,
                              'Marca',
                              'Ej. Honda',
                              icon: Icons.sell_outlined,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _field(
                              model,
                              'Modelo',
                              'Ej. CBR 600',
                              icon: Icons.two_wheeler_outlined,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _field(
                              plate,
                              'Placa',
                              'Ej. ABC123',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _field(
                              year,
                              'Año',
                              'Ej. 2026',
                              icon: Icons.calendar_today_outlined,
                              number: true,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _field(
                              color,
                              'Color',
                              'Ej. Negro',
                              icon: Icons.palette_outlined,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (brand.text.trim().isNotEmpty &&
                            model.text.trim().isNotEmpty &&
                            plate.text.trim().isNotEmpty) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Guardar moto'),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.brand.accentColor,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      await _store.saveMotorcycle(
        widget.workshop.id,
        _clientId,
        ClientMotorcycle(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          brand: brand.text.trim(),
          model: model.text.trim(),
          plate: plate.text.trim().toUpperCase(),
          year: year.text.trim(),
          color: color.text.trim(),
        ),
      );
      await _reload();
    }
    brand.dispose();
    model.dispose();
    plate.dispose();
    year.dispose();
    color.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    required IconData icon,
    bool number = false,
  }) => TextField(
    controller: controller,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    scrollPadding: const EdgeInsets.only(bottom: 180),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFF242A2F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF414850)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF414850)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: widget.brand.accentColor, width: 1.5),
      ),
    ),
  );

  Future<void> _showAppointmentNotifications() async {
    final upcoming = _upcomingAppointments;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF191B1F),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Handle(),
              const _Title(
                icon: Icons.notifications_active_outlined,
                title: 'Recordatorios',
                subtitle: 'Tus próximas citas con el taller',
              ),
              const SizedBox(height: 16),
              if (upcoming.isEmpty)
                const Text(
                  'No tienes citas próximas.',
                  style: TextStyle(color: Color(0xFFB4B9C0)),
                )
              else
                for (final item in upcoming.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: widget.brand.accentColor.withValues(
                        alpha: .15,
                      ),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        color: widget.brand.accentColor,
                      ),
                    ),
                    title: Text(item.serviceType),
                    subtitle: Text(
                      '${_date(item.date)} · ${_formatTime12h(item.time)}\n${widget.workshop.name}',
                    ),
                    isThreeLine: true,
                  ),
              const SizedBox(height: 10),
              const Text(
                'También podrás recibir el recordatorio por correo o celular cuando el servicio de mensajería esté conectado.',
                style: TextStyle(color: Color(0xFF92969E), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(ClientAppointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Deseas cancelar la cita del ${_date(appointment.date)} a las ${_formatTime12h(appointment.time)}? El horario quedará disponible para otro cliente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conservar cita'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.cancelAppointment(appointment);
      await _reload();
      _notice('Cita cancelada. El horario volvió a estar disponible.');
    } on AppointmentCancellationNotAllowedException {
      _notice('Solo puedes cancelar hasta 24 horas antes de la cita.');
    } on AppointmentPersistenceException {
      _notice(
        'No pudimos cancelar la cita. Revisa tu conexión e inténtalo nuevamente.',
      );
    }
  }

  Future<void> _showBooking([
    String? initialService,
    DateTime? initialDate,
    String? initialTime,
  ]) async {
    if (_motorcycles.isEmpty) {
      _notice('Primero agrega una moto para reservar el servicio.');
      setState(() => _tab = 2);
      return;
    }
    var motorcycle = _motorcycles.first;
    var service = initialService ?? 'Mantenimiento';
    final mechanics = await WorkshopMechanicStore().available(
      widget.workshop.id,
    );
    final mechanicFeedback = await WorkshopFeedbackStore().list(
      widget.workshop.id,
    );
    if (!mounted) return;
    WorkshopMechanic? selectedMechanic;
    (double, int) ratingFor(WorkshopMechanic mechanic) {
      final ratings = mechanicFeedback
          .where(
            (item) =>
                item.mechanicName.trim().toLowerCase() ==
                mechanic.name.trim().toLowerCase(),
          )
          .toList();
      if (ratings.isEmpty) return (0, 0);
      return (
        ratings.fold<int>(0, (sum, item) => sum + item.rating) / ratings.length,
        ratings.length,
      );
    }

    Widget mechanicAvatar(WorkshopMechanic mechanic) => ClipOval(
      child: SizedBox.square(
        dimension: 48,
        child: mechanic.photoBytes == null
            ? ColoredBox(
                color: widget.brand.accentColor.withValues(alpha: .16),
                child: Center(
                  child: Text(
                    mechanic.name.isEmpty
                        ? '?'
                        : mechanic.name[0].toUpperCase(),
                    style: TextStyle(
                      color: widget.brand.accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            : Image.memory(mechanic.photoBytes!, fit: BoxFit.cover),
      ),
    );
    final now = DateTime.now();
    var date = initialDate ?? appointmentInitialDateForMonth(now, now.month);
    var availableTimes = _workshopTimeSlots(
      widget.workshop.openingHours,
      date: date,
    );
    if (availableTimes.isEmpty) {
      date =
          _nextBookableDate(
            date,
            appointmentCalendarLastDate(now),
            widget.workshop.openingHours,
          ) ??
          date;
      availableTimes = _workshopTimeSlots(
        widget.workshop.openingHours,
        date: date,
      );
    }
    var time = initialTime != null && availableTimes.contains(initialTime)
        ? initialTime
        : availableTimes.firstOrNull ?? '';
    String? slotError;
    final notes = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF191B1F),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Handle(),
                const _Title(
                  icon: Icons.calendar_month_outlined,
                  title: 'Agendar cita',
                  subtitle: 'Selecciona servicio, fecha y hora',
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<ClientMotorcycle>(
                  initialValue: motorcycle,
                  decoration: const InputDecoration(labelText: 'Tu moto'),
                  items: [
                    for (final item in _motorcycles)
                      DropdownMenuItem(
                        value: item,
                        child: Text('${item.displayName} · ${item.plate}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) motorcycle = value;
                  },
                ),
                const SizedBox(height: 18),
                const _Label('TIPO DE SERVICIO'),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in const [
                      'Mantenimiento',
                      'Reparación',
                      'Diagnóstico',
                      'Cambio de repuestos',
                      'Revisión general',
                      'Otro / No estoy seguro',
                    ])
                      ChoiceChip(
                        label: Text(item),
                        selected: service == item,
                        onSelected: (_) => setSheet(() => service = item),
                      ),
                  ],
                ),
                if (mechanics.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _Label('MECÁNICO DE PREFERENCIA'),
                  const SizedBox(height: 9),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setSheet(() => selectedMechanic = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: widget.brand.accentColor
                                .withValues(alpha: .14),
                            foregroundColor: widget.brand.accentColor,
                            child: const Icon(Icons.groups_2_outlined),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cualquiera disponible',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'El taller asignará al profesional indicado',
                                  style: TextStyle(
                                    color: Color(0xFFAEB3BA),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selectedMechanic == null
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: widget.brand.accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF34383E)),
                  for (final item in mechanics) ...[
                    Builder(
                      builder: (context) {
                        final rating = ratingFor(item);
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setSheet(() => selectedMechanic = item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                mechanicAvatar(item),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        item.specialty,
                                        style: const TextStyle(
                                          color: Color(0xFFBFC2C7),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFFFB547),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            rating.$2 == 0
                                                ? 'Nuevo · sin calificaciones'
                                                : '${rating.$1.toStringAsFixed(1)} · ${rating.$2} opiniones',
                                            style: const TextStyle(
                                              color: Color(0xFFAEB3BA),
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (item.experienceYears > 0) ...[
                                            const Text(
                                              '  ·  ',
                                              style: TextStyle(
                                                color: Color(0xFFAEB3BA),
                                              ),
                                            ),
                                            Flexible(
                                              child: Text(
                                                '${item.experienceYears} años de experiencia',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFFAEB3BA),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (item.bio.trim().isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.bio,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF8F949C),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  selectedMechanic?.id == item.id
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: widget.brand.accentColor,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFF34383E)),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'El taller confirmará la asignación según disponibilidad.',
                    style: TextStyle(color: Color(0xFF92969E), fontSize: 11),
                  ),
                ],
                const SizedBox(height: 18),
                const _Label('FECHA'),
                const SizedBox(height: 9),
                InkWell(
                  onTap: () async {
                    final result = await _pickAppointmentDate(date);
                    if (result != null) {
                      setSheet(() {
                        date = result;
                        availableTimes = _workshopTimeSlots(
                          widget.workshop.openingHours,
                          date: date,
                        );
                        time = availableTimes.contains(time)
                            ? time
                            : availableTimes.firstOrNull ?? '';
                        slotError = null;
                      });
                    }
                  },
                  child: _Selection(
                    icon: Icons.calendar_today_outlined,
                    text: _date(date),
                  ),
                ),
                const SizedBox(height: 18),
                const _Label('HORA'),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in availableTimes)
                      ChoiceChip(
                        avatar: const Icon(Icons.schedule_outlined, size: 17),
                        label: Text(_formatTime12h(item)),
                        selected: time == item,
                        onSelected: (_) => setSheet(() {
                          time = item;
                          slotError = null;
                        }),
                      ),
                  ],
                ),
                if (availableTimes.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'El taller está cerrado en esta fecha. Elige otro día.',
                    style: TextStyle(
                      color: Color(0xFFFFB15C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202429),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF40474F)),
                  ),
                  child: TextField(
                    controller: notes,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Motivo de la cita (opcional)',
                      hintText: 'Ejemplo: la moto no enciende',
                      prefixIcon: Icon(
                        Icons.edit_note_rounded,
                        color: widget.brand.accentColor,
                      ),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: const Color(0xFF202429),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: widget.brand.accentColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: Color(0xFF92969E),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Esta información llegará únicamente al taller seleccionado.',
                        style: TextStyle(
                          color: Color(0xFF92969E),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (slotError != null) ...[
                  Text(
                    slotError!,
                    style: const TextStyle(
                      color: Color(0xFFFF7378),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _PrimaryButton(
                  label: 'Confirmar cita',
                  icon: Icons.check_rounded,
                  color: widget.brand.accentColor,
                  onPressed: () async {
                    if (availableTimes.isEmpty) {
                      setSheet(() {
                        slotError =
                            'El taller no atiende en esta fecha. Elige otro día.';
                      });
                      return;
                    }
                    final available = await _store.isSlotAvailable(
                      widget.workshop.id,
                      date,
                      time,
                    );
                    if (!available) {
                      setSheet(() {
                        slotError =
                            'Este horario ya fue reservado. Elige otra hora.';
                      });
                      return;
                    }
                    if (context.mounted) Navigator.pop(context, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      try {
        await _store.saveAppointment(
          widget.workshop.id,
          _clientId,
          ClientAppointment(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            motorcycleId: motorcycle.id,
            motorcycleName: '${motorcycle.displayName} · ${motorcycle.plate}',
            serviceType: service,
            date: date,
            time: time,
            notes: notes.text.trim(),
            mechanicName: selectedMechanic?.name ?? '',
          ),
        );
        await _reload();
        _notice('Cita programada. Te recordaremos antes de la fecha.');
      } on AppointmentSlotUnavailableException {
        _notice('Ese horario acaba de ser reservado. Elige otra hora.');
      } on AppointmentPersistenceException {
        _notice(
          'No pudimos guardar la cita. Revisa tu conexión e inténtalo nuevamente.',
        );
      }
    }
    // The modal future completes before its reverse animation is fully removed.
    // Wait for that transition so the text field no longer depends on the controller.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    notes.dispose();
  }

  Future<DateTime?> _pickAppointmentDate(DateTime initialDate) {
    final systemNow = DateTime.now();
    final today = appointmentToday(systemNow);
    final lastAvailableDate = appointmentCalendarLastDate(systemNow);
    final clampedInitialDate = clampAppointmentDate(
      value: initialDate,
      systemNow: systemNow,
    );
    final safeInitialDate = _nextBookableDate(
      clampedInitialDate,
      lastAvailableDate,
      widget.workshop.openingHours,
    );
    if (safeInitialDate == null) {
      _notice('El taller no tiene días de atención configurados.');
      return Future<DateTime?>.value();
    }

    return showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      currentDate: today,
      firstDate: today,
      lastDate: lastAvailableDate,
      selectableDayPredicate: (day) => _workshopTimeSlots(
        widget.workshop.openingHours,
        date: day,
      ).isNotEmpty,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Selecciona la fecha de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Elegir fecha',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: widget.brand.accentColor,
            onPrimary: Colors.black,
            surface: const Color(0xFF191E23),
            onSurface: Colors.white,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: const Color(0xFF191E23),
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: const Color(0xFF20262B),
            headerForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF414850)),
            ),
          ),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _showFeedback([ClientAppointment? appointment]) async {
    var rating = 0;
    final mechanics = await WorkshopMechanicStore().list(widget.workshop.id);
    if (!mounted) return;
    var mechanicName = appointment?.mechanicName ?? '';
    if (mechanicName.isEmpty && mechanics.length == 1) {
      mechanicName = mechanics.first.name;
    }
    final comment = TextEditingController();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF191B1F),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Handle(),
                const _Title(
                  icon: Icons.star_rounded,
                  title: 'Califica tu servicio',
                  subtitle: 'El administrador recibirá tu valoración',
                ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    children: [
                      for (var index = 1; index <= 5; index++)
                        IconButton(
                          tooltip: '$index estrellas',
                          iconSize: 42,
                          color: widget.brand.accentColor,
                          onPressed: () => setSheet(() => rating = index),
                          icon: Icon(
                            index <= rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    rating == 0
                        ? 'Selecciona una calificación'
                        : '$rating de 5 estrellas',
                    style: const TextStyle(color: Color(0xFFB8BCC2)),
                  ),
                ),
                const SizedBox(height: 18),
                if (mechanics.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue:
                        mechanics.any((item) => item.name == mechanicName)
                        ? mechanicName
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Mecánico que te atendió',
                      prefixIcon: Icon(Icons.engineering_outlined),
                    ),
                    items: [
                      for (final item in mechanics)
                        DropdownMenuItem(
                          value: item.name,
                          child: Text(item.name),
                        ),
                    ],
                    onChanged: (value) => mechanicName = value ?? '',
                  )
                else
                  const Text(
                    'La calificación será asignada al equipo del taller.',
                    style: TextStyle(color: Color(0xFFB8BCC2)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: comment,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Comentario',
                    hintText: 'Cuéntanos cómo fue la atención y el resultado',
                  ),
                ),
                const SizedBox(height: 20),
                _PrimaryButton(
                  label: 'Enviar calificación',
                  icon: Icons.send_rounded,
                  color: widget.brand.accentColor,
                  onPressed: rating == 0
                      ? null
                      : () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (sent == true) {
      await _feedback.add(
        WorkshopFeedback(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          workshopId: widget.workshop.id,
          clientName: _profile.fullName,
          clientEmail: _profile.email,
          mechanicName: mechanicName.trim().isEmpty
              ? 'Equipo del taller'
              : mechanicName.trim(),
          serviceType: appointment?.serviceType ?? 'Servicio recibido',
          rating: rating,
          comment: comment.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      _notice('Gracias. El administrador ya puede ver tu calificación.');
    }
    comment.dispose();
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientRegistrationScreen(
          tenantContext: widget.tenantContext,
          brandController: widget.brandController,
          authController: widget.authController,
          isEditing: true,
          initialData: _profile.toFormData(),
        ),
      ),
    );
    final updated = await ClientProfileRepository().getCurrentProfile();
    if (!mounted || updated == null) return;
    setState(() => _profile = updated);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ClientSettingsScreen(
          profile: _profile,
          workshop: widget.workshop,
          brand: widget.brand,
          onEdit: () async {
            Navigator.of(context).pop();
            await _editProfile();
          },
          onRecovery: _openRecovery,
          onChangePassword: _openChangePassword,
        ),
      ),
    );
  }

  Future<void> _openRecovery() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountRecoveryScreen(
          accountType: RecoveryAccountType.client,
          initialEmail: _profile.email,
        ),
      ),
    );
  }

  Future<void> _openChangePassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CredentialSettingsScreen(
          brand: widget.brand,
          passwordOnly: true,
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que iniciar sesión de nuevo para ver tus talleres, pedidos y datos personales.',
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
    if (confirmed == true) await _signOut();
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    await LocalClientProfileStore().signOut();
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

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

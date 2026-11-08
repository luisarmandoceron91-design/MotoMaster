import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'client_registration_controller.dart';
import 'package:moto_master/core/location/colombia_locations.dart';
import 'package:moto_master/core/auth/admin_auth_controller.dart';
import 'package:moto_master/core/branding/workshop_brand.dart';
import 'package:moto_master/core/tenant/tenant_context.dart';
import 'package:moto_master/core/security/password_policy.dart';
import 'package:moto_master/core/auth/auth_service.dart';
import '../../workshop_selection/client_workshop_selection_screen.dart';

class ClientRegistrationView extends StatefulWidget {
  const ClientRegistrationView({
    super.key,
    required this.controller,
    this.isEditing = false,
    this.initialData,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
    this.existingGoogleAccount = false,
  });

  final ClientRegistrationController controller;
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;
  final bool existingGoogleAccount;

  @override
  State<ClientRegistrationView> createState() => _ClientRegistrationViewState();
}

class _ClientRegistrationViewState extends State<ClientRegistrationView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  String? _selectedDepartment;
  bool _acceptTerms = false;
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoFileName;
  bool _isPickingPhoto = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    // Inicializamos controladores con datos si estamos en modo edición
    _nameController = TextEditingController(
      text: widget.initialData?['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.initialData?['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.initialData?['phone'] ?? '',
    );
    _cityController = TextEditingController(
      text: widget.initialData?['city'] ?? '',
    );
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _profilePhotoBytes = widget.initialData?['profilePhotoBytes'] as Uint8List?;
    _profilePhotoFileName =
        widget.initialData?['profilePhotoFileName'] as String?;
    _acceptTerms = widget.isEditing;
    _selectedDepartment = widget.initialData?['department'] as String?;

    if (widget.existingGoogleAccount) {
      final user = AuthService().currentUser;
      final metadata = user?.userMetadata ?? const <String, dynamic>{};
      _nameController.text = (metadata['full_name'] ?? metadata['name'] ?? '')
          .toString();
      _emailController.text = user?.email ?? '';
      _phoneController.text = metadata['phone']?.toString() ?? '';
    }

    // Mantiene compatibilidad con perfiles creados antes de separar la ubicación.
    if (_selectedDepartment == null && widget.initialData?['city'] != null) {
      final parts = widget.initialData!['city'].toString().split(', ');
      if (parts.length > 1) {
        _selectedDepartment = parts[0];
        _cityController.text = parts.sublist(1).join(', ');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFFFF6A00);

    return Scaffold(
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
                colors: [
                  Color(0x66000000),
                  Color(0x36000000),
                  Color(0xA6000000),
                ],
                stops: [0, .5, 1],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _buildAccessCard(accentColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).maybePop();
  }

  Widget _buildProfilePhoto(Color accentColor) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1B1C20),
            border: Border.all(color: accentColor, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: ClipOval(
            child: _profilePhotoBytes == null
                ? ColoredBox(
                    color: accentColor,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  )
                : Image.memory(
                    _profilePhotoBytes!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
          ),
        ),
        Positioned(
          right: -3,
          bottom: -2,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1B1C20), width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickProfilePhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || selection == null) return;

      final file = selection.files.single;
      if (file.bytes == null) {
        _showMessage('No fue posible leer la imagen seleccionada.');
        return;
      }
      if (file.bytes!.lengthInBytes > 1024 * 1024) {
        _showMessage('La foto debe pesar menos de 1 MB.');
        return;
      }

      setState(() {
        _profilePhotoBytes = file.bytes;
        _profilePhotoFileName = file.name;
      });
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo abrir el selector de imágenes.');
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildAccessCard(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xF01B1C20),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: .9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xA8000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfilePhoto(accentColor),
            const SizedBox(height: 18),
            Text(
              widget.isEditing ? 'Actualizar datos' : 'Crear cuenta',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isEditing
                  ? 'Modifica tu información personal para mantener tu perfil actualizado.'
                  : 'Regístrate como cliente y disfruta de todos nuestros servicios.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _isPickingPhoto ? null : _pickProfilePhoto,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: accentColor.withValues(alpha: .75)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              icon: _isPickingPhoto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_a_photo_outlined, size: 20),
              label: Text(
                _profilePhotoBytes == null
                    ? 'Agregar foto de perfil (opcional)'
                    : 'Cambiar foto de perfil',
              ),
            ),
            if (_profilePhotoFileName != null) ...[
              const SizedBox(height: 7),
              Text(
                _profilePhotoFileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFBFC0C4), fontSize: 11),
              ),
            ],
            const SizedBox(height: 24),
            _buildTextField(
              Icons.person_outline,
              'Nombre completo *',
              _nameController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              Icons.email_outlined,
              'Correo electrónico *',
              _emailController,
              readOnly: widget.existingGoogleAccount,
            ),
            if (!widget.isEditing && !widget.existingGoogleAccount) ...[
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _passwordController,
                label: 'Contraseña *',
                obscureText: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirmar contraseña *',
                obscureText: _obscureConfirmation,
                onToggle: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                confirmation: true,
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              Icons.phone_outlined,
              'Número de celular *',
              _phoneController,
              prefix: '+57 ',
              isPhone: true,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Departamento *',
              value: _selectedDepartment,
              items: colombiaLocations.keys.toList(),
              onChanged: (val) {
                setState(() {
                  _selectedDepartment = val;
                  _cityController.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (_selectedDepartment == null) {
                  return Iterable<String>.empty();
                }
                final options = colombiaLocations[_selectedDepartment]!;
                return options.where((String option) {
                  return option.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  );
                });
              },
              onSelected: (String selection) {
                _cityController.text = selection;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (value) => _cityController.text = value,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.location_city,
                          color: Colors.white60,
                          size: 22,
                        ),
                        labelText: 'Ciudad/Municipio *',
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF4B4E55),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF6A00),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: _selectedDepartment == null
                            ? const Color(0xFF202126)
                            : const Color(0xFF24262B),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                      ),
                      validator: (val) =>
                          (val == null || val.isEmpty) ? 'Obligatorio' : null,
                    );
                  },
            ),
            const SizedBox(height: 25),
            if (!widget.isEditing)
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _acceptTerms,
                      onChanged: (val) =>
                          setState(() => _acceptTerms = val ?? false),
                      activeColor: accentColor,
                      side: BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        children: [
                          const TextSpan(text: 'Acepto los '),
                          TextSpan(
                            text: 'Términos y Condiciones',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' y la '),
                          TextSpan(
                            text: 'Política de Privacidad',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' de Moto Master.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isEditing ? 'Guardar cambios' : 'Crear cuenta',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                widget.isEditing
                    ? 'Volver al panel'
                    : 'Volver a tipos de acceso',
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE9E9E9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String label,
    TextEditingController controller, {
    String? prefix,
    bool isPhone = false,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white60, size: 22),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Colors.white60),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF4B4E55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFFF6A00), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFF24262B),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
      ),
      validator: (val) => (val == null || val.isEmpty) ? 'Obligatorio' : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (val) => (val == null || val.isEmpty) ? 'Obligatorio' : null,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.location_city,
          color: Colors.white60,
          size: 22,
        ),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF4B4E55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFFF6A00), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFF24262B),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    bool confirmation = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: confirmation
          ? TextInputAction.next
          : TextInputAction.next,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF4B4E55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFFF6A00), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFF24262B),
      ),
      validator: (value) {
        final policyError = validateStrongPassword(value);
        if (policyError != null) return policyError;
        if (confirmation && value != _passwordController.text) {
          return 'Las contraseñas no coinciden';
        }
        return null;
      },
    );
  }

  Future<void> _handleRegister() async {
    if (!widget.isEditing && !_acceptTerms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Acepta los términos')));
      return;
    }
    if (_formKey.currentState!.validate()) {
      if (widget.isEditing) {
        final error = await widget.controller.updateClient(
          fullName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          department: _selectedDepartment ?? '',
          city: _cityController.text,
          profilePhotoBytes: _profilePhotoBytes,
          profilePhotoFileName: _profilePhotoFileName,
        );
        if (!mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Datos actualizados con éxito!')),
          );
          Navigator.of(context).pop(); // Vuelve al dashboard
        }
      } else {
        final error = await widget.controller.registerClient(
          fullName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          department: _selectedDepartment ?? '',
          city: _cityController.text,
          password: _passwordController.text,
          existingGoogleAccount: widget.existingGoogleAccount,
          profilePhotoBytes: _profilePhotoBytes,
          profilePhotoFileName: _profilePhotoFileName,
        );
        if (!mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        } else {
          final profile = widget.controller.savedProfile;
          if (profile == null) {
            _showMessage('No fue posible cargar el perfil guardado.');
            return;
          }
          if (widget.controller.requiresEmailConfirmation) {
            // Supabase puede requerir la confirmación del correo antes de
            // entregar una sesión. La cuenta ya quedó creada y el cliente
            // debe continuar al directorio, no quedar devuelto a la pantalla
            // anterior sin saber qué ocurrió. Al intentar entrar a un taller
            // se le recordará confirmar el correo e iniciar sesión.
            _showMessage(
              'Cuenta creada. Confirma tu correo para poder entrar a un taller.',
            );
          }
          if (widget.controller.savedLocally) {
            _showMessage(
              'Perfil guardado en este dispositivo. La nube todavía no está conectada.',
            );
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ClientWorkshopSelectionScreen(
                profile: profile,
                tenantContext: widget.tenantContext,
                brandController: widget.brandController,
                authController: widget.authController,
              ),
            ),
          );
        }
      }
    }
  }
}

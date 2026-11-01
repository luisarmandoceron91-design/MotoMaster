import 'package:flutter/material.dart';
import '../../../core/auth/admin_auth_controller.dart';
import '../../../core/branding/workshop_brand.dart';
import '../../../core/tenant/tenant_context.dart';
import 'client_registration_controller.dart';
import 'client_registration_view.dart';

class ClientRegistrationScreen extends StatefulWidget {
  const ClientRegistrationScreen({
    super.key,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
    this.isEditing = false, // Indica si estamos editando el perfil
    this.initialData, // Datos actuales para llenar el formulario
    this.existingGoogleAccount = false,
  });

  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final bool existingGoogleAccount;

  @override
  State<ClientRegistrationScreen> createState() =>
      _ClientRegistrationScreenState();
}

class _ClientRegistrationScreenState extends State<ClientRegistrationScreen> {
  late final ClientRegistrationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ClientRegistrationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            ClientRegistrationView(
              controller: _controller,
              isEditing: widget.isEditing,
              initialData: widget.initialData,
              tenantContext: widget.tenantContext,
              brandController: widget.brandController,
              authController: widget.authController,
              existingGoogleAccount: widget.existingGoogleAccount,
            ),
            if (_controller.isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6A00)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

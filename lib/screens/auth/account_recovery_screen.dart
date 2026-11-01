import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_service.dart';
import 'new_password_screen.dart';

enum RecoveryAccountType { administrator, client }

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({
    super.key,
    required this.accountType,
    this.initialEmail = '',
  });

  final RecoveryAccountType accountType;
  final String initialEmail;

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  static const _accent = Color(0xFFFF6500);
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+57 ');
  final _code = TextEditingController();
  bool _emailMode = true;
  bool _loading = false;
  bool _codeSent = false;
  bool _emailLinkSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail.trim();
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _accountLabel => widget.accountType == RecoveryAccountType.client
      ? 'cliente'
      : 'administrador';

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
              colors: [Color(0x88000000), Color(0x55000000), Color(0xC0000000)],
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xF51A1C20),
                    border: Border.all(color: _accent),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xA8000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: _emailLinkSent
                      ? _emailLinkSentBody()
                      : _codeSent
                      ? _verificationCodeBody()
                      : _requestBody(),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _requestBody() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Volver',
            onPressed: _loading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const Icon(Icons.lock_reset_rounded, color: _accent, size: 54),
        const SizedBox(height: 14),
        const Text(
          'Recupera tu acceso',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Cuenta de $_accountLabel. Tu correo electrónico funciona como identificador de acceso.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFC7C9CC), height: 1.4),
        ),
        const SizedBox(height: 22),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.email_outlined),
              label: Text('Correo'),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.sms_outlined),
              label: Text('Celular (próximamente)'),
              enabled: false,
            ),
          ],
          selected: {_emailMode},
          onSelectionChanged: (selection) => setState(() {
            _emailMode = selection.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),
        if (_emailMode)
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Correo electrónico registrado',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              filled: true,
              fillColor: const Color(0xFF25272C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) => value == null || !value.contains('@')
                ? 'Ingresa el correo usado al registrarte.'
                : null,
          )
        else
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: InputDecoration(
              labelText: 'Celular registrado con indicativo',
              hintText: '+57 3001234567',
              prefixIcon: const Icon(Icons.phone_android_outlined),
              filled: true,
              fillColor: const Color(0xFF25272C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) =>
                value == null ||
                    !value.trim().startsWith('+') ||
                    value.replaceAll(RegExp(r'\D'), '').length < 10
                ? 'Incluye el indicativo y un celular válido.'
                : null,
          ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF8C8C)),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _loading ? null : _sendRecovery,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _emailMode ? 'Enviar enlace al correo' : 'Enviar código por SMS',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Por seguridad, el sistema no confirma públicamente si una cuenta existe.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9FA2A8), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _emailLinkSentBody() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.mark_email_read_outlined, color: _accent, size: 58),
      const SizedBox(height: 14),
      const Text(
        'Revisa tu correo',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      Text(
        'Enviamos un enlace seguro a ${_maskedDestination()}. Ábrelo para crear una contraseña nueva.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFC7C9CC), height: 1.4),
      ),
      const SizedBox(height: 18),
      const Text(
        'Si no aparece, revisa la carpeta de correo no deseado. El enlace vence por seguridad.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF9FA2A8), fontSize: 13),
      ),
      const SizedBox(height: 22),
      FilledButton.icon(
        onPressed: _loading ? null : _sendEmail,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.black,
        ),
        icon: _loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
        label: const Text('Reenviar enlace'),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: _loading ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Volver al inicio de sesión'),
      ),
    ],
  );

  Widget _verificationCodeBody() => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Volver',
            onPressed: _loading
                ? null
                : () => setState(() {
                    _codeSent = false;
                    _error = null;
                  }),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        Icon(
          _emailMode ? Icons.mark_email_unread_outlined : Icons.sms_outlined,
          color: _accent,
          size: 58,
        ),
        const SizedBox(height: 14),
        const Text(
          'Verifica el código',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Escribe los 8 dígitos enviados a ${_maskedDestination()}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFC7C9CC)),
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            counterText: '',
            labelText: 'Código de verificación',
            filled: true,
            fillColor: const Color(0xFF25272C),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (value) => value == null || value.length != 8
              ? 'Ingresa los 8 dígitos.'
              : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF8C8C)),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _loading ? null : _verifyCode,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
            ),
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: const Text(
              'Verificar y continuar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _loading ? null : (_emailMode ? _sendEmail : _sendSms),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reenviar código'),
        ),
      ],
    ),
  );

  String _maskedDestination() {
    if (_emailMode) {
      final value = _email.text.trim();
      final at = value.indexOf('@');
      if (at <= 1) return value;
      return '${value.substring(0, 2)}••••${value.substring(at)}';
    }
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return _phone.text;
    return '••••••${digits.substring(digits.length - 4)}';
  }

  Future<void> _sendRecovery() async {
    if (!_formKey.currentState!.validate()) return;
    if (_emailMode) {
      await _sendEmail();
    } else {
      await _sendSms();
    }
  }

  Future<void> _sendEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().sendPasswordReset(_email.text);
      if (mounted) setState(() => _emailLinkSent = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No fue posible enviar el enlace. Revisa el correo y la conexión e inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendSms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().sendPhoneRecoveryCode(_phone.text);
      if (mounted) setState(() => _codeSent = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'El envío SMS se activará cuando conectemos Supabase y el proveedor de mensajes.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = _emailMode
          ? await AuthService().verifyEmailRecoveryCode(
              email: _email.text,
              code: _code.text,
            )
          : await AuthService().verifyPhoneRecoveryCode(
              phone: _phone.text,
              code: _code.text,
            );
      if (response.session == null) {
        throw StateError('No se creó una sesión de recuperación.');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NewPasswordScreen(
            onCompleted: (recoveryContext) =>
                Navigator.of(recoveryContext).pop(),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'El código no es válido, venció o el servicio de envío aún no está conectado.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

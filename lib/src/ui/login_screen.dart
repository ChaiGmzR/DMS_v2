import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'ui_helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TextEditingController _apiController;
  bool _loading = false;
  bool _showServer = false;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(text: widget.appState.apiBaseUrl);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 980 : 460),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _BrandPanel(
                            apiUrl: widget.appState.apiBaseUrl,
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(width: 420, child: _loginPanel()),
                      ],
                    )
                  : _loginPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'DMS',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Defect Management System',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el usuario'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingresa el PIN' : null,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => setState(() => _showServer = !_showServer),
                icon: Icon(
                  _showServer ? Icons.expand_less : Icons.settings_ethernet,
                ),
                label: Text(
                  _showServer ? 'Ocultar servidor' : 'Configurar servidor API',
                ),
              ),
              if (_showServer) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _apiController,
                  decoration: const InputDecoration(
                    labelText: 'URL API',
                    helperText: 'Ejemplo: http://192.168.1.10:5000/api',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Configura la URL de la API';
                    final uri = Uri.tryParse(text);
                    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                      return 'URL invalida';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Iniciar sesion'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.appState.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        apiUrl: _apiController.text,
      );
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('$error', error: true));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.apiUrl});

  final String apiUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 28),
          Text(
            'Captura, reparacion y validacion de defectos',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            'Version Flutter para telefonos, laptops y estaciones Windows. Usa la misma API del DMS actual.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(icon: Icons.smartphone, label: 'Movil'),
              _Chip(icon: Icons.laptop_windows, label: 'Windows'),
              _Chip(icon: Icons.qr_code_scanner, label: 'Escaneo compatible'),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'API actual: $apiUrl',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    );
  }
}

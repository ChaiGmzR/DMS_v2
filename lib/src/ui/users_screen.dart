import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'ui_helpers.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<SelectOption> _roles = [];
  List<SelectOption> _areas = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SectionHeader(
                title: 'Gestion de usuarios',
                subtitle: '${_users.length} usuarios visibles para tu rol',
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                    FilledButton.icon(
                      onPressed: _roles.isEmpty ? null : _createUser,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Nuevo'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                    ? const Center(child: Text('No hay usuarios para mostrar'))
                    : isCompact(context)
                    ? _mobileList()
                    : _desktopTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopTable() {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Usuario')),
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Rol')),
          DataColumn(label: Text('Area')),
          DataColumn(label: Text('Activo')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: _users.map((user) => _userRow(user)).toList(),
      ),
    );
  }

  DataRow _userRow(Map<String, dynamic> user) {
    final isSelf = '${user['id']}' == '${widget.appState.user?.id}';
    return DataRow(
      cells: [
        DataCell(Text('${user['id']}')),
        DataCell(Text('${user['username']}')),
        DataCell(Text('${user['nombre_completo']}')),
        DataCell(Text(_roleLabel('${user['rol']}'))),
        DataCell(Text('${user['area'] ?? '-'}')),
        DataCell(
          Switch(
            value: user['activo'] == 1 || user['activo'] == true,
            onChanged: isSelf ? null : (value) => _setActive(user, value),
          ),
        ),
        DataCell(_actions(user, isSelf)),
      ],
    );
  }

  Widget _mobileList() {
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _users[index];
        final isSelf = '${user['id']}' == '${widget.appState.user?.id}';
        return ListTile(
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            '${user['username']}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${user['nombre_completo']}\n${_roleLabel('${user['rol']}')} | ${user['area'] ?? '-'}',
          ),
          isThreeLine: true,
          trailing: _actions(user, isSelf),
        );
      },
    );
  }

  Widget _actions(Map<String, dynamic> user, bool isSelf) {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Editar',
          onPressed: () => _editUser(user),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Cambiar PIN',
          onPressed: () => _changePassword(user),
          icon: const Icon(Icons.key_outlined),
        ),
        IconButton(
          tooltip: 'Desactivar',
          onPressed: isSelf ? null : () => _deactivate(user),
          icon: const Icon(Icons.person_off_outlined),
        ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.appState.api.getUsers(),
        widget.appState.api.getRoles(),
        widget.appState.api.getAreas(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<Map<String, dynamic>>;
          _roles = results[1] as List<SelectOption>;
          _areas = results[2] as List<SelectOption>;
        });
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUser() async {
    final result = await showDialog<_UserFormResult>(
      context: context,
      builder: (_) => _UserDialog(roles: _roles, areas: _areas),
    );
    if (result == null) return;
    try {
      await widget.appState.api.createUser(result.toCreateJson());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snack('Usuario creado'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final result = await showDialog<_UserFormResult>(
      context: context,
      builder: (_) => _UserDialog(roles: _roles, areas: _areas, user: user),
    );
    if (result == null) return;
    try {
      await widget.appState.api.updateUser(
        '${user['id']}',
        result.toUpdateJson(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('Usuario actualizado'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<void> _changePassword(Map<String, dynamic> user) async {
    final password = await _passwordDialog('${user['username']}');
    if (password == null) return;
    try {
      await widget.appState.api.changeUserPassword('${user['id']}', password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snack('PIN actualizado'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<void> _deactivate(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('Se desactivara ${user['username']}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.appState.api.deactivateUser('${user['id']}');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('Usuario desactivado'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<void> _setActive(Map<String, dynamic> user, bool active) async {
    try {
      await widget.appState.api.updateUser('${user['id']}', {
        'nombre_completo': user['nombre_completo'],
        'rol': user['rol'],
        'area': user['area'],
        'activo': active,
      });
      await _load();
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<String?> _passwordDialog(String username) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nuevo PIN para $username'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nuevo PIN'),
            validator: (value) => value == null || value.length < 4
                ? 'Minimo 4 caracteres'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, controller.text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _roleLabel(String role) {
    final match = _roles.where((item) => item.value == role).firstOrNull;
    return match?.label ?? role;
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.roles, required this.areas, this.user});

  final List<SelectOption> roles;
  final List<SelectOption> areas;
  final Map<String, dynamic>? user;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _nameController;
  String? _role;
  String? _area;
  bool _active = true;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _usernameController = TextEditingController(
      text: '${user?['username'] ?? ''}',
    );
    _passwordController = TextEditingController();
    _nameController = TextEditingController(
      text: '${user?['nombre_completo'] ?? ''}',
    );
    _role = user == null ? null : '${user['rol']}';
    _area = user?['area'] == null ? null : '${user?['area']}';
    _active = user == null || user['activo'] == 1 || user['activo'] == true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar usuario' : 'Nuevo usuario'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  enabled: !_isEdit,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'PIN'),
                    validator: (value) => value == null || value.length < 4
                        ? 'Minimo 4 caracteres'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: widget.roles
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.value,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _role = value),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _area,
                  decoration: const InputDecoration(labelText: 'Area'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin area'),
                    ),
                    ...widget.areas.map(
                      (item) => DropdownMenuItem(
                        value: item.value,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _area = value),
                ),
                if (_isEdit)
                  SwitchListTile(
                    title: const Text('Activo'),
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _UserFormResult(
                username: _usernameController.text.trim().toLowerCase(),
                password: _passwordController.text,
                nombreCompleto: _nameController.text.trim(),
                rol: _role!,
                area: _area,
                activo: _active,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _UserFormResult {
  const _UserFormResult({
    required this.username,
    required this.password,
    required this.nombreCompleto,
    required this.rol,
    required this.area,
    required this.activo,
  });

  final String username;
  final String password;
  final String nombreCompleto;
  final String rol;
  final String? area;
  final bool activo;

  Map<String, dynamic> toCreateJson() => {
    'username': username,
    'password': password,
    'nombre_completo': nombreCompleto,
    'rol': rol,
    'area': area,
  };

  Map<String, dynamic> toUpdateJson() => {
    'nombre_completo': nombreCompleto,
    'rol': rol,
    'area': area,
    'activo': activo,
  };
}

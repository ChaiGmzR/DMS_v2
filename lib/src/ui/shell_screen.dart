import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'defects_screen.dart';
import 'qa_screen.dart';
import 'repair_screen.dart';
import 'ui_helpers.dart';
import 'users_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final modules = _modules();
    if (_selectedIndex >= modules.length) _selectedIndex = 0;

    final selectedModule = modules[_selectedIndex];
    final defectsSelected = selectedModule.shortLabel == 'Defectos';
    final body = defectsSelected
        ? DefectsScreen(
            appState: widget.appState,
            navigationMenu: modules.length > 1 ? _moduleMenu(modules) : null,
          )
        : IndexedStack(
            index: _selectedIndex,
            children: modules.map((module) => module.screen).toList(),
          );

    return Scaffold(
      appBar: defectsSelected
          ? null
          : AppBar(
              title: Text(selectedModule.label),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(widget.appState.user?.displayName ?? ''),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed: widget.appState.logout,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
      bottomNavigationBar: !defectsSelected && isCompact(context)
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              destinations: modules
                  .map(
                    (module) => NavigationDestination(
                      icon: Icon(module.icon),
                      label: module.shortLabel,
                    ),
                  )
                  .toList(),
            )
          : null,
      body: defectsSelected || isCompact(context)
          ? body
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) =>
                      setState(() => _selectedIndex = value),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 12),
                    child: Icon(Icons.fact_check_outlined, size: 32),
                  ),
                  destinations: modules
                      .map(
                        (module) => NavigationRailDestination(
                          icon: Icon(module.icon),
                          label: Text(module.shortLabel),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
    );
  }

  Widget _moduleMenu(List<_Module> modules) {
    return PopupMenuButton<int>(
      tooltip: 'Cambiar modulo',
      icon: const Icon(Icons.apps),
      onSelected: (index) => setState(() => _selectedIndex = index),
      itemBuilder: (context) => [
        for (var index = 0; index < modules.length; index++)
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Icon(modules[index].icon),
                const SizedBox(width: 10),
                Text(modules[index].shortLabel),
              ],
            ),
          ),
      ],
    );
  }

  List<_Module> _modules() {
    final user = widget.appState.user!;
    final modules = <_Module>[];

    if (user.canCapture ||
        user.rol == 'Supervisor_Calidad' ||
        user.rol == 'Admin') {
      modules.add(
        _Module(
          label: 'Captura y lista de defectos',
          shortLabel: 'Defectos',
          icon: Icons.assignment_add,
          screen: DefectsScreen(appState: widget.appState),
        ),
      );
    }

    if (user.canRepair) {
      modules.add(
        _Module(
          label: 'Reparacion',
          shortLabel: 'Reparacion',
          icon: Icons.build_circle_outlined,
          screen: RepairScreen(appState: widget.appState),
        ),
      );
    }

    if (user.canQuality) {
      modules.add(
        _Module(
          label: 'Validacion QA',
          shortLabel: 'QA',
          icon: Icons.verified_outlined,
          screen: QaScreen(appState: widget.appState),
        ),
      );
    }

    if (user.canManageUsers) {
      modules.add(
        _Module(
          label: 'Gestion de usuarios',
          shortLabel: 'Usuarios',
          icon: Icons.manage_accounts_outlined,
          screen: UsersScreen(appState: widget.appState),
        ),
      );
    }

    return modules;
  }
}

class _Module {
  const _Module({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.screen,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final Widget screen;
}

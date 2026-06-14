import 'package:flutter/material.dart';

import '../services/fish_service.dart';
import '../services/water_body_service.dart';
import '../state/auth_controller.dart';
import 'map_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

/// Tela principal que controla a navegação entre as abas
/// Mapa, Buscar e Eu através de uma BottomNavigationBar.
class HomeShell extends StatefulWidget {
  /// Serviço opcional repassado à tela de busca (usado nos testes).
  final FishService? fishService;

  /// Serviço opcional repassado ao mapa.
  final WaterBodyService? waterBodyService;

  /// Sessão atual; alimenta a aba "Eu". Opcional para os testes existentes.
  final AuthController? auth;

  const HomeShell({super.key, this.fishService, this.waterBodyService, this.auth});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      MapScreen(service: widget.waterBodyService),
      SearchScreen(service: widget.fishService),
      ProfileScreen(auth: widget.auth),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Eu',
          ),
        ],
      ),
    );
  }
}

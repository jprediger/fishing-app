import 'package:flutter/material.dart';

import '../services/fish_service.dart';
import 'map_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

/// Tela principal que controla a navegação entre as abas
/// Mapa, Buscar e Eu através de uma BottomNavigationBar.
class HomeShell extends StatefulWidget {
  /// Serviço opcional repassado à tela de busca (usado nos testes).
  final FishService? fishService;

  const HomeShell({super.key, this.fishService});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    const MapScreen(),
    SearchScreen(service: widget.fishService),
    const ProfileScreen(),
  ];

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
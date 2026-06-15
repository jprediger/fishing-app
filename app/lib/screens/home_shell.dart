import 'package:flutter/material.dart';

import '../models/establishment.dart';
import '../services/catch_service.dart';
import '../services/establishment_service.dart';
import '../services/fish_service.dart';
import '../services/profile_service.dart';
import '../services/water_body_service.dart';
import '../state/auth_controller.dart';
import 'establishment_search_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Tela principal que controla a navegação entre as abas
/// Mapa, Buscar e Eu através de uma BottomNavigationBar.
class HomeShell extends StatefulWidget {
  /// Serviço opcional repassado à tela de busca (usado nos testes).
  final FishService? fishService;

  /// Serviço opcional repassado às telas de catches.
  final CatchService? catchService;

  /// Serviço opcional repassado à tela de perfil.
  final ProfileService? profileService;

  /// Serviço opcional repassado ao mapa.
  final WaterBodyService? waterBodyService;

  /// Serviço opcional repassado à aba "Locais".
  final EstablishmentService? establishmentService;

  /// Sessão atual; alimenta a aba "Eu". Opcional para os testes existentes.
  final AuthController? auth;

  const HomeShell({
    super.key,
    this.fishService,
    this.catchService,
    this.profileService,
    this.waterBodyService,
    this.establishmentService,
    this.auth,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const int _mapIndex = 0;

  int _currentIndex = 0;

  /// Estabelecimento que o usuário pediu para "ver no mapa" (aba Locais).
  /// Repassado ao [MapScreen], que centraliza e marca o ponto.
  Establishment? _focusedEstablishment;

  /// Abre o mapa centralizado no estabelecimento escolhido na aba "Locais".
  void _showEstablishmentOnMap(Establishment establishment) {
    setState(() {
      _focusedEstablishment = establishment;
      _currentIndex = _mapIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Construído a cada build para que mudanças de foco cheguem ao MapScreen.
    final pages = <Widget>[
      MapScreen(
        waterBodyService: widget.waterBodyService,
        fishService: widget.fishService,
        catchService: widget.catchService,
        establishmentService: widget.establishmentService,
        authToken: widget.auth?.token,
        focusEstablishment: _focusedEstablishment,
      ),
      SearchScreen(service: widget.fishService),
      EstablishmentSearchScreen(
        service: widget.establishmentService,
        onShowOnMap: _showEstablishmentOnMap,
      ),
      ProfileScreen(
        auth: widget.auth,
        authToken: widget.auth?.token,
        catchService: widget.catchService,
        profileService: widget.profileService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
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
            icon: Icon(Icons.store_mall_directory_outlined),
            selectedIcon: Icon(Icons.store_mall_directory),
            label: 'Locais',
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

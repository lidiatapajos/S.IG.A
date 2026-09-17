import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../disposal_points/disposal_points_page.dart';
import '../waste_guide/waste_guide_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MapController _mapController = MapController();

  // Belém como localização inicial enquanto o GPS não responde.
  LatLng _localizacaoAtual = const LatLng(-1.4558, -48.4902);

  bool _carregandoLocalizacao = true;

  // Pontos de reciclagem.
  final List<LatLng> _pontosReciclagem = const [
    LatLng(-1.4515, -48.4890),
    LatLng(-1.4568, -48.4840),
    LatLng(-1.4620, -48.4930),
  ];

  @override
  void initState() {
    super.initState();
    _obterLocalizacao();
  }

  Future<void> _obterLocalizacao() async {
    try {
      bool servicoAtivo = await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        setState(() {
          _carregandoLocalizacao = false;
        });
        return;
      }

      LocationPermission permissao = await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        setState(() {
          _carregandoLocalizacao = false;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition();

      final novaLocalizacao = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _localizacaoAtual = novaLocalizacao;
        _carregandoLocalizacao = false;
      });

      _mapController.move(
        novaLocalizacao,
        15,
      );
    } catch (e) {
      setState(() {
        _carregandoLocalizacao = false;
      });
    }
  }

  void _abrirMenu() {
    Scaffold.of(context).openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ==========================================
      // MENU LATERAL
      // ==========================================
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Cabeçalho do menu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  25,
                  20,
                  25,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo/logo_sem_fundo.png',
                      height: 85,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'S.I.G.A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Início
              ListTile(
                leading: const Icon(
                  Icons.home_outlined,
                  color: Color(0xFF1565C0),
                ),
                title: const Text(
                  'Início',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              // Pontos de reciclagem
              ListTile(
                leading: const Icon(
                  Icons.recycling,
                  color: Color(0xFF2E7D32),
                ),
                title: const Text(
                  'Pontos de reciclagem',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PontosDescarteScreen(),
                    ),
                  );
                },
              ),

              // Como separar o lixo
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF1565C0),
                ),
                title: const Text(
                  'Como separar o lixo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Waste(),
                    ),
                  );
                },
              ),

              const Spacer(),

              const Divider(),

              const Padding(
                padding: EdgeInsets.only(
                  bottom: 20,
                ),
                child: Text(
                  'S.I.G.A',
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ==========================================
      // APP BAR
      // ==========================================
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAFC),
        elevation: 0,
        centerTitle: true,

        // ☰ TRÊS LINHAS
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(
                Icons.menu,
                size: 34,
                color: Color(0xFF1565C0),
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),

        // S.I.G.A
        title: const Text(
          'S.I.G.A',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontSize: 27,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),

        // SUA LOGO
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 14,
            ),
            child: Image.asset(
              'assets/logo/logo_sem_fundo.png',
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),

      // ==========================================
      // MAPA
      // ==========================================
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _localizacaoAtual,
              initialZoom: 14.5,
            ),
            children: [
              // Mapa
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.siga',
              ),

              // Pontos de reciclagem
              MarkerLayer(
                markers: [
                  // Localização atual
                  Marker(
                    point: _localizacaoAtual,
                    width: 55,
                    height: 55,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Pontos de reciclagem
                  ..._pontosReciclagem.map(
                    (ponto) {
                      return Marker(
                        point: ponto,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF1565C0),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.recycling,
                            color: Color(0xFF1565C0),
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // ==========================================
          // CARREGANDO LOCALIZAÇÃO
          // ==========================================
          if (_carregandoLocalizacao)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Localizando você...',
                      style: TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ==========================================
          // BOTÃO PARA VOLTAR PARA SUA LOCALIZAÇÃO
          // ==========================================
          Positioned(
            right: 18,
            bottom: 25,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1565C0),
              elevation: 5,
              onPressed: () {
                _mapController.move(
                  _localizacaoAtual,
                  15,
                );
              },
              child: const Icon(
                Icons.my_location,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

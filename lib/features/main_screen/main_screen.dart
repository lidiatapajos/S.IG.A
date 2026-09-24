import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/widgets/api_feedback.dart';
import '../../core/widgets/ecoponto_details.dart';
import '../disposal_points/disposal_points_page.dart';
import '../waste_guide/waste_guide_page.dart';

class MainScreen extends StatefulWidget {
  final LatLng localizacao;
  const MainScreen({super.key, required this.localizacao});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _api = SigaApi();
  final _mapController = MapController();
  late Future<List<Ecoponto>> _pontos;

  @override
  void initState() {
    super.initState();
    _pontos = _api.ecopontos(origem: widget.localizacao);
  }

  void _recarregar() =>
      setState(() => _pontos = _api.ecopontos(origem: widget.localizacao));

  @override
  void dispose() {
    _api.close();
    _mapController.dispose();
    super.dispose();
  }

  void _abrirPonto(Ecoponto ponto) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          SingleChildScrollView(child: EcopontoDetails(ponto: ponto)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: const Color(0xFF1565C0),
                  child: Column(
                    children: [
                      Image.asset('assets/logo/logo_sem_fundo.png', height: 85),
                      const Text(
                        'S.I.G.A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Início'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.recycling, color: Color(0xFF2E7D32)),
                  title: const Text('Pontos de reciclagem'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PontosDescarteScreen(origem: widget.localizacao),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Como separar o lixo'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ComoSepararScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7FAFC),
          foregroundColor: const Color(0xFF1565C0),
          centerTitle: true,
          title: const Text(
            'S.I.G.A',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: _recarregar,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar pontos',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Image.asset('assets/logo/logo_sem_fundo.png', width: 48),
            ),
          ],
        ),
        body: FutureBuilder<List<Ecoponto>>(
          future: _pontos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError) {
              return ApiFeedback(
                error: snapshot.hasError ? snapshot.error : null,
                onRetry: _recarregar,
              );
            }
            final pontos = snapshot.data ?? [];
            return Column(
              children: [
                if (pontos.any((ponto) => ponto.demonstrativo))
                  const DemoNotice(),
                if (pontos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nenhum ponto cadastrado ainda.'),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: widget.localizacao,
                          initialZoom: 14.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.siga',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: widget.localizacao,
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF1565C0),
                                  size: 42,
                                ),
                              ),
                              ...pontos.map(
                                (ponto) => Marker(
                                  point: ponto.posicao,
                                  width: 50,
                                  height: 50,
                                  child: IconButton(
                                    onPressed: () => _abrirPonto(ponto),
                                    tooltip: ponto.nome,
                                    icon: Icon(
                                      ponto.icone,
                                      color: ponto.cor,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SimpleAttributionWidget(
                            source: Text('OpenStreetMap contributors'),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 18,
                        bottom: 36,
                        child: FloatingActionButton(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1565C0),
                          tooltip: 'Voltar ao ponto escolhido',
                          onPressed: () =>
                              _mapController.move(widget.localizacao, 15),
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

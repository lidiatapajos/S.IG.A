import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/widgets/api_feedback.dart';
import '../../core/widgets/ecoponto_details.dart';

class PontosDescarteScreen extends StatefulWidget {
  final LatLng origem;
  const PontosDescarteScreen({super.key, required this.origem});
  @override
  State<PontosDescarteScreen> createState() => _PontosDescarteScreenState();
}

class _PontosDescarteScreenState extends State<PontosDescarteScreen> {
  final _api = SigaApi();
  final _buscaController = TextEditingController();
  late Future<List<Categoria>> _categorias;
  late Future<List<Ecoponto>> _pontos;
  String _filtro = 'Todos';
  Timer? _debounce;
  Ecoponto? _selecionado;

  @override
  void initState() {
    super.initState();
    _categorias = _api.categorias();
    _pontos = _api.ecopontos(origem: widget.origem);
  }

  void _buscar() {
    _debounce?.cancel();
    setState(() {
      _selecionado = null;
      _pontos = _api.ecopontos(
        busca: _buscaController.text,
        categoria: _filtro,
        origem: widget.origem,
      );
    });
  }

  void _mudarBusca(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _buscar);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Pontos de descarte'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1565C0),
          actions: [
            IconButton(
              onPressed: _buscar,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _buscaController,
                onChanged: _mudarBusca,
                decoration: InputDecoration(
                  hintText: 'Buscar por nome, endereço ou bairro',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            FutureBuilder<List<Categoria>>(
              future: _categorias,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () =>
                        setState(() => _categorias = _api.categorias()),
                    child: const Text('Tentar carregar categorias novamente'),
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final opcoes = [
                  const Categoria(id: 0, codigo: 'Todos', nome: 'Todos'),
                  ...snapshot.data!,
                ];
                return SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: opcoes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => ChoiceChip(
                      label: Text(opcoes[index].nome),
                      selected: _filtro == opcoes[index].codigo,
                      onSelected: (_) {
                        _filtro = opcoes[index].codigo;
                        _buscar();
                      },
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: FutureBuilder<List<Ecoponto>>(
                future: _pontos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      snapshot.hasError) {
                    return ApiFeedback(
                      error: snapshot.hasError ? snapshot.error : null,
                      onRetry: _buscar,
                    );
                  }
                  final pontos = snapshot.data ?? [];
                  if (pontos.isEmpty) {
                    return const Center(
                      child: Text('Nenhum ponto encontrado para essa busca.'),
                    );
                  }
                  return Column(
                    children: [
                      if (pontos.any((ponto) => ponto.demonstrativo))
                        const DemoNotice(),
                      Expanded(
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: widget.origem,
                            initialZoom: 14,
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
                                  point: widget.origem,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                                ...pontos.map(
                                  (ponto) => Marker(
                                    point: ponto.posicao,
                                    width: 50,
                                    height: 50,
                                    child: IconButton(
                                      tooltip: ponto.nome,
                                      onPressed: () =>
                                          setState(() => _selecionado = ponto),
                                      icon: Icon(
                                        ponto.icone,
                                        color: ponto.cor,
                                        size: 34,
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
                      ),
                      if (_selecionado != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                          ),
                          child: SingleChildScrollView(
                            child: EcopontoDetails(
                              ponto: _selecionado!,
                              onClose: () =>
                                  setState(() => _selecionado = null),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

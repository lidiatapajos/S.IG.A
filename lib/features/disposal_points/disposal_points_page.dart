import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// Modelo de um ponto de descarte
class Ecoponto {
  final String nome;
  final String endereco;
  final String categoria; // 'Reciclaveis' | 'Eletronicos' | 'Oleo'
  final String horario;
  final LatLng posicao;

  const Ecoponto({
    required this.nome,
    required this.endereco,
    required this.categoria,
    required this.horario,
    required this.posicao,
  });

  Color get cor {
    switch (categoria) {
      case 'Reciclaveis':
        return const Color(0xFF2E7D32);
      case 'Eletronicos':
        return const Color(0xFF546E7A);
      case 'Oleo':
        return const Color(0xFF1565C0);
      default:
        return Colors.grey;
    }
  }

  IconData get icone {
    switch (categoria) {
      case 'Reciclaveis':
        return Icons.recycling;
      case 'Eletronicos':
        return Icons.electrical_services;
      case 'Oleo':
        return Icons.water_drop;
      default:
        return Icons.place;
    }
  }
}

class PontosDescarteScreen extends StatefulWidget {
  const PontosDescarteScreen({super.key});

  @override
  State<PontosDescarteScreen> createState() => _PontosDescarteScreenState();
}

class _PontosDescarteScreenState extends State<PontosDescarteScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _buscaController = TextEditingController();

  // Filtro selecionado: 'Todos', 'Reciclaveis', 'Eletronicos', 'Oleo'
  String _filtroSelecionado = 'Todos';

  // Ponto de descarte selecionado (exibido no card inferior)
  Ecoponto? _ecopontoSelecionado;

  LatLng? _minhaLocalizacao;

  // >>> Substitua pelos ecopontos reais da sua cidade (ou busque de uma API/banco) <<<
  final List<Ecoponto> _ecopontos = const [
    Ecoponto(
      nome: 'Ecoponto Nazaré',
      endereco: 'Av. Nazaré, 987 - Nazaré, Belém/PA',
      categoria: 'Reciclaveis',
      horario: 'Seg a Sáb - 8h às 17h',
      posicao: LatLng(-1.4558, -48.4788),
    ),
    Ecoponto(
      nome: 'Ponto de Coleta Marco',
      endereco: 'R. do Marco, 123 - Marco, Belém/PA',
      categoria: 'Reciclaveis',
      horario: 'Seg a Sex - 9h às 18h',
      posicao: LatLng(-1.4490, -48.4650),
    ),
    Ecoponto(
      nome: 'Coleta Eletrônicos São Brás',
      endereco: 'Av. José Bonifácio, 500 - São Brás, Belém/PA',
      categoria: 'Eletronicos',
      horario: 'Seg a Sex - 8h às 16h',
      posicao: LatLng(-1.4570, -48.4700),
    ),
    Ecoponto(
      nome: 'Ponto de Óleo Nazaré',
      endereco: 'Tv. Padre Eutíquio, 200 - Nazaré, Belém/PA',
      categoria: 'Oleo',
      horario: 'Todos os dias - 7h às 19h',
      posicao: LatLng(-1.4610, -48.4790),
    ),
  ];

  List<Ecoponto> get _ecopontosFiltrados {
    if (_filtroSelecionado == 'Todos') return _ecopontos;
    return _ecopontos.where((e) => e.categoria == _filtroSelecionado).toList();
  }

  @override
  void initState() {
    super.initState();
    _pegarLocalizacaoUsuario();
  }

  Future<void> _pegarLocalizacaoUsuario() async {
    try {
      final habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) return;

      LocationPermission permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) return;
      }
      if (permissao == LocationPermission.deniedForever) return;

      final posicao = await Geolocator.getCurrentPosition();
      setState(() {
        _minhaLocalizacao = LatLng(posicao.latitude, posicao.longitude);
      });
    } catch (_) {
      // Se der erro (ex: emulador sem GPS), o mapa continua funcionando
      // só sem o marcador de localização do usuário.
    }
  }

  double _distanciaKm(LatLng destino) {
    if (_minhaLocalizacao == null) return 0;
    final metros = Geolocator.distanceBetween(
      _minhaLocalizacao!.latitude,
      _minhaLocalizacao!.longitude,
      destino.latitude,
      destino.longitude,
    );
    return metros / 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1565C0)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pontos de descarte',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildBarraBusca(),
          const SizedBox(height: 10),
          _buildFiltros(),
          const SizedBox(height: 10),
          Expanded(child: _buildMapa()),
          if (_ecopontoSelecionado != null)
            _buildCardEcoponto(_ecopontoSelecionado!),
        ],
      ),
    );
  }

  Widget _buildBarraBusca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _buscaController,
        decoration: InputDecoration(
          hintText: 'Buscar ponto de descarte',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF2F4F6),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (texto) {
          // Filtra por nome ou endereço, se quiser complementar o filtro por categoria
          setState(() {});
        },
      ),
    );
  }

  Widget _buildFiltros() {
    final opcoes = [
      {'label': 'Todos', 'value': 'Todos'},
      {'label': 'Recicláveis', 'value': 'Reciclaveis'},
      {'label': 'Eletrônicos', 'value': 'Eletronicos'},
      {'label': 'Óleo', 'value': 'Oleo'},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opcoes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opcao = opcoes[index];
          final selecionado = _filtroSelecionado == opcao['value'];
          return GestureDetector(
            onTap: () => setState(() => _filtroSelecionado = opcao['value']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selecionado ? const Color(0xFF1565C0) : Colors.white,
                border: Border.all(
                  color: selecionado
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFCFD8DC),
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                opcao['label']!,
                style: TextStyle(
                  color: selecionado ? Colors.white : const Color(0xFF455A64),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapa() {
    final centroInicial = _minhaLocalizacao ??
        (_ecopontos.isNotEmpty
            ? _ecopontos.first.posicao
            : const LatLng(-1.4558, -48.4788));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: centroInicial,
        initialZoom: 14,
      ),
      children: [
        // Camada de tiles do OpenStreetMap (gratuita, sem chave de API)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.seuapp.reciclagem',
        ),
        MarkerLayer(
          markers: [
            // Marcador da localização do usuário
            if (_minhaLocalizacao != null)
              Marker(
                point: _minhaLocalizacao!,
                width: 40,
                height: 40,
                child:
                    const Icon(Icons.my_location, color: Colors.blue, size: 30),
              ),
            // Marcadores dos ecopontos filtrados
            ..._ecopontosFiltrados.map(
              (ponto) => Marker(
                point: ponto.posicao,
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => setState(() => _ecopontoSelecionado = ponto),
                  child: Icon(ponto.icone, color: ponto.cor, size: 38),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardEcoponto(Ecoponto ponto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place, color: ponto.cor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ponto.nome,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1565C0)),
                ),
                const SizedBox(height: 2),
                Text(ponto.endereco,
                    style: const TextStyle(
                        color: Color(0xFF546E7A), fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ponto.cor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ponto.icone, size: 14, color: ponto.cor),
                      const SizedBox(width: 4),
                      Text(
                        ponto.categoria == 'Reciclaveis'
                            ? 'Recicláveis'
                            : ponto.categoria == 'Eletronicos'
                                ? 'Eletrônicos'
                                : 'Óleo',
                        style: TextStyle(
                            color: ponto.cor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: Color(0xFF90A4AE)),
                    const SizedBox(width: 4),
                    Text(ponto.horario,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF90A4AE))),
                  ],
                ),
                if (_minhaLocalizacao != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(0xFF90A4AE)),
                      const SizedBox(width: 4),
                      Text(
                        '${_distanciaKm(ponto.posicao).toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF90A4AE)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF1565C0)),
            onPressed: () {
              // Aqui você pode abrir uma tela com mais detalhes do ecoponto
            },
          ),
        ],
      ),
    );
  }
}

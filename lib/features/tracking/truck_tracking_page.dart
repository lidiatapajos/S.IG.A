import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/siga_ui.dart';

class TruckTrackingPage extends StatefulWidget {
  final LatLng initialLocation;
  const TruckTrackingPage({super.key, required this.initialLocation});
  @override
  State<TruckTrackingPage> createState() => _TruckTrackingPageState();
}

class _TruckTrackingPageState extends State<TruckTrackingPage> with WidgetsBindingObserver {
  final _api = SigaApi(timeout: const Duration(seconds: 10));
  final _map = MapController();
  final _age = Stopwatch();
  Timer? _timer;
  List<TruckPosition> _trucks = [];
  bool _busy = false, _resumed = true, _centered = false;
  String? _error;
  int _tick = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_resumed || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      setState(() {});
      if (++_tick % 5 == 0) _load();
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _load();
  }
  int _seconds(TruckPosition truck) => truck.idadeSegundos + _age.elapsed.inSeconds;
  bool _live(TruckPosition truck) => _error == null && _seconds(truck) <= 30;
  Future<void> _load() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    final requestAge = Stopwatch()..start();
    try {
      final trucks = await _api.caminhoes();
      if (!mounted) return;
      setState(() {
        // Contagem conservadora: inclui latência para nunca rejuvenescer sinal antigo.
        _trucks = trucks.map((t) => TruckPosition(id: t.id, nome: t.nome,
          posicao: t.posicao, precisao: t.precisao,
          idadeSegundos: t.idadeSegundos + requestAge.elapsed.inSeconds)).toList();
        _age..reset()..start(); _error = null;
      });
      if (!_centered && trucks.isNotEmpty && _resumed) {
        _map.move(trucks.first.posicao, 16); _centered = true;
      }
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : 'Não foi possível atualizar o mapa.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel(); _api.close(); _map.dispose(); _age.stop();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final trucks = _trucks.where((t) => _seconds(t) < 120).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Onde está o caminhão?'), actions: [
        IconButton(tooltip: 'Atualizar posições', onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const InfoBanner('Simulação com aparelho real da equipe. Não representa um veículo oficial de coleta.',
          icon: Icons.science_outlined, color: AppColors.greenDark),
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child:
          InfoBanner('Sem confirmação ao vivo. $_error', icon: Icons.wifi_off, color: Colors.orange)),
        SizedBox(height: 340, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: widget.initialLocation, initialZoom: 14),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'br.com.siga.app'),
            MarkerLayer(markers: trucks.map((t) => Marker(point: t.posicao, width: 56, height: 56,
              child: Tooltip(message: '${t.nome}: ${_live(t) ? 'ao vivo' : 'última posição'}',
                child: Container(decoration: BoxDecoration(color: _live(t) ? AppColors.greenDark : Colors.grey,
                  shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 30))))).toList()),
            const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
          ],
        ))),
        const SizedBox(height: 14),
        if (trucks.isEmpty && !_busy) const InfoBanner('Nenhum caminhão transmitindo agora. Peça à equipe para iniciar o compartilhamento no aparelho autorizado.', icon: Icons.local_shipping_outlined),
        ...trucks.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: FeatureTile(
          icon: Icons.local_shipping_outlined, title: t.nome,
          subtitle: '${_live(t) ? 'Ao vivo' : 'Sinal desatualizado / conexão indisponível'} • há ${_seconds(t)} s\nPrecisão GPS: aproximadamente ${t.precisao.round()} m',
          color: _live(t) ? AppColors.greenDark : Colors.grey,
          onTap: () => _map.move(t.posicao, 16)))),
        const Text('Consulta automática a cada 5 segundos. Após 30 segundos sem GPS novo, o sinal fica desatualizado; após 2 minutos, a posição sai do mapa. O mapa precisa de internet.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

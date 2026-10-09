import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/api_feedback.dart';
import '../../core/widgets/ecoponto_details.dart';
import '../../core/widgets/siga_ui.dart';
import '../disposal_points/disposal_points_page.dart';
import '../waste_guide/waste_guide_page.dart';
import '../reports/report_page.dart';
import '../reports/track_report_page.dart';

class MainScreen extends StatefulWidget {
  final LatLng localizacao;
  const MainScreen({super.key, required this.localizacao});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _api = SigaApi();
  late Future<List<Ecoponto>> _pontos;
  @override
  void initState() { super.initState(); _pontos = _api.ecopontos(origem: widget.localizacao); }
  @override
  void dispose() { _api.close(); super.dispose(); }
  void _refresh() => setState(() => _pontos = _api.ecopontos(origem: widget.localizacao));
  void _open(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  void _point(Ecoponto point) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => SingleChildScrollView(child: EcopontoDetails(ponto: point)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(children: [
        Image.asset('assets/logo/logo_sem_fundo.png', height: 33),
        const SizedBox(width: 10),
        const Text('S.I.G.A', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.blueDark, letterSpacing: 1.4)),
      ]),
      actions: [IconButton(tooltip: 'Atualizar', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      indicatorColor: AppColors.lightBlue,
      onDestinationSelected: (i) {
        if (i == 1) _open(PontosDescarteScreen(origem: widget.localizacao));
        if (i == 2) _open(const ComoSepararScreen());
        if (i == 3) _open(ReportPage(initialLocation: widget.localizacao));
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
        NavigationDestination(icon: Icon(Icons.place_outlined), label: 'Ecopontos'),
        NavigationDestination(icon: Icon(Icons.recycling_rounded), label: 'Separar'),
        NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Denunciar'),
      ],
    ),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: RefreshIndicator(onRefresh: () async { _refresh(); try { await _pontos; } catch (_) {} },
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 24), children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.blueDark, AppColors.blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OLÁ, BELÉM! 🌿', style: TextStyle(color: Color(0xFFD8EBFF), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              const Text('O que vamos fazer pelo\nmeio ambiente hoje?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.16)),
              const SizedBox(height: 20),
              Row(children: [const Icon(Icons.location_on_outlined, color: Colors.white, size: 18), const SizedBox(width: 7),
                Expanded(child: Text('Sua região • Belém, PA', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                TextButton(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('Alterar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              ]),
            ]),
          ),
          const SizedBox(height: 22),
          const SectionHeading('Acesso rápido', subtitle: 'Tudo que você precisa em poucos toques'),
          const SizedBox(height: 12),
          FeatureTile(icon: Icons.add_location_alt_outlined, title: 'Pontos de descarte', subtitle: 'Encontre lugares para descartar corretamente',
            onTap: () => _open(PontosDescarteScreen(origem: widget.localizacao))),
          const SizedBox(height: 10),
          FeatureTile(icon: Icons.recycling_rounded, title: 'Como separar o lixo', subtitle: 'Descubra o destino correto de cada resíduo', color: AppColors.greenDark,
            onTap: () => _open(const ComoSepararScreen())),
          const SizedBox(height: 10),
          FeatureTile(icon: Icons.camera_alt_outlined, title: 'Denunciar descarte irregular', subtitle: 'Fotografe e informe o local, de forma anônima', color: const Color(0xFFDB7138),
            onTap: () => _open(ReportPage(initialLocation: widget.localizacao))),
          const SizedBox(height: 10),
          FeatureTile(icon: Icons.receipt_long_outlined, title: 'Acompanhar denúncia', subtitle: 'Consulte a situação usando seu protocolo', color: AppColors.blueDark,
            onTap: () => _open(const TrackReportPage())),
          const SizedBox(height: 24),
          const SectionHeading('Perto de você', subtitle: 'Pontos encontrados no mapa da região'),
          const SizedBox(height: 12),
          SizedBox(height: 245, child: ClipRRect(borderRadius: BorderRadius.circular(20),
            child: FlutterMap(options: MapOptions(initialCenter: widget.localizacao, initialZoom: 13.8), children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'br.com.siga.projeto'),
              MarkerLayer(markers: [Marker(point: widget.localizacao, width: 46, height: 46,
                child: const Icon(Icons.location_pin, color: AppColors.blue, size: 40))]),
              const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
            ]),
          )),
          const SizedBox(height: 12),
          FutureBuilder<List<Ecoponto>>(future: _pontos, builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done || snap.hasError) {
              return SizedBox(height: 135, child: ApiFeedback(error: snap.hasError ? snap.error : null, onRetry: _refresh));
            }
            final points = snap.data ?? [];
            if (points.isEmpty) return const InfoBanner('Nenhum ecoponto cadastrado nesta região ainda.');
            return Column(children: [
              if (points.any((p) => p.demonstrativo)) const Padding(padding: EdgeInsets.only(bottom: 10), child: DemoNotice()),
              ...points.take(3).map((p) => Padding(padding: const EdgeInsets.only(bottom: 9), child:
                FeatureTile(icon: p.icone, title: p.nome, subtitle: p.distanciaKm == null ? '${p.categoriaNome} • Belém' : '${p.categoriaNome} • ${p.distanciaKm!.toStringAsFixed(1)} km em linha reta', color: p.cor, onTap: () => _point(p)))),
            ]);
          }),
          const SizedBox(height: 14),
          const InfoBanner('O S.I.G.A é um protótipo acadêmico. Confirme endereço e horários antes de ir a um ponto de descarte.', icon: Icons.school_outlined, color: AppColors.greenDark),
        ]),
      ),
    )),
  );
}

import 'package:flutter/material.dart';
import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/api_feedback.dart';
import '../../core/widgets/siga_ui.dart';
import '../../core/theme/app_colors.dart';
import 'confirm_location_page.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _api = SigaApi();
  final _search = TextEditingController();
  late Future<List<Bairro>> _bairros;
  bool _loadingGps = false;
  @override
  void initState() { super.initState(); _bairros = _api.bairros(); }
  @override
  void dispose() { _search.dispose(); _api.close(); super.dispose(); }

  void _open({String? bairro, double? latitude, double? longitude}) => Navigator.push(context,
    MaterialPageRoute<void>(builder: (_) => ConfirmLocationPage(bairro: bairro, latitude: latitude, longitude: longitude)));

  Future<void> _gps() async {
    setState(() => _loadingGps = true);
    try {
      final p = await obterLocalizacaoAtual();
      if (!mounted) return;
      _open(latitude: p.latitude, longitude: p.longitude);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is LocationException
        ? e.message : 'GPS não disponível. Escolha sua região no mapa.')));
    } finally { if (mounted) setState(() => _loadingGps = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sua localização')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeading('Onde você está?', subtitle: 'Escolha seu bairro ou marque um ponto no mapa.'),
            const SizedBox(height: 16),
            TextField(controller: _search, onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar bairro em Belém')),
            const SizedBox(height: 12),
            FeatureTile(icon: Icons.my_location_rounded, title: _loadingGps ? 'Localizando...' : 'Usar minha localização',
              subtitle: 'Permitir acesso ao GPS do dispositivo', onTap: _loadingGps ? () {} : _gps),
            const SizedBox(height: 9),
            FeatureTile(icon: Icons.map_outlined, title: 'Escolher no mapa', subtitle: 'Indique o local com precisão, sem GPS',
              color: AppColors.greenDark, onTap: () => _open()),
            const SizedBox(height: 20),
            const SectionHeading('Bairros', subtitle: 'Selecione um para escolher o ponto exato no mapa'),
          ])),
        Expanded(child: FutureBuilder<List<Bairro>>(future: _bairros, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || snap.hasError) {
            return ApiFeedback(error: snap.hasError ? snap.error : null,
              onRetry: () => setState(() => _bairros = _api.bairros()));
          }
          final search = _search.text.trim().toLowerCase();
          final bairros = (snap.data ?? []).where((b) => b.nome.toLowerCase().contains(search)).toList();
          if (bairros.isEmpty) return const Center(child: Text('Nenhum bairro encontrado.', style: TextStyle(color: AppColors.textSecondary)));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20), itemCount: bairros.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (_, i) => Material(color: Colors.white, borderRadius: BorderRadius.circular(13),
              child: InkWell(onTap: () => _open(bairro: bairros[i].nome), borderRadius: BorderRadius.circular(13),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.greenDark, size: 22),
                    const SizedBox(width: 12), Expanded(child: Text(bairros[i].nome,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ])),
              ),
            ),
          );
        })),
      ]),
    )),
  );
}

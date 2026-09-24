import 'package:flutter/material.dart';

import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/api_feedback.dart';
import '../../core/theme/app_colors.dart';
import 'confirm_location_page.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _api = SigaApi();
  final _searchController = TextEditingController();
  late Future<List<Bairro>> _bairros;
  bool _buscandoLocalizacao = false;

  @override
  void initState() {
    super.initState();
    _bairros = _api.bairros();
  }

  Future<void> usarLocalizacaoAtual() async {
    setState(() => _buscandoLocalizacao = true);
    try {
      final posicao = await obterLocalizacaoAtual();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ConfirmLocationPage(
            latitude: posicao.latitude,
            longitude: posicao.longitude,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is LocationException
                ? error.message
                : 'Não foi possível obter sua localização. Selecione um bairro ou ponto no mapa.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _buscandoLocalizacao = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Selecione sua localização')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar bairro',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.my_location, color: AppColors.blue),
                title: Text(
                  _buscandoLocalizacao
                      ? 'Buscando localização...'
                      : 'Usar minha localização atual',
                ),
                onTap: _buscandoLocalizacao ? null : usarLocalizacaoAtual,
                trailing: _buscandoLocalizacao
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: AppColors.green),
                title: const Text('Escolher diretamente no mapa'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ConfirmLocationPage(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'BAIRROS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Bairro>>(
                  future: _bairros,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done ||
                        snapshot.hasError) {
                      return ApiFeedback(
                        error: snapshot.hasError ? snapshot.error : null,
                        onRetry: () =>
                            setState(() => _bairros = _api.bairros()),
                      );
                    }
                    final busca = _searchController.text.trim().toLowerCase();
                    final bairros = (snapshot.data ?? [])
                        .where((b) => b.nome.toLowerCase().contains(busca))
                        .toList();
                    if (bairros.isEmpty) {
                      return const Center(
                          child: Text('Nenhum bairro encontrado.'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: bairros.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.green,
                        ),
                        title: Text(bairros[index].nome),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ConfirmLocationPage(
                                bairro: bairros[index].nome),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

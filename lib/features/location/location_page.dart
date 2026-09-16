import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'confirm_location_page.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _buscandoLocalizacao = false;

  final List<String> bairros = [
    'Água Branca',
    'Área Militar',
    'Benguí',
    'Campina',
    'Canudos',
    'Condor',
    'Cremação',
    'Guamá',
    'Jurunas',
    'Marco',
    'Nazaré',
    'Pedreira',
    'Reduto',
    'Sacramenta',
    'São Brás',
    'Tapanã',
    'Terra Firme',
    'Umarizal',
    'Val-de-Cans',
  ];

  late List<String> bairrosFiltrados;

  @override
  void initState() {
    super.initState();
    bairrosFiltrados = bairros;
  }

  void filtrarBairros(String texto) {
    setState(() {
      bairrosFiltrados = bairros.where((bairro) {
        return bairro.toLowerCase().contains(texto.toLowerCase());
      }).toList();
    });
  }

  void abrirConfirmacaoBairro(String bairro) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmLocationPage(
          bairro: bairro,
        ),
      ),
    );
  }

  Future<void> usarLocalizacaoAtual() async {
    setState(() {
      _buscandoLocalizacao = true;
    });

    try {
      bool servicoAtivo = await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ative a localização do dispositivo para continuar.',
            ),
          ),
        );

        return;
      }

      LocationPermission permissao = await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A permissão de localização foi negada.',
            ),
          ),
        );

        return;
      }

      if (permissao == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A permissão de localização está bloqueada nas configurações.',
            ),
          ),
        );

        return;
      }

      final Position posicao = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmLocationPage(
            latitude: posicao.latitude,
            longitude: posicao.longitude,
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível obter sua localização.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _buscandoLocalizacao = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Selecione sua localização',
          style: AppTextStyles.subtitle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: filtrarBairros,
                decoration: const InputDecoration(
                  hintText: 'Buscar bairro',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: InkWell(
                onTap: _buscandoLocalizacao ? null : usarLocalizacaoAtual,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _buscandoLocalizacao
                              ? 'Buscando sua localização...'
                              : 'Usar minha localização atual',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_buscandoLocalizacao)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BAIRROS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: bairrosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum bairro encontrado.',
                        style: AppTextStyles.body,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      itemCount: bairrosFiltrados.length,
                      separatorBuilder: (context, index) {
                        return const Divider(
                          height: 1,
                          color: AppColors.border,
                        );
                      },
                      itemBuilder: (context, index) {
                        final bairro = bairrosFiltrados[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.secondary,
                          ),
                          title: Text(
                            bairro,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () {
                            abrirConfirmacaoBairro(bairro);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

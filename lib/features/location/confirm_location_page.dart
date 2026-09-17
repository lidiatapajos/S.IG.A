import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

import '../disposal_points/disposal_points_page.dart';

class ConfirmLocationPage extends StatefulWidget {
  final String? bairro;
  final double? latitude;
  final double? longitude;

  const ConfirmLocationPage({
    super.key,
    this.bairro,
    this.latitude,
    this.longitude,
  });

  @override
  State<ConfirmLocationPage> createState() => _ConfirmLocationPageState();
}

class _ConfirmLocationPageState extends State<ConfirmLocationPage> {
  // Centro aproximado de Belém
  static const LatLng belem = LatLng(
    -1.4558,
    -48.4902,
  );

  late LatLng localizacao;

  @override
  void initState() {
    super.initState();

    if (widget.latitude != null && widget.longitude != null) {
      localizacao = LatLng(
        widget.latitude!,
        widget.longitude!,
      );
    } else {
      localizacao = belem;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String localExibido = widget.bairro ?? 'Localização atual';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Confirmar localização',
          style: AppTextStyles.subtitle,
        ),
      ),
      body: Column(
        children: [
          // MAPA
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: localizacao,
                    initialZoom: 15,

                    // Permite alterar o ponto tocando no mapa
                    onTap: (tapPosition, point) {
                      setState(() {
                        localizacao = point;
                      });
                    },
                  ),
                  children: [
                    // OPENSTREETMAP
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.siga.app',
                    ),

                    // MARCADOR
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: localizacao,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on,
                            size: 45,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // CARD SOBRE O MAPA
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Local selecionado',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                localExibido,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PARTE INFERIOR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta localização está correta?',
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Você pode tocar no mapa para ajustar o ponto.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DisposalPointsPage(),
                            ));
                      },
                      icon: const Icon(
                        Icons.check_circle_outline,
                      ),
                      label: const Text(
                        'Confirmar localização',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

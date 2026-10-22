import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/siga_ui.dart';

class ReportLocationPage extends StatefulWidget {
  final LatLng initialLocation;
  const ReportLocationPage({super.key, required this.initialLocation});
  @override
  State<ReportLocationPage> createState() => _ReportLocationPageState();
}

class _ReportLocationPageState extends State<ReportLocationPage> {
  late LatLng position;
  @override
  void initState() { super.initState(); position = widget.initialLocation; }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local do descarte')),
    body: Column(children: [
      const Padding(padding: EdgeInsets.all(14), child: InfoBanner(
        'Toque no mapa para indicar onde está o lixo, não necessariamente onde você está.', icon: Icons.touch_app_outlined)),
      Expanded(child: FlutterMap(
        options: MapOptions(initialCenter: position, initialZoom: 15.5, onTap: (_, p) => setState(() => position = p)),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'br.com.siga.projeto'),
          MarkerLayer(markers: [Marker(point: position, width: 54, height: 54,
            child: const Icon(Icons.location_on_rounded, color: AppColors.blue, size: 50))]),
          const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
        ],
      )),
      Container(padding: const EdgeInsets.all(18), color: Colors.white, child: SafeArea(top: false,
        child: Column(children: [
          Text('Lat ${position.latitude.toStringAsFixed(5)}  •  Long ${position.longitude.toStringAsFixed(5)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, position),
            icon: const Icon(Icons.check_circle_outline), label: const Text('Confirmar este ponto'))),
        ]),
      )),
    ]),
  );
}

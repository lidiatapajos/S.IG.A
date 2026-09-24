import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}

Future<LatLng> obterLocalizacaoAtual() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException(
      'Ative a localização do dispositivo para continuar.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationException(
      'Libere a localização nas configurações do dispositivo ou selecione um ponto no mapa.',
    );
  }
  if (permission == LocationPermission.denied) {
    throw const LocationException(
      'A permissão foi negada. Você também pode selecionar um ponto no mapa.',
    );
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(timeLimit: Duration(seconds: 15)),
  );
  return LatLng(position.latitude, position.longitude);
}

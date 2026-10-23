import 'dart:async';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'tracking_api.dart';

/// Android foreground service: stays active with the phone screen locked.
/// The per-device token is only kept in memory, never written to disk.
@pragma('vm:entry-point')
void startTrackingTask() {
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(SigaTrackerTask());
}

class SigaTrackerTask extends TaskHandler {
  String? _id;
  String? _token;
  bool _sending = false;
  bool _stopping = false;
  int _lastSentMillis = 0;

  void _status(String message, {bool error = false}) {
    FlutterForegroundTask.sendDataToMain({'type': error ? 'error' : 'status', 'message': message});
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    FlutterForegroundTask.sendDataToMain({'type': 'ready'});
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    if (data['action'] == 'link') {
      final id = data['id'];
      final token = data['token'];
      if (id is String && token is String && !_stopping) {
        _id = id;
        _token = token;
        FlutterForegroundTask.sendDataToMain({'type': 'linked'});
        _status('Rastreamento ativo. Pode bloquear a tela.');
      }
    } else if (data['action'] == 'stop') {
      unawaited(_stop());
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_id == null || _token == null || _sending || _stopping) return;
    unawaited(_send());
  }

  Future<void> _send() async {
    _sending = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        timeLimit: const Duration(seconds: 14),
      );
      final captured = position.timestamp.millisecondsSinceEpoch;
      if (captured <= _lastSentMillis) return;
      await TrackingApi.sendPosition(id: _id!, token: _token!, position: position);
      _lastSentMillis = captured;
      final time = DateTime.now();
      final text = 'Último envio: ${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';
      _status(text);
      await FlutterForegroundTask.updateService(
        notificationTitle: 'SIGA Rastreador • GPS ativo',
        notificationText: text,
      );
    } on TrackingException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        _status('Sessão inválida ou expirada. Peça nova autorização.', error: true);
        await _stop(deleteSession: false);
      } else if (e.statusCode == 409) {
        // The last GPS fix was repeated, no need to send it again.
      } else {
        _status(e.message, error: true);
      }
    } catch (_) {
      _status('Sem GPS ou internet. Tentando novamente...', error: true);
    } finally {
      _sending = false;
    }
  }

  Future<void> _stop({bool deleteSession = true}) async {
    if (_stopping) return;
    _stopping = true;
    // The task may be in the middle of sending. Prevent more uploads.
    final id = _id;
    final token = _token;
    _id = null;
    _token = null;
    if (deleteSession && id != null && token != null) {
      try {
        await TrackingApi.endSession(id: id, token: token);
      } catch (_) {
        _status('Parado no celular; o mapa ocultará a posição em até 2 minutos.', error: true);
      }
    }
    _status('Compartilhamento encerrado.');
    await FlutterForegroundTask.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _id = null;
    _token = null;
  }
}

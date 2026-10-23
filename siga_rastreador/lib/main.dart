import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'tracker_service.dart';
import 'tracking_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'siga_localizacao',
      channelName: 'SIGA - Localização ativa',
      channelDescription: 'Mostra quando este aparelho está transmitindo GPS como caminhão de simulação.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
  runApp(const SigaTrackerApp());
}

class SigaTrackerApp extends StatelessWidget {
  const SigaTrackerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SIGA Rastreador',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff7855b7)),
      useMaterial3: true,
    ),
    home: const TrackingPage(),
  );
}

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final _keyController = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  bool _running = false;
  String _message = 'Este aparelho não está transmitindo.';
  ({String id, String token})? _pendingCredentials;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onServiceData);
    _syncRunning();
  }

  Future<void> _syncRunning() async {
    final active = await FlutterForegroundTask.isRunningService;
    if (!mounted) return;
    setState(() {
      _running = active;
      if (active) _message = 'Serviço ativo. Toque em Parar para encerrar.';
    });
  }

  void _onServiceData(Object data) {
    if (!mounted || data is! Map) return;
    final type = data['type'];
    if (type == 'ready') _sendCredentialsToTask();
    if (type == 'linked') {
      _pendingCredentials = null;
      _keyController.clear();
    }
    if (type == 'status' || type == 'error') {
      setState(() => _message = data['message']?.toString() ?? 'Atualização do serviço.');
      if (_message.contains('encerrado') || _message.contains('expirada')) {
        unawaited(_syncRunning());
      }
    }
  }

  void _sendCredentialsToTask() {
    final pair = _pendingCredentials;
    if (pair != null) {
      FlutterForegroundTask.sendDataToTask({'action': 'link', 'id': pair.id, 'token': pair.token});
    }
  }

  Future<void> _start() async {
    if (_busy || _running) return;
    if (!_consent) {
      setState(() => _message = 'Marque a autorização antes de iniciar.');
      return;
    }
    setState(() { _busy = true; _message = 'Validando chave e GPS...'; });
    try {
      if (!Platform.isAndroid) throw Exception('Este aplicativo foi preparado somente para Android.');
      final pair = TrackingApi.decodeKey(_keyController.text);
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Ative a localização GPS do celular.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Permita a localização precisa para o SIGA Rastreador nas configurações do Android.');
      }
      if (await Geolocator.getLocationAccuracy() != LocationAccuracyStatus.precise) {
        throw Exception('Habilite a localização precisa (não aproximada) nas permissões do aplicativo.');
      }
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Validate the token with the existing backend BEFORE starting background tracking.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        timeLimit: const Duration(seconds: 18),
      );
      await TrackingApi.sendPosition(id: pair.id, token: pair.token, position: position);
      _pendingCredentials = pair;
      final startResult = await FlutterForegroundTask.startService(
        serviceId: 701,
        serviceTypes: const [ForegroundServiceTypes.location],
        notificationTitle: 'SIGA Rastreador • GPS ativo',
        notificationText: 'Compartilhando localização do caminhão de simulação',
        callback: startTrackingTask,
      );
      // The API response varies across plugin versions; verify actual service state.
      final running = await FlutterForegroundTask.isRunningService;
      if (!running) throw Exception('Não foi possível iniciar o serviço Android ($startResult).');
      // Backup for slow Android task isolate initialization.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _sendCredentialsToTask();
      if (!mounted) return;
      setState(() { _running = true; _message = 'GPS em execução. Pode bloquear a tela.'; });
    } catch (e) {
      _pendingCredentials = null;
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() { _busy = true; _message = 'Encerrando compartilhamento...'; });
    try {
      FlutterForegroundTask.sendDataToTask({'action': 'stop'});
      // The task deletes the server-side session before stopping. Allow a short window.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (await FlutterForegroundTask.isRunningService) {
        // If the worker did not answer, ensure that the phone stops transmitting.
        await FlutterForegroundTask.stopService();
      }
      _pendingCredentials = null;
      _keyController.clear();
      if (mounted) setState(() { _running = false; _consent = false; _message = 'Compartilhamento interrompido.'; });
    } catch (_) {
      if (mounted) setState(() => _message = 'Falha ao encerrar. Verifique a notificação do Android.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onServiceData);
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(title: const Text('SIGA • Rastreador')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.local_shipping_outlined, size: 74, color: Color(0xff7855b7)),
              const SizedBox(height: 14),
              Text('Este celular representa um caminhão', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text('Aplicativo exclusivo para celulares autorizados pelo administrador. A localização será exibida no mapa público do SIGA enquanto a sessão estiver ativa.', textAlign: TextAlign.center),
              const SizedBox(height: 22),
              TextField(
                controller: _keyController,
                enabled: !_running && !_busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Chave do caminhão',
                  hintText: 'Cole a chave gerada no painel web',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: (_running || _busy) ? null : (checked) => setState(() => _consent = checked ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Autorizo o compartilhamento do GPS deste aparelho durante a simulação.'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (_busy || _running) ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar transmissão'),
              ),
              OutlinedButton.icon(
                onPressed: (_busy || !_running) ? null : _stop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Parar e desvincular'),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(_running ? Icons.radio_button_checked : Icons.radio_button_off, color: _running ? Colors.green : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_message)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Enquanto a transmissão estiver ativa, o Android mostrará uma notificação. Você pode bloquear a tela. A autorização atual expira em até 4 horas; se o serviço for encerrado pelo sistema, abra o app e inicie novamente. Não manipule o celular dirigindo.'),
            ],
          ),
        ),
      ),
    );
  }
}

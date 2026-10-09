import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import '../../core/services/siga_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/siga_ui.dart';
import 'report_location_page.dart';
import 'report_success_page.dart';

class ReportPage extends StatefulWidget {
  final LatLng initialLocation;
  const ReportPage({super.key, required this.initialLocation});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _api = SigaApi();
  final _desc = TextEditingController();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  late LatLng _position;
  String _category = 'lixo_domestico';
  Uint8List? _photo;
  bool _sending = false;
  bool _processing = false;
  String? _error;
  final Map<String, String> _categories = const {
    'lixo_domestico': 'Lixo doméstico',
    'entulho': 'Entulho / construção',
    'moveis': 'Móveis e objetos',
    'perigosos': 'Resíduos perigosos',
    'outros': 'Outros',
  };

  @override
  void initState() { super.initState(); _position = widget.initialLocation; }
  @override
  void dispose() { _api.close(); _desc.dispose(); super.dispose(); }

  Future<void> _choosePhoto(ImageSource source) async {
    setState(() { _processing = true; _error = null; });
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1550, maxHeight: 1550, imageQuality: 82);
      if (picked == null) return;
      final raw = await picked.readAsBytes();
      // Recria o bitmap em uma imagem nova antes de enviar: reduz informações embutidas.
      final decoded = img.decodeImage(raw);
      if (decoded == null) throw const FormatException('Não foi possível abrir esta imagem. Use JPG ou PNG.');
      final clean = img.Image(width: decoded.width, height: decoded.height);
      img.compositeImage(clean, decoded);
      Uint8List? encoded;
      for (final quality in [82, 68, 52, 38]) {
        final candidate = Uint8List.fromList(img.encodeJpg(clean, quality: quality));
        if (candidate.lengthInBytes <= 2 * 1024 * 1024) { encoded = candidate; break; }
      }
      if (encoded == null) throw const FormatException('Foto muito grande. Tente outra com menos detalhes.');
      if (!mounted) return;
      setState(() => _photo = encoded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is FormatException ? e.message : 'Não foi possível selecionar a foto. Tente novamente.');
    } finally { if (mounted) setState(() => _processing = false); }
  }

  Future<void> _choosePlace() async {
    final point = await Navigator.push<LatLng>(context, MaterialPageRoute(
      builder: (_) => ReportLocationPage(initialLocation: _position)));
    if (point != null && mounted) setState(() => _position = point);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) { setState(() => _error = 'Adicione uma foto do local antes de enviar.'); return; }
    setState(() { _sending = true; _error = null; });
    try {
      final data = await _api.enviarDenuncia(
        categoria: _category,
        descricao: _desc.text.trim(),
        latitude: _position.latitude,
        longitude: _position.longitude,
        fotoBase64: 'data:image/jpeg;base64,${base64Encode(_photo!)}',
      );
      if (!mounted) return;
      final code = data['protocolo']?.toString();
      if (code == null || code.isEmpty) throw const ApiException('O servidor não enviou um protocolo.');
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => ReportSuccessPage(protocol: code)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Falha ao enviar denúncia. Tente novamente.');
    } finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Denunciar descarte')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650), child:
      Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 28), children: [
        const SectionHeading('Vamos cuidar da nossa cidade', subtitle: 'Registre um descarte irregular de forma anônima.'),
        const SizedBox(height: 16),
        const InfoBanner('Não informe dados pessoais, não fotografe rostos nem se aproxime de locais perigosos.',
          icon: Icons.shield_outlined, color: AppColors.greenDark),
        const SizedBox(height: 20),
        const SectionHeading('1. Foto do local'),
        const SizedBox(height: 10),
        SigaCard(child: Column(children: [
          if (_photo != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.memory(_photo!, height: 185, width: double.infinity, fit: BoxFit.cover)),
            const SizedBox(height: 10),
            const Text('Foto preparada para envio', style: TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w700)),
          ] else ...[
            Container(height: 115, width: double.infinity,
              decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(14)),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.blue),
                SizedBox(height: 8), Text('Adicione uma foto da ocorrência', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              ])),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: (_sending || _processing) ? null : () => _choosePhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Galeria'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: (_sending || _processing) ? null : () => _choosePhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 18), label: const Text('Câmera'))),
          ]),
          if (_processing) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
        ])),
        const SizedBox(height: 20),
        const SectionHeading('2. Tipo de descarte'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: _category,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined), labelText: 'Selecione a categoria'),
          items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: _sending ? null : (value) { if (value != null) setState(() => _category = value); },
        ),
        const SizedBox(height: 20),
        const SectionHeading('3. Local da ocorrência'),
        const SizedBox(height: 10),
        FeatureTile(icon: Icons.edit_location_alt_outlined, title: 'Ajustar no mapa',
          subtitle: 'Lat ${_position.latitude.toStringAsFixed(5)} • Long ${_position.longitude.toStringAsFixed(5)}',
          onTap: _choosePlace),
        const SizedBox(height: 8),
        const InfoBanner('Confirme o ponto exato do lixo: o GPS pode indicar somente sua posição atual.', icon: Icons.info_outline),
        const SizedBox(height: 20),
        const SectionHeading('4. Mais detalhes (opcional)'),
        const SizedBox(height: 10),
        TextFormField(controller: _desc, maxLength: 500, maxLines: 4,
          decoration: const InputDecoration(hintText: 'Ex.: entulho acumulado na calçada, próximo à esquina...'),
          validator: (v) => (v?.length ?? 0) > 500 ? 'Máximo de 500 caracteres.' : null),
        if (_error != null) ...[
          const SizedBox(height: 10), InfoBanner(_error!, color: const Color(0xFFB84242), icon: Icons.error_outline),
        ],
        const SizedBox(height: 17),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: (_sending || _processing) ? null : _submit,
          icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
          label: Text(_sending ? 'Enviando denúncia...' : 'Enviar denúncia anônima'))),
        const SizedBox(height: 11),
        const Text('O envio precisa de internet e do backend disponível. Você só receberá um protocolo se o servidor confirmar o registro.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
      ])),
    )),
  );
}

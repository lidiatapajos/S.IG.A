import 'package:flutter/material.dart';
import '../../core/services/siga_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/siga_ui.dart';

class TrackReportPage extends StatefulWidget {
  final String? initialProtocol;
  const TrackReportPage({super.key, this.initialProtocol});
  @override
  State<TrackReportPage> createState() => _TrackReportPageState();
}

class _TrackReportPageState extends State<TrackReportPage> {
  final _api = SigaApi();
  late final TextEditingController _controller;
  bool loading = false;
  Map<String, dynamic>? result;
  String? error;
  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.initialProtocol ?? '');
    if (widget.initialProtocol != null) WidgetsBinding.instance.addPostFrameCallback((_) => _search()); }
  @override
  void dispose() { _controller.dispose(); _api.close(); super.dispose(); }
  String _label(String s) => {
    'pendente':'Recebida', 'em_analise':'Em análise', 'em_atendimento':'Em atendimento',
    'resolvida':'Resolvida', 'rejeitada':'Não aprovada',
  }[s] ?? s;

  Future<void> _search() async {
    final code = _controller.text.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{48}$').hasMatch(code)) {
      setState(() { error = 'Digite um protocolo válido de 48 caracteres.'; result = null; });
      return;
    }
    setState(() { loading = true; error = null; result = null; });
    try {
      final data = await _api.consultarDenuncia(code);
      if (!mounted) return;
      setState(() => result = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e is ApiException ? e.message : 'Não foi possível consultar o protocolo.');
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acompanhar denúncia')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: ListView(
      padding: const EdgeInsets.all(20), children: [
        const SectionHeading('Consultar protocolo', subtitle: 'Acompanhe sua solicitação sem precisar se cadastrar.'),
        const SizedBox(height: 18),
        TextField(controller: _controller, autocorrect: false, maxLength: 48,
          decoration: const InputDecoration(labelText: 'Código do protocolo', prefixIcon: Icon(Icons.receipt_long_outlined)),
          onSubmitted: (_) => _search()),
        const SizedBox(height: 4),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: loading ? null : _search,
          icon: const Icon(Icons.search_rounded), label: Text(loading ? 'Consultando...' : 'Consultar andamento'))),
        if (error != null) ...[
          const SizedBox(height: 18), InfoBanner(error!, color: const Color(0xFFB34242), icon: Icons.error_outline),
        ],
        if (result != null) ...[
          const SizedBox(height: 22),
          SigaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SITUAÇÃO DA OCORRÊNCIA', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.circle, color: AppColors.greenDark, size: 13), const SizedBox(width: 8),
              Text(_label(result!['status']?.toString() ?? 'pendente'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary))]),
            const Divider(height: 26),
            Text('Tipo: ${result!['categoria'] ?? '-'}'),
            const SizedBox(height: 6),
            Text('Descrição: ${(result!['descricao']?.toString().isNotEmpty ?? false) ? result!['descricao'] : 'Sem descrição'}'),
            const SizedBox(height: 6),
            Text('Registrada em: ${result!['criado_em'] ?? '-'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
        ],
        const SizedBox(height: 24),
        const InfoBanner('O protocolo é privado. O andamento depende da análise dos responsáveis pelo serviço.', icon: Icons.privacy_tip_outlined),
      ],
    ))),
  );
}

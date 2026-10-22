import 'package:flutter/material.dart';
import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/api_feedback.dart';
import '../../core/widgets/siga_ui.dart';

class ComoSepararScreen extends StatefulWidget {
  const ComoSepararScreen({super.key});
  @override
  State<ComoSepararScreen> createState() => _ComoSepararScreenState();
}

class _ComoSepararScreenState extends State<ComoSepararScreen> {
  final _api = SigaApi();
  late Future<GuiaData> _guia;
  int _tab = 0;
  @override
  void initState() { super.initState(); _guia = _api.guia(); }
  @override
  void dispose() { _api.close(); super.dispose(); }
  void _reload() => setState(() => _guia = _api.guia());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Como separar')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 660), child: Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(18, 8, 18, 15), child:
        SectionHeading('Cada resíduo no seu lugar ♻️', subtitle: 'Descubra onde e como descartar corretamente.')),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [ _tabButton('Tipos de resíduos', 0), _tabButton('Dicas práticas', 1) ]),
      )),
      const SizedBox(height: 12),
      Expanded(child: FutureBuilder<GuiaData>(future: _guia, builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.hasError) {
          return ApiFeedback(error: snap.hasError ? snap.error : null, onRetry: _reload);
        }
        final guia = snap.data!;
        if (_tab == 1) {
          if (guia.dicas.isEmpty) return const Center(child: Text('Nenhuma dica cadastrada.'));
          return ListView.separated(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            itemCount: guia.dicas.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => SigaCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(
                color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.greenDark)),
              const SizedBox(width: 12), Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child:
                Text(guia.dicas[i], style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.45)))),
            ])));
        }
        if (guia.residuos.isEmpty) return const Center(child: Text('Nenhum tipo de resíduo cadastrado.'));
        return ListView.separated(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          itemCount: guia.residuos.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _residuoCard(guia.residuos[i]));
      })),
    ]))),
  );

  Widget _tabButton(String text, int index) => Expanded(child: Material(color: Colors.transparent,
    child: InkWell(onTap: () => setState(() => _tab = index), borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: _tab == index ? AppColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(12)),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800,
          color: _tab == index ? Colors.white : AppColors.blue, fontSize: 13))),
    ),
  ));

  Widget _residuoCard(ResiduoInfo item) => SigaCard(padding: EdgeInsets.zero,
    child: ClipRRect(borderRadius: BorderRadius.circular(19), child: IntrinsicHeight(child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(width: 79, color: item.corPrincipal, alignment: Alignment.center,
        child: Icon(item.icone, color: Colors.white, size: 36)),
      Expanded(child: Container(color: item.corFundo, padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(item.titulo, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: item.corPrincipal)),
          const SizedBox(height: 6),
          Text(item.descricao, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.45)),
        ]))),
    ]))));
}

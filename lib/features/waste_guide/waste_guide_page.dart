import 'package:flutter/material.dart';

import '../../core/models/siga_models.dart';
import '../../core/services/siga_api.dart';
import '../../core/widgets/api_feedback.dart';

// Mantém compatibilidade com chamadas anteriores, sem criar outro MaterialApp.
class Waste extends StatelessWidget {
  const Waste({super.key});
  @override
  Widget build(BuildContext context) => const ComoSepararScreen();
}

class ComoSepararScreen extends StatefulWidget {
  const ComoSepararScreen({super.key});
  @override
  State<ComoSepararScreen> createState() => _ComoSepararScreenState();
}

class _ComoSepararScreenState extends State<ComoSepararScreen> {
  final _api = SigaApi();
  late Future<GuiaData> _guia;
  int _aba = 0;

  @override
  void initState() {
    super.initState();
    _guia = _api.guia();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  void _recarregar() => setState(() => _guia = _api.guia());

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Como separar'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1565C0),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3EEFC),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    _botaoAba('Tipos de resíduos', 0),
                    _botaoAba('Dicas', 1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<GuiaData>(
                future: _guia,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      snapshot.hasError) {
                    return ApiFeedback(
                      error: snapshot.hasError ? snapshot.error : null,
                      onRetry: _recarregar,
                    );
                  }
                  final guia = snapshot.data!;
                  if (_aba == 1) {
                    if (guia.dicas.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma dica cadastrada ainda.'),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: guia.dicas
                          .map(
                            (dica) => ListTile(
                              leading: const Icon(
                                Icons.lightbulb_outline,
                                color: Color(0xFF1565C0),
                              ),
                              title: Text(dica),
                            ),
                          )
                          .toList(),
                    );
                  }
                  if (guia.residuos.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma orientação cadastrada ainda.'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: guia.residuos.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _card(guia.residuos[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _botaoAba(String texto, int index) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _aba = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:
                  _aba == index ? const Color(0xFF1565C0) : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            alignment: Alignment.center,
            child: Text(
              texto,
              style: TextStyle(
                color: _aba == index ? Colors.white : const Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

  Widget _card(ResiduoInfo item) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                color: item.corPrincipal,
                alignment: Alignment.center,
                child: Icon(item.icone, color: Colors.white, size: 36),
              ),
              Expanded(
                child: Container(
                  color: item.corFundo,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: item.corPrincipal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.descricao,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF546E7A),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

import 'package:flutter/material.dart';

void main() => runApp(const Waste());

class Waste extends StatelessWidget {
  const Waste({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Como separar',
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const ComoSepararScreen(),
    );
  }
}

/// Modelo simples para cada tipo de resíduo
class ResiduoInfo {
  final String titulo;
  final String descricao;
  final IconData icone;
  final Color corPrincipal;
  final Color corFundo;

  const ResiduoInfo({
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.corPrincipal,
    required this.corFundo,
  });
}

class ComoSepararScreen extends StatefulWidget {
  const ComoSepararScreen({super.key});

  @override
  State<ComoSepararScreen> createState() => _ComoSepararScreenState();
}

class _ComoSepararScreenState extends State<ComoSepararScreen> {
  // 0 = Tipos de resíduos | 1 = Dicas
  int _abaSelecionada = 0;

  final List<ResiduoInfo> _residuos = const [
    ResiduoInfo(
      titulo: 'Resíduos orgânicos',
      descricao:
          'Restos de alimentos, frutas, verduras, cascas, borra de café.',
      icone: Icons.eco,
      corPrincipal: Color(0xFF2E7D32),
      corFundo: Color(0xFFE3F3E5),
    ),
    ResiduoInfo(
      titulo: 'Recicláveis',
      descricao: 'Papel, papelão, plásticos, metais e vidros.',
      icone: Icons.recycling,
      corPrincipal: Color(0xFF1565C0),
      corFundo: Color(0xFFDCEBFB),
    ),
    ResiduoInfo(
      titulo: 'Rejeitos',
      descricao:
          'Itens não recicláveis, como papel higiênico, fraldas e embalagens sujas.',
      icone: Icons.delete_outline,
      corPrincipal: Color(0xFF455A64),
      corFundo: Color(0xFFE7EBEC),
    ),
    ResiduoInfo(
      titulo: 'Resíduos perigosos',
      descricao:
          'Pilhas, baterias, lâmpadas, medicamentos. Devem ser levados a pontos de descarte específicos.',
      icone: Icons.warning_amber_rounded,
      corPrincipal: Color(0xFFD32F2F),
      corFundo: Color(0xFFFBE1E1),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1565C0)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Volta para a tela anterior (ex: pagina_principal)
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Como separar',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildToggleTabs(),
          const SizedBox(height: 8),
          Expanded(
            child: _abaSelecionada == 0 ? _buildListaResiduos() : _buildDicas(),
          ),
        ],
      ),
    );
  }

  /// Pílula com as duas abas (Tipos de resíduos / Dicas)
  Widget _buildToggleTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE3EEFC),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _buildTabButton('Tipos de resíduos', 0),
            _buildTabButton('Dicas', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String texto, int index) {
    final bool selecionado = _abaSelecionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _abaSelecionada = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selecionado ? const Color(0xFF1565C0) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              color: selecionado ? Colors.white : const Color(0xFF1565C0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Lista de cards com os tipos de resíduos
  Widget _buildListaResiduos() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _residuos.length,
      itemBuilder: (context, index) {
        final item = _residuos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildResiduoCard(item),
        );
      },
    );
  }

  Widget _buildResiduoCard(ResiduoInfo item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Faixa colorida com ícone
            Container(
              width: 90,
              color: item.corPrincipal,
              alignment: Alignment.center,
              child: Icon(item.icone, color: Colors.white, size: 36),
            ),
            // Texto
            Expanded(
              child: Container(
                color: item.corFundo,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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

  /// Conteúdo simples para a aba "Dicas"
  Widget _buildDicas() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0)),
          title: Text('Lave as embalagens recicláveis antes de descartar.'),
        ),
        ListTile(
          leading: Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0)),
          title: Text('Nunca misture pilhas e baterias com o lixo comum.'),
        ),
        ListTile(
          leading: Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0)),
          title: Text('Separe o óleo de cozinha usado em garrafas PET.'),
        ),
      ],
    );
  }
}

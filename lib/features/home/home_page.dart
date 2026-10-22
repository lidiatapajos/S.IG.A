import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/siga_ui.dart';
import '../location/confirm_location_page.dart';
import '../location/location_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  Future<void> _useGps() async {
    setState(() => _loading = true);
    try {
      final p = await obterLocalizacaoAtual();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => ConfirmLocationPage(latitude: p.latitude, longitude: p.longitude)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        e is LocationException ? e.message : 'GPS indisponível. Você pode selecionar o local manualmente.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 15),
              Expanded(child: SingleChildScrollView(
                child: Column(children: [
                  Align(alignment: Alignment.centerLeft, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(99)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.eco_rounded, color: AppColors.greenDark, size: 16), SizedBox(width: 6),
                      Text('CUIDANDO DE BELÉM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.greenDark))
                    ]),
                  )),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.blue.withAlpha(15), blurRadius: 40, spreadRadius: 8)],
                    ),
                    child: Image.asset('assets/logo/logo_sem_fundo.png', height: 164, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.recycling_rounded, size: 126, color: AppColors.blue)),
                  ),
                  const SizedBox(height: 26),
                  const Text('S.I.G.A', style: TextStyle(color: AppColors.blueDark, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const Text('Sistema Integrado de Gestão de Resíduos', textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4)),
                  const SizedBox(height: 21),
                  const Text('Sua cidade mais limpa começa com uma atitude.', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: AppColors.textPrimary, fontWeight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 8),
                  const Text('Encontre pontos de descarte, aprenda a separar os resíduos e ajude a cuidar de Belém.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 28),
                  const InfoBanner('Projeto acadêmico de tecnologia e sustentabilidade • Belém, PA', icon: Icons.school_outlined, color: AppColors.greenDark),
                ]),
              )),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _loading ? null : _useGps,
                icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
                label: Text(_loading ? 'Buscando sua localização...' : 'Usar minha localização'),
              )),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LocationPage())),
                icon: const Icon(Icons.search_rounded), label: const Text('Escolher bairro ou endereço'),
              )),
              const SizedBox(height: 16),
              const Text('S.I.G.A • Protótipo de uso cidadão', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/siga_ui.dart';
import 'track_report_page.dart';

class ReportSuccessPage extends StatelessWidget {
  final String protocol;
  const ReportSuccessPage({super.key, required this.protocol});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Denúncia registrada'), automaticallyImplyLeading: false),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.greenDark, size: 72)),
          const SizedBox(height: 22),
          const Text('Recebemos sua denúncia!', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 9),
          const Text('A ocorrência foi registrada na API. Guarde o protocolo para acompanhar o andamento.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 22),
          SigaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SEU PROTOCOLO PRIVADO', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 10),
            SelectableText(protocol, style: const TextStyle(color: AppColors.blueDark, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: protocol));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Protocolo copiado.'))); },
              icon: const Icon(Icons.copy_rounded), label: const Text('Copiar protocolo'))),
          ])),
          const SizedBox(height: 16),
          const InfoBanner('Quem tiver esse código poderá consultar o status da ocorrência. Não o publique.',
            icon: Icons.lock_outline, color: AppColors.greenDark),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => TrackReportPage(initialProtocol: protocol))),
            child: const Text('Acompanhar denúncia'))),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), child: const Text('Voltar ao início')),
        ]),
      ),
    )),
  );
}

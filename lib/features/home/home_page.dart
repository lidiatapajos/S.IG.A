import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../location/confirm_location_page.dart';
import '../location/location_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _useCurrentLocation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfirmLocationPage(),
      ),
    );
  }

  void _searchAddress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo/logo_sem_fundo.png',
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'S.I.G.A',
                      style: AppTextStyles.siga,
                    ),
                    const Text(
                      'SISTEMA INTEGRADO\nDE GESTÃO DE RESÍDUOS',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 3,
                      width: 200,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'PREFEITURA DE',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const Text(
                      'BELÉM',
                      style: AppTextStyles.belem,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Belém mais limpa,\npor você.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.slogan,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _useCurrentLocation(context),
                      icon: const Icon(Icons.location_on, size: 26),
                      label: const Text(
                        'USAR MINHA\nLOCALIZAÇÃO',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.button,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: AppColors.white,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'OU',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _searchAddress(context),
                      icon: const Icon(Icons.location_on, size: 24),
                      label: const Text(
                        'BUSCAR UM\nENDEREÇO',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.button,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(
                          color: AppColors.blue,
                          width: 2,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

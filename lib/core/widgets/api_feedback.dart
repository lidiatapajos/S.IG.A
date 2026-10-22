import 'package:flutter/material.dart';

import '../services/siga_api.dart';

class ApiFeedback extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const ApiFeedback({super.key, this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is ApiException
                          ? (error as ApiException).message
                          : 'Não foi possível carregar os dados. Tente novamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
        ),
      );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFFFF3D6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Text(
          'Há pontos de demonstração neste mapa. Os locais e horários marcados como exemplo não foram confirmados.',
          style: TextStyle(fontSize: 12, color: Color(0xFF684900)),
        ),
      );
}

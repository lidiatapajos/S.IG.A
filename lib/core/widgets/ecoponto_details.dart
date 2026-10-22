import 'package:flutter/material.dart';

import '../models/siga_models.dart';

class EcopontoDetails extends StatelessWidget {
  final Ecoponto ponto;
  final VoidCallback? onClose;
  const EcopontoDetails({super.key, required this.ponto, this.onClose});
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ponto.icone, color: ponto.cor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ponto.nome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(ponto.endereco),
                    const SizedBox(height: 4),
                    Text(ponto.categoriaNome,
                        style: TextStyle(color: ponto.cor)),
                    Text(ponto.horario),
                    if (ponto.distanciaKm != null)
                      Text(
                        '${ponto.distanciaKm!.toStringAsFixed(1)} km em linha reta do ponto escolhido',
                      ),
                    if (ponto.demonstrativo)
                      const Text(
                        'Exemplo de teste: local e horário não confirmados.',
                        style: TextStyle(color: Color(0xFF684900)),
                      ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar',
                ),
            ],
          ),
        ),
      );
}

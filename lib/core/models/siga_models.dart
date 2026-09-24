import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Bairro {
  final int id;
  final String nome;
  const Bairro({required this.id, required this.nome});
  factory Bairro.fromJson(Map<String, dynamic> json) =>
      Bairro(id: json['id'] as int, nome: json['nome'] as String);
}

class Categoria {
  final int id;
  final String codigo;
  final String nome;
  const Categoria({required this.id, required this.codigo, required this.nome});
  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id'] as int,
        codigo: json['codigo'] as String,
        nome: json['nome'] as String,
      );
}

class Ecoponto {
  final int id;
  final String nome;
  final String endereco;
  final String categoria;
  final String categoriaNome;
  final String horario;
  final LatLng posicao;
  final bool demonstrativo;
  final double? distanciaKm;

  const Ecoponto({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.categoria,
    required this.categoriaNome,
    required this.horario,
    required this.posicao,
    required this.demonstrativo,
    this.distanciaKm,
  });

  factory Ecoponto.fromJson(Map<String, dynamic> json) => Ecoponto(
        id: json['id'] as int,
        nome: json['nome'] as String,
        endereco: json['endereco'] as String,
        categoria: json['categoria'] as String,
        categoriaNome: json['categoria_nome'] as String,
        horario: json['horario'] as String,
        posicao: LatLng(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        ),
        demonstrativo: json['demonstrativo'] as bool,
        distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      );

  Color get cor {
    switch (categoria) {
      case 'Reciclaveis':
        return const Color(0xFF2E7D32);
      case 'Eletronicos':
        return const Color(0xFF546E7A);
      case 'Oleo':
        return const Color(0xFF1565C0);
      default:
        return Colors.grey;
    }
  }

  IconData get icone {
    switch (categoria) {
      case 'Reciclaveis':
        return Icons.recycling;
      case 'Eletronicos':
        return Icons.electrical_services;
      case 'Oleo':
        return Icons.water_drop;
      default:
        return Icons.place;
    }
  }
}

class ResiduoInfo {
  final String codigo;
  final String titulo;
  final String descricao;
  const ResiduoInfo({
    required this.codigo,
    required this.titulo,
    required this.descricao,
  });
  factory ResiduoInfo.fromJson(Map<String, dynamic> json) => ResiduoInfo(
        codigo: json['codigo'] as String,
        titulo: json['titulo'] as String,
        descricao: json['descricao'] as String,
      );

  Color get corPrincipal {
    switch (codigo) {
      case 'Organicos':
        return const Color(0xFF2E7D32);
      case 'Reciclaveis':
        return const Color(0xFF1565C0);
      case 'Perigosos':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF455A64);
    }
  }

  Color get corFundo => corPrincipal.withAlpha(26);
  IconData get icone {
    switch (codigo) {
      case 'Organicos':
        return Icons.eco;
      case 'Reciclaveis':
        return Icons.recycling;
      case 'Perigosos':
        return Icons.warning_amber_rounded;
      default:
        return Icons.delete_outline;
    }
  }
}

class GuiaData {
  final List<ResiduoInfo> residuos;
  final List<String> dicas;
  const GuiaData({required this.residuos, required this.dicas});
}

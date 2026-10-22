import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SigaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const SigaCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withAlpha(140)),
          boxShadow: const [BoxShadow(color: Color(0x0C123D65), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeading(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ],
      );
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  const FeatureTile({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.color = AppColors.blue});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(width: 50, height: 50,
                decoration: BoxDecoration(color: color.withAlpha(23), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 25)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.25)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.textSecondary),
            ]),
          ),
        ),
      );
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline, this.color = AppColors.blue});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: color.withAlpha(19), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [Icon(icon, color: color, size: 19), const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.35)))]),
      );
}

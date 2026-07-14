import 'package:flutter/material.dart';

class WasteCategory {
  const WasteCategory({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.descriptionVi,
    required this.descriptionEn,
    required this.disposalInstructionVi,
    required this.disposalInstructionEn,
    required this.colorHex,
  });

  final String id;
  final String nameVi;
  final String nameEn;
  final String descriptionVi;
  final String descriptionEn;
  final String disposalInstructionVi;
  final String disposalInstructionEn;
  final String colorHex;

  String name(Locale locale) => locale.languageCode == 'en' ? nameEn : nameVi;

  String description(Locale locale) =>
      locale.languageCode == 'en' ? descriptionEn : descriptionVi;

  String disposalInstruction(Locale locale) => locale.languageCode == 'en'
      ? disposalInstructionEn
      : disposalInstructionVi;

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}

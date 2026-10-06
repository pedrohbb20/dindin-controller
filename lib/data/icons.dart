import 'package:flutter/material.dart';

/// Ícones de categoria disponíveis (por nome).
///
/// O Flutter exige instâncias `const` de [IconData] para manter o
/// tree-shaking de fontes no build de release, então guardamos o NOME do
/// ícone no banco e resolvemos aqui para um ícone constante.
const Map<String, IconData> kIconesCategoria = {
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'home': Icons.home,
  'favorite': Icons.favorite,
  'school': Icons.school,
  'sports_esports': Icons.sports_esports,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'work': Icons.work,
  'trending_up': Icons.trending_up,
  'savings': Icons.savings,
  'card_giftcard': Icons.card_giftcard,
  'swap_horiz': Icons.swap_horiz,
  'attach_money': Icons.attach_money,
  'more_horiz': Icons.more_horiz,
};

/// Resolve o ícone pelo nome guardado no banco (fallback seguro).
IconData iconeCategoria(String? nome) =>
    kIconesCategoria[nome] ?? Icons.more_horiz;

import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

class EventFilters extends StatelessWidget {
  const EventFilters({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: l10n.searchEvents,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}

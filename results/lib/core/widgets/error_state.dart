import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.title, required this.error});

  final String title;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SelectableText(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// App brand mark — shield logo from assets/logo/app_icon.png.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

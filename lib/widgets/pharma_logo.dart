import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PharmaLogo extends StatelessWidget {
  const PharmaLogo({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/PharmaLab_logo.svg',
      width: height * 1174 / 513,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: 'PharmaLab',
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/pharma_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PharmaLabApp());
}

class PharmaLabApp extends StatelessWidget {
  const PharmaLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaLab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('es', 'BO'),
      supportedLocales: const [
        Locale('es', 'BO'),
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginScreen(),
      builder: (context, child) {
        final service = PharmaService.instance;
        return ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final page = child ?? const SizedBox.shrink();
            return Column(
              children: [
                if (service.isLoggedIn) const Material(
                  color:  Color(0xFFFFF3D6),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Sesión real ·, stock, pedidos y cambios '
                          'de dirección de prueba ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color.fromARGB(255, 13, 32, 68),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(key: const ValueKey('app-navigator'), child: page),
              ],
            );
          },
        );
      },
    );
  }
}

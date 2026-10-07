import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/sync_config.dart';
import 'data/tema.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Datas em português (calendário, formatos locais)
  await initializeDateFormatting('pt_BR');
  // SQLite no desktop (Linux/Windows/macOS)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Preferência de tema salva (padrão: modo escuro)
  await Tema.carregar();
  // Nuvem de sincronização (só liga se a chave estiver configurada; sem ela
  // o app funciona 100% offline, como sempre funcionou).
  if (SyncConfig.configurado) {
    try {
      await Supabase.initialize(
        url: SyncConfig.url,
        publishableKey: SyncConfig.chave,
      );
    } catch (_) {
      // sem nuvem o app segue funcionando normalmente
    }
  }
  runApp(const DindinApp());
}

class DindinApp extends StatelessWidget {
  const DindinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Tema.tudo,
      builder: (context, _) {
        return MaterialApp(
          title: 'Dindin Controller',
          debugShowCheckedModeBanner: false,
          theme: Tema.claro(),
          darkTheme: Tema.escuro(),
          themeMode: Tema.notifier.value,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        );
      },
    );
  }
}

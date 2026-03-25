import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/app.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_store_plus/media_store_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeDateFormatting('es', null);
  await initializeDateFormatting('es_CO', null);
  await MediaStore.ensureInitialized();
  MediaStore.appFolder = 'CameYo';
  await initializeDependencies();

  runApp(const CameYoApp());
}

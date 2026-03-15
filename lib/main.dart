import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/app.dart';
import 'package:flutter_app/core/di/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeDependencies();

  runApp(const CameYoApp());
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/app.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/app_insights_service.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:flutter_app/core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('AI_CONN: ${AppConstants.appInsightsConnectionString}');

  AppInsightsService.instance.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeDateFormatting('es', null);
  await initializeDateFormatting('es_CO', null);
  await MediaStore.ensureInitialized();
  MediaStore.appFolder = 'CameYo';
  await initializeDependencies();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Flutter error: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  runZonedGuarded(
    () {
      AppLogger.event('app_started');
      runApp(const CameYoApp());
    },
    (error, stackTrace) {
      AppLogger.error('Uncaught error', error, stackTrace);
    },
  );
}

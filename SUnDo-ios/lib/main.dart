import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'app/widget_background.dart';
import 'data/services/home_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidgetService.configure();
  final deps = await AppDependencies.create();
  await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  runApp(RoutiningApp(deps: deps));
}

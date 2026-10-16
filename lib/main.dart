import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'app/widget_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await AppDependencies.create();
  await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  runApp(RoutiningApp(deps: deps));
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mvp_app/app_controller.dart';
import 'package:mvp_app/ui_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainStage(),
    );
  }
}

class MainStage extends StatefulWidget {
  const MainStage({super.key});

  @override
  State<MainStage> createState() => _MainStageState();
}

class _MainStageState extends State<MainStage> with WidgetsBindingObserver {
  late final AppController controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = AppController();
    _initialization = controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    unawaited(controller.handleLifecycleStateChanged(state));

    if (state != AppLifecycleState.resumed) {
      controller.handleAppBackgrounded();
      return;
    }

    unawaited(_resumePomodoroTimeline());
  }

  Future<void> _resumePomodoroTimeline() async {
    await _initialization;
    if (!mounted) {
      return;
    }

    await controller.synchronizeWithCurrentTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        final Widget content;
        if (snapshot.connectionState != ConnectionState.done) {
          content = const Center(child: CircularProgressIndicator());
        } else {
          content = UIWidgets(controller: controller);
        }

        return Scaffold(body: content);
      },
    );
  }
}

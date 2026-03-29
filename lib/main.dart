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

class _MainStageState extends State<MainStage> {
  late final AppController controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    controller = AppController();
    _initialization = controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.webp'),
                fit: BoxFit.cover,
              ),
            ),
            child: UIWidgets(controller: controller),
          ),
        );
      },
    );
  }
}

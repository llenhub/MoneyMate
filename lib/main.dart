import 'package:material_ui/material_ui.dart';

void main() => runApp(const MoneyMateApp());

class MoneyMateApp extends StatelessWidget {
  const MoneyMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MoneyMate',
    theme: ThemeData(colorSchemeSeed: const Color(0xff26805d)),
    home: Scaffold(
      appBar: AppBar(title: const Text('MoneyMate')),
      body: const Center(child: Text('MoneyMate')),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'inventory.dart'; // Import Firebase Storage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Envanter Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: InventoryScreen(),
    );
  }
}

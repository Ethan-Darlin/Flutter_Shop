import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/auth_screen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/user_info_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> kNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: kNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(), // Обертка для проверки авторизации
      routes: {
        '/products': (context) => ProductListScreen(), // Маршрут для экрана с продуктами
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final FirebaseService firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: firebaseService.auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final User user = snapshot.data!;
          return UserInfoScreen(
            userId: user.uid,
            emailVerified: user.emailVerified,
          );
        } else {
          return AuthScreen();
        }
      },
    );
  }
}
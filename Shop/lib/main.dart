import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/auth_screen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/productDetailScreen.dart';
import 'package:shop/screens/user_info_screen.dart';
import 'firebase_options.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await savePushToken(user.uid);
  }

  runApp(const MyApp());
}

Future<void> savePushToken(String userId) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'push_token': token});
      print('Push token сохранён: $token');
    } else {
      print('Не удалось получить push token');
    }
  } catch (e) {
    print('Ошибка при сохранении push token: $e');
  }
}

final GlobalKey<NavigatorState> kNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await savePushToken(user.uid);
      }
    });
  }

  void _initDeepLinks() async {

    _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) _navigateFromDeepLink(uri);
    });

    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) _navigateFromDeepLink(initialUri);
  }

  void _navigateFromDeepLink(Uri uri) {

    if (uri.scheme == 'myapp' && uri.host == 'product' && uri.queryParameters.containsKey('productId')) {
      final productId = uri.queryParameters['productId'];
      if (productId != null) {
        kNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: productId),
          ),
        );
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: kNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(),
      routes: {
        '/products': (context) => ProductListScreen(),
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
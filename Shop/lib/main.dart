import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/auth_screen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/productDetailScreen.dart';
import 'package:shop/screens/user_info_screen.dart';
import 'firebase_options.dart';
import 'package:app_links/app_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
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
  }

  void _initDeepLinks() async {
    // Для случая, когда приложение уже запущено
    _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) _navigateFromDeepLink(uri);
    });

    // Для случая, когда приложение запущено по ссылке из закрытого состояния
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) _navigateFromDeepLink(initialUri);
  }

  void _navigateFromDeepLink(Uri uri) {
    // Пример: myapp://product?productId=2
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
    // Можно добавить обработку других схем, если потребуется
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
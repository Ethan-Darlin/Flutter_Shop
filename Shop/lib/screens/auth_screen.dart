import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,  // Отключение баннера DEBUG
      home: AuthScreen(),
      routes: {
        '/products': (context) => ProductListScreen(), // Зарегистрируйте маршрут
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool rememberMe = false; // Флаг для кнопки "Запомнить меня"
  final FirebaseService firebaseService = FirebaseService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  // Focus nodes
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode usernameFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    usernameFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }
  void _navigateToProducts() {
    Navigator.pushReplacementNamed(context, '/products'); // Убедитесь, что маршрут настроен
  }
  // Загрузка сохраненного пользователя
  void _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      emailController.text = savedEmail;
      setState(() {
        rememberMe = true; // Если email сохранен, значит, выбрана опция "Запомнить меня"
      });
    }
  }

  void _saveUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      prefs.setString('email', emailController.text);  // Сохраняем email только если "Запомнить меня" выбрано
    } else {
      prefs.remove('email');  // Удаляем email если "Запомнить меня" не выбрано
    }
  }

  @override
  Widget build(BuildContext context) {
    final onAuth = isLogin
        ? () async {
      await firebaseService.onLogin(email: emailController.text, password: passwordController.text);
      if (rememberMe) {
        _saveUserCredentials(); // Сохранение данных, если "Запомнить меня" выбрано
      }
    }
        : () {
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Passwords do not match!'),
        ));
      } else {
        firebaseService.onRegister(
          email: emailController.text,
          password: passwordController.text,
          username: usernameController.text,
        );
      }
    };

    final buttonText = isLogin ? 'Log in' : 'Sign up';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Color(0xFF18171c),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLogin ? 'Log in' : 'Sign up',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 30),
              // Username field (visible for registration)
              if (!isLogin)
                TextField(
                  controller: usernameController,
                  focusNode: usernameFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Color(0xFF1F1F1F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Color(0xFF7B4B7F)),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              SizedBox(height: 30),
              // Email field
              TextField(
                controller: emailController,
                focusNode: emailFocusNode,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Color(0xFF7B4B7F)),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 30),
              // Password field
              TextField(
                controller: passwordController,
                focusNode: passwordFocusNode,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Color(0xFF7B4B7F)),
                  ),
                ),
                style: TextStyle(color: Colors.white),
                obscureText: true,
              ),
              SizedBox(height: 30),
              // Confirm Password field (only for registration)
              if (!isLogin)
                TextField(
                  controller: confirmPasswordController,
                  focusNode: confirmPasswordFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Color(0xFF1F1F1F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Color(0xFF7B4B7F)),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  obscureText: true,
                ),
              SizedBox(height: 0),
              // "Remember Me" Checkbox
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (bool? value) {
                      setState(() {
                        rememberMe = value ?? false;
                      });
                    },
                  ),
                  Text(
                    'Remember me',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAuth,
                  child: Text(
                    buttonText,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEE3A57), // Цвет кнопки
                    foregroundColor: Colors.white, // Цвет текста
                    padding: EdgeInsets.symmetric(vertical: 10), // Вертикальные отступы
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Скругленные углы
                    elevation: 5, // Тень
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await firebaseService.signInWithGoogle(context); // Передача контекста
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Здесь добавляем изображение
                      SvgPicture.asset(
                        'assets/images/google.svg', // Путь к вашему SVG
                        height: 24, // Задайте высоту изображения
                        width: 24, // Задайте ширину изображения
                      ),
                      SizedBox(width: 8), // Отступ между изображением и текстом
                      Text(
                        'Sign in with Google',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: TextButton(
                  child: Text(
                    isLogin ? 'Don’t have an account? Sign up' : 'Already have an account? Log in',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

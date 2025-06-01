import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthScreen(),
      routes: {
        '/products': (context) => ProductListScreen(),
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
  bool rememberMe = false;
  final FirebaseService firebaseService = FirebaseService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode usernameFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();

  final _formKey = GlobalKey<FormState>();
  bool _showErrors = false;

  String? _emailErrorText; // для кастомной ошибки email
  String? _passwordErrorText; // для кастомной ошибки пароля

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
    Navigator.pushReplacementNamed(context, '/products');
  }

  void _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      emailController.text = savedEmail;
      setState(() {
        rememberMe = true;
      });
    }
  }

  void _saveUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      prefs.setString('email', emailController.text);
    } else {
      prefs.remove('email');
    }
  }

  void _showResetPasswordDialog() {
    final _emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF18171c),
          title: Text(
            'Сброс пароля',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Введите ваш email',
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Отмена',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                await firebaseService.resetPassword(_emailController.text);
                Navigator.of(context).pop();
              },
              child: Text(
                'Отправить',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите email';
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Некорректный email';
    if (_emailErrorText != null) return _emailErrorText;
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (value.length < 6) return 'Минимум 6 символов';
    if (_passwordErrorText != null) return _passwordErrorText;
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите имя';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Повторите пароль';
    if (value != passwordController.text) return 'Пароли не совпадают';
    return null;
  }

  Future<void> _onAuth() async {
    setState(() {
      _showErrors = true;
      _emailErrorText = null;
      _passwordErrorText = null;
    });

    if (!_formKey.currentState!.validate()) return;

    if (isLogin) {
      try {
        await firebaseService.onLogin(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        if (rememberMe) {
          _saveUserCredentials();
        }
        _navigateToProducts();
      } catch (e) {
        String err = e.toString();
        // Обработка ошибок авторизации
        if (err.contains('Пользователь с таким email не найден') || err.contains('user-not-found')) {
          setState(() {
            _emailErrorText = 'Пользователь с таким email не найден';
            _passwordErrorText = null;
          });
        } else if (err.contains('Неверный пароль') || err.contains('wrong-password')) {
          setState(() {
            _emailErrorText = null;
            _passwordErrorText = 'Неверный пароль';
          });
        } else if (err.contains('Некорректный email') || err.contains('invalid-email')) {
          setState(() {
            _emailErrorText = 'Некорректный email';
            _passwordErrorText = null;
          });
        } else if (err.contains('Пользователь отключён') || err.contains('user-disabled')) {
          setState(() {
            _emailErrorText = 'Пользователь отключен';
            _passwordErrorText = null;
          });
        } else {
          setState(() {
            _emailErrorText = 'Проверьте введённый email!';
            _passwordErrorText = null;
          });
        }
        // Триггерим повторную валидацию, чтобы ошибка появилась под полем
        _formKey.currentState!.validate();
      }
    } else {
      try {
        await firebaseService.onRegister(
          email: emailController.text.trim(),
          password: passwordController.text,
          username: usernameController.text.trim(),
        );
        _navigateToProducts();
      } catch (e) {
        String err = e.toString();
        if (err.contains('существует') || err.contains('email уже существует') || err.contains('already in use')) {
          setState(() {
            _emailErrorText = 'Данная почта уже занята';
          });
          _formKey.currentState!.validate();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = isLogin ? 'Авторизация' : 'Регистрация';

    final inputDecoration = InputDecoration(
      contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      filled: true,
      fillColor: Color(0xFF1F1F1F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Color(0xFF7B4B7F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Color(0xFF7B4B7F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Color(0xFFEE3A57)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      errorStyle: TextStyle(color: Colors.redAccent),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Color(0xFF18171c),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              autovalidateMode:
              _showErrors ? AutovalidateMode.always : AutovalidateMode.disabled,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? 'Авторизация' : 'Регистрация',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 32),
                  if (!isLogin) ...[
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        controller: usernameController,
                        focusNode: usernameFocusNode,
                        decoration: inputDecoration.copyWith(labelText: 'Имя'),
                        style: TextStyle(color: Colors.white),
                        validator: _validateUsername,
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: emailController,
                      focusNode: emailFocusNode,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Email',
                        errorText: _emailErrorText,
                      ),
                      style: TextStyle(color: Colors.white),
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (val) {
                        if (_emailErrorText != null) {
                          setState(() {
                            _emailErrorText = null;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: passwordController,
                      focusNode: passwordFocusNode,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Пароль',
                        errorText: _passwordErrorText,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                      obscureText: !_isPasswordVisible,
                      validator: _validatePassword,
                      onChanged: (val) {
                        if (_passwordErrorText != null) {
                          setState(() {
                            _passwordErrorText = null;
                          });
                        }
                      },
                    ),
                  ),
                  if (isLogin) ...[
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: rememberMe,
                          onChanged: (bool? value) {
                            setState(() {
                              rememberMe = value ?? false;
                            });
                          },
                          activeColor: Color(0xFFEE3A57),
                        ),
                        Text(
                          'Запомнить меня',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _showResetPasswordDialog,
                        child: Text(
                          'Забыли пароль?',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  if (!isLogin) ...[
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        controller: confirmPasswordController,
                        focusNode: confirmPasswordFocusNode,
                        decoration: inputDecoration.copyWith(
                          labelText: 'Подтвердите пароль',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        style: TextStyle(color: Colors.white),
                        obscureText: !_isConfirmPasswordVisible,
                        validator: _validateConfirmPassword,
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onAuth,
                      child: Text(
                        buttonText,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFEE3A57),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        await firebaseService.signInWithGoogle(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/google.svg',
                            height: 24,
                            width: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Войти с Google',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    child: Text(
                      isLogin
                          ? 'У вас нету аккаунта? Регистрация'
                          : 'У вас уже есть аккаунт? Войти',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                        _showErrors = false;
                        _emailErrorText = null;
                        _passwordErrorText = null;
                        _formKey.currentState?.reset();
                      });
                    },
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
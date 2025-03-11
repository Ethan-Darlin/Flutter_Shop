import 'package:flutter/material.dart';

class AuthForm extends StatelessWidget {
  const AuthForm({
    Key? key,
    required this.onAuth,
    required this.authButtonText,
    required this.emailController,
    required this.passwordController,
    this.usernameController, // Добавляем контроллер для имени пользователя
    this.isLogin = true, // Добавляем флаг, чтобы знать, в каком состоянии находимся
  }) : super(key: key);

  final VoidCallback onAuth;
  final String authButtonText;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController? usernameController; // Опциональный контроллер для имени пользователя
  final bool isLogin; // Флаг для проверки состояния входа

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isLogin) // Показываем поле имени пользователя только при регистрации
          TextFormField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
        TextFormField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextFormField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 16.0),
        ElevatedButton(
          child: Text(authButtonText),
          onPressed: onAuth,
        ),
        const SizedBox(height: 16.0),
        ElevatedButton.icon(
          icon: Image.network(
              'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-32.png'),
          label: const Text('Sign in with Google'),
          onPressed: null,
        ),
      ],
    );
  }
}
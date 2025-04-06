import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop/screens/addCategoryScreen.dart';
import 'package:shop/screens/addProductScreen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/auth_screen.dart';
import 'package:shop/screens/scan_page.dart';

import 'createAddressScreen.dart'; // Import the AuthScreen

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({
    Key? key,
    required this.userId,
    required this.emailVerified,
  }) : super(key: key);

  final String userId; // Храним userId
  final bool emailVerified; // Храним статус проверки email

  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    // Инициализируем Future для загрузки данных пользователя
    _userDataFuture = FirebaseService().firestore.collection('users').doc(widget.userId).get();
  }

  void _redirectToAuthScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()), // Navigate to AuthScreen
    );
  }

  void _refreshData() {
    setState(() {
      // Обновляем Future при нажатии на кнопку
      _userDataFuture = FirebaseService().firestore.collection('users').doc(widget.userId).get();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _userDataFuture,
          builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            } else if (!snapshot.hasData || !snapshot.data!.exists) {
              // Redirect to AuthScreen if user not found
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _redirectToAuthScreen();
              });
              return Center(child: Text('Пользователь не найден. Перенаправление на страницу авторизации...'));
            }

            // Получаем данные пользователя из Firestore
            final userData = snapshot.data!.data()!;
            final username = userData['username'] ?? 'Не указано';
            final email = userData['email'] ?? 'Не указано';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('User name: $username'),
                Text('User email: $email'),
                Text('Email verified: ${widget.emailVerified}'), // Отображаем статус проверки email
                if (!widget.emailVerified) // Если email не подтвержден, показываем кнопку
                  TextButton(
                    onPressed: () {
                      FirebaseService().onVerifyEmail(); // Метод для подтверждения email
                    },
                    child: Text('Подтвердить Email'),
                  ),
                ElevatedButton(
                  onPressed: _refreshData, // Метод для обновления данных
                  child: Text('Обновить данные'), // Кнопка для обновления
                ),
                TextButton(
                  onPressed: () {
                    FirebaseService().logOut();
                  },
                  child: Text('Выйти'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProductListScreen()),
                    );
                  },
                  child: Text('Показать продукты'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddProductScreen(creatorId: widget.userId)), // Передаем userId
                    );
                  },
                  child: Text('Добавить продукты'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddCategoryScreen()), // Переход к новому экрану
                    );
                  },
                  child: Text('Добавить категорию'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateAddressScreen()),
                    );
                  },
                  child: Text('Создать новый адрес'),
                ),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => QRScanPage()),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
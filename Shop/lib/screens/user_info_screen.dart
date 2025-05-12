import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop/screens/addCategoryScreen.dart';
import 'package:shop/screens/addProductScreen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/auth_screen.dart';
import 'package:shop/screens/scan_page.dart';
import 'package:shop/screens/supplierApplicationsScreen.dart';
import 'package:shop/screens/adminReviewsScreen.dart';
import 'package:shop/screens/adminProductModerationScreen.dart';
import 'package:shop/screens/myProductsScreen.dart';
import 'package:shop/screens/editProductScreen.dart';
import 'createAddressScreen.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({
    Key? key,
    required this.userId,
    required this.emailVerified,
  }) : super(key: key);

  final String userId;
  final bool emailVerified;

  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userDataFuture;

  @override
  void initState() {
    super.initState();

    _userDataFuture = FirebaseService().firestore.collection('users').doc(widget.userId).get();
  }

  void _redirectToAuthScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  void _refreshData() {
    setState(() {

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

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _redirectToAuthScreen();
              });
              return Center(child: Text('Пользователь не найден. Перенаправление на страницу авторизации...'));
            }

            final userData = snapshot.data!.data()!;
            final username = userData['username'] ?? 'Не указано';
            final email = userData['email'] ?? 'Не указано';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('User name: $username'),
                Text('User email: $email'),
                Text('Email verified: ${widget.emailVerified}'),
                if (!widget.emailVerified)
                  TextButton(
                    onPressed: () {
                      FirebaseService().onVerifyEmail();
                    },
                    child: Text('Подтвердить Email'),
                  ),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: Text('Обновить данные'),
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
                      MaterialPageRoute(builder: (context) => AddProductScreen(creatorId: widget.userId)),
                    );
                  },
                  child: Text('Добавить продукты'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddCategoryScreen()),
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
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SupplierApplicationsScreen()),
                    );
                  },
                  child: Text('Заявки поставщиков'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminReviewsScreen()),
                    );
                  },
                  child: Text('Модерирование комментариев'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminProductModerationScreen()),
                    );
                  },
                  child: Text('Админ товары'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyProductsScreen()),
                    );
                  },
                  child: Text('мои товары'),
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
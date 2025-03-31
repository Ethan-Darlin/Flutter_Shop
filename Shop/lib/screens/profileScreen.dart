import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shop/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/screens/cartScreen.dart';
import 'package:shop/screens/productDetailScreen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'dart:typed_data';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  Future<List<Map<String, dynamic>>>? ordersFuture;
  Future<List<Map<String, dynamic>>>? similarProductsFuture; // Future for similar products
  int _selectedIndex = 0; // Index of the selected navigation item

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchUserOrders();
    _fetchSimilarProducts(); // Fetch similar products on init
  }

  Future<void> _fetchUserData() async {
    userData = await FirebaseService().getUserData();
    setState(() {});
  }

  Future<void> _fetchUserOrders() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      ordersFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: userId)
          .get()
          .then((snapshot) {
        return snapshot.docs.map((doc) {
          return {
            'order_id': doc.id, // Save order ID
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();
      });
    }
  }

  Future<void> _fetchSimilarProducts() async {
    similarProductsFuture = FirebaseFirestore.instance
        .collection('products')
        .get()
        .then((snapshot) {
      // Получаем все товары
      final allProducts = snapshot.docs.map((doc) {
        return {
          'product_id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      // Перемешиваем товары
      allProducts.shuffle();

      // Возвращаем, например, первые 10 товаров
      return allProducts.take(10).toList();
    });

    setState(() {}); // Обновляем состояние
  }

  void _showQrDialog(String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('QR-код для заказа №$orderId'),
          content: SingleChildScrollView(
            child: QrImageView(
              data: orderId,
              version: QrVersions.auto,
              size: 200.0, // Size of QR code
              gapless: false,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final _currentPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Сменить пароль'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(labelText: 'Текущий пароль'),
                obscureText: true,
              ),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(labelText: 'Новый пароль'),
                obscureText: true,
              ),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: 'Подтвердите новый пароль'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                if (_newPasswordController.text == _confirmPasswordController.text) {
                  await FirebaseService().changePassword(
                    currentPassword: _currentPasswordController.text,
                    newPassword: _newPasswordController.text,
                  );
                  Navigator.of(context).pop();
                } else {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Пароли не совпадают')),
                  );
                }
              },
              child: Text('Сменить'),
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog() {
    final _emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Сброс пароля'),
          content: TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Введите ваш email'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseService().resetPassword(_emailController.text);
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Отправить'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToProductDetail(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product), // Navigate to product detail
      ),
    );
  }

  void onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProductListScreen(),
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(),
        ),
      );
    }
    // Update the selected index
    setState(() {
      _selectedIndex = index;
    });
  }

  String formatPrice(double price) {
    int rubles = price.toInt();
    int kopecks = ((price - rubles) * 100).round();
    return kopecks == 0 ? '$rubles р.' : '$rubles р. $kopecks к.';
  }

  Widget _buildSimilarProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Text(
            'Похожие товары',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: similarProductsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Ошибка загрузки похожих товаров', style: TextStyle(color: Colors.red)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Нет похожих товаров.', style: TextStyle(color: Colors.white)));
            }

            final similarProducts = snapshot.data!;

            return Container(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  final product = similarProducts[index];
                  final imageUrl = product['image_url'];
                  Uint8List? imageBytes;

                  if (imageUrl != null) {
                    try {
                      String cleanedImageUrl = imageUrl.trim();
                      imageBytes = base64Decode(cleanedImageUrl);
                    } catch (e) {
                      print('Ошибка декодирования изображения: $e');
                      imageBytes = null;
                    }
                  }

                  return Container(
                    width: 180,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Card(
                      elevation: 2,
                      color: Color(0xFF18171c),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(product: product),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              child: imageBytes != null
                                  ? Image.memory(
                                imageBytes,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                                  : Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: TextStyle(color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formatPrice(product['price']),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Личный кабинет')),
      body: SingleChildScrollView( // Wrap the entire body in SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userData != null)
                Text('Username: ${userData!['username']}', style: TextStyle(fontSize: 20)),
              SizedBox(height: 10),
              if (userData != null)
                Text('Email: ${userData!['email']}', style: TextStyle(fontSize: 20)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showChangePasswordDialog,
                child: Text('Сменить пароль'),
              ),
              ElevatedButton(
                onPressed: _showResetPasswordDialog,
                child: Text('Сбросить пароль'),
              ),
              SizedBox(height: 20),
              Text('Ваши заказы:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('У вас нет заказов.'));
                  }
                  final orders = snapshot.data!;

                  return ListView.builder(
                    shrinkWrap: true, // Allow ListView to take only necessary space
                    physics: NeverScrollableScrollPhysics(), // Disable scrolling for ListView
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return GestureDetector(
                        onTap: () => _navigateToProductDetail(order), // Navigate to product detail
                        child: Card(
                          child: ListTile(
                            title: Text('Заказ №${order['order_id']}'),
                            subtitle: Text('Сумма: ${order['total_price']}\nСтатус: ${order['status']}'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 20),
              _buildSimilarProductsSection(), // Add similar products section
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Корзина',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), // Icon for profile
            label: 'Профиль', // Text for profile
          ),
        ],
        currentIndex: _selectedIndex, // Set index to "Profile"
        onTap: (index) {
          onItemTapped(index);
        },
        backgroundColor: Color(0xFF18171c),
        unselectedItemColor: Colors.white, // Color for unselected items
        unselectedIconTheme: IconThemeData(color: Colors.white), // Color for unselected icons
      ),
    );
  }
}
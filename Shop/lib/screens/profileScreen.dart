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
  Future<List<Map<String, dynamic>>>? orderItemsFuture; // Declare orderItemsFuture
  Future<List<Map<String, dynamic>>>? similarProductsFuture; // Future for similar products
  int _selectedIndex = 0; // Index of the selected navigation item

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchUserOrderItems(); // Fetch user order items on init
    _fetchSimilarProducts(); // Fetch similar products on init
  }

  Future<void> _fetchUserData() async {
    userData = await FirebaseService().getUserData();
    setState(() {});
  }

  Future<void> _fetchUserOrderItems() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      try {
        // Получаем заказы пользователя
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('user_id', isEqualTo: userId)
            .get();

        if (ordersSnapshot.docs.isEmpty) {
          print('No orders found for user: $userId');
          setState(() {
            orderItemsFuture = Future.value([]); // Устанавливаем пустой результат
          });
          return;
        }

        // Собираем все order_id из заказов
        final orderIds = ordersSnapshot.docs.map((doc) => doc.id).toList();

        // Получаем связанные товары из коллекции order_items
        final orderItemsSnapshot = await FirebaseFirestore.instance
            .collection('order_items')
            .where('order_id', whereIn: orderIds)
            .get();

        if (orderItemsSnapshot.docs.isEmpty) {
          print('No order items found for user: $userId');
          setState(() {
            orderItemsFuture = Future.value([]); // Устанавливаем пустой результат
          });
          return;
        }

        // Группируем товары по order_id
        final groupedItems = <String, List<Map<String, dynamic>>>{};

        for (var doc in orderItemsSnapshot.docs) {
          final data = {
            'order_item_id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
          final orderId = data['order_id'] as String;

          if (!groupedItems.containsKey(orderId)) {
            groupedItems[orderId] = [];
          }
          groupedItems[orderId]!.add(data);
        }

        // Преобразуем в список Map для FutureBuilder
        final groupedItemList = groupedItems.entries
            .map((entry) => {'order_id': entry.key, 'items': entry.value})
            .toList();

        setState(() {
          orderItemsFuture = Future.value(groupedItemList);
        });
      } catch (e) {
        print('Error fetching order items: $e');
        setState(() {
          orderItemsFuture = Future.error(e);
        });
      }
    } else {
      print('User is not authenticated.');
      setState(() {
        orderItemsFuture = Future.value([]);
      });
    }
  }

  Future<void> _fetchSimilarProducts() async {
    similarProductsFuture = FirebaseFirestore.instance
        .collection('products')
        .get()
        .then((snapshot) {
      final allProducts = snapshot.docs.map((doc) {
        return {
          'product_id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      allProducts.shuffle(); // Shuffle products
      return allProducts.take(10).toList(); // Return first 10 products
    });

    setState(() {}); // Update state after fetching similar products
  }

  void _showQrDialog(String orderItemId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('QR-код для товара'),
          content: SingleChildScrollView(
            child: QrImageView(
              data: orderItemId,
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
    setState(() {
      _selectedIndex = index; // Update selected index
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
      body: SingleChildScrollView(
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
              Text('Ваши товары:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: orderItemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('У вас нет товаров.'));
                  }

                  final groupedOrders = snapshot.data!;

                  return Container(
                    height: 600, // Ограничиваем высоту блока
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[900], // Фон для всего блока
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Scrollbar( // Добавляем полоску прокрутки
                      thumbVisibility: true,
                      child: ListView.builder(
                        padding: EdgeInsets.all(8.0),
                        itemCount: groupedOrders.length,
                        itemBuilder: (context, index) {
                          final order = groupedOrders[index];
                          final orderId = order['order_id'];
                          final items = order['items'] as List<Map<String, dynamic>>;

                          return Card(
                            color: Colors.blueGrey[800], // Общий фон для одного заказа
                            margin: EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Заказ ID: $orderId',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(), // Отключаем прокрутку внутри заказа
                                    itemCount: items.length,
                                    itemBuilder: (context, itemIndex) {
                                      final item = items[itemIndex];
                                      return Container(
                                        margin: EdgeInsets.only(bottom: 8.0),
                                        child: ListTile(
                                          tileColor: Colors.blueGrey[700],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          title: Text(
                                            item['name'],
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Цена: ${item['price']}',
                                                style: TextStyle(color: Colors.white70),
                                              ),
                                              Text(
                                                'Количество: ${item['quantity']}',
                                                style: TextStyle(color: Colors.white70),
                                              ),
                                              Text(
                                                'Статус: ${item['item_status']}',
                                                style: TextStyle(color: Colors.white70),
                                              ),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(Icons.qr_code, color: Colors.white),
                                            onPressed: () => _showQrDialog(item['order_item_id']),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showChangePasswordDialog,
                child: Text('Сменить пароль'),
              ),
              ElevatedButton(
                onPressed: _showResetPasswordDialog,
                child: Text('Сбросить пароль'),
              ),
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
        unselectedItemColor: Colors.white,
      ),
    );
  }
}
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
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'likedProductsScreen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  Future<List<Map<String, dynamic>>>? orderItemsFuture;
  Future<List<Map<String, dynamic>>>? similarProductsFuture;
  int _selectedIndex = 2;
  bool _isPurchaseHistoryExpanded = false;

  static const Color _backgroundColor = Color(0xFF18171c);
  static const Color _surfaceColor = Color(0xFF1f1f24);
  static const Color _primaryColor = Color(0xFFEE3A57);
  static const Color _secondaryTextColor = Color(0xFFa0a0a0);
  static const Color _textFieldFillColor = Color(0xFF2a2a2e);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchUserOrderItems();
  }
  String getUserRoleLabel(String? role) {
    switch (role) {
      case 'user':
        return 'Покупатель';
      case 'admin':
        return 'Администратор';
      case 'supplier':
        return 'Поставщик';
      case 'seller':
        return 'Продавец';
      default:
        return 'Неизвестно';
    }
  }

  Future<void> _fetchUserData() async {
    try {
      userData = await FirebaseService().getUserData();
      if (mounted) setState(() {});
    } catch (e) {
      print("Error fetching user data: $e");

    }
  }
  Future<List<Map<String, dynamic>>> _fetchLikedProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {

      final likedSnapshot = await FirebaseFirestore.instance
          .collection('isLiked')
          .where('user_id', isEqualTo: user.uid)
          .get();

      final likedProductIds = likedSnapshot.docs.map((doc) {
        final productId = doc['product_id'];
        return productId is int ? productId.toString() : productId as String;
      }).toList();

      if (likedProductIds.isEmpty) return [];

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: likedProductIds)
          .get();

      return productsSnapshot.docs.map((doc) {
        return {
          'product_id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      print('Ошибка получения лайкнутых товаров: $e');
      return [];
    }
  }

  Future<void> _fetchUserOrderItems() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('User is not authenticated.');

      if (mounted) {
        setState(() {
          orderItemsFuture = Future.value([]);
        });
      }
      return;
    }

    try {

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            orderItemsFuture = Future.value([]);
          });
        }
        print('No orders found for user: $userId');
        return;
      }

      final orderIds = ordersSnapshot.docs.map((doc) => doc.id).toList();

      if (orderIds.isEmpty) {
        if (mounted) {
          setState(() {
            orderItemsFuture = Future.value([]);
          });
        }
        return;
      }

      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .where('order_id', whereIn: orderIds)
          .get();

      if (orderItemsSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            orderItemsFuture = Future.value([]);
          });
        }
        print('No order items found for user orders: $orderIds');
      }

      final groupedItems = <String, List<Map<String, dynamic>>>{};
      final orderDates = <String, Timestamp>{};

      for (var orderDoc in ordersSnapshot.docs) {
        if (orderDoc.data()['created_at'] != null) {
          orderDates[orderDoc.id] = orderDoc.data()['created_at'] as Timestamp;
        } else {
          print('created_at is null for order ID: ${orderDoc.id}');
        }

        groupedItems[orderDoc.id] = [];
      }

      for (var doc in orderItemsSnapshot.docs) {
        final data = {
          'order_item_id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
        final orderId = data['order_id'] as String;

        if (groupedItems.containsKey(orderId)) {
          groupedItems[orderId]!.add(data);
        }
      }

      final filteredOrders = groupedItems.entries
          .where((entry) => entry.value.any((item) =>
      item['item_status'] == 'Доставлен' || item['item_status'] == 'В пути'))
          .map((entry) => {
        'order_id': entry.key,
        'items': entry.value,
        'order_date': orderDates[entry.key],
      })
          .toList();

      filteredOrders.sort((a, b) {
        final dateA = a['order_date'] as Timestamp?;
        final dateB = b['order_date'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        print("Successfully fetched and processed filtered order items.");
        setState(() {
          orderItemsFuture = Future.value(filteredOrders);
        });
      }
    } catch (e, stackTrace) {
      print('Error fetching order items: $e');
      print('Stack trace: $stackTrace');

      final errorFuture = Future<List<Map<String, dynamic>>>.error(
          'Ошибка загрузки заказов: $e', stackTrace);

      if (mounted) {
        setState(() {
          orderItemsFuture = errorFuture;
        });
      }
    }
  }
  Future<List<Map<String, dynamic>>> _fetchCompletedOrders() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      final orderIds = ordersSnapshot.docs.map((doc) => doc.id).toList();
      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .where('order_id', whereIn: orderIds)
          .get();

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

      return groupedItems.entries
          .where((entry) => entry.value.any((item) => item['item_status'] == 'completed'))
          .map((entry) => {
        'order_id': entry.key,
        'items': entry.value,
        'order_date': ordersSnapshot.docs.firstWhere((doc) => doc.id == entry.key)['created_at'],
      })
          .toList();
    } catch (e) {
      print('Error fetching completed orders: $e');
      return [];
    }
  }
  void _showPurchaseHistoryDialog() async {
    final completedOrders = await _fetchCompletedOrders();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("История покупок"),
          content: SizedBox(
            width: double.maxFinite,
            child: completedOrders.isEmpty
                ? Center(child: Text("Нет завершенных заказов"))
                : ListView.builder(
              itemCount: completedOrders.length,
              itemBuilder: (context, index) {
                final order = completedOrders[index];
                final orderId = order['order_id'];
                final orderDate = order['order_date'];
                final items = order['items'];

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Заказ #$orderId', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Дата: ${_formatDate(orderDate)}'),
                        ...items.map((item) => Text('${item['name']} - ${item['quantity']} шт.')).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Закрыть"),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentlyViewedProducts() async {
    return await FirebaseService().getRecentlyViewedOrRandomProducts();
  }

  String formatPrice(dynamic price) {
    double priceDouble;

    if (price is double) {
      priceDouble = price;
    } else if (price is int) {
      priceDouble = price.toDouble();
    } else if (price is String) {
      priceDouble = double.tryParse(price) ?? 0.0;
    } else {
      priceDouble = 0.0;
    }

    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();

    if (kopecks == 0) {
      return '$rubles BYN';
    } else {
      String kopecksStr = kopecks.toString().padLeft(2, '0');
      return '$rubles.$kopecksStr BYN';
    }
  }
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Дата неизвестна';
    final date = timestamp.toDate();

    return '${date.day.toString().padLeft(2,'0')} ${['янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'][date.month-1]} ${date.year}, ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
  }

  void _showQrDialog(String orderItemId, String productName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'QR-код для товара',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                productName,
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondaryTextColor, fontSize: 14),
              ),
              SizedBox(height: 15),
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.white, // Фон для QR-кода
                child: QrImageView(
                  data: orderItemId,
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Закрыть', style: TextStyle(color: _primaryColor)),
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
    final _formKey = GlobalKey<FormState>(); // Ключ для валидации формы

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Сменить пароль', style: TextStyle(color: Colors.white)),
          content: Form( // Используем Form для валидации
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPasswordField(_currentPasswordController, 'Текущий пароль'),
                SizedBox(height: 10),
                _buildPasswordField(_newPasswordController, 'Новый пароль',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите новый пароль';
                      }
                      if (value.length < 6) { // Пример валидации
                        return 'Пароль должен быть не менее 6 символов';
                      }
                      return null;
                    }
                ),
                SizedBox(height: 10),
                _buildPasswordField(_confirmPasswordController, 'Подтвердите новый пароль',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Подтвердите пароль';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Пароли не совпадают';
                      }
                      return null;
                    }
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Отмена', style: TextStyle(color: _secondaryTextColor)),
            ),
            ElevatedButton( // Делаем кнопку смены пароля основной
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) { // Проверяем форму
                  try {

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Center(child: CircularProgressIndicator(color: _primaryColor));
                      },
                    );

                    await FirebaseService().changePassword(
                      currentPassword: _currentPasswordController.text,
                      newPassword: _newPasswordController.text,
                    );

                    Navigator.of(context).pop(); // Убрать индикатор
                    Navigator.of(context).pop(); // Закрыть диалог смены пароля

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Пароль успешно изменен.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    Navigator.of(context).pop(); // Убрать индикатор
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ошибка смены пароля: ${e.toString()}'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: Text('Сменить'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, {String? Function(String?)? validator}) {
    return TextFormField( // Используем TextFormField для валидации
      controller: controller,
      obscureText: true,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _secondaryTextColor),
        filled: true,
        fillColor: _textFieldFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none, // Убираем границу по умолчанию
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor, width: 1), // Граница при фокусе
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: validator, // Передаем валидатор
    );
  }


  void _showResetPasswordDialog() {
    final _emailController = TextEditingController(text: userData?['email'] ?? ''); // Предзаполняем email
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Сброс пароля', style: TextStyle(color: Colors.white)),
          content: Form(
            key: _formKey,
            child: TextFormField( // Используем TextFormField
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email для сброса',
                labelStyle: TextStyle(color: _secondaryTextColor),
                filled: true,
                fillColor: _textFieldFillColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor, width: 1),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.redAccent, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.redAccent, width: 1),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'Введите корректный email';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Отмена', style: TextStyle(color: _secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () async {
                if(_formKey.currentState!.validate()) {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Center(child: CircularProgressIndicator(color: _primaryColor));
                      },
                    );
                    await FirebaseService().resetPassword(_emailController.text);
                    Navigator.of(context).pop(); // Убрать индикатор
                    Navigator.of(context).pop(); // Закрыть диалог сброса
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Письмо для сброса пароля отправлено на ${_emailController.text}.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    Navigator.of(context).pop(); // Убрать индикатор
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ошибка отправки: ${e.toString()}'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: Text('Отправить'),
            ),
          ],
        );
      },
    );
  }

  void onItemTapped(int index) {

    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Главная
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProductListScreen(), settings: RouteSettings(name: '/productList')),
        );
        break;
      case 1: // Корзина
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CartScreen(), settings: RouteSettings(name: '/cart')),
        );
        break;
      case 2: // Профиль (уже здесь)

        break;
    }
  }

  Widget _buildUserInfoSection() {
    if (userData == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    // Функция для корректного парсинга баллов как double
    double parseLoyaltyPoints(dynamic rawPoints) {
      if (rawPoints is double) return rawPoints;
      if (rawPoints is int) return rawPoints.toDouble();
      if (rawPoints is String) return double.tryParse(rawPoints) ?? 0.0;
      return 0.0;
    }

    double loyaltyPoints = parseLoyaltyPoints(userData?['loyalty_points']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _primaryColor.withOpacity(0.8),
            child: Icon(Icons.person_outline, size: 30, color: Colors.white),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userData!['username'] ?? 'Пользователь',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        getUserRoleLabel(userData!['role']),
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  userData!['email'] ?? 'Email не указан',
                  style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.stars, color: Colors.amber, size: 20),
                    SizedBox(width: 5),
                    Text(
                      'Баллы: ${loyaltyPoints.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<List<Map<String, dynamic>>> _fetchPurchaseHistory() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      if (ordersSnapshot.docs.isEmpty) return [];

      final orderIds = ordersSnapshot.docs.map((doc) => doc.id).toList();

      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .where('order_id', whereIn: orderIds)
          .get();

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

      return groupedItems.entries
          .where((entry) => entry.value.every((item) =>
      item['item_status'] == 'Возврат' || item['item_status'] == 'Выдан'))
          .map((entry) => {
        'order_id': entry.key,
        'items': entry.value,
        'order_date': ordersSnapshot.docs
            .firstWhere((doc) => doc.id == entry.key)['created_at'],
      })
          .toList();
    } catch (e) {
      print('Error fetching purchase history: $e');
      return [];
    }
  }
  Widget _buildPurchaseHistorySection() {
    const double maxHeight = 130; // Максимальная фиксированная высота секции
    const double baseOrderHeight = 60; // Базовая высота заказа, если в нём один товар
    const double additionalItemHeight = 60; // Дополнительная высота за каждый товар в заказе

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isPurchaseHistoryExpanded = !_isPurchaseHistoryExpanded; // Переключаем состояние раскрытия
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'История покупок',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Icon(
                  _isPurchaseHistoryExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (_isPurchaseHistoryExpanded)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchPurchaseHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                );
              } else if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30),
                  child: Center(
                    child: Text(
                      'Ошибка загрузки истории покупок: ${snapshot.error}',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_outlined, size: 50, color: _secondaryTextColor),
                        SizedBox(height: 10),
                        Text(
                          'История покупок пуста',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _secondaryTextColor, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final historyOrders = snapshot.data!;

              double contentHeight = 0;
              for (final order in historyOrders) {
                final items = order['items'] as List<dynamic>? ?? [];

                contentHeight += baseOrderHeight + (items.length - 1) * additionalItemHeight;
              }

              final double containerHeight = contentHeight <= maxHeight ? contentHeight : maxHeight;

              return Container(
                height: containerHeight,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  physics: contentHeight > maxHeight
                      ? AlwaysScrollableScrollPhysics() // Прокрутка, если контент больше максимальной высоты
                      : NeverScrollableScrollPhysics(), // Без прокрутки, если контент меньше максимальной высоты
                  itemCount: historyOrders.length,
                  itemBuilder: (context, index) {
                    final order = historyOrders[index];
                    var orderId = order['order_id'] ?? 'N/A';
                    final items = order['items'] ?? [];
                    final orderDate = order['order_date'] as Timestamp?;

                    if (orderId.length > 10) {
                      orderId = '${orderId.substring(0, 10)}...';
                    }

                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: _surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Заказ #$orderId',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _formatDate(orderDate),
                                  style: TextStyle(
                                    color: _secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Divider(color: _secondaryTextColor.withOpacity(0.3), height: 20),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              itemBuilder: (context, itemIndex) {
                                final item = items[itemIndex];
                                final productName = item['name'] ?? 'Название товара';
                                final price = item['price'];
                                final quantity = item['quantity'] ?? 1;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    '$productName - ${formatPrice(price)} x $quantity',
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => SizedBox(height: 12),
                ),
              );
            },
          ),
      ],
    );
  }
  Widget _buildOrdersSection() {
    const double maxHeight = 210; // Максимальная высота секции
    const double baseOrderHeight = 150; // Базовая высота заказа, если в нём один товар
    const double additionalItemHeight = 60; // Дополнительная высота за каждый товар в заказе

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 12.0),
          child: Text(
            'Мои покупки',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: orderItemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _primaryColor));
            } else if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30),
                child: Center(
                  child: Text(
                    'Ошибка загрузки заказов: ${snapshot.error}',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 50, color: _secondaryTextColor),
                      SizedBox(height: 10),
                      Text(
                        'У вас еще нет покупок',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _secondaryTextColor, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }

            final groupedOrders = snapshot.data!;

            double contentHeight = 0;
            for (final order in groupedOrders) {
              final items = order['items'] as List<dynamic>? ?? [];

              contentHeight += baseOrderHeight + (items.length - 1) * additionalItemHeight;
            }

            final double containerHeight = contentHeight <= maxHeight ? contentHeight : maxHeight;

            return Container(
              height: containerHeight,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                physics: contentHeight > maxHeight
                    ? AlwaysScrollableScrollPhysics() // Прокрутка, если контент больше максимальной высоты
                    : NeverScrollableScrollPhysics(), // Без прокрутки, если контент меньше максимальной высоты
                itemCount: groupedOrders.length,
                itemBuilder: (context, index) {
                  final order = groupedOrders[index];
                  var orderId = order['order_id'] ?? 'N/A';
                  final items = order['items'] ?? [];
                  final orderDate = order['order_date'] as Timestamp?;

                  if (orderId.length > 10) {
                    orderId = '${orderId.substring(0, 10)}...';
                  }

                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: _surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Заказ #$orderId',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatDate(orderDate),
                                style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                              ),
                            ],
                          ),
                          Divider(color: _secondaryTextColor.withOpacity(0.3), height: 20),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemBuilder: (context, itemIndex) {
                              final item = items[itemIndex];
                              final productName = item['name'] ?? 'Название товара';
                              final price = item['price'];
                              final quantity = item['quantity'] ?? 1;
                              final orderItemId = item['order_item_id'] ?? '';
                              final itemStatus = item['item_status'] ?? '';

                              final bool showQrButton = [
                                'Возврат',
                                'Получен',
                                'Доставлен',
                                'В пути'
                              ].contains(itemStatus);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            productName,
                                            style: TextStyle(color: Colors.white, fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '${formatPrice(price)} x $quantity',
                                            style: TextStyle(color: _secondaryTextColor, fontSize: 13),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Статус: $itemStatus',
                                            style: TextStyle(
                                              color: _secondaryTextColor.withOpacity(0.8),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 10),

                                    if (showQrButton)
                                      IconButton(
                                        icon: Icon(
                                          Icons.qr_code_2_rounded,
                                          color: _primaryColor,
                                          size: 28,
                                        ),
                                        tooltip: 'Показать QR-код для товара',
                                        onPressed: () {
                                          _showQrDialog(orderItemId, productName);
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                      )
                                    else
                                      SizedBox(width: 48), // Отступ, если кнопки нет
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) => SizedBox(height: 12),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentlyViewedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 30.0, bottom: 12.0),
          child: Text(
            'Ранее просмотренные',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRecentlyViewedProducts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 280,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (context, index) => _buildProductCardSkeleton(),
                ),
              );
            } else if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30),
                child: Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: Colors.redAccent))),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
                child: Text(
                  'Вы ещё ничего не смотрели',
                  style: TextStyle(color: Color(0xFFa0a0a0), fontSize: 16),
                ),
              );
            }

            final products = snapshot.data!;

            return Container(
              height: 276,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: 16.0, right: 8.0),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final mainImageUrl = product['main_image_url'];
                  final productName = product['name'] ?? 'Название товара';
                  final firstWord = productName.split(' ').first;

                  return Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Card(
                      elevation: 0,
                      color: Color(0xFF1f1f24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 150,
                            width: double.infinity,
                            color: Color(0xFF2a2a2e),
                            child: mainImageUrl != null && mainImageUrl.isNotEmpty
                                ? Image.network(
                              mainImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.broken_image, color: Color(0xFFa0a0a0), size: 40),
                            )
                                : Center(
                              child: Icon(Icons.image_not_supported, color: Color(0xFFa0a0a0), size: 40),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  firstWord,
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formatPrice(product['price'] ?? 0),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                SizedBox(height: 5),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProductDetailScreen(
                                            productId: product['product_id'].toString(),
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFEE3A57),
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Подробнее',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
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

  Widget _buildProductCardSkeleton() {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 8.0),
      child: Card(
        elevation: 0,
        color: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              color: _textFieldFillColor, // Цвет заглушки
              margin: EdgeInsets.all(1), // Небольшой отступ, чтобы было видно карточку
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 100, color: _textFieldFillColor), // Заглушка для текста
                  SizedBox(height: 8),
                  Container(height: 16, width: 60, color: _textFieldFillColor), // Заглушка для цены
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showSupplierDialog() {
    final _phoneController = TextEditingController();
    final String? userEmail = userData?['email']; // или FirebaseAuth.instance.currentUser?.email
    final _formKey = GlobalKey<FormState>();
    final _fioController = TextEditingController();
    final _descriptionController = TextEditingController();
    XFile? _pickedImage;
    String? _imageUrl;
    bool _isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _pickImage() async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (picked != null) {
                setState(() {
                  _pickedImage = picked;
                });
              }
            }

            Future<String?> _uploadToImageKit(XFile file) async {
              final url = 'https://upload.imagekit.io/api/v1/files/upload';

              final String publicKey = 'public_0EblotM8xHzpWNJUXWiVtRnHbGA=';
              final String privateKey = 'private_ZKL7E/ailo8o7MHqrvHIpxQRIiE='; // ! Не используйте на проде
              final String fileName = file.name;

              final String basicAuth = 'Basic ' + base64Encode(utf8.encode('$privateKey:'));

              final request = http.MultipartRequest('POST', Uri.parse(url));
              request.headers['Authorization'] = basicAuth;
              request.fields['fileName'] = fileName;
              request.fields['publicKey'] = publicKey;


              request.files.add(await http.MultipartFile.fromPath('file', file.path));

              final response = await request.send();
              final respStr = await response.stream.bytesToString();
              if (response.statusCode == 200) {
                final data = jsonDecode(respStr);
                return data['url'];
              } else {
                print('Ошибка ImageKit: $respStr');
                return null;
              }
            }

            Future<void> _submit() async {
              if (!_formKey.currentState!.validate() || _pickedImage == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Заполните все поля и выберите фото документов!'), backgroundColor: Colors.red),
                );
                return;
              }
              setState(() => _isLoading = true);

              try {

                final imageUrl = await _uploadToImageKit(_pickedImage!);
                if (imageUrl == null) throw Exception('Ошибка загрузки фото');

                final anketaId = Uuid().v4();
                final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
                final email = userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';

                await FirebaseFirestore.instance.collection('supplier_applications').doc(anketaId).set({
                  'anketa_id': anketaId,
                  'user_id': userId,
                  'fio': _fioController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'email': email,
                  'document_photo': imageUrl,
                  'description': _descriptionController.text.trim(),
                  'created_at': FieldValue.serverTimestamp(),
                  'status': 'pending', // Для модерации
                });

                Navigator.of(context).pop(); // Закрываем диалог
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ваша анкета отправлена!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            }

            return AlertDialog(
              backgroundColor: _surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text('Анкета поставщика', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 350,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _fioController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'ФИО',
                            labelStyle: TextStyle(color: _secondaryTextColor),
                            filled: true,
                            fillColor: _textFieldFillColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Введите ваше ФИО' : null,
                        ),
                        SizedBox(height: 14),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Номер телефона',
                            labelStyle: TextStyle(color: _secondaryTextColor),
                            filled: true,
                            fillColor: _textFieldFillColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Введите номер телефона';
                            final phonePattern = RegExp(r'^\+?\d{7,15}$');
                            if (!phonePattern.hasMatch(v.trim())) return 'Введите корректный номер';
                            return null;
                          },
                        ),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: Icon(Icons.upload_file),
                              label: Text(_pickedImage == null ? 'Документы' : 'Фото выбрано'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                            ),
                            if (_pickedImage != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Icon(Icons.check_circle, color: Colors.green),
                              ),
                          ],
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Дополнительная информация',
                            labelStyle: TextStyle(color: _secondaryTextColor),
                            filled: true,
                            fillColor: _textFieldFillColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) => null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text('Отмена', style: TextStyle(color: _secondaryTextColor)),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Отправить заявку'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Растягиваем кнопки
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.business_center_outlined, size: 20),
            label: Text('Стать поставщиком'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _showSupplierDialog,
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.lock_reset_outlined, size: 20, color: _secondaryTextColor),
            label: Text('Сбросить пароль по Email', style: TextStyle(color: _secondaryTextColor)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _secondaryTextColor.withOpacity(0.5)),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _showResetPasswordDialog,
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.password_outlined, size: 20, color: _secondaryTextColor),
            label: Text('Сменить текущий пароль', style: TextStyle(color: _secondaryTextColor)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _secondaryTextColor.withOpacity(0.5)),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _showChangePasswordDialog,
          ),
          SizedBox(height: 12),

          ElevatedButton.icon(
            icon: Icon(Icons.logout, size: 20),
            label: Text('Выйти из аккаунта'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _surfaceColor, // Цвет фона как у карточек
              foregroundColor: _primaryColor, // Цвет текста и иконки - акцентный
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0, // Без тени
            ),
            onPressed: () async {

              bool confirmLogout = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: _surfaceColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text('Выход', style: TextStyle(color: Colors.white)),
                  content: Text('Вы уверены, что хотите выйти из аккаунта?', style: TextStyle(color: _secondaryTextColor)),
                  actions: [
                    TextButton(
                      child: Text('Отмена', style: TextStyle(color: _secondaryTextColor)),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: Text('Выйти', style: TextStyle(color: _primaryColor)),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ) ?? false;

              if (confirmLogout) {
                await FirebaseService().logOut();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Личный кабинет',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.favorite_border, color: Colors.white),
            tooltip: 'Избранное',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LikedProductsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator( // Добавляем возможность обновить данные свайпом вниз
        onRefresh: () async {

          await _fetchUserData();
          await _fetchUserOrderItems();
        },
        color: _primaryColor, // Цвет индикатора
        backgroundColor: _surfaceColor,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(), // Позволяет скроллить даже если контента мало для RefreshIndicator
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0), // Отступ снизу
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildUserInfoSection(), // Секция с информацией о пользователе
                ),
                _buildRolePanel(context),
                _buildOrdersSection(), // Секция с историей заказов
                _buildPurchaseHistorySection(),
                _buildRecentlyViewedSection(),
                _buildActionButtons(), // Секция с кнопками действий
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Корзина',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
        currentIndex: _selectedIndex, // Устанавливаем индекс для "Профиля"
        selectedItemColor: _primaryColor, // Цвет активного элемента
        unselectedItemColor: _secondaryTextColor, // Цвет неактивных элементов
        backgroundColor: _surfaceColor, // Фон панели
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: onItemTapped,
      ),
    );
  }
  Widget _buildRolePanel(BuildContext context) {
    final String? role = (userData?['role'] ?? userData?['status'])?.toString()?.toLowerCase();

    if (role == null) return SizedBox.shrink();

    switch (role) {
      case 'admin':
        return _buildAdminPanel(context);
      case 'supplier':
        return _buildSupplierPanel(context);
      case 'seller':
        return _buildSellerPanel(context);
      default:
        return SizedBox.shrink();
    }
  }
// Панель для администратора (admin)
  Widget _buildAdminPanel(BuildContext context) {
    return Card(
      color: _surfaceColor,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Панель администратора', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(Icons.verified_user, color: Colors.white),
              label: Text('Модерация товаров'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white, // <-- вот эта строка!
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/admin-moderation');
              },
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.comment, color: Colors.white),
              label: Text('Модерация комментариев'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white, // <-- вот эта строка!
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/admin-reviews');
              },
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.assignment_ind, color: Colors.white),
              label: Text('Заявки поставщиков'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white, // <-- вот эта строка!
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/admin-supplier-applications');
              },
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.layers, color: Colors.white),
              label: Text('Добавить категорию'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/admin-category');
              },
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.location_on, color: Colors.white),
              label: Text('Добавить адрес'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/admin-address');
              },
            ),
          ],
        ),
      ),
    );
  }

// Панель для поставщика (supplier)
  Widget _buildSupplierPanel(BuildContext context) {
    return Card(
      color: _surfaceColor,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Панель поставщика', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(Icons.add_business, color: Colors.white),
              label: Text('Добавить товар'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white, // <-- вот эта строка!
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/add-product');
              },
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.list_alt, color: Colors.white),
              label: Text('Мои товары'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white, // <-- вот эта строка!
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/my-products');
              },
            ),
          ],
        ),
      ),
    );
  }

// Панель для продавца (seller)
  Widget _buildSellerPanel(BuildContext context) {
    return Card(
      color: _surfaceColor,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Панель продавца', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(Icons.qr_code_scanner, color: Colors.white),
              label: Text('Сканировать QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white, // <-- вот эта строка!
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/qr-scan');
              },
            ),
          ],
        ),
      ),
    );
  }
}
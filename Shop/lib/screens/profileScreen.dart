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
  Future<List<Map<String, dynamic>>>? orderItemsFuture;
  Future<List<Map<String, dynamic>>>? similarProductsFuture;
  int _selectedIndex = 2; // Профиль - третий элемент (индекс 2)

  // --- Цвета темы ---
  static const Color _backgroundColor = Color(0xFF18171c);
  static const Color _surfaceColor = Color(0xFF1f1f24); // Цвет карточек, панелей
  static const Color _primaryColor = Color(0xFFEE3A57); // Акцентный цвет
  static const Color _secondaryTextColor = Color(0xFFa0a0a0); // Серый текст
  static const Color _textFieldFillColor = Color(0xFF2a2a2e);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchUserOrderItems();
    _fetchSimilarProducts();
  }

  // --- Методы загрузки данных (без изменений) ---
  Future<void> _fetchUserData() async {
    try {
      userData = await FirebaseService().getUserData();
      if (mounted) setState(() {});
    } catch (e) {
      print("Error fetching user data: $e");
      // Можно показать SnackBar или другое уведомление об ошибке
    }
  }

// --- Полный метод _fetchUserOrderItems с правильным catch ---
  Future<void> _fetchUserOrderItems() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('User is not authenticated.');
      // Устанавливаем пустой результат синхронно
      if (mounted) {
        setState(() {
          orderItemsFuture = Future.value([]);
        });
      }
      return;
    }

    // Используем try-catch для всего процесса загрузки
    try {
      // Получаем заказы пользователя
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true) // Используем 'created_at'
          .get();

      // Если заказов нет
      if (ordersSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            orderItemsFuture = Future.value([]); // Устанавливаем пустой результат
          });
        }
        print('No orders found for user: $userId');
        return;
      }

      final orderIds = ordersSnapshot.docs.map((doc) => doc.id).toList();

      // Дополнительная проверка, если вдруг orderIds пустой
      if (orderIds.isEmpty) {
        if (mounted) {
          setState(() {
            orderItemsFuture = Future.value([]);
          });
        }
        return;
      }

      // Получаем связанные товары
      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .where('order_id', whereIn: orderIds)
          .get();

      // Если товаров нет
      if (orderItemsSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            orderItemsFuture = Future.value([]); // Отображаем как пустой список заказов
          });
        }
        print('No order items found for user orders: $orderIds');
      }

      // Группируем товары по order_id и сохраняем даты
      final groupedItems = <String, List<Map<String, dynamic>>>{};
      final orderDates = <String, Timestamp>{};

      for (var orderDoc in ordersSnapshot.docs) {
        if (orderDoc.data()['created_at'] != null) {
          orderDates[orderDoc.id] = orderDoc.data()['created_at'] as Timestamp;
        } else {
          print('created_at is null for order ID: ${orderDoc.id}');
        }
        // Инициализируем пустой список для каждого заказа
        groupedItems[orderDoc.id] = [];
      }

      for (var doc in orderItemsSnapshot.docs) {
        final data = {
          'order_item_id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
        final orderId = data['order_id'] as String;
        // Добавляем товар в уже существующий список заказа
        if (groupedItems.containsKey(orderId)) {
          groupedItems[orderId]!.add(data);
        }
      }

      // Преобразуем в список Map для FutureBuilder, добавляя дату
      final groupedItemList = groupedItems.entries.map((entry) {
        return {
          'order_id': entry.key,
          'items': entry.value,
          'order_date': orderDates[entry.key] // Добавляем дату
        };
      }).toList();

      // Сортируем группы заказов по дате (новейшие сначала)
      groupedItemList.sort((a, b) {
        final dateA = a['order_date'] as Timestamp?;
        final dateB = a['order_date'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // descending
      });

      // === Успешное завершение: Обновляем состояние с результатом ===
      if (mounted) {
        print("Successfully fetched and processed order items."); // Лог успеха
        setState(() {
          orderItemsFuture = Future.value(groupedItemList);
        });
      }

    } catch (e, stackTrace) { // Ловим ошибку и стек вызовов
      print('Error fetching order items: $e');
      print('Stack trace: $stackTrace'); // Печатаем стек для детальной отладки

      // === ОБРАБОТКА ОШИБКИ: Правильный вызов setState ===
      final errorFuture = Future<List<Map<String, dynamic>>>.error('Ошибка загрузки заказов: $e', stackTrace); // Передаем и стек

      if (mounted) {
        setState(() {
          orderItemsFuture = errorFuture;
        });
      }
      // === КОНЕЦ ИСПРАВЛЕНИЯ ===
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

      // Filter for completed orders
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
    final completedOrders = await _fetchCompletedOrders(); // Fetch completed orders

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

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Existing buttons...

          ElevatedButton(
            child: Text("История покупок"),
            onPressed: _showPurchaseHistoryDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _fetchSimilarProducts() async {
    try {
      similarProductsFuture = FirebaseFirestore.instance
          .collection('products')
      // .orderBy(...) // Можно добавить логику выбора похожих товаров
          .limit(10) // Ограничиваем количество
          .get()
          .then((snapshot) {
        if (snapshot.docs.isEmpty) {
          return <Map<String, dynamic>>[]; // Возвращаем пустой список, если нет продуктов
        }
        final allProducts = snapshot.docs.map((doc) {
          return {
            'product_id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();
        allProducts.shuffle(); // Перемешиваем для разнообразия
        return allProducts;
      });
      if (mounted) setState(() {}); // Обновляем UI
    } catch (e) {
      print('Error fetching similar products: $e');
      if (mounted) {
        setState(() {
          // Устанавливаем Future с ошибкой, чтобы FutureBuilder ее отобразил
          similarProductsFuture = Future.error('Ошибка загрузки похожих товаров: $e');
        });
      }
    }
  }

  // --- Вспомогательные функции (форматирование цены) ---
  String formatPrice(dynamic price) {
    // Скопировано из CartScreen - лучше вынести в утилиты
    double priceDouble;
    if (price is int) {
      priceDouble = price.toDouble();
    } else if (price is String) {
      priceDouble = double.tryParse(price) ?? 0.0;
    } else if (price is double) {
      priceDouble = price;
    } else {
      priceDouble = 0.0;
    }
    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();
    // Используем ₽ вместо р.
    return kopecks == 0 ? '$rubles ₽' : '$rubles ₽ ${kopecks.toString().padLeft(2, '0')} коп.';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Дата неизвестна';
    final date = timestamp.toDate();
    // Форматируем дату (Пример: 06 апр 2025, 16:20)
    return '${date.day.toString().padLeft(2,'0')} ${['янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'][date.month-1]} ${date.year}, ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
  }

  // --- Диалоговые окна (стилизованные) ---
  void _showQrDialog(String orderItemId, String productName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surfaceColor, // Темный фон
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'QR-код для товара',
            style: TextStyle(color: Colors.white),
          ),
          content: Column( // Используем Column для QR и названия
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                productName, // Отображаем название товара
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondaryTextColor, fontSize: 14),
              ),
              SizedBox(height: 15),
              Container(
                padding: EdgeInsets.all(8), // Белая рамка вокруг QR
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
                    // Показываем индикатор загрузки
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

  // Вспомогательный метод для создания полей пароля в диалоге
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

  // --- Навигация (обновлен индекс профиля) ---
  void onItemTapped(int index) {
    // Предотвращаем ненужную навигацию на текущий экран
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
      // Ничего не делаем
        break;
    }
  }

  // --- Секции UI ---
  Widget _buildUserInfoSection() {
    if (userData == null) {
      // Можно показать скелетон загрузки или компактный индикатор
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar( // Аватарка (заглушка)
            radius: 30,
            backgroundColor: _primaryColor.withOpacity(0.8),
            child: Icon(Icons.person_outline, size: 30, color: Colors.white),
            // TODO: Загружать фото пользователя, если оно есть
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userData!['username'] ?? 'Пользователь',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 4),
              Text(
                userData!['email'] ?? 'Email не указан',
                style: TextStyle(fontSize: 14, color: _secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersSection() {
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
          future: orderItemsFuture, // Убедись, что эта переменная инициализируется
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _primaryColor));
            } else if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30),
                child: Center(child: Text('Ошибка загрузки заказов: ${snapshot.error}', style: TextStyle(color: Colors.redAccent))),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                  decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 50, color: _secondaryTextColor),
                          SizedBox(height: 10),
                          Text(
                              'У вас еще нет покупок',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _secondaryTextColor, fontSize: 16)
                          ),
                        ],
                      )
                  )
              );
            }

            final groupedOrders = snapshot.data!;

            return ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: groupedOrders.length,
              itemBuilder: (context, index) {
                final order = groupedOrders[index];
                final orderId = order['order_id'] ?? 'N/A'; // Безопасное получение ID заказа
                final items = (order['items'] as List<dynamic>?) // Безопасное приведение типа
                    ?.whereType<Map<String, dynamic>>() // Отфильтровываем не-Map элементы
                    .toList() ?? // Преобразуем в List
                    <Map<String, dynamic>>[]; // Или пустой список, если items null или не List
                final orderDate = order['order_date'] as Timestamp?;

                // Проверка, если список товаров пуст после фильтрации
                if (items.isEmpty && orderId != 'N/A') {
                  print("Предупреждение: Заказ $orderId не содержит корректных товаров.");
                  // Можно вернуть пустой контейнер или сообщение об ошибке для этого заказа
                  // return SizedBox.shrink();
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
                              // Безопасно обрезаем ID
                              'Заказ #${orderId.length > 6 ? orderId.substring(0, 6) + '...' : orderId}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatDate(orderDate), // Используем функцию форматирования
                              style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                        Divider(color: _secondaryTextColor.withOpacity(0.3), height: 20),
                        // Список товаров в заказе
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, itemIndex) {
                            final item = items[itemIndex];
                            // Безопасно получаем данные товара
                            final String orderItemId = item['order_item_id']?.toString() ?? ''; // Преобразуем в String, если не null, иначе пустая строка
                            final String productName = item['name'] ?? 'Название товара';
                            final String itemStatus = item['item_status'] ?? 'Обрабатывается';
                            final dynamic itemPrice = item['price']; // Оставляем dynamic для formatPrice
                            final int itemQuantity = (item['quantity'] is int) ? item['quantity'] : ( (item['quantity'] is String) ? int.tryParse(item['quantity']) ?? 1 : 1 ) ; // Безопасное получение количества

                            // Условие для показа QR-кода (настрой под свои статусы)
                            final bool showQrButton = ['ready_for_pickup', 'delivered', 'completed', 'pending'].contains(itemStatus.toLowerCase()); // Пример статусов

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  // Место для изображения товара (если есть)
                                  // ClipRRect( borderRadius: BorderRadius.circular(8), child: Image.network(..., width: 50, height: 50, fit: BoxFit.cover))

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productName, // Используем безопасную переменную
                                          style: TextStyle(color: Colors.white, fontSize: 15),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          // Используем безопасные переменные
                                          '${formatPrice(itemPrice)} x $itemQuantity',
                                          style: TextStyle(color: _secondaryTextColor, fontSize: 13),
                                        ),
                                        SizedBox(height: 4),
                                        Text( // Статус товара
                                          'Статус: $itemStatus', // Используем безопасную переменную
                                          style: TextStyle(color: _secondaryTextColor.withOpacity(0.8), fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 10),

                                  // --- START: Кнопка QR-кода ---
                                  if (showQrButton) // Показываем кнопку только если условие true
                                    IconButton(
                                      icon: Icon(Icons.qr_code_2_rounded, color: _primaryColor, size: 28,),
                                      tooltip: 'Показать QR-код для товара',
                                      onPressed: () {
                                        // Передаем ID ЭЛЕМЕНТА ЗАКАЗА (order_item_id), а не ID продукта
                                        // и название товара в диалог
                                        _showQrDialog(orderItemId, productName);
                                      },
                                      padding: EdgeInsets.zero, // Уменьшает отступы вокруг иконки
                                      constraints: BoxConstraints(), // Уменьшает минимальный размер кнопки
                                    )
                                  else
                                  // Чтобы сохранить выравнивание, если кнопки нет, можно добавить SizedBox
                                    SizedBox(width: 48), // Ширина IconButton примерно 48

                                  // --- END: Кнопка QR-кода ---
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
            );
          },
        ),
      ],
    );
  }

  Widget _buildSimilarProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 30.0, bottom: 12.0),
          child: Text(
            'Возможно, вам понравится',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: similarProductsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Показываем горизонтальные скелетоны
              return Container(
                height: 280, // Примерная высота карточки
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3, // Количество скелетонов
                  itemBuilder: (context, index) => _buildProductCardSkeleton(),
                ),
              );
            } else if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30),
                child: Center(child: Text('${snapshot.error}', style: TextStyle(color: Colors.redAccent))),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Не показываем ничего, если нет похожих товаров (или можно показать сообщение)
              return SizedBox.shrink();
              // return Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30),
              //   child: Center(child: Text('Нет рекомендованных товаров.', style: TextStyle(color: _secondaryTextColor))),
              // );
            }

            final similarProducts = snapshot.data!;

            return Container(
              height: 280, // Высота контейнера для горизонтального списка
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: 16.0, right: 8), // Отступы для списка
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  final product = similarProducts[index];
                  final imageUrl = product['image_url']; // Предполагаем, что это Base64 строка
                  Uint8List? imageBytes;

                  if (imageUrl is String && imageUrl.isNotEmpty) {
                    try {
                      // Убираем возможные префиксы data:image/...;base64,
                      final base64String = imageUrl.split(',').last;
                      imageBytes = base64Decode(base64String);
                    } catch (e) {
                      print('Ошибка декодирования изображения для ${product['name']}: $e');
                      imageBytes = null; // Оставляем null в случае ошибки
                    }
                  }

                  return Container(
                    width: 160, // Ширина карточки товара
                    margin: EdgeInsets.only(right: 8.0),
                    child: Card(
                      elevation: 0,
                      color: _surfaceColor, // Цвет фона карточки
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias, // Обрезка содержимого по границам
                      child: InkWell( // Делаем карточку кликабельной
                        onTap: () {
                          // Используем push, а не pushReplacement, чтобы можно было вернуться
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              // Передаем product_id вместо всего объекта,
                              // ProductDetailScreen сам загрузит данные по ID
                              // builder: (context) => ProductDetailScreen(productId: product['product_id']),
                              // ИЛИ если ProductDetailScreen принимает Map:
                              builder: (context) => ProductDetailScreen(product: product),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Изображение товара
                            Container(
                              height: 150, // Фиксированная высота изображения
                              width: double.infinity,
                              color: _textFieldFillColor, // Фон-заглушка
                              child: imageBytes != null
                                  ? Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: _secondaryTextColor, size: 40),
                              )
                                  : Center(child: Icon(Icons.image_not_supported, color: _secondaryTextColor, size: 40)), // Заглушка
                            ),

                            // Информация о товаре
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? 'Название товара',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                    maxLines: 2, // Максимум 2 строки
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    formatPrice(product['price'] ?? 0),
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  // Виджет скелетона для карточки товара
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


  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Растягиваем кнопки
        children: [
          OutlinedButton.icon( // Используем OutlinedButton для менее важного действия
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
          // Кнопка выхода
          ElevatedButton.icon(
            icon: Icon(Icons.logout, size: 20),
            label: Text('Выйти из аккаунта'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _surfaceColor, // Цвет фона как у карточек
              foregroundColor: _primaryColor, // Цвет текста и иконки - акцентный
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0, // Без тени
              // side: BorderSide(color: _primaryColor.withOpacity(0.5)) // Можно добавить рамку
            ),
            onPressed: () async {
              // Показываем диалог подтверждения выхода
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
                      onPressed: () => Navigator.of(context).pop(false), // Возвращаем false
                    ),
                    TextButton(
                      child: Text('Выйти', style: TextStyle(color: _primaryColor)),
                      onPressed: () => Navigator.of(context).pop(true), // Возвращаем true
                    ),
                  ],
                ),
              ) ?? false; // Если диалог закрыли иначе, считаем что отмена (false)

              if (confirmLogout) {
                await FirebaseService().logOut();
                // Перенаправляем на экран входа или главный экран (в зависимости от логики приложения)
                // Убедитесь, что после выхода пользователь не может вернуться назад в профиль
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false); // Пример перехода на /login
                // или
                // Navigator.of(context).pushNamedAndRemoveUntil('/productList', (Route<dynamic> route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Основной Build метод ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Личный кабинет', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _backgroundColor, // Фон AppBar в цвет фона Scaffold
        elevation: 0, // Убираем тень
        automaticallyImplyLeading: false, // Убираем кнопку назад по умолчанию
      ),
      body: RefreshIndicator( // Добавляем возможность обновить данные свайпом вниз
        onRefresh: () async {
          // Перезагружаем все данные
          await _fetchUserData();
          await _fetchUserOrderItems();
          await _fetchSimilarProducts();
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
                _buildOrdersSection(), // Секция с историей заказов
                _buildSimilarProductsSection(), // Секция с похожими товарами
                _buildActionButtons(), // Секция с кнопками действий
              ],
            ),
          ),
        ),
      ),
      // --- Нижняя навигационная панель (как в CartScreen) ---
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
}
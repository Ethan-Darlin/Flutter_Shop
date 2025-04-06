import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
// import 'package:shop/screens/productDetailScreen.dart'; // Не используется напрямую здесь, но может понадобиться для изображений
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/profileScreen.dart';
import 'dart:convert'; // Понадобится, если будем добавлять изображения Base64
import 'dart:typed_data'; // Понадобится, если будем добавлять изображения Base64

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _cartItemsFuture;
  late Future<List<Map<String, dynamic>>> _deliveryAddressesFuture;
  String? _selectedDeliveryId;
  int _selectedIndex = 1; // Корзина - второй элемент
  double _totalPrice = 0.0; // Храним общую стоимость в состоянии

  @override
  void initState() {
    super.initState();
    _loadCartData(); // Загружаем данные при инициализации
    _deliveryAddressesFuture = FirebaseService().getAllDeliveryAddresses();
    print('CartScreen initialized.');
  }

  // Загрузка данных корзины и расчет суммы
  void _loadCartData() {
    _cartItemsFuture = FirebaseService().getCartItems();
    _cartItemsFuture.then((items) {
      _calculateTotalPrice(items);
      if (mounted) {
        setState(() {}); // Обновляем UI после расчета суммы
      }
    }).catchError((error) {
      print("Error loading cart items: $error");
      if (mounted) {
        setState(() {}); // Обновляем UI в случае ошибки
      }
    });
  }

  // Расчет общей суммы
  void _calculateTotalPrice(List<Map<String, dynamic>> items) {
    double total = items.fold(0.0, (sum, item) {
      var price = item['price'];
      // Приведение цены к double, если она int
      if (price is int) {
        price = price.toDouble();
      } else if (price is String) {
        price = double.tryParse(price) ?? 0.0;
      } else if (price is! double) {
        price = 0.0; // Если тип не поддерживается, считаем цену 0
      }

      var quantity = item['quantity'];
      // Приведение количества к int, если оно другого типа
      if (quantity is! int) {
        quantity = 1; // Значение по умолчанию
      }

      return sum + (price as double) * quantity;
    });
    if (mounted) {
      setState(() {
        _totalPrice = total;
      });
    }
  }


  // Форматирование цены (скопировано из ProductDetailScreen)
  String formatPrice(dynamic price) {
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
    return kopecks == 0 ? '$rubles ₽' : '$rubles ₽ $kopecks коп.';
  }

  Future<void> _removeFromCart(String docId, Map<String, dynamic> itemToRemove) async {
    print('Trying to remove item with docId: $docId');
    try {
      // Удаляем товар из корзины
      await FirebaseService().removeFromCart(docId);
      print('Item removed from cart.');

      // Возвращаем количество товара обратно в size_stock (если логика нужна)
      // Раскомментируйте, если используете эту логику
      /*
      await FirebaseService().updateProductStock(
        itemToRemove['product_id'], // ID товара
        itemToRemove['selected_size'], // Выбранный размер
        itemToRemove['quantity'], // Количество, которое нужно вернуть
      );
      print('Product stock updated after removing item.');
      */

      // Обновляем состояние корзины и пересчитываем сумму
      _loadCartData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${itemToRemove['name']} удален из корзины'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.redAccent,
        ));
      }

    } catch (e) {
      print('Error removing item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка при удалении товара.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _placeOrder(String deliveryId) async {
    print('Attempting to place order...');
    final cartItems = await _cartItemsFuture; // Получаем текущие элементы корзины

    if (cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Корзина пуста. Нечего заказывать.'),
        ));
      }
      return;
    }

    // Используем уже рассчитанную _totalPrice
    print('Total price for order: $_totalPrice');

    try {
      // Оформляем заказ
      await FirebaseService().placeOrder(cartItems, _totalPrice, deliveryId);
      print('Order placed successfully.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Заказ успешно оформлен!'),
          backgroundColor: Colors.green,
        ));

        // Обновляем состояние корзины (она должна стать пустой)
        _loadCartData();
        // Можно также перейти на экран заказов или профиля
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OrdersScreen())); // Пример
        // Сбрасываем выбранный адрес
        setState(() {
          _selectedDeliveryId = null;
        });
      }

    } catch (e) {
      print('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка при оформлении заказа: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // Навигация (оставляем вашу логику)
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
          MaterialPageRoute(
              builder: (context) => ProductListScreen(),
              settings: RouteSettings(name: '/productList')),
        );
        break;
      case 1: // Корзина (уже здесь)
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CartScreen(), settings: RouteSettings(name: '/cart')));
        break;
      case 2: // Профиль
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => ProfileScreen(),
              settings: RouteSettings(name: '/profile')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18171c), // Темный фон
      appBar: AppBar(
        title: Text('Корзина', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF18171c), // Фон AppBar в цвет фона Scaffold
        elevation: 0, // Убираем тень
        automaticallyImplyLeading: false, // Убираем кнопку назад по умолчанию
        // Можно добавить кастомную кнопку назад, если нужно:
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back_ios, color: Colors.white),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cartItemsFuture,
        builder: (context, snapshot) {
          // --- Состояния загрузки, ошибки, пустой корзины ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.white));
          } else if (snapshot.hasError) {
            print("Error in FutureBuilder: ${snapshot.error}"); // Логируем ошибку
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Произошла ошибка загрузки корзины.\nПопробуйте позже.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column( // Используем Column для иконки и текста
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[600]),
                  SizedBox(height: 16),
                  Text('Ваша корзина пуста', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Добавьте товары, чтобы сделать заказ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => onItemTapped(0), // Переход на главную
                    child: Text('К товарам'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEE3A57),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                  )
                ],
              ),
            );
          }

          // --- Отображение корзины ---
          final cartItems = snapshot.data!;

          return Column( // Основной столбец для адреса и списка
            children: [
              // --- Выбор Адреса Доставки ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _deliveryAddressesFuture,
                  builder: (context, deliverySnapshot) {
                    if (deliverySnapshot.connectionState == ConnectionState.waiting) {
                      // Можно показать компактный индикатор загрузки
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        child: Row(children: [
                          SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 10),
                          Text("Загрузка адресов...", style: TextStyle(color: Colors.grey))
                        ]),
                      );
                    } else if (deliverySnapshot.hasError) {
                      return Text('Ошибка загрузки адресов', style: TextStyle(color: Colors.redAccent));
                    } else if (!deliverySnapshot.hasData || deliverySnapshot.data!.isEmpty) {
                      // TODO: Предложить добавить адрес
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        alignment: Alignment.centerLeft,
                        child: Text('Нет сохраненных адресов доставки', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    final addresses = deliverySnapshot.data!;
                    // Стилизация DropdownButton
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: Color(0xFF2a2a2e), // Фон как у полей ввода
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DropdownButtonHideUnderline( // Убираем стандартное подчеркивание
                        child: DropdownButton<String>(
                          isExpanded: true, // Растягиваем на всю ширину контейнера
                          hint: Text('Выберите адрес доставки', style: TextStyle(color: Colors.grey[400])),
                          value: _selectedDeliveryId,
                          dropdownColor: Color(0xFF2a2a2e), // Цвет фона выпадающего списка
                          style: TextStyle(color: Colors.white, fontSize: 16), // Стиль текста элементов
                          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]), // Цвет иконки
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDeliveryId = newValue;
                            });
                          },
                          items: addresses.map<DropdownMenuItem<String>>((address) {
                            return DropdownMenuItem<String>(
                              value: address['doc_id'], // Используем doc_id
                              child: Text(
                                address['delivery_address'] ?? 'Адрес не указан', // Защита от null
                                overflow: TextOverflow.ellipsis, // Обрезка длинного текста
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- Список Товаров ---
              Expanded( // Занимает оставшееся место перед bottomSheet
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 80), // Отступ снизу для bottomSheet
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final docId = item['docId']; // ID документа в корзине для удаления

                    // TODO: Если есть URL изображения (base64), декодировать его здесь
                    // Uint8List? imageBytes;
                    // final imageUrl = item['image_url'];
                    // if (imageUrl is String && imageUrl.isNotEmpty) { ... }

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      color: Color(0xFF1f1f24), // Цвет фона карточки
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      elevation: 0, // Без тени
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Место для изображения (если будет)
                            // if (imageBytes != null) ClipRRect(...) else Container(...)
                            // SizedBox(width: 12),

                            // Информация о товаре
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? 'Название товара', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 6),
                                  Text('Размер: ${item['selected_size'] ?? '-'}', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text('Количество: ${item['quantity'] ?? 1}', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                                  SizedBox(height: 8),
                                  Text(formatPrice(item['price'] ?? 0), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            SizedBox(width: 10),
                            // Кнопка удаления
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]),
                              padding: EdgeInsets.zero, // Убираем лишние отступы у иконки
                              constraints: BoxConstraints(), // Убираем лишние ограничения размера
                              onPressed: () {
                                if (docId != null) {
                                  // Показываем диалог подтверждения
                                  showDialog(
                                      context: context,
                                      builder: (BuildContext ctx) {
                                        return AlertDialog(
                                          backgroundColor: Color(0xFF1f1f24),
                                          title: Text('Удалить товар?', style: TextStyle(color: Colors.white)),
                                          content: Text('Вы уверены, что хотите удалить "${item['name']}" из корзины?', style: TextStyle(color: Colors.grey[300])),
                                          actions: <Widget>[
                                            TextButton(
                                              child: Text('Отмена', style: TextStyle(color: Colors.grey)),
                                              onPressed: () => Navigator.of(ctx).pop(),
                                            ),
                                            TextButton(
                                              child: Text('Удалить', style: TextStyle(color: Colors.redAccent)),
                                              onPressed: () {
                                                Navigator.of(ctx).pop(); // Закрыть диалог
                                                _removeFromCart(docId, item); // Удалить товар
                                              },
                                            ),
                                          ],
                                        );
                                      }
                                  );
                                } else {
                                  print("Error: docId is null for item ${item['name']}");
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось удалить товар: отсутствует ID.'), backgroundColor: Colors.red));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // --- Нижняя панель с Итого и Кнопкой Заказа ---
      bottomSheet: FutureBuilder<List<Map<String, dynamic>>>( // Показываем только если корзина не пуста
          future: _cartItemsFuture,
          builder: (context, snapshot) {
            // Не показываем bottomSheet, если корзина пуста, идет загрузка или ошибка
            if (!snapshot.hasData || snapshot.data!.isEmpty || snapshot.connectionState != ConnectionState.done) {
              return SizedBox.shrink(); // Возвращаем пустой виджет
            }
            // Показываем панель, если есть товары
            return Container(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 12.0,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom // Учет SafeArea
                    : 12.0,
              ),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFF18171c), // Фон панели
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Итого:',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        formatPrice(_totalPrice), // Используем _totalPrice из состояния
                        style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      // Кнопка активна только если выбран адрес доставки
                      onPressed: _selectedDeliveryId != null ? () {
                        _placeOrder(_selectedDeliveryId!);
                      } : null, // Делаем неактивной, если адрес не выбран
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFEE3A57),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        // Стиль для неактивного состояния
                        disabledBackgroundColor: Colors.grey[700],
                        disabledForegroundColor: Colors.grey[400],
                      ),
                      child: Text(
                          _selectedDeliveryId != null ? 'Оформить заказ' : 'Выберите адрес', // Меняем текст кнопки
                          style: TextStyle(fontSize: 16)
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
      ),
      // --- Нижняя навигационная панель ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), // Иконки в стиле outline
            activeIcon: Icon(Icons.home), // Активная иконка
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
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFFEE3A57), // Цвет активного элемента
        unselectedItemColor: Colors.grey[400], // Цвет неактивных элементов
        backgroundColor: Color(0xFF1f1f24), // Фон панели (чуть светлее основного)
        type: BottomNavigationBarType.fixed, // Чтобы все элементы отображались
        selectedFontSize: 12, // Размер шрифта активного
        unselectedFontSize: 12, // Размер шрифта неактивного
        onTap: onItemTapped, // Используем ваш обработчик нажатий
      ),
    );
  }
}
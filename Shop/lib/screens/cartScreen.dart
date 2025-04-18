import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart'; // Убедись, что путь правильный
import 'package:shop/screens/productListScreen.dart'; // Убедись, что путь правильный
import 'package:shop/screens/profileScreen.dart'; // Убедись, что путь правильный
// import 'dart:convert'; // Не используется напрямую в этом коде
// import 'dart:typed_data'; // Не используется напрямую в этом коде
import 'package:flutter/services.dart';

// ==============================================================
// Вспомогательные элементы для диалога оплаты
// ==============================================================

// Перечисление для брендов карт
enum CardBrand { unknown, visa, mastercard, mir } // Добавь mir, если нужно

// Вспомогательная функция для определения бренда по номеру карты
Widget getCardBrandIcon(String cardNumber) {
  String digitsOnly = cardNumber.replaceAll(' ', '');
  CardBrand brand = CardBrand.unknown;

  if (digitsOnly.startsWith('4')) {
    brand = CardBrand.visa;
  } else if (RegExp(r'^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[01]|2720)')
      .hasMatch(digitsOnly)) {
    brand = CardBrand.mastercard;
  } else if (RegExp(r'^(220[0-4])').hasMatch(digitsOnly)) {
    brand = CardBrand
        .mir; // Не забудь добавить case CardBrand.mir ниже, если используешь
  }
  // Добавь другие проверки

  switch (brand) {
    case CardBrand.visa:
      try {
        // Используй SizedBox для контроля размера и сохранения пропорций
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
              width: 30,
              height: 20, // Примерные размеры, подбери
              child: Image.asset('assets/images/visa_logo.png',
                  fit: BoxFit.contain)),
        );
      } catch (e) {
        print("Error loading visa logo: $e");
        return Icon(Icons.credit_card, color: Colors.blue[700], size: 20);
      }
    case CardBrand.mastercard:
      try {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
              width: 30,
              height: 20, // Примерные размеры, подбери
              child: Image.asset('assets/images/mastercard_logo.png',
                  fit: BoxFit.contain)),
        );
      } catch (e) {
        print("Error loading mastercard logo: $e");
        return Icon(Icons.credit_card, color: Colors.orange[800], size: 20);
      }
    case CardBrand.mir: // Добавь этот case, если распознаешь МИР
      try {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
              width: 30,
              height: 20, // Примерные размеры, подбери
              child: Image.asset('assets/images/mir_logo.png',
                  fit: BoxFit.contain)),
        );
      } catch (e) {
        print("Error loading mir logo: $e");
        return Icon(Icons.credit_card, color: Colors.green[600], size: 20);
      }
    default:
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(Icons.credit_card,
              color: Colors.grey[600],
              size: 24)); // Можно сделать size: 20 для единообразия
  }
}

// ==============================================================
// Форматтеры ввода
// ==============================================================

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digitsOnly[i]);
    }
    String formattedCardNumber = buffer.toString();
    if (formattedCardNumber.length > 19) {
      formattedCardNumber = formattedCardNumber.substring(0, 19);
    }
    return TextEditingValue(
      text: formattedCardNumber,
      selection: TextSelection.collapsed(offset: formattedCardNumber.length),
    );
  }
}

class ExpirationDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final length = digitsOnly.length;

    if (length == 0) {
      return newValue.copyWith(text: '');
    }

    if (length <= 2) {
      int? month = int.tryParse(digitsOnly);
      if (month != null) {
        if (digitsOnly.length == 2) {
          if (month == 0) return oldValue;
          if (month > 12) {
            if (digitsOnly[0] == '0' || digitsOnly[0] == '1') {
              return TextEditingValue(
                  text: digitsOnly[0],
                  selection: TextSelection.collapsed(offset: 1));
            } else {
              return TextEditingValue(
                  text: '0${digitsOnly[0]}',
                  selection: TextSelection.collapsed(offset: 2));
            }
          }
        } else if (digitsOnly.length == 1) {
          if (month > 1) {
            return TextEditingValue(
                text: '0$digitsOnly',
                selection: TextSelection.collapsed(offset: 2));
          }
        }
      }
      return newValue;
    }

    final buffer = StringBuffer();
    int month = int.parse(digitsOnly.substring(0, 2));
    if (month > 12 || month == 0) {
      return oldValue;
    }
    buffer.write(digitsOnly.substring(0, 2));
    buffer.write('/');
    if (length > 2) {
      buffer.write(digitsOnly.substring(2, length > 4 ? 4 : length));
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

// ==============================================================
// Основной виджет экрана корзины
// ==============================================================

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _cartItemsFuture;
  late Future<List<Map<String, dynamic>>> _deliveryAddressesFuture;
  String? _selectedDeliveryId;
  int _selectedIndex = 1;
  double _totalPrice = 0.0;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCartData();
    _deliveryAddressesFuture = FirebaseService().getAllDeliveryAddresses();
    print('CartScreen initialized.');
  }

  Future<void> _loadUserData() async {
    try {
      userData = await FirebaseService().getUserData();
      print('User Data Loaded: $userData');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _loadCartData() {
    _cartItemsFuture = FirebaseService().getCartItems();
    _cartItemsFuture.then((items) {
      _calculateTotalPrice(items);
      if (mounted) {
        setState(() {});
      }
    }).catchError((error) {
      print("Error loading cart items: $error");
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _calculateTotalPrice(List<Map<String, dynamic>> items) {
    double total = items.fold(0.0, (sum, item) {
      var price = item['price'];
      if (price is int)
        price = price.toDouble();
      else if (price is String)
        price = double.tryParse(price) ?? 0.0;
      else if (price is! double) price = 0.0;
      var quantity = item['quantity'];
      if (quantity is! int) quantity = 1;
      return sum + (price as double) * quantity;
    });
    if (mounted) {
      setState(() {
        _totalPrice = total;
      });
    }
  }

  String formatPrice(dynamic price) {
    double priceDouble;
    if (price is int)
      priceDouble = price.toDouble();
    else if (price is String)
      priceDouble = double.tryParse(price) ?? 0.0;
    else if (price is double)
      priceDouble = price;
    else
      priceDouble = 0.0;
    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();
    return kopecks == 0 ? '$rubles ₽' : '$rubles ₽ $kopecks коп.';
  }

  Future<void> _removeFromCart(
      String docId, Map<String, dynamic> itemToRemove) async {
    print('Trying to remove item with docId: $docId');
    try {
      await FirebaseService().removeFromCart(docId);
      print('Item removed from cart.');
      _loadCartData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${itemToRemove['name']} удален из корзины'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.redAccent[100],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      print('Error removing item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка при удалении товара.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _placeOrder(String deliveryId) async {
    print('Attempting to place order...');
    final cartItems = await _cartItemsFuture;
    if (cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Корзина пуста. Нечего заказывать.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    print('Total price for order: $_totalPrice');
    _showPaymentDialog(_totalPrice, deliveryId, cartItems);
  }

  // ==============================================================
  // !!! ДИАЛОГ ОПЛАТЫ С ИЗМЕНЕННЫМ MARGIN У SNACKBAR !!!
  // ==============================================================
  void _showPaymentDialog(
      double amount, String deliveryId, List<Map<String, dynamic>> cartItems) {
    final TextEditingController cardNumberController = TextEditingController();
    final TextEditingController expirationDateController =
        TextEditingController();
    final TextEditingController cvvController = TextEditingController();
    final FocusNode expirationFocusNode = FocusNode();
    final FocusNode cvvFocusNode = FocusNode();

    // --- Логика предзаполнения карты ---
    if (userData != null && userData!['card_token'] != null) {
      String cardToken = userData!['card_token'];
      String digitsOnly = cardToken.replaceAll(RegExp(r'\D'), '');
      final buffer = StringBuffer();
      for (int i = 0; i < digitsOnly.length; i++) {
        if (i > 0 && i % 4 == 0) buffer.write(' ');
        buffer.write(digitsOnly[i]);
      }
      String formattedToken = buffer.toString();
      cardNumberController.text = formattedToken.length > 19
          ? formattedToken.substring(0, 19)
          : formattedToken;
    }
    // --- Конец логики предзаполнения ---

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget brandIcon = getCardBrandIcon(cardNumberController.text);

            InputDecoration inputDecoration(String label, String hint,
                {Widget? prefixIcon, Widget? suffixIcon}) {
              return InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(color: Colors.grey[400]),
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                        child: prefixIcon)
                    : null,
                suffixIcon: suffixIcon,
                filled: true,
                fillColor: Color(0xFF2a2a2e),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide:
                        BorderSide(color: Colors.grey[700]!, width: 1.0)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide:
                        BorderSide(color: Color(0xFFEE3A57), width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide:
                        BorderSide(color: Colors.redAccent, width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide:
                        BorderSide(color: Colors.redAccent, width: 1.5)),
                counterText: "",
              );
            }

            return AlertDialog(
              backgroundColor: Color(0xFF1f1f24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              title: Text("Оплата картой",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Сумма к оплате: ${formatPrice(amount)}",
                        style:
                            TextStyle(color: Colors.grey[300], fontSize: 16)),
                    SizedBox(height: 20),
                    // --- Поле номера карты ---
                    TextFormField(
                        controller: cardNumberController,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 1.5),
                        decoration: inputDecoration(
                            "Номер карты", "0000 0000 0000 0000",
                            prefixIcon: Icon(Icons.credit_card,
                                color: Colors.grey[500], size: 22),
                            suffixIcon: brandIcon),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                          CardNumberInputFormatter()
                        ],
                        onChanged: (value) {
                          setStateDialog(() {}); // Обновить иконку
                          if (value.length == 19) {
                            FocusScope.of(context)
                                .requestFocus(expirationFocusNode);
                          }
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null ||
                              value.replaceAll(" ", "").length != 16)
                            return 'Введите 16 цифр';
                          return null;
                        }),
                    SizedBox(height: 15),
                    // --- Срок действия и CVV ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                              controller: expirationDateController,
                              focusNode: expirationFocusNode,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                              decoration: inputDecoration("ММ/ГГ", "12/28",
                                  prefixIcon: Icon(Icons.calendar_today,
                                      color: Colors.grey[500], size: 20)),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                                ExpirationDateInputFormatter()
                              ],
                              onChanged: (value) {
                                if (value.length == 5) {
                                  FocusScope.of(context)
                                      .requestFocus(cvvFocusNode);
                                }
                              },
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) {
                                if (value == null || value.length != 5)
                                  return 'MM/ГГ';
                                final RegExp format =
                                    RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$');
                                if (!format.hasMatch(value)) return 'Неверно';
                                final parts = value.split('/');
                                final month = int.tryParse(parts[0]);
                                final year = int.tryParse(parts[1]);
                                if (month == null || year == null)
                                  return 'Ошибка';
                                final now = DateTime.now();
                                final currentYearLastTwoDigits = now.year % 100;
                                if (year < currentYearLastTwoDigits ||
                                    (year == currentYearLastTwoDigits &&
                                        month < now.month)) return 'Истек';
                                return null;
                              }),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                              controller: cvvController,
                              focusNode: cvvFocusNode,
                              obscureText: true,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  letterSpacing: 2.0),
                              decoration: inputDecoration("CVV", "•••",
                                  prefixIcon: Icon(Icons.lock_outline,
                                      color: Colors.grey[500], size: 20)),
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) {
                                if (value == null || value.length != 3)
                                  return '3 цифры';
                                return null;
                              }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
              actionsAlignment: MainAxisAlignment.end,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      padding:
                          EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
                  child: Text("Отмена"),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.verified_user_outlined, size: 18),
                  label: Text("Оплатить ${formatPrice(amount)}"),
                  onPressed: () {
                    if (_validatePaymentFields(cardNumberController.text,
                        expirationDateController.text, cvvController.text)) {
                      print("Данные карты введены корректно (имитация)...");
                      Navigator.of(context).pop();
                      _confirmOrder(deliveryId, cartItems);
                    } else {
                      // --- ИЗМЕНЕНИЕ ЗДЕСЬ ---
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Данные карты неверны. Проверьте выделенные поля.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        // Поднимаем SnackBar выше (значение 0.35 - для примера, подбери свое)
                        margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height *
                                0.35, // <--- УВЕЛИЧЕННЫЙ ОТСТУП
                            left: 15,
                            right: 15),
                        duration: Duration(seconds: 3), // Увеличим время показа
                      ));
                      // --- КОНЕЦ ИЗМЕНЕНИЯ ---
                      HapticFeedback.mediumImpact();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEE3A57),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0)),
                    elevation: 2,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==============================================================
  // !!! ОБНОВЛЕННАЯ ФУНКЦИЯ ВАЛИДАЦИИ !!!
  // ==============================================================
  bool _validatePaymentFields(
      String cardNumber, String expirationDate, String cvv) {
    final digitsOnlyCard = cardNumber.replaceAll(" ", "");
    if (digitsOnlyCard.length != 16) {
      print("Validation Error: Card number length is not 16");
      return false;
    }
    final RegExp expirationRegExp = RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$');
    if (!expirationRegExp.hasMatch(expirationDate)) {
      print(
          "Validation Error: Expiration date format is not MM/YY ($expirationDate)");
      return false;
    }
    final parts = expirationDate.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null) {
      print(
          "Validation Error: Could not parse month or year from $expirationDate");
      return false;
    }
    final now = DateTime.now();
    final currentYearLastTwoDigits = now.year % 100;
    if (year < currentYearLastTwoDigits ||
        (year == currentYearLastTwoDigits && month < now.month)) {
      print(
          "Validation Error: Card has expired (Expiry: $month/20$year, Current: ${now.month}/${now.year})");
      return false;
    }
    if (year > currentYearLastTwoDigits + 10) {
      print(
          "Validation Error: Expiration year ($year) is too far in the future (current: $currentYearLastTwoDigits)");
      return false;
    }
    if (cvv.length != 3) {
      print("Validation Error: CVV length is not 3");
      return false;
    }
    print("Validation Success for $cardNumber, $expirationDate, $cvv");
    return true;
  }

  // Финальное подтверждение и создание заказа в Firebase
  Future<void> _confirmOrder(
      String deliveryId, List<Map<String, dynamic>> cartItems) async {
    print("Confirming order...");
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          /* Индикатор загрузки */
          return Dialog(
              backgroundColor: Color(0xFF1f1f24),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: Color(0xFFEE3A57)),
                    SizedBox(height: 15),
                    Text("Обработка заказа...",
                        style: TextStyle(color: Colors.white))
                  ])));
        });
    try {
      await FirebaseService().placeOrder(cartItems, _totalPrice, deliveryId);
      print('Order placed successfully.');
      Navigator.of(context).pop(); // Закрываем индикатор
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Заказ успешно оформлен!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
        _loadCartData();
        setState(() {
          _selectedDeliveryId = null;
        });
      }
    } catch (e) {
      Navigator.of(context).pop(); // Закрываем индикатор
      print('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка при оформлении заказа: Попробуйте снова.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  // Навигация по нижней панели
  void onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => ProductListScreen(),
                settings: RouteSettings(name: '/productList')));
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => ProfileScreen(),
                settings: RouteSettings(name: '/profile')));
        break;
    }
  }

  // ==============================================================
  // Метод Build виджета CartScreen
  // ==============================================================
  @override
  Widget build(BuildContext context) {
    // Весь код метода build остается БЕЗ ИЗМЕНЕНИЙ по сравнению с твоим последним примером
    // ... (вставь сюда свой код метода build от Scaffold(...) до конца) ...
    return Scaffold(
      backgroundColor: Color(0xFF18171c),
      // Темный фон
      appBar: AppBar(
        title: Text('Корзина', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF18171c), // Фон AppBar в цвет фона Scaffold
        elevation: 0, // Убираем тень
        automaticallyImplyLeading: false, // Убираем кнопку назад по умолчанию
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cartItemsFuture,
        builder: (context, snapshot) {
          // --- Состояния загрузки, ошибки, пустой корзины ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: Colors.white));
          } else if (snapshot.hasError) {
            print(
                "Error in FutureBuilder: ${snapshot.error}"); // Логируем ошибку
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                    'Произошла ошибка загрузки корзины.\nПопробуйте позже.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 16)),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // --- Отображение пустой корзины ---
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_shopping_cart_outlined,
                      size: 80,
                      color: Colors.grey[700]), // Иконка пустой корзины
                  SizedBox(height: 16),
                  Text('Ваша корзина пуста',
                      style: TextStyle(color: Colors.grey[400], fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Добавьте товары, чтобы сделать заказ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: () => onItemTapped(0), // Переход на главную
                    child: Text('Перейти к товарам'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEE3A57),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                ],
              ),
            );
          }

          // --- Отображение корзины с товарами ---
          final cartItems = snapshot.data!;
          return Column(
            children: [
              // --- Выбор Адреса Доставки ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _deliveryAddressesFuture,
                  builder: (context, deliverySnapshot) {
                    // ... (Код отображения адресов без изменений) ...
                    if (deliverySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 15.0, horizontal: 12.0),
                          decoration: BoxDecoration(
                              color: Color(0xFF2a2a2e),
                              borderRadius: BorderRadius.circular(8.0)),
                          child: Row(children: [
                            SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.grey[400])),
                            SizedBox(width: 12),
                            Text("Загрузка адресов...",
                                style: TextStyle(color: Colors.grey[400]))
                          ]));
                    } else if (deliverySnapshot.hasError) {
                      return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 15.0, horizontal: 12.0),
                          decoration: BoxDecoration(
                              color: Color(0xFF2a2a2e),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.redAccent)),
                          child: Text('Ошибка загрузки адресов',
                              style: TextStyle(color: Colors.redAccent)));
                    } else if (!deliverySnapshot.hasData ||
                        deliverySnapshot.data!.isEmpty) {
                      return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 15.0, horizontal: 12.0),
                          decoration: BoxDecoration(
                              color: Color(0xFF2a2a2e).withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8.0)),
                          alignment: Alignment.centerLeft,
                          child: Row(children: [
                            Icon(Icons.location_off_outlined,
                                color: Colors.grey[500], size: 18),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text('Нет сохраненных адресов доставки',
                                    style: TextStyle(color: Colors.grey[400])))
                          ]));
                    }
                    final addresses = deliverySnapshot.data!;
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                      decoration: BoxDecoration(
                          color: Color(0xFF2a2a2e),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                              color: _selectedDeliveryId == null
                                  ? Colors.grey[700]!
                                  : Color(0xFFEE3A57),
                              width: 1.0)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('Выберите адрес доставки',
                              style: TextStyle(color: Colors.grey[400])),
                          value: _selectedDeliveryId,
                          dropdownColor: Color(0xFF2a2a2e),
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.grey[400]),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDeliveryId = newValue;
                            });
                          },
                          items: addresses
                              .map<DropdownMenuItem<String>>((address) {
                            return DropdownMenuItem<String>(
                                value: address['doc_id'],
                                child: Text(
                                    address['delivery_address'] ??
                                        'Адрес не указан',
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- Список Товаров ---
              Expanded(
                child: ListView.builder(
                  padding:
                      EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    // ... (Код отображения товара в Card без изменений) ...
                    final item = cartItems[index];
                    final docId = item['docId'];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6.0),
                      color: Color(0xFF1f1f24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(item['name'] ?? 'Название товара',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600)),
                                    SizedBox(height: 6),
                                    Text(
                                        'Размер: ${item['selected_size'] ?? '-'}',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14)),
                                    SizedBox(height: 4),
                                    Text('Кол-во: ${item['quantity'] ?? 1}',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14)),
                                    SizedBox(height: 8),
                                    Text(formatPrice(item['price'] ?? 0),
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                  ])),
                              SizedBox(width: 10),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.redAccent[100]
                                        ?.withOpacity(0.8)),
                                tooltip: "Удалить из корзины",
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: () {
                                  if (docId != null) {
                                    showDialog(
                                        context: context,
                                        builder: (BuildContext ctx) {
                                          /* Диалог подтверждения удаления */
                                          return AlertDialog(
                                              backgroundColor:
                                                  Color(0xFF1f1f24),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              title: Text('Удалить товар?',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              content: Text(
                                                  'Удалить "${item['name']}" (${item['selected_size']}) из корзины?',
                                                  style: TextStyle(
                                                      color: Colors.grey[300])),
                                              actions: <Widget>[
                                                TextButton(
                                                    child: Text('Отмена',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.grey)),
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop()),
                                                TextButton(
                                                    child: Text('Удалить',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .redAccent)),
                                                    onPressed: () {
                                                      Navigator.of(ctx).pop();
                                                      _removeFromCart(
                                                          docId, item);
                                                    })
                                              ]);
                                        });
                                  } else {
                                    print(
                                        "Error: docId is null for item ${item['name']}");
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          'Не удалось удалить товар: отсутствует ID.'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                  }
                                },
                              ),
                            ]),
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
      bottomSheet: FutureBuilder<List<Map<String, dynamic>>>(
          future: _cartItemsFuture,
          builder: (context, snapshot) {
            // ... (Код bottomSheet без изменений) ...
            if (!snapshot.hasData ||
                snapshot.data!.isEmpty ||
                snapshot.connectionState != ConnectionState.done) {
              return SizedBox.shrink();
            }
            return Container(
              padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 12.0,
                  bottom: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 12.0),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Color(0xFF18171c),
                  border: Border(
                      top: BorderSide(color: Colors.grey[800]!, width: 0.5))),
              child: Row(children: [
                Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Итого:',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 14)),
                      SizedBox(height: 2),
                      Text(formatPrice(_totalPrice),
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ]),
                SizedBox(width: 16),
                Expanded(
                    child: ElevatedButton(
                  onPressed: _selectedDeliveryId != null
                      ? () => _placeOrder(_selectedDeliveryId!)
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEE3A57),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                      disabledBackgroundColor: Colors.grey[700],
                      disabledForegroundColor: Colors.grey[400],
                      elevation: _selectedDeliveryId != null ? 2 : 0),
                  child: Text(
                      _selectedDeliveryId != null
                          ? 'Оформить заказ'
                          : 'Выберите адрес',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                )),
              ]),
            );
          }),
      // --- Нижняя навигационная панель ---
      bottomNavigationBar: BottomNavigationBar(
        // ... (Код BottomNavigationBar без изменений) ...
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Главная'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Корзина'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFFEE3A57),
        unselectedItemColor: Colors.grey[500],
        backgroundColor: Color(0xFF1f1f24),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 4,
        onTap: onItemTapped,
      ),
    );
  }
} // Конец класса _CartScreenState

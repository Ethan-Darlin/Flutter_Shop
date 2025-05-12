import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shop/firebase_service.dart'; 
import 'package:shop/screens/productListScreen.dart'; 
import 'package:shop/screens/profileScreen.dart'; 
import 'package:shop/screens/mapAddressPicker.dart'; 


import 'package:flutter/services.dart';

enum CardBrand { unknown, visa, mastercard, mir }


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
        .mir; 
  }


  switch (brand) {
    case CardBrand.visa:
      try {

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
              width: 30,
              height: 20, 
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
              height: 20, 
              child: Image.asset('assets/images/mastercard_logo.png',
                  fit: BoxFit.contain)),
        );
      } catch (e) {
        print("Error loading mastercard logo: $e");
        return Icon(Icons.credit_card, color: Colors.orange[800], size: 20);
      }
    case CardBrand.mir: 
      try {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
              width: 30,
              height: 20, 
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
              size: 24)); 
  }
}




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

    return kopecks == 0
        ? '$rubles BYN'
        : '$rubles.${kopecks.toString().padLeft(2, '0')} BYN';
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



  void _showPaymentDialog(
      double amount, String deliveryId, List<Map<String, dynamic>> cartItems) {
    final TextEditingController cardNumberController = TextEditingController();
    final TextEditingController expirationDateController = TextEditingController();
    final TextEditingController cvvController = TextEditingController();
    final FocusNode expirationFocusNode = FocusNode();
    final FocusNode cvvFocusNode = FocusNode();

    double updatedAmount = amount;
    bool useLoyaltyPoints = false; 
    double loyaltyPoints = double.tryParse(userData?['loyalty_points'] ?? '0') ?? 0.0;

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
                fillColor: const Color(0xFF2a2a2e),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
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
                    const BorderSide(color: Color(0xFFEE3A57), width: 1.5)),
              );
            }

            void updateAmount() {
              if (useLoyaltyPoints) {
                updatedAmount =
                    (amount - loyaltyPoints).clamp(0.0, double.infinity);
              } else {
                updatedAmount = amount;
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1f1f24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Оплата картой",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Icon(
                    Icons.verified_user_outlined,
                    size: 22, 
                    color: Colors.white,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Сумма к оплате:",
                            style:
                            TextStyle(color: Colors.grey, fontSize: 16)),
                        Text(formatPrice(updatedAmount),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Списать баллы:",
                            style:
                            TextStyle(color: Colors.grey, fontSize: 16)),
                        Switch(
                          value: useLoyaltyPoints,
                          onChanged: (newValue) {
                            setStateDialog(() {
                              useLoyaltyPoints = newValue;
                              updateAmount(); 
                            });
                          },
                          activeColor: const Color(0xFFEE3A57),
                        ),
                      ],
                    ),

                    if (loyaltyPoints > 0)
                      Text("Ваши баллы: ${loyaltyPoints.toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 20),

                    TextFormField(
                        controller: cardNumberController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 1.5),
                        decoration: inputDecoration(
                            "Номер карты", "0000 0000 0000 0000",
                            prefixIcon: const Icon(Icons.credit_card,
                                color: Colors.grey, size: 22),
                            suffixIcon: brandIcon),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                          CardNumberInputFormatter()
                        ],
                        onChanged: (value) {
                          setStateDialog(() {});
                        }),
                    const SizedBox(height: 15),


                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: expirationDateController,
                            focusNode: expirationFocusNode,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            decoration: inputDecoration(
                              "ММ/ГГ",
                              "12/28",
                              prefixIcon: const Icon(Icons.calendar_today, color: Colors.grey, size: 22), 
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              ExpirationDateInputFormatter()
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                            controller: cvvController,
                            focusNode: cvvFocusNode,
                            obscureText: true,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            decoration: inputDecoration(
                              "CVV",
                              "•••",
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 22), 
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "Отмена",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(

                  label: Text(
                    "Оплатить ${formatPrice(updatedAmount)}",
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEE3A57), 
                    foregroundColor: Colors.white, 
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (updatedAmount > 0) {
                      Navigator.of(context).pop();
                      _confirmOrder(
                          deliveryId, cartItems, useLoyaltyPoints, loyaltyPoints);
                    } else {
                      FirebaseService().updateUserData({'loyalty_points': "0"});
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Оплата успешно завершена'),
                          backgroundColor: Colors.green));
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }



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

  Future<void> _confirmOrder(String deliveryId, List<Map<String, dynamic>> cartItems,
      bool useLoyaltyPoints, double loyaltyPoints) async {
    print("Подтверждение заказа...");
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
              backgroundColor: const Color(0xFF1f1f24),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: const [
                    CircularProgressIndicator(color: Color(0xFFEE3A57)),
                    SizedBox(height: 15),
                    Text("Обработка заказа...",
                        style: TextStyle(color: Colors.white))
                  ])));
        });

    try {

      if (useLoyaltyPoints) {
        await FirebaseService().updateUserData({'loyalty_points': "0"});
        print("Баллы лояльности списаны.");
      }

      double finalPrice = _totalPrice - (useLoyaltyPoints ? loyaltyPoints : 0);
      finalPrice = finalPrice.clamp(0.0, double.infinity); 

      await FirebaseService().placeOrder(cartItems, finalPrice, deliveryId);

      for (var item in cartItems) {
        final productId = item['product_id'];
        final selectedSize = item['selected_size'];
        final selectedColor = item['selected_color'];
        final quantityBought = item['quantity'];

        await FirebaseService().updateProductStock(
          productId,
          selectedSize,
          selectedColor,
          -quantityBought, 
        );
      }

      await FirebaseService().clearCart();

      print('Заказ успешно оформлен.');
      Navigator.of(context).pop(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Заказ успешно оформлен!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
        _loadCartData(); 
        setState(() {
          _selectedDeliveryId = null;
        });
      }
    } catch (e) {
      Navigator.of(context).pop(); 
      print('Ошибка оформления заказа: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Ошибка при оформлении заказа. Попробуйте снова.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

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
  Future<void> _updateCartItemQuantity(String docId, int newQuantity) async {
    print('Обновление количества: docId=$docId, newQuantity=$newQuantity');
    try {
      await FirebaseService().updateCartItem(docId, {'quantity': newQuantity});
      print('Количество обновлено в Firestore.');
      _loadCartData(); 
    } catch (e) {
      print('Ошибка обновления количества: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка обновления количества'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }



  @override
  Widget build(BuildContext context) {
    const Color _surfaceColor = Color(0xFF1f1f24);

    return Scaffold(
      backgroundColor: Color(0xFF18171c),
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        title: const Text(
          'Корзина',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cartItemsFuture,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: Colors.white));
          } else if (snapshot.hasError) {
            print(
                "Error in FutureBuilder: ${snapshot.error}"); 
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

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_shopping_cart_outlined,
                      size: 80,
                      color: Colors.grey[700]), 
                  SizedBox(height: 16),
                  Text('Ваша корзина пуста',
                      style: TextStyle(color: Colors.grey[400], fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Добавьте товары, чтобы сделать заказ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: () => onItemTapped(0), 
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

          final cartItems = snapshot.data!;
          return Column(
            children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: FirebaseService().getAllDeliveryAddresses(), 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2e),
                            borderRadius: BorderRadius.circular(8.0)),
                        child: Row(children: [
                          SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.grey[400])),
                          const SizedBox(width: 12),
                          const Text("Загрузка адресов...",
                              style: TextStyle(color: Colors.grey))
                        ]),
                      );
                    } else if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2e),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.redAccent)),
                        child: const Text('Ошибка загрузки адресов',
                            style: TextStyle(color: Colors.redAccent)),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2e).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8.0)),
                        alignment: Alignment.centerLeft,
                        child: Row(children: const [
                          Icon(Icons.location_off_outlined,
                              color: Colors.grey, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text('Нет доступных адресов',
                                  style: TextStyle(color: Colors.grey)))
                        ]),
                      );
                    }

                    final addresses = snapshot.data!;

                    return Row(
                      children: [

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                            decoration: BoxDecoration(
                                color: const Color(0xFF2a2a2e),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                    color: _selectedDeliveryId == null
                                        ? Colors.grey[700]!
                                        : const Color(0xFFEE3A57),
                                    width: 1.0)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: Text('Выберите адрес доставки',
                                    style: TextStyle(color: Colors.grey[400])),
                                value: _selectedDeliveryId,
                                dropdownColor: const Color(0xFF2a2a2e),
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Colors.grey[400]),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedDeliveryId = newValue; 
                                  });
                                },
                                items: addresses.map<DropdownMenuItem<String>>((address) {
                                  return DropdownMenuItem<String>(
                                    value: address['doc_id'],
                                    child: Text(
                                      address['delivery_address'] ?? 'Без названия',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        GestureDetector(
                          onTap: () async {
                            final LatLng? selectedLocation = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapAddressPicker(),
                              ),
                            );

                            if (selectedLocation != null) {
                              setState(() {

                                final selectedAddress = addresses.firstWhere(
                                      (address) =>
                                  address['latitude'] == selectedLocation.latitude &&
                                      address['longitude'] == selectedLocation.longitude,
                                  orElse: () => {}, 
                                );

                                if (selectedAddress.isNotEmpty) {
                                  _selectedDeliveryId = selectedAddress['doc_id'];
                                }
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2a2a2e),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            padding: const EdgeInsets.all(10.0),
                            child: const Icon(Icons.map_outlined, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),


              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final docId = item['docId'];
                    final maxQuantity = item['available_quantity'] ?? 1; 
                    final currentQuantity = item['quantity'] ?? 1;

                    print('--- Item Build ---');
                    print('Name: ${item['name']}');
                    print('Doc ID: $docId');
                    print('Current Quantity: $currentQuantity (type: ${currentQuantity.runtimeType})');
                    print('Max Quantity: $maxQuantity (type: ${maxQuantity.runtimeType})');
                    print('Condition for '+': ${currentQuantity < maxQuantity}');
                    print('------------------');


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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                                color: Colors.grey[400], fontSize: 14)),
                                        SizedBox(height: 8),


                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [

                                            GestureDetector(
                                              onTap: currentQuantity > 1
                                                  ? () async {
                                                print('Нажата кнопка "-" для docId: $docId');
                                                await _updateCartItemQuantity(docId, currentQuantity - 1);
                                              }
                                                  : null,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: currentQuantity > 1 ? const Color(0xFF2a2a2e) : const Color(0xFF1f1f24),
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                padding: const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.remove,
                                                  color: currentQuantity > 1 ? Colors.white : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            Text(
                                              '$currentQuantity',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            GestureDetector(
                                              onTap: currentQuantity < maxQuantity
                                                  ? () async {
                                                print('Нажата кнопка "+" для docId: $docId');
                                                await _updateCartItemQuantity(docId, currentQuantity + 1);
                                              }
                                                  : null,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: currentQuantity < maxQuantity ? const Color(0xFF2a2a2e) : const Color(0xFF1f1f24),
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                padding: const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.add,
                                                  color: currentQuantity < maxQuantity ? Colors.white : Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
                                    color: Colors.redAccent[100]?.withOpacity(0.8)),
                                tooltip: "Удалить из корзины",
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: () {
                                  if (docId != null) {
                                    showDialog(
                                        context: context,
                                        builder: (BuildContext ctx) {

                                          return AlertDialog(
                                              backgroundColor: Color(0xFF1f1f24),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12)),
                                              title: Text('Удалить товар?',
                                                  style: TextStyle(color: Colors.white)),
                                              content: Text(
                                                  'Удалить "${item['name']}" (${item['selected_size']}) из корзины?',
                                                  style: TextStyle(
                                                      color: Colors.grey[300])),
                                              actions: <Widget>[
                                                TextButton(
                                                    child: Text('Отмена',
                                                        style: TextStyle(
                                                            color: Colors.grey)),
                                                    onPressed: () =>
                                                        Navigator.of(ctx).pop()),
                                                TextButton(
                                                    child: Text('Удалить',
                                                        style: TextStyle(
                                                            color: Colors.redAccent)),
                                                    onPressed: () {
                                                      Navigator.of(ctx).pop();
                                                      _removeFromCart(docId, item);
                                                    })
                                              ]);
                                        });
                                  } else {
                                    print(
                                        "Error: docId is null for item ${item['name']}");
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

      bottomSheet: FutureBuilder<List<Map<String, dynamic>>>(
          future: _cartItemsFuture,
          builder: (context, snapshot) {

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

      bottomNavigationBar: BottomNavigationBar(

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
} 

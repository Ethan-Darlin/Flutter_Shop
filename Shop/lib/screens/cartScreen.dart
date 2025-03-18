import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _cartItemsFuture;

  @override
  void initState() {
    super.initState();
    _cartItemsFuture = FirebaseService().getCartItems();
  }

  Future<void> _removeFromCart(String docId) async {
    await FirebaseService().removeFromCart(docId);
    setState(() {
      _cartItemsFuture = FirebaseService().getCartItems();
    });
  }

  Future<void> _placeOrder() async {
    final cartItems = await FirebaseService().getCartItems();
    double totalPrice = cartItems.fold(0.0, (sum, item) {
      var price = item['price'];
      if (price is int) {
        price = price.toDouble();
      }
      return sum + (price as double) * (item['quantity'] ?? 1);
    });

    await FirebaseService().placeOrder(cartItems, totalPrice);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Заказ оформлен!'),
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Корзина'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cartItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Корзина пуста'));
          }

          final cartItems = snapshot.data!;
          double totalPrice = cartItems.fold(0.0, (sum, item) {
            var price = item['price'];
            if (price is int) {
              price = price.toDouble();
            }
            return sum + (price as double) * (item['quantity'] ?? 1);
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final docId = item['docId']; // Получаем docId из данных

                    return ListTile(
                      title: Text(item['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Цена: ${item['price'].toString()}'),
                          Text('Размер: ${item['selected_size'] ?? 'Не указан'}'),
                          Text('Количество: ${item['quantity'].toString()}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_shopping_cart),
                        onPressed: () {
                          if (docId != null) {
                            _removeFromCart(docId);
                          } else {
                            print('Ошибка: docId равен null');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Итого: ${totalPrice.toStringAsFixed(2)}'),
                    ElevatedButton(
                      onPressed: _placeOrder,
                      child: Text('Оформить заказ'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
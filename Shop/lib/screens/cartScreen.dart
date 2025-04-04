import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/productDetailScreen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/profileScreen.dart'; // Импортируем экран деталей продукта

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _cartItemsFuture;
  late Future<List<Map<String, dynamic>>> _deliveryAddressesFuture;
  String? _selectedDeliveryId; // Для хранения выбранного адреса
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _cartItemsFuture = FirebaseService().getCartItems();
    _deliveryAddressesFuture = FirebaseService().getAllDeliveryAddresses(); // Получаем адреса
    print('CartScreen initialized and fetching cart items...');
  }

  Future<void> _removeFromCart(String docId) async {
    print('Trying to remove item with docId: $docId');

    // Получаем информацию о товаре перед его удалением
    final cartItems = await FirebaseService().getCartItems();
    final itemToRemove = cartItems.firstWhere((item) => item['docId'] == docId);

    print('Item to remove: ${itemToRemove['name']} - Quantity: ${itemToRemove['quantity']}');

    // Удаляем товар из корзины
    await FirebaseService().removeFromCart(docId);
    print('Item removed from cart.');

    // Возвращаем количество товара обратно в size_stock
    await FirebaseService().updateProductStock(
      itemToRemove['product_id'], // ID товара
      itemToRemove['selected_size'], // Выбранный размер
      itemToRemove['quantity'], // Количество, которое нужно вернуть
    );
    print('Product stock updated after removing item.');

    setState(() {
      _cartItemsFuture = FirebaseService().getCartItems();
    });
    print('Cart items list updated after removal.');
  }

  Future<void> _placeOrder(String deliveryId) async {
    print('Attempting to place order...');

    final cartItems = await FirebaseService().getCartItems();
    double totalPrice = cartItems.fold(0.0, (sum, item) {
      var price = item['price'];
      if (price is int) {
        price = price.toDouble();
      }
      return sum + (price as double) * (item['quantity'] ?? 1);
    });

    print('Total price calculated: $totalPrice');

    // Оформляем заказ
    await FirebaseService().placeOrder(cartItems, totalPrice, deliveryId); // Передаем deliveryId
    print('Order placed successfully.');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Заказ оформлен!'),
    ));

    // Обновляем состояние корзины
    setState(() {
      _cartItemsFuture = FirebaseService().getCartItems();
    });

    print('Cart items list updated after placing order.');

    Navigator.pop(context); // Вернуться на предыдущий экран
  }

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // Переход на экран со списком товаров
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProductListScreen(), // Перейти на экран со списком продуктов
        ),
      );
    } else if (index == 1) {
      // Переход на экран корзины (возможно, это избыточно, так как вы уже на этом экране)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(),
        ),
      );
    }
    // Добавьте дополнительные условия для других экранов при необходимости
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

          print('Building cart list with ${cartItems.length} items');

          return Column(
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _deliveryAddressesFuture,
                builder: (context, deliverySnapshot) {
                  if (deliverySnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (deliverySnapshot.hasError) {
                    return Center(child: Text('Ошибка: ${deliverySnapshot.error}'));
                  } else if (!deliverySnapshot.hasData || deliverySnapshot.data!.isEmpty) {
                    return Center(child: Text('Нет адресов доставки'));
                  }

                  final addresses = deliverySnapshot.data!;
                  return DropdownButton<String>(
                    hint: Text('Выберите адрес доставки'),
                    value: _selectedDeliveryId,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDeliveryId = newValue;
                      });
                    },
                    items: addresses.map<DropdownMenuItem<String>>((address) {
                      return DropdownMenuItem<String>(
                        value: address['doc_id'], // Используем doc_id как значение
                        child: Text(address['delivery_address']),
                      );
                    }).toList(),
                  );
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final docId = item['docId'];
                    final orderItemId = item['order_item_id']; // Предполагается, что у вас есть этот ID

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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_shopping_cart),
                            onPressed: () {
                              if (docId != null) {
                                _removeFromCart(docId);
                              }
                            },
                          ),
                        ],
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
                      onPressed: () async {
                        if (_selectedDeliveryId != null) {
                          await _placeOrder(_selectedDeliveryId!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Пожалуйста, выберите адрес.')),
                          );
                        }
                      },
                      child: Text('Оформить заказ'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
        currentIndex: _selectedIndex,
        unselectedItemColor: Colors.white,
        backgroundColor: Color(0xFF18171c),
        onTap: (index) {
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(),
              ),
            );
          } else {
            onItemTapped(index);
          }
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/cartScreen.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shop/screens/productDetailScreen.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  int _selectedIndex = 0; // Для отслеживания выбранного индекса

  @override
  void initState() {
    super.initState();
    _productsFuture = FirebaseService().getProducts();
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    await FirebaseService().addToCart(product);
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      // Если выбран индекс корзины, переходим на экран корзины
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(),
        ),
      ).then((_) {
        // Когда возвращаемся из корзины, устанавливаем индекс на 0 (Главная)
        setState(() {
          _selectedIndex = 0;
        });
      });
    } else {
      setState(() {
        _selectedIndex = index; // Обновляем индекс при нажатии на другие элементы
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Продукты'),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartScreen()),
              ).then((_) {
                // Когда возвращаемся из корзины, устанавливаем индекс на 0 (Главная)
                setState(() {
                  _selectedIndex = 0;
                });
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Продукты не найдены'));
          }

          final products = snapshot.data!;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Количество колонок
              childAspectRatio: 0.7, // Соотношение сторон карточки
              crossAxisSpacing: 10, // Отступ между колонками
              mainAxisSpacing: 10, // Отступ между строками
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
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

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(product: product),
                    ),
                  );
                },
                child: Card(
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imageBytes != null
                          ? Image.memory(
                        imageBytes,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                          : Container(height: 100, color: Colors.grey),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          product['name'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'Цена: ${product['price']}',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      Spacer(),
                      TextButton(
                        onPressed: () => _addToCart(product),
                        child: Text('В корзину'),
                      ),
                    ],
                  ),
                ),
              );
            },
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
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}


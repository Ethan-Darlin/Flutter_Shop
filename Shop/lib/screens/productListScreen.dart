import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/cartScreen.dart';
import 'package:shop/screens/profileScreen.dart'; // Импортируйте экран профиля
import 'dart:convert';
import 'dart:typed_data';
import 'package:shop/screens/productDetailScreen.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  int _selectedIndex = 0;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _productsFuture = FirebaseService().getProducts();
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    await FirebaseService().addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Товар добавлен в корзину')),
    );
  }

  String formatPrice(double price) {
    int rubles = price.toInt();
    int kopecks = ((price - rubles) * 100).round(); // Получаем копейки

    if (kopecks == 0) {
      return '$rubles р.'; // Если копейки равны 0, выводим только рубли
    } else {
      return '$rubles р. $kopecks к.'; // Иначе выводим рубли и копейки
    }
  }

  void onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(),
        ),
      ).then((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(), // Переход на экран профиля
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showSizeSelectionDialog(Map<String, dynamic> product) {
    final sizeStock = product['size_stock'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Позволяет управлять высотой
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          width: double.infinity, // Устанавливаем ширину на всю ширину экрана
          height: MediaQuery.of(context).size.height * 0.3, // Устанавливаем высоту
          color: Color(0xFF18171c), // Устанавливаем фоновый цвет
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Выберите размер',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Divider(color: Colors.grey), // Линия под заголовком
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: sizeStock.entries.map<Widget>((entry) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3E3E3E), // Цвет кнопок
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Закрываем текущее окно
                      _showQuantityDialog(product, entry.key);
                    },
                    child: Text(entry.key, style: TextStyle(color: Colors.white)), // Цвет текста на кнопках
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuantityDialog(Map<String, dynamic> product, String selectedSize) {
    int quantity = 1;
    final sizeStock = product['size_stock'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Позволяет управлять высотой
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          width: double.infinity, // Устанавливаем ширину на всю ширину экрана
          height: MediaQuery.of(context).size.height * 0.4, // Устанавливаем высоту
          color: Color(0xFF18171c), // Устанавливаем фоновый цвет
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Выберите количество',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Divider(color: Colors.grey), // Линия под заголовком
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3E3E3E), // Цвет кнопки
                          shape: CircleBorder(), // Кнопка в форме круга
                        ),
                        onPressed: () {
                          if (quantity > 1) {
                            setState(() {
                              quantity--;
                            });
                          }
                        },
                        child: Icon(Icons.remove, color: Colors.white), // Иконка для уменьшения
                      ),
                      SizedBox(width: 16),
                      Text('$quantity', style: TextStyle(fontSize: 24, color: Colors.white)),
                      SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3E3E3E), // Цвет кнопки
                          shape: CircleBorder(), // Кнопка в форме круга
                        ),
                        onPressed: () {
                          if (quantity < (sizeStock[selectedSize] ?? 0)) {
                            setState(() {
                              quantity++;
                            });
                          }
                        },
                        child: Icon(Icons.add, color: Colors.white), // Иконка для увеличения
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _addToCart({
                        ...product,
                        'selected_size': selectedSize,
                        'quantity': quantity,
                      });
                      Navigator.of(context).pop(); // Закрываем диалоговое окно
                    },
                    child: Text('Добавить в корзину'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18171c),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 70.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию...',
                    hintStyle: TextStyle(color: Colors.white),
                    fillColor: Color.fromRGBO(50, 37, 67, 1),
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent), // Убираем цвет границы
                      borderRadius: BorderRadius.circular(30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent), // Убираем цвет границы
                      borderRadius: BorderRadius.circular(30),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white,
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('Продукты не найдены'));
                  }

                  final products = snapshot.data!
                      .where((product) => product['name'].toLowerCase().contains(_searchQuery))
                      .toList();

                  return GridView.builder(
                    shrinkWrap: true, // Обрезает GridView по размеру
                    physics: NeverScrollableScrollPhysics(), // Отключаем скроллинг GridView
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.5,
                      crossAxisSpacing: 0,
                      mainAxisSpacing: 2,
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

                      // Подсчет общего количества всех размеров
                      final sizeStock = product['size_stock'] as Map<String, dynamic>? ?? {};
                      final totalQuantity =
                      sizeStock.values.fold(0, (sum, quantity) => sum + (quantity as int));

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
                          elevation: 2,
                          color: Color(0xFF18171c),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: imageBytes != null
                                    ? Image.memory(
                                  imageBytes,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                                    : Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.white,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  children: [
                                    if (totalQuantity < 10)
                                      Image.asset(
                                        'assets/images/procent.png',
                                        height: 20,
                                        width: 20,
                                      ),
                                    SizedBox(width: 0),
                                    Padding(
                                      padding: EdgeInsets.only(top: 5), // Отступ сверху на 5 пикселей
                                      child: Text(
                                        '${formatPrice(product['price'])}',
                                        style: TextStyle(
                                          color: totalQuantity < 10 ? Colors.red : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, top: 5.0),
                                child: Text(
                                  product['name'],
                                  style: TextStyle(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  product['description'],
                                  style: TextStyle(color: Colors.white),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 0),
                                child: SizedBox(
                                  width: double.infinity, // Устанавливаем ширину на всю карточку
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () => _showSizeSelectionDialog(product),
                                    child: Text(
                                      'В корзину',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFEE3A57), // Цвет кнопки
                                      foregroundColor: Colors.white, // Цвет текста
                                      padding: EdgeInsets.symmetric(vertical: 10), // Вертикальные отступы
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Скругленные углы
                                      elevation: 0, // Тень
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
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
            icon: Icon(Icons.person), // Заменили иконку на "профиль"
            label: 'Профиль', // Изменили текст на "Профиль"
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: onItemTapped,
        backgroundColor: Color(0xFF18171c),
        unselectedItemColor: Colors.white, // Цвет для невыбранных элементов
        unselectedIconTheme: IconThemeData(color: Colors.white), // Цвет невыбранных иконок
      ),
    );
  }
}
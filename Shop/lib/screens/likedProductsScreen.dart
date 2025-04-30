import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shop/screens/productDetailScreen.dart';
import 'package:shop/screens/cartScreen.dart';
import 'package:shop/screens/productListScreen.dart';

class LikedProductsScreen extends StatefulWidget {
  @override
  _LikedProductsScreenState createState() => _LikedProductsScreenState();
}

class _LikedProductsScreenState extends State<LikedProductsScreen> {
  Future<List<Map<String, dynamic>>>? likedProductsFuture;
  int _selectedIndex = 1; // Индекс кнопки "Избранное" в навигации

  // Цветовая схема
  static const Color _backgroundColor = Color(0xFF18171c);
  static const Color _surfaceColor = Color(0xFF1f1f24);
  static const Color _primaryColor = Color(0xFFEE3A57);
  static const Color _secondaryTextColor = Color(0xFFa0a0a0);
  static const Color _textColor = Color(0xFFe0e0e0);

  @override
  void initState() {
    super.initState();
    likedProductsFuture = _fetchLikedProducts();
  }

  Future<List<Map<String, dynamic>>> _fetchLikedProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Пользователь не авторизован.');
      return [];
    }

    try {
      final likedSnapshot = await FirebaseFirestore.instance
          .collection('isLiked')
          .where('user_id', isEqualTo: user.uid)
          .get();

      final likedProductIds = likedSnapshot.docs.map((doc) => doc['product_id'] as int).toList();

      if (likedProductIds.isEmpty) return [];

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('product_id', whereIn: likedProductIds)
          .get();

      return productsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'product_id': doc.id,
          ...data,
          'price': _parsePrice(data['price']),
          'discount': data['discount'] is int ? data['discount'] : (data['discount'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Ошибка получения лайкнутых товаров: $e');
      return [];
    }
  }

  double _parsePrice(dynamic price) {
    if (price is int) return price.toDouble();
    if (price is double) return price;
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Предотвращаем повторный переход на текущую страницу

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Главная
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProductListScreen()),
        );
        break;
      case 1: // Избранное (уже здесь)
        break;
      case 2: // Корзина
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CartScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Избранное', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      backgroundColor: _backgroundColor,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: likedProductsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки: ${snapshot.error}',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: _secondaryTextColor),
                  SizedBox(height: 16),
                  Text(
                    'У вас нет лайкнутых товаров',
                    style: TextStyle(
                      color: _secondaryTextColor,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Добавляйте товары в избранное, чтобы они появились здесь',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _secondaryTextColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          final likedProducts = snapshot.data!;
          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: likedProducts.length,
            itemBuilder: (context, index) {
              final product = likedProducts[index];
              return _buildProductCard(context, product);
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Избранное',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Корзина',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: _primaryColor,
        unselectedItemColor: _secondaryTextColor,
        backgroundColor: _surfaceColor,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final discount = product['discount'] as int;
    final hasDiscount = discount > 0;
    final price = product['price'] as double;
    final discountedPrice = hasDiscount ? price * (100 - discount) / 100 : price;
    final productName = product['name']?.toString() ?? 'Без названия';
    final firstWord = productName.split(' ').first; // Берём только первое слово

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: product['product_id'].toString(),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Изображение товара
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      product['main_image_url'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-$discount%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.favorite,
                    color: _primaryColor,
                    size: 24,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Информация о товаре
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      firstWord,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatPrice(discountedPrice),
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (hasDiscount)
                        Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            _formatPrice(price),
                            style: TextStyle(
                              color: _secondaryTextColor,
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    int rubles = price.toInt();
    int kopecks = ((price - rubles) * 100).round();
    return kopecks == 0
        ? '$rubles ₽'
        : '$rubles ₽ ${kopecks.toString().padLeft(2, '0')} коп.';
  }
}
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
  int _selectedIndex = 1; 

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
    if (_selectedIndex == index) return; 

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: 
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProductListScreen()),
        );
        break;
      case 1: 
        break;
      case 2: 
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
              childAspectRatio: 0.58,
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

    const Color _surfaceColor = Color(0xFF25252C);
    const Color _primaryColor = Color(0xFFEE3A57);
    final Color _secondaryTextColor = Colors.grey[400]!;
    final Color _textFieldFillColor = Color(0xFF25252C);

    final imageUrl = product['main_image_url'] as String?;

    int totalQuantity = 0;
    final sizesData = product['sizes'] as Map<String, dynamic>?;
    if (sizesData != null) {
      sizesData.forEach((size, sizeValue) {
        if (sizeValue is Map<String, dynamic>) {
          final colorsData = sizeValue['color_quantities'] as Map<String, dynamic>?;
          if (colorsData != null) {
            colorsData.forEach((color, quantity) {
              if (quantity is int) totalQuantity += quantity;
            });
          }
        }
      });
    }
    final bool isOutOfStock = totalQuantity <= 0;
    final productId = product['product_id']?.toString();

    final int discount = (product['discount'] is int) ? product['discount'] : 0;
    final bool hasDiscount = discount > 0;
    final double price = (product['price'] is double)
        ? product['price']
        : (product['price'] is int)
        ? (product['price'] as int).toDouble()
        : double.tryParse(product['price']?.toString() ?? '') ?? 0.0;
    final double discountedPrice = hasDiscount ? price * (100 - discount) / 100 : price;

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
      return kopecks == 0
          ? '$rubles BYN'
          : '$rubles.${kopecks.toString().padLeft(2, '0')} BYN';
    }

    return Card(
      elevation: 0,
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (productId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(productId: productId),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Не удалось открыть товар.'), backgroundColor: Colors.red));
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    color: _textFieldFillColor,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: _secondaryTextColor, size: 40)
                    )
                        : Center(child: Icon(Icons.image_not_supported, color: _secondaryTextColor, size: 40)),
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
                  child: Icon(Icons.favorite, color: _primaryColor, size: 24),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    children: [
                      Text(
                        formatPrice(discountedPrice),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (hasDiscount)
                        Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            formatPrice(price),
                            style: TextStyle(
                              color: _secondaryTextColor,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 6),

                  Text(
                    product['name'] ?? 'Название товара',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (productId == null || isOutOfStock)
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailScreen(productId: productId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock ? Colors.grey[700] : _primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700]?.withOpacity(0.7),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        elevation: 0,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(isOutOfStock ? 'Нет в наличии' : 'Подробнее'),
                    ),
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
import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/profileScreen.dart'; // Used for navigation
import 'package:shop/screens/cartScreen.dart'; // Used for navigation
import 'dart:convert';
import 'dart:typed_data';
import 'package:shop/screens/productDetailScreen.dart'; // Importing the updated screen

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  int _selectedIndex = 0;
  String _searchQuery = "";

  // Colors
  final Color _backgroundColor = Color(0xFF18171c);
  final Color _surfaceColor = Color(0xFF25252C);
  final Color _primaryColor = Color(0xFFEE3A57);
  final Color _secondaryTextColor = Colors.grey[400]!;
  final Color _textFieldFillColor = Color(0xFF25252C);

  @override
  void initState() {
    super.initState();
    _productsFuture = FirebaseService().getProducts();
  }

  // Price formatting
  String formatPrice(dynamic price) {
    double priceDouble;
    if (price is double) { priceDouble = price; }
    else if (price is int) { priceDouble = price.toDouble(); }
    else if (price is String) { priceDouble = double.tryParse(price) ?? 0.0; }
    else { priceDouble = 0.0; }

    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();

    if (kopecks == 0) { return '$rubles ₽'; }
    else { String kopecksStr = kopecks.toString().padLeft(2, '0'); return '$rubles.$kopecksStr ₽'; }
  }

  void onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() { _selectedIndex = index; });

    switch (index) {
      case 0: break; // Already on main
      case 1: // Cart
        Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen())).then((_) {});
        break;
      case 2: // Profile
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
        break;
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: TextField(
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Поиск товаров...', hintStyle: TextStyle(color: _secondaryTextColor),
          filled: true, fillColor: _surfaceColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1)),
          prefixIcon: Icon(Icons.search, color: _secondaryTextColor),
          contentPadding: EdgeInsets.symmetric(vertical: 14.0),
        ),
        onChanged: (value) { setState(() { _searchQuery = value.toLowerCase(); }); },
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products) {
    final filteredProducts = products.where((product) =>
    (product['name']?.toString().toLowerCase() ?? '').contains(_searchQuery) ||
        (product['description']?.toString().toLowerCase() ?? '').contains(_searchQuery)).toList();

    if (filteredProducts.isEmpty && _searchQuery.isNotEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('По запросу "$_searchQuery" ничего не найдено.', textAlign: TextAlign.center, style: TextStyle(color: _secondaryTextColor, fontSize: 16),),),);
    }
    if (filteredProducts.isEmpty && products.isNotEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('Товары не найдены.', style: TextStyle(color: _secondaryTextColor, fontSize: 16),),),);
    }
    if (products.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('Товаров пока нет.', style: TextStyle(color: _secondaryTextColor, fontSize: 16),),),);
    }

    return GridView.builder(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.54,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(filteredProducts[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = product['main_image_url'] as String?;

    // --- НОВЫЙ подсчет общего количества ---
    int totalQuantity = 0;
    final sizesData = product['sizes'] as Map<String, dynamic>?;
    if (sizesData != null) {
      sizesData.forEach((size, sizeValue) {
        if (sizeValue is Map<String, dynamic>) {
          final colorsData = sizeValue['color_quantities'] as Map<String, dynamic>?;
          if (colorsData != null) {
            colorsData.forEach((color, quantity) {
              if (quantity is int) {
                totalQuantity += quantity;
              }
            });
          }
        }
      });
    }

    final bool isOutOfStock = totalQuantity <= 0;
    final productId = product['product_id']?.toString();

    return Card(
      elevation: 0,
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (productId != null) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: productId),
            ));
          } else {
            print("Error: Product ID is null for product ${product['name']}");
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть товар.'), backgroundColor: Colors.red));
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Изображение ---
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                color: _textFieldFillColor,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: _secondaryTextColor, size: 40))
                    : Center(child: Icon(Icons.image_not_supported, color: _secondaryTextColor, size: 40)),
              ),
            ),

            // --- Информация о товаре ---
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Цена ---
                  Text(
                    formatPrice(product['price']),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 6),

                  // --- Название товара ---
                  Text(
                    product['name'] ?? 'Название товара',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),

                  // --- Краткое Описание (опционально) ---
                  Text(
                    product['description'] ?? '',
                    style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),

                  // --- Кнопка "Подробнее" ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (productId == null || isOutOfStock) ? null : () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(productId: productId),
                        ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _primaryColor));
                  } else if (snapshot.hasError) {
                    return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('Ошибка загрузки товаров: ${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent))));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('Товаров пока нет.', style: TextStyle(color: _secondaryTextColor, fontSize: 16))));
                    }

                    return SingleChildScrollView(
                      child: _buildProductGrid(snapshot.data!),
                    );
                  },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Корзина'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: _primaryColor,
        unselectedItemColor: _secondaryTextColor,
        backgroundColor: Color(0xFF1f1f24),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12, unselectedFontSize: 12,
        onTap: onItemTapped,
      ),
    );
  }
}
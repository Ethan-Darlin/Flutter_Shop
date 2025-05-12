import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop/screens/productDetailScreen.dart';
import 'package:shop/screens/editProductScreen.dart';
// import 'package:shop/screens/editProductScreen.dart'; // если реализуешь редактирование


class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({Key? key}) : super(key: key);

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  String _searchQuery = "";
  final Color _backgroundColor = const Color(0xFF18171c);
  final Color _surfaceColor = const Color(0xFF25252C);
  final Color _primaryColor = const Color(0xFFEE3A57);
  final Color _secondaryTextColor = const Color(0xFFa0a0a0);
  final Color _textFieldFillColor = const Color(0xFF25252C);

  int _selectedIndex = 0;

  // --- Фильтры, если надо
  String? _selectedCategory;
  String? _selectedSize;
  String? _selectedColor;
  String? _selectedSeason;
  String? _selectedBrand;
  String? _otherBrandName;
  String? _selectedMaterial;
  bool _isFiltersVisible = false;
  RangeValues _weightRange = const RangeValues(0, 5);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        title: const Text(
          'Мои товары',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- Поиск
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Поиск ваших товаров...',
                  hintStyle: TextStyle(color: _secondaryTextColor),
                  filled: true,
                  fillColor: _surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _primaryColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  prefixIcon: Icon(Icons.search, color: _secondaryTextColor),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              ),
            ),
            // --- Контент
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('creator_id', isEqualTo: user?.uid)
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _primaryColor));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  List<Map<String, dynamic>> myProducts = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['doc_id'] = doc.id;
                    return data;
                  }).toList();

                  // Поиск
                  if (_searchQuery.isNotEmpty) {
                    myProducts = myProducts.where((prod) {
                      final name = (prod['name'] ?? '').toString().toLowerCase();
                      final desc = (prod['description'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || desc.contains(_searchQuery);
                    }).toList();
                  }

                  if (myProducts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'У вас пока нет созданных товаров.',
                          style: TextStyle(color: _secondaryTextColor, fontSize: 16),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: myProducts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.53,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final product = myProducts[index];
                      final docId = product['doc_id'];
                      final productId = product['product_id']?.toString();
                      final imageUrl = product['main_image_url'] as String?;
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
                      final isOutOfStock = totalQuantity <= 0;

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
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1.0,
                                child: Container(
                                  color: _textFieldFillColor,
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: _secondaryTextColor, size: 40))
                                      : Center(child: Icon(Icons.image_not_supported, color: _secondaryTextColor, size: 40)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${product['price']} BYN",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      product['name'] ?? 'Название товара',
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product['description'] ?? '',
                                      style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: (productId == null || isOutOfStock)
                                                ? null
                                                : () {
                                              Navigator.push(context, MaterialPageRoute(
                                                builder: (context) => ProductDetailScreen(productId: productId),
                                              ));
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isOutOfStock ? Colors.grey[700] : _primaryColor,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor: Colors.grey[700]?.withOpacity(0.7),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              elevation: 0,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(isOutOfStock ? 'Нет в наличии' : 'Подробнее'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // --- Кнопка редактирования (реализуй EditProductScreen)
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.amber, size: 22),
                                          tooltip: 'Редактировать',
                                          onPressed: () {
                                            if (user == null) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditProductScreen(
                                                  productDocId: product['doc_id'],
                                                  creatorId: user.uid,
                                                ),
                                              ),
                                            );
                                          },
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
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // --- Навигация, если надо
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'Корзина'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: _primaryColor,
        unselectedItemColor: _secondaryTextColor,
        backgroundColor: _surfaceColor,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12, unselectedFontSize: 12,
        onTap: (idx) {
          setState(() => _selectedIndex = idx);
          // обработка навигации
        },
      ),
    );
  }
}
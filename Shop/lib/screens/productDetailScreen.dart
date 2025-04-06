import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/screens/cartScreen.dart';
import 'package:shop/screens/productListScreen.dart';
// import 'package:shop/screens/profileScreen.dart'; // Если ProfileScreen используется в onTapItem, раскомментируйте

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  ProductDetailScreen({required this.product});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedSize;
  int _quantity = 1;
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _commentController = TextEditingController();
  Future<List<Map<String, dynamic>>>? similarProductsFuture;
  final FocusNode _focusNode = FocusNode();
  int _rating = 5; // По умолчанию 5 звезд
  double _averageRating = 0.0;
  bool _hasReviews = false;
  int reviewsCount = 0;
  int _selectedIndex = 0; // Восстановлено для логики навигации

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
    _calculateAverageRating().then((result) {
      if (mounted) {
        setState(() {
          _averageRating = result['average'];
          _hasReviews = result['hasReviews'];
          reviewsCount = result['count'];
        });
      }
    });
    similarProductsFuture = _fetchRandomProducts();

    _focusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(() {});
    _focusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchRandomProducts() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('product_id', isNotEqualTo: widget.product['product_id'])
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) {
        print('Нет других товаров в коллекции.');
        return [];
      }

      List<Map<String, dynamic>> allProducts = snapshot.docs
          .map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      })
          .toList();

      allProducts.shuffle();
      return allProducts.take(4).toList();
    } catch (e) {
      print('Ошибка при загрузке случайных товаров: $e');
      return [];
    }
  }

  Future<void> _addReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Вы должны быть авторизованы для добавления отзыва.')),
        );
      }
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Комментарий не может быть пустым.')),
        );
      }
      return;
    }

    await FirebaseFirestore.instance.collection('reviews').add({
      'product_id': widget.product['product_id'],
      'user_id': user.uid,
      'rating': _rating,
      'comment': _commentController.text.trim(),
      'created_at': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
    _focusNode.unfocus();
    if (mounted) {
      _calculateAverageRating().then((result) {
        if (mounted) {
          setState(() {
            _averageRating = result['average'];
            _hasReviews = result['hasReviews'];
            reviewsCount = result['count'];
            _rating = 5; // Сбрасываем рейтинг на 5 звезд после отправки
          });
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Отзыв добавлен!')),
      );
    }
  }

  Future<void> _fetchProductDetails() async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .where('product_id', isEqualTo: widget.product['product_id'])
          .limit(1)
          .get();

      if (productDoc.docs.isNotEmpty) {
        final productData = productDoc.docs.first.data();
        if (mounted) {
          setState(() {
            widget.product['size_stock'] = productData['size_stock'];
            widget.product['category'] = productData['category'];
            _selectedSize = null;
            _quantity = 1;
          });
          print('Загруженная категория: ${widget.product['category']}');
        }
      } else {
        print('Товар не найден.');
      }
    } catch (e) {
      print('Ошибка при загрузке деталей товара: $e');
    }
  }

  String formatPrice(dynamic price) {
    double priceDouble;
    if (price is int) {
      priceDouble = price.toDouble();
    } else if (price is String) {
      priceDouble = double.tryParse(price) ?? 0.0;
    } else if (price is double) {
      priceDouble = price;
    } else {
      priceDouble = 0.0;
    }

    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();
    return kopecks == 0 ? '$rubles ₽' : '$rubles ₽ $kopecks коп.';
  }


  Future<void> _addToCart() async {
    if (_selectedSize == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Пожалуйста, выберите размер.'),
        ));
      }
      return;
    }
    // Убедимся, что quantity соответствует выбранному состоянию
    // Это уже должно быть установлено в _showQuantityDialog
    await _firebaseService.addToCart({
      ...widget.product,
      'selected_size': _selectedSize,
      'quantity': _quantity, // Используем актуальное _quantity
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Товар добавлен в корзину'),
        duration: Duration(seconds: 1),
      ));
    }
  }

  void _showSizeSelectionDialog() {
    final sizeStock = widget.product['size_stock'] as Map<String, dynamic>? ?? {};
    final availableSizes = sizeStock.entries
        .where((entry) => entry.value is int && entry.value > 0)
        .map((entry) => entry.key)
        .toList();

    if (availableSizes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('К сожалению, этого товара нет в наличии.'),
        ));
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF18171c),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                  'Выберите размер',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableSizes.map<Widget>((size) {
                  // Проверяем, выбран ли этот размер текущим
                  final isSelected = _selectedSize == size;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Color(0xFFEE3A57) : Color(0xFF3E3E3E), // Цвет фона в зависимости от выбора
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: isSelected ? BorderSide(color: Colors.white54, width: 1) : BorderSide.none, // Обводка для выбранного
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedSize = size;
                        _quantity = 1;
                      });
                      // Вызываем _showQuantityDialog только если размер действительно выбран
                      if (_selectedSize != null) {
                        _showQuantityDialog();
                      }
                    },
                    child: Text(size),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showQuantityDialog() {
    final sizeStock = widget.product['size_stock'] as Map<String, dynamic>? ?? {};
    final maxQuantity = sizeStock[_selectedSize] as int? ?? 0;

    if (maxQuantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Размер $_selectedSize не доступен.'),
        ));
      }
      return;
    }

    // Используем _quantity из состояния, чтобы сохранить выбор между открытиями
    // int currentQuantity = _quantity; // Убираем, будем менять _quantity напрямую

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF18171c),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                      'Выберите количество (макс: $maxQuantity)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Color(0xFF3E3E3E)),
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                        onPressed: _quantity > 1 ? () {
                          setModalState(() { // Обновляем UI диалога
                            _quantity--;
                          });
                          setState(() {}); // Обновляем основное состояние (для кнопки "Добавить")
                        } : null,
                        child: Icon(Icons.remove),
                      ),
                      SizedBox(width: 24),
                      Text(
                          '$_quantity', // Используем _quantity из состояния
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      SizedBox(width: 24),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Color(0xFF3E3E3E)),
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                        onPressed: _quantity < maxQuantity ? () {
                          setModalState(() {
                            _quantity++;
                          });
                          setState(() {}); // Обновляем основное состояние
                        } : null,
                        child: Icon(Icons.add),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFEE3A57),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        // Количество уже обновлено в setState
                        _addToCart();
                        Navigator.of(context).pop();
                      },
                      child: Text('Добавить в корзину', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _calculateAverageRating() async {
    try {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('product_id', isEqualTo: widget.product['product_id'])
          .get();

      final reviewDocs = reviewsSnapshot.docs;
      int reviewCount = reviewDocs.length;

      if (reviewCount == 0) {
        return {'average': 0.0, 'hasReviews': false, 'count': 0};
      }

      double totalRating = 0;
      for (var doc in reviewDocs) {
        final data = doc.data();
        final rating = data['rating'];
        if (rating is num) {
          totalRating += rating;
        }
      }

      double averageRating = totalRating / reviewCount;
      // Округляем до одного знака после запятой
      averageRating = (averageRating * 10).round() / 10.0;
      return {
        'average': averageRating,
        'hasReviews': true,
        'count': reviewCount,
      };
    } catch (e) {
      print("Ошибка при подсчете среднего рейтинга: $e");
      return {'average': 0.0, 'hasReviews': false, 'count': 0};
    }
  }

  // --- Восстановленный метод для навигации ---
  void onItemTapped(int index) {
    // Эта логика вызывается из родительского виджета,
    // который отображает BottomNavigationBar
    setState(() {
      _selectedIndex = index; // Обновляем выбранный индекс, если нужно
    });
    if (index == 0) { // Индекс для ProductListScreen
      // Избегаем перехода на тот же экран
      if (ModalRoute.of(context)?.settings.name != '/productList') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListScreen(),
            settings: RouteSettings(name: '/productList'), // Добавляем имя маршрута
          ),
        );
      }
    } else if (index == 1) { // Индекс для CartScreen
      // Избегаем перехода на тот же экран
      if (ModalRoute.of(context)?.settings.name != '/cart') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CartScreen(),
            settings: RouteSettings(name: '/cart'), // Добавляем имя маршрута
          ),
        );
      }
    }
    // Добавьте другие пункты навигации по аналогии
    // else if (index == 2) { // Например, для ProfileScreen
    //   if (ModalRoute.of(context)?.settings.name != '/profile') {
    //     Navigator.pushReplacement(
    //       context,
    //       MaterialPageRoute(builder: (context) => ProfileScreen(), settings: RouteSettings(name: '/profile')),
    //     );
    //   }
    // }
  }
  // --- Конец восстановленного метода ---


  void _showReviewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Делаем фон прозрачным для DraggableScrollableSheet
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Color(0xFF18171c), // Основной фон листа
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Отзывы (${reviewsCount})',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Divider(color: Colors.grey[700], height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('reviews')
                          .where('product_id', isEqualTo: widget.product['product_id'])
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: Colors.white));
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Ошибка загрузки отзывов.', style: TextStyle(color: Colors.grey)));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text('Будьте первым, кто оставит отзыв!', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ));
                        }

                        final reviews = snapshot.data!.docs;

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: reviews.length,
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          separatorBuilder: (context, index) => Divider(color: Colors.grey[800]),
                          itemBuilder: (context, index) {
                            final review = reviews[index].data() as Map<String, dynamic>;
                            final userId = review['user_id'];
                            final rating = review['rating'] ?? 0;
                            final comment = review['comment'] ?? 'Комментарий отсутствует';
                            final timestamp = review['created_at'] as Timestamp?;
                            final dateString = timestamp != null
                                ? '${timestamp.toDate().day.toString().padLeft(2,'0')}.${timestamp.toDate().month.toString().padLeft(2,'0')}.${timestamp.toDate().year}' // Формат ДД.ММ.ГГГГ
                                : '';


                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                              builder: (context, userSnapshot) {
                                String username = 'Аноним';
                                if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData && userSnapshot.data!.exists) {
                                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                  username = userData['username'] ?? 'Аноним';
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(username, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text(dateString, style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: List.generate(5, (starIndex) {
                                          // Отображаем половину звезды, если рейтинг дробный (не просто)
                                          // Для простоты оставим целые звезды
                                          return Icon(
                                            starIndex < rating ? Icons.star : Icons.star_border,
                                            color: Colors.yellow[600],
                                            size: 16,
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 8),
                                      Text(comment, style: TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSimilarProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0 + 5.0, right: 16.0, top: 24.0, bottom: 16.0),
          child: Text(
            'Похожие товары',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: similarProductsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ));
            } else if (snapshot.hasError) {
              print("Ошибка загрузки похожих товаров: ${snapshot.error}");
              return Center(child: Text('Ошибка загрузки похожих товаров', style: TextStyle(color: Colors.grey)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Нет похожих товаров.', style: TextStyle(color: Colors.grey)),
              ));
            }

            final similarProducts = snapshot.data!;

            return Container(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: 16.0 + 5.0, right: 16.0),
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  final product = similarProducts[index];
                  final imageUrl = product['image_url'];
                  Uint8List? imageBytes;

                  if (imageUrl is String && imageUrl.isNotEmpty) {
                    try {
                      String base64String = imageUrl.startsWith('data:')
                          ? imageUrl.split(',').last
                          : imageUrl;
                      base64String = base64String.trim();
                      imageBytes = base64Decode(base64String);
                    } catch (e) {
                      print('Ошибка декодирования Base64 для товара ${product['name']}: $e');
                    }
                  }

                  return Container(
                    width: 180,
                    margin: EdgeInsets.only(right: 12.0),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: Color(0xFF1f1f24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      child: InkWell(
                        onTap: () {
                          // Используем pushReplacement для предотвращения глубокого стека одинаковых экранов
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(product: product),
                              settings: RouteSettings(name: '/productDetail/${product['product_id']}'), // Уникальное имя маршрута
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: imageBytes != null
                                  ? Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[800], child: Icon(Icons.broken_image, color: Colors.grey[600])),
                              )
                                  : Container(
                                color: Colors.grey[800],
                                child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? 'Без имени',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    formatPrice(product['price'] ?? 0),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(left: 10.0, right: 10.0, bottom: 10.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductDetailScreen(product: product),
                                        settings: RouteSettings(name: '/productDetail/${product['product_id']}'),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Перейти',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFEE3A57).withOpacity(0.9),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _showFullScreenImage(Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.black.withOpacity(0.5),
                  shape: CircleBorder(),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  String getReviewsText(int count) {
    if (count == 0) return 'Нет оценок';
    int lastDigit = count % 10;
    int lastTwoDigits = count % 100;

    if (lastTwoDigits >= 11 && lastTwoDigits <= 19) {
      return '$count оценок';
    }
    if (lastDigit == 1) {
      return '$count оценка';
    }
    if (lastDigit >= 2 && lastDigit <= 4) {
      return '$count оценки';
    }
    return '$count оценок';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.product['image_url'];
    Uint8List? imageBytes;

    if (imageUrl is String && imageUrl.isNotEmpty) {
      try {
        String base64String = imageUrl.startsWith('data:')
            ? imageUrl.split(',').last
            : imageUrl;
        base64String = base64String.trim();
        imageBytes = base64Decode(base64String);
      } catch (e) {
        print('Ошибка декодирования Base64 в build: $e');
      }
    }

    return Scaffold(
      backgroundColor: Color(0xFF18171c),
      appBar: AppBar(
        backgroundColor: Color(0xFF18171c),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Если нужно, добавьте заголовок
        // title: Text(widget.product['name'] ?? '', style: TextStyle(color: Colors.white, fontSize: 18)),
        // centerTitle: true,
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100.0), // Отступ для bottomSheet
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Основное выравнивание слева
          children: [
            // --- Изображение ---
            if (imageBytes != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(imageBytes!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.memory(
                      imageBytes,
                      height: MediaQuery.of(context).size.height * 0.45,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: MediaQuery.of(context).size.height * 0.45,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Icon(Icons.broken_image, color: Colors.grey[600], size: 50),
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.45,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 50),
                ),
              ),
            SizedBox(height: 16),

            // --- Название и Описание ---
            Padding(
              // Оставляем левый отступ +5
              padding: const EdgeInsets.only(left: 16.0 + 5.0, right: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product['name'] ?? 'Название товара',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 12),
                  Text(
                    widget.product['description'] ?? 'Описание отсутствует.',
                    style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // --- Блок Рейтинга и Отзывов ---
            Padding(
              // Оставляем левый отступ +5
              padding: const EdgeInsets.only(left: 5.0 + 5.0, right: 5.0),
              child: InkWell(
                onTap: _showReviewsBottomSheet,
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: Color(0xFF2a2a2e),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.yellow[600], size: 24),
                                SizedBox(width: 8),
                                Text(
                                  _hasReviews ? _averageRating.toStringAsFixed(1) : '-',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              getReviewsText(reviewsCount),
                              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[700],
                        margin: EdgeInsets.symmetric(horizontal: 12.0),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Читать отзывы или оставить свой',
                          style: TextStyle(fontSize: 15, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),


            // --- Секция Добавления Отзыва (ИЗМЕНЕНО ДЛЯ ЦЕНТРИРОВАНИЯ) ---
            Padding(
              // Оставляем горизонтальные отступы, но центрируем содержимое
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // Убрали доп. левый отступ здесь
              child: Column(
                // ИЗМЕНЕНО: Выравнивание по центру
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Оставить отзыв',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 12),
                  // Рейтинг звездами
                  Row(
                    // ИЗМЕНЕНО: Выравнивание звезд по центру
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_outline,
                            color: Colors.yellow[600],
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 16),
                  // Поле ввода комментария
                  TextField( // Текстовое поле будет центрировано своим родителем Column
                    controller: _commentController,
                    focusNode: _focusNode,
                    style: TextStyle(color: Colors.white),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addReview(),
                    textAlign: TextAlign.start, // Центрируем текст внутри поля
                    decoration: InputDecoration(
                      hintText: 'Ваш комментарий...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Color(0xFF2a2a2e),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Color(0xFFEE3A57), width: 1),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Кнопка отправки отзыва
                  // ИЗМЕНЕНО: Убрали Align, кнопка будет центрирована Column
              SizedBox( // Оборачиваем для задания ширины
                width: double.infinity, // Делаем кнопку максимально широкой в рамках родительского Padding
                child: ElevatedButton.icon(
                  icon: Icon(Icons.send_outlined, size: 18), // Добавляем иконку
                  label: Text('Отправить отзыв'), // Можно использовать более полный текст
                  onPressed: _addReview, // Ваша функция отправки
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEE3A57), // <<< ЗАМЕНЯЕМ ЦВЕТ ФОНА на акцентный
                    foregroundColor: Colors.white, // Цвет текста и иконки
                    padding: EdgeInsets.symmetric(vertical: 14), // <<< Изменяем внутренние отступы для лучшего вида
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0), // <<< Можно чуть больше скруглить углы
                    ),
                    textStyle: TextStyle( // <<< Задаем стиль текста для единообразия
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    elevation: 2, // Можно добавить небольшую тень для выделения
                  ),
                ),
              ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // --- Похожие Товары ---
            _buildSimilarProductsSection(),

            SizedBox(height: 5),

          ],
        ),
      ),
      // --- Нижняя закрепленная панель ---
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 12.0,
          bottom: MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom // Учет SafeArea снизу
              : 12.0,
        ),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xFF18171c),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Цена:',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  formatPrice(widget.product['price'] ?? 0),
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _showSizeSelectionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEE3A57),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                    _selectedSize == null ? 'Выбрать размер' : 'Добавить в корзину',
                    style: TextStyle(fontSize: 16)
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), // Иконки в стиле outline
            activeIcon: Icon(Icons.home), // Активная иконка
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Корзина',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFFEE3A57), // Цвет активного элемента
        unselectedItemColor: Colors.grey[400], // Цвет неактивных элементов
        backgroundColor: Color(0xFF1f1f24), // Фон панели (чуть светлее основного)
        type: BottomNavigationBarType.fixed, // Чтобы все элементы отображались
        selectedFontSize: 12, // Размер шрифта активного
        unselectedFontSize: 12, // Размер шрифта неактивного
        onTap: onItemTapped, // Используем ваш обработчик нажатий
      ),

    );
  }
}
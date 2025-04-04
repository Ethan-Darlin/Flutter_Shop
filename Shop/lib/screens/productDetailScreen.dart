import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/screens/cartScreen.dart';
import 'package:shop/screens/productListScreen.dart';
import 'package:shop/screens/profileScreen.dart';

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
  final FocusNode _focusNode = FocusNode(); // Создаем FocusNode
  int _rating = 5;
  double _averageRating = 0.0;
  bool _hasReviews = false;
  late Future<List<Map<String, dynamic>>> _similarProductsFuture;
  int reviewsCount = 0;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
    _calculateAverageRating().then((result) {
      setState(() {
        _averageRating = result['average'];
        _hasReviews = result['hasReviews'];
        reviewsCount = result['count'];
      });
    });
    // Update this line
    similarProductsFuture = _fetchRandomProducts();

    // Добавляем слушатель на изменение фокуса
    _focusNode.addListener(() {
    setState(() {});
    });
  }

  Future<List<Map<String, dynamic>>> _fetchSimilarProducts() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get(); // Получаем все товары

      print('Всего товаров: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('Нет товаров в коллекции.');
        return [];
      }

      List<Map<String, dynamic>> allProducts = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Исключаем текущий товар из списка
      allProducts.removeWhere((product) => product['product_id'] == widget.product['product_id']);

      print('Найдено товаров после исключения текущего: ${allProducts.length}');

      if (allProducts.isEmpty) {
        print('Нет похожих товаров.');
        return [];
      }

      // Перемешиваем список и берем первые 4 товара
      allProducts.shuffle();
      return allProducts.take(4).toList();
    } catch (e) {
      print('Ошибка при загрузке похожих товаров: $e');
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> _fetchRandomProducts() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get(); // Получаем все товары

      if (snapshot.docs.isEmpty) {
        print('Нет товаров в коллекции.');
        return [];
      }

      List<Map<String, dynamic>> allProducts = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Перемешиваем список и берем первые 4 товара
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы должны быть авторизованы для добавления отзыва.')),
      );
      return;
    }
    await FirebaseFirestore.instance.collection('reviews').add({
      'product_id': widget.product['product_id'],
      'user_id': user.uid,
      'rating': _rating,
      'comment': _commentController.text,
      'created_at': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
    setState(() {});
  }

  Future<void> _fetchProductDetails() async {
    final productQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('product_id', isEqualTo: widget.product['product_id'])
        .get();

    if (productQuery.docs.isNotEmpty) {
      final productData = productQuery.docs.first.data() as Map<String, dynamic>;
      setState(() {
        widget.product['size_stock'] = productData['size_stock'];
        widget.product['category'] = productData['category']; // Загружаем категорию
        _selectedSize = null;
        _quantity = 1;
      });
      print('Загруженная категория: ${widget.product['category']}'); // Логируем загруженную категорию
    } else {
      print('Товар не найден.');
    }
  }

  String formatPrice(double price) {
    int rubles = price.toInt();
    int kopecks = ((price - rubles) * 100).round();
    return kopecks == 0 ? '$rubles р.' : '$rubles р. $kopecks к.';
  }

  Future<void> _addToCart() async {
    await _firebaseService.addToCart({
      ...widget.product,
      'selected_size': _selectedSize,
      'quantity': _quantity,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Товар добавлен в корзину'),
    ));
  }

  void _showSizeSelectionDialog() {
    final sizeStock = widget.product['size_stock'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(18),
          width: double.infinity,
          color: Color(0xFF18171c),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Выберите размер', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              Divider(color: Colors.grey),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: sizeStock.entries.map<Widget>((entry) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3E3E3E),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _selectedSize = entry.key;
                      _showQuantityDialog();
                    },
                    child: Text(entry.key, style: TextStyle(color: Colors.white)),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuantityDialog() {
    int quantity = 1;
    final sizeStock = widget.product['size_stock'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(16),
              color: Color(0xFF18171c),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Выберите количество', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3E3E3E),
                          shape: CircleBorder(),
                        ),
                        onPressed: () {
                          if (quantity > 1) {
                            setState(() {
                              quantity--;
                            });
                          }
                        },
                        child: Icon(Icons.remove, color: Colors.white),
                      ),
                      SizedBox(width: 16),
                      Text('$quantity', style: TextStyle(fontSize: 24, color: Colors.white)),
                      SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3E3E3E),
                          shape: CircleBorder(),
                        ),
                        onPressed: () {
                          if (quantity < (sizeStock[_selectedSize] ?? 0)) {
                            setState(() {
                              quantity++;
                            });
                          }
                        },
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _addToCart();
                      Navigator.of(context).pop();
                    },
                    child: Text('Добавить в корзину'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _calculateAverageRating() async {
    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('product_id', isEqualTo: widget.product['product_id'])
        .get();

    if (reviewsSnapshot.docs.isEmpty) {
      return {'average': 0.0, 'hasReviews': false, 'count': 0};
    }

    double totalRating = 0;
    int reviewCount = reviewsSnapshot.docs.length;

    for (var doc in reviewsSnapshot.docs) {
      totalRating += (doc.data() as Map<String, dynamic>)['rating'];
    }

    double averageRating = totalRating / reviewCount;
    return {
      'average': averageRating,
      'hasReviews': true,
      'count': reviewCount,
    };
  }

  void onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProductListScreen(),
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(),
        ),
      );
    }
  }

  void _showReviewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF18171c),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Отзывы:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Container(
                height: 2,
                color: Colors.white,
                width: double.infinity,
              ),
              SizedBox(height: 8),
              SizedBox(
                height: 600,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reviews')
                      .where('product_id', isEqualTo: widget.product['product_id'])
                      .orderBy('created_at', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('Отзывов пока нет.', style: TextStyle(color: Colors.white)));
                    }

                    final reviews = snapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[index].data() as Map<String, dynamic>;
                        final userId = review['user_id'];

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              return ListTile(
                                title: Text('Загрузка...', style: TextStyle(color: Colors.white)),
                              );
                            }
                            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                              return ListTile(
                                title: Text('Пользователь не найден', style: TextStyle(color: Colors.white)),
                              );
                            }

                            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            final username = userData['username'] ?? 'Неизвестный';

                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              color: Color(0xFF3E3E3E),
                              child: ListTile(
                                title: Text('Рейтинг: ${review['rating']}', style: TextStyle(color: Colors.white)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$username: ${review['comment'] ?? 'Комментарий отсутствует'}', style: TextStyle(color: Colors.white)),
                                    SizedBox(height: 4),
                                    Text(
                                      review['created_at'] != null
                                          ? (review['created_at'] as Timestamp).toDate().toString()
                                          : '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
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
  }

  Widget _buildSimilarProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
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
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Ошибка загрузки похожих товаров', style: TextStyle(color: Colors.white)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Нет похожих товаров.', style: TextStyle(color: Colors.white)));
            }

            final similarProducts = snapshot.data!;

            return Container(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  final product = similarProducts[index];
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

                  return Container(
                    width: 180,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Card(
                      elevation: 2,
                      color: Color(0xFF18171c),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(product: product),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              child: imageBytes != null
                                  ? Image.memory(
                                imageBytes,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                                  : Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: TextStyle(color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formatPrice(product['price']),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Перейти',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFEE3A57),
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;

        return Dialog(
          backgroundColor: Colors.black,
          child: Container(
            height: screenSize.height * 0.5,
            width: screenSize.width * 0.8,
            child: Stack(
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: Image.memory(imageBytes),
                  ),
                ),
                Positioned(
                  left: 240,
                  bottom: 330,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.black),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      hoverColor: Colors.transparent,
                      splashColor: Colors.red.withOpacity(0.5),
                      highlightColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String getReviewsText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return '$count оценка';
    } else if ((count % 10 >= 2 && count % 10 <= 4) && (count % 100 < 10 || count % 100 >= 20)) {
      return '$count оценки';
    } else {
      return '$count оценок';
    }
  }
  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.product['image_url'];
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

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Убираем автоматическое изменение размера при появлении клавиатуры
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageBytes != null)
                  GestureDetector(
                    onTap: () => _showFullScreenImage(imageBytes!),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color(0xFF18171c),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            child: Image.memory(
                              imageBytes,
                              height: 400,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0, bottom: 10),
                            child: Text(
                              '${formatPrice(widget.product['price'])}',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product['name'],
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.product['description'],
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: GestureDetector(
                    onTap: _showReviewsBottomSheet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF3E3E3E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.all(3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/star.png',
                                          width: 24,
                                          height: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '${_averageRating.toStringAsFixed(1)}',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    _hasReviews
                                        ? Text(
                                      getReviewsText(reviewsCount),
                                      style: TextStyle(fontSize: 14, color: Colors.white),
                                    )
                                        : Text(
                                      '0 отзывов!',
                                      style: TextStyle(fontSize: 14, color: Colors.white),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(Icons.arrow_forward, color: Colors.white),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          width: 2,
                          color: Colors.white,
                          height: 60,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF3E3E3E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            padding: EdgeInsets.all(7),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Поделитесь опытом использования!',
                                  style: TextStyle(fontSize: 17, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Добавить отзыв',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.yellow,
                              size: 32,
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        focusNode: _focusNode, // Привязываем FocusNode к полю ввода
                        decoration: InputDecoration(
                          labelText: _focusNode.hasFocus ? '' : 'Ваш комментарий', // Скрываем текст при фокусе
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(10),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addReview,
                        child: Text(
                          'Добавить отзыв',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFEE3A57)),
                      ),
                    ],
                  ),
                ),

                _buildSimilarProductsSection(),

                SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            bottom: 0.0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Color(0xFF18171c),
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showSizeSelectionDialog,
                        child: Text(
                          'В корзину',
                          style: TextStyle(
                            color: Colors.white, // Устанавливаем цвет текста белым
                            fontSize: 18, // Устанавливаем размер текста
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFEE3A57),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                BottomNavigationBar(
                  backgroundColor: Color(0xFF18171c),
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
                  selectedItemColor: Colors.white,
                  unselectedItemColor: Colors.white,
                  onTap: (index) {
                    if (index == 2) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(), // Переход на экран профиля
                        ),
                      );
                    } else {
                      onItemTapped(index); // Обработка других пунктов меню
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
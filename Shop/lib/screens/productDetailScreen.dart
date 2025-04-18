import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shop/firebase_service.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/screens/cartScreen.dart';
import 'package:shop/screens/productListScreen.dart';
// import 'package:shop/screens/profileScreen.dart';

class ImageKitService {
  static const String _imageKitUrl =
      'https://upload.imagekit.io/api/v1/files/upload';
  static const String _publicKey = 'public_0EblotM8xHzpWNJUXWiVtRnHbGA=';
  static const String _privateKey =
      'private_ZKL7E/ailo8o7MHqrvHIpxQRIiE='; // SECURE THIS KEY

  static Future<String?> uploadImage(File imageFile) async {
    try {
      String authHeader = 'Basic ' + base64Encode(utf8.encode('$_privateKey:'));
      var request = http.MultipartRequest('POST', Uri.parse(_imageKitUrl));
      request.headers.addAll({'Authorization': authHeader});
      request.fields['fileName'] = imageFile.path.split('/').last;
      request.fields['publicKey'] = _publicKey;
      request.fields['useUniqueFileName'] = 'true';
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseData.body);
        return jsonResponse['url'];
      } else {
        print('ImageKit Ошибка: ${responseData.body}');
        return null;
      }
    } catch (e) {
      print('ImageKit Исключение: $e');
      return null;
    }
  }
}

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines; // Количество строк до сворачивания
  final TextStyle? style;
  final TextStyle? linkStyle;

  const ExpandableText(
      this.text, {
        Key? key,
        this.trimLines = 3,
        this.style,
        this.linkStyle,
      }) : super(key: key);

  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false; // Контролирует состояние текста (развернут/свёрнут)

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = widget.style ??
        Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white70, height: 1.5);

    final linkTextStyle = widget.linkStyle ??
        defaultTextStyle?.copyWith(
            color: Colors.blueAccent, fontWeight: FontWeight.w600);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Определяем, превышает ли текст заданное количество строк
        final TextPainter textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: defaultTextStyle),
          maxLines: widget.trimLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        // Показывать ли кнопку "Читать далее"
        final bool isTextOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Текст (обрезанный или полный)
            Text(
              widget.text,
              style: defaultTextStyle,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              maxLines: _isExpanded ? null : widget.trimLines,
            ),

            // Кнопка "Читать далее" / "Свернуть"
            if (isTextOverflowing)
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded; // Переключаем состояние
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _isExpanded ? 'Свернуть' : 'Читать далее...',
                    style: linkTextStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  // --- ИСПРАВЛЕНО: Константы объявлены здесь как static const ---
  static const Color primaryColor = Color(0xFFEE3A57);
  static const Color darkBg = Color(0xFF18171c);
  static const Color lightBg = Color(0xFF1f1f24);
  static const Color lighterBg = Color(0xFF2a2a2e);
  static const Color accentColor = Color(0xFF3D74FF);

  ProductDetailScreen({required this.productId, Key? key}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _productData;
  bool _isLoadingProduct = true;
  String? _errorMessage;
  String? _selectedSize;
  String? _selectedColor;
  int _quantity = 1;
  String? _mainImageUrl;
  String? _currentDisplayedImageUrl;
  Map<String, String?> _productColorImageUrls = {};
  List<String> _availableSizes = [];
  Map<String, List<String>> _availableColorsPerSize = {};
  Map<String, Map<String, int>> _availableQuantities = {};
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _commentController = TextEditingController();
  Future<List<Map<String, dynamic>>>? similarProductsFuture;
  final FocusNode _focusNode = FocusNode();
  int _rating = 5;
  double _averageRating = 0.0;
  bool _hasReviews = false;
  int reviewsCount = 0;
  int _selectedIndex = 0;
  List<File> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _fetchProductDataAndDetails();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(() {});
    _focusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductDataAndDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProduct = true;
      _errorMessage = null;
    });
    try {
      final productIdInt = int.tryParse(widget.productId);
      if (productIdInt == null) throw Exception("Некорректный ID продукта");
      QuerySnapshot productQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('product_id', isEqualTo: productIdInt)
          .limit(1)
          .get();
      if (productQuery.docs.isEmpty) throw Exception("Товар не найден");
      final productDoc = productQuery.docs.first;
      _productData = productDoc.data() as Map<String, dynamic>?;
      if (_productData == null) throw Exception("Ошибка данных продукта");
      _productData!['doc_id'] = productDoc.id;
      _mainImageUrl = _productData!['main_image_url'] as String?;
      _currentDisplayedImageUrl =
          _mainImageUrl?.isNotEmpty == true ? _mainImageUrl : null;
      _parseProductVariants(_productData!);
      _loadSecondaryData();
    } catch (e, stackTrace) {
      print('Ошибка загрузки: $e\n$stackTrace');
      if (!mounted) return;
      setState(() => _errorMessage = 'Не удалось загрузить товар: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProduct = false);
    }
  }

  void _parseProductVariants(Map<String, dynamic> data) {
    _productColorImageUrls.clear();
    _availableSizes.clear();
    _availableColorsPerSize.clear();
    _availableQuantities.clear();
    final productColorsData = data['colors'] as Map<String, dynamic>?;
    if (productColorsData != null) {
      productColorsData.forEach((colorName, imageUrl) {
        _productColorImageUrls[colorName] =
            (imageUrl is String && imageUrl.isNotEmpty) ? imageUrl : null;
      });
    }
    final sizesData = data['sizes'] as Map<String, dynamic>?;
    if (sizesData != null) {
      sizesData.forEach((sizeName, sizeDetails) {
        if (sizeDetails is Map<String, dynamic>) {
          final colorQuantitiesData =
              sizeDetails['color_quantities'] as Map<String, dynamic>?;
          if (colorQuantitiesData != null && colorQuantitiesData.isNotEmpty) {
            List<String> colorsForThisSize = [];
            Map<String, int> quantitiesForThisSize = {};
            bool hasValidQuantity = false;
            colorQuantitiesData.forEach((colorName, quantity) {
              if (quantity is int && quantity >= 0) {
                colorsForThisSize.add(colorName);
                quantitiesForThisSize[colorName] = quantity;
                if (quantity > 0) hasValidQuantity = true;
              }
            });
            if (colorsForThisSize.isNotEmpty && hasValidQuantity) {
              _availableSizes.add(sizeName);
              _availableColorsPerSize[sizeName] = colorsForThisSize;
              _availableQuantities[sizeName] = quantitiesForThisSize;
            }
          }
        }
      });
      _availableSizes.sort((a, b) {
        final numA = int.tryParse(a);
        final numB = int.tryParse(b);
        if (numA != null && numB != null) return numA.compareTo(numB);
        return a.compareTo(b);
      });
    }
  }

  void _loadSecondaryData() {
    _calculateAverageRating().then((result) {
      if (mounted)
        setState(() {
          _averageRating = result['average'];
          _hasReviews = result['hasReviews'];
          reviewsCount = result['count'];
        });
    });
    similarProductsFuture = _fetchSimilarProducts();
  }

  void _onSizeSelected(String size) {
    if (_selectedSize != size)
      setState(() {
        _selectedSize = size;
        _selectedColor = null;
        _currentDisplayedImageUrl = _mainImageUrl;
        _quantity = 1;
      });
  }

  void _onColorSelected(String color) {
    if (!(_availableColorsPerSize[_selectedSize ?? '']?.contains(color) ??
        false)) return;
    final isAvailable = (_availableQuantities[_selectedSize!]?[color] ?? 0) > 0;
    if (!isAvailable && mounted)
      _showErrorSnackBar("Цвет '$color' временно недоступен.",
          duration: Duration(seconds: 2));
    if (_selectedColor != color)
      setState(() {
        _selectedColor = color;
        String? colorImage = _productColorImageUrls[color];
        _currentDisplayedImageUrl =
            (colorImage != null && colorImage.isNotEmpty)
                ? colorImage
                : _mainImageUrl;
        _quantity = 1;
      });
  }

  int _getMaxQuantity() {
    if (_selectedSize == null || _selectedColor == null) return 0;
    return _availableQuantities[_selectedSize!]?[_selectedColor!] ?? 0;
  }

  double _calculateDiscountedPrice() {
    final price = _productData?['price'] as num?;
    final discount = _productData?['discount'] as num?;
    if (price == null) return 0.0;
    final double originalPrice = price.toDouble();
    double currentPrice = originalPrice;
    if (discount != null && discount > 0 && discount <= 100) {
      currentPrice = originalPrice * (1 - discount / 100.0);
    }
    return currentPrice;
  }

  Future<void> _addToCart() async {
    if (_selectedSize == null) {
      _showErrorSnackBar('Выберите размер');
      return;
    }
    if (_selectedColor == null) {
      _showErrorSnackBar('Выберите цвет');
      return;
    }
    final maxQuantity = _getMaxQuantity();
    if (maxQuantity <= 0) {
      _showErrorSnackBar('Нет в наличии');
      return;
    }
    if (_quantity > maxQuantity) {
      _showErrorSnackBar('Максимум $maxQuantity шт.');
      return;
    }
    if (_quantity <= 0) {
      _showErrorSnackBar('Укажите количество');
      return;
    }
    final cartItemData = {
      'product_id': _productData?['product_id'],
      'doc_id': _productData?['doc_id'],
      'name': _productData?['name'],
      'price': _calculateDiscountedPrice(),
      'main_image_url': _mainImageUrl,
      'selected_size': _selectedSize,
      'selected_color': _selectedColor,
      'quantity': _quantity,
    };
    cartItemData.removeWhere((key, value) => value == null);
    try {
      await _firebaseService.addToCart(cartItemData);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Добавлено в корзину'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ));
    } catch (e) {
      _showErrorSnackBar('Ошибка добавления: $e');
    }
  }
  Future<String?> _getCategoryNameById(int categoryId) async {
    try {
      // Выполняем запрос к коллекции категорий
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('categories')
          .where('category_id', isEqualTo: categoryId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Возвращаем имя категории
        return snapshot.docs.first.data()['name'] as String?;
      }
    } catch (e) {
      print('Ошибка получения имени категории: $e');
    }
    return null; // Если категория не найдена
  }

  Future<List<Map<String, dynamic>>> _fetchSimilarProducts() async {
    try {
      final currentProductId = _productData?['product_id'];
      final currentCategoryId = _productData?['category_id'];
      if (currentProductId == null || currentCategoryId == null) return [];
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('products')
          .where('category_id', isEqualTo: currentCategoryId)
          .where('product_id', isNotEqualTo: currentProductId)
          .limit(10)
          .get();
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['doc_id'] = doc.id;
        String? imageUrl = data['main_image_url'] as String?;
        if (imageUrl == null || imageUrl.isEmpty) {
          Map<String, dynamic>? colors =
              data['colors'] as Map<String, dynamic>?;
          if (colors != null && colors.isNotEmpty) {
            imageUrl = colors.values.firstWhere(
                (url) => url is String && url.isNotEmpty,
                orElse: () => null);
          }
        }
        data['thumbnail_url'] = imageUrl;
        data.remove('colors');
        data.remove('sizes');
        data.remove('description');
        data.remove('main_image_url');
        data.remove('material');
        data.remove('brand');
        data.remove('weight');
        data.remove('season');
        return data;
      }).toList()
        ..shuffle()
        ..take(4);
    } catch (e) {
      print('Ошибка похожих товаров: $e');
      return [];
    }
  }

  Future<void> _addReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('Вы должны быть авторизованы');
      return;
    }
    final currentProductId = _productData?['product_id']?.toString();
    if (currentProductId == null) {
      _showErrorSnackBar('Ошибка ID продукта');
      return;
    }

    // Проверка на существующий комментарий
    final existingReviews = await FirebaseFirestore.instance
        .collection('reviews')
        .where('product_id', isEqualTo: currentProductId)
        .where('user_id', isEqualTo: user.uid)
        .get();

    if (existingReviews.docs.isNotEmpty) {
      _showErrorSnackBar('Вы можете оставить только один комментарий.');
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      _showErrorSnackBar('Комментарий не может быть пустым');
      return;
    }

    try {
      // Проверяем, совершал ли пользователь покупку
      final isPurchased = await _isProductPurchased(user.uid, currentProductId);

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        for (var imageFile in _selectedImages) {
          String? imageUrl = await ImageKitService.uploadImage(imageFile);
          if (imageUrl != null) imageUrls.add(imageUrl);
        }
      }

      // Добавляем отзыв в Firestore
      await FirebaseFirestore.instance.collection('reviews').add({
        'product_id': currentProductId,
        'user_id': user.uid,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'images': imageUrls,
        'verified_purchase': isPurchased, // Добавляем флаг "Проверенная покупка"
        'liked_by': [],
        'likes': 0,
      });

      // Очистка полей после добавления отзыва
      _commentController.clear();
      _focusNode.unfocus();
      if (!mounted) return;
      setState(() {
        _rating = 5;
        _selectedImages.clear();
      });

      _loadSecondaryData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Отзыв добавлен!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Ошибка добавления отзыва: $e');
    }
  }
  void _showDeleteReviewDialog(BuildContext context, String reviewId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ProductDetailScreen.lightBg,
          title: Text(
            'Удалить комментарий',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Вы уверены, что хотите удалить этот комментарий?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Отмена', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('reviews')
                      .doc(reviewId)
                      .delete();
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Ошибка при удалении комментария: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: Text('Удалить'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _calculateAverageRating() async {
    final currentProductId = _productData?['product_id']?.toString();
    if (currentProductId == null)
      return {'average': 0.0, 'hasReviews': false, 'count': 0};
    try {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('product_id', isEqualTo: currentProductId)
          .get();
      final reviewDocs = reviewsSnapshot.docs;
      int reviewCount = reviewDocs.length;
      if (reviewCount == 0)
        return {'average': 0.0, 'hasReviews': false, 'count': 0};
      double totalRating = 0;
      for (var doc in reviewDocs) {
        final data = doc.data();
        final rating = data['rating'];
        if (rating is num) totalRating += rating;
      }
      double averageRating = (totalRating / reviewCount * 10).round() / 10.0;
      return {
        'average': averageRating,
        'hasReviews': true,
        'count': reviewCount
      };
    } catch (e) {
      print("Ошибка рейтинга: $e");
      return {'average': 0.0, 'hasReviews': false, 'count': 0};
    }
  }

  Future<bool> _isProductPurchased(String userId, String productId) async {
    try {
      print('Проверяем покупку для userId: $userId, productId: $productId');

      // Получаем все заказы пользователя
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: userId)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        print('У пользователя нет заказов.');
        return false;
      }

      final orderIds = ordersSnapshot.docs.map((doc) => doc.id).toList();
      print('ID заказов пользователя: $orderIds');

      // Преобразуем productId в число, если это возможно
      final int? productIdInt = int.tryParse(productId);
      if (productIdInt == null) {
        print('Ошибка: productId не удалось преобразовать в число.');
        return false;
      }

      // Проверяем, есть ли завершенные товары с переданным productId
      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .where('order_id', whereIn: orderIds) // Проверка по ID заказов
          .where('product_id', isEqualTo: productIdInt) // Проверка по product_id как числу
          .where('item_status', isEqualTo: 'completed') // Проверка статуса
          .limit(1) // Достаточно одной записи
          .get();

      final hasCompletedPurchase = orderItemsSnapshot.docs.isNotEmpty;

      // Логируем результат для отладки
      print('Результат проверки: $hasCompletedPurchase');

      return hasCompletedPurchase;
    } catch (e) {
      print('Ошибка проверки покупки: $e');
      return false;
    }
  }

  Future<void> _toggleLikeReview(String reviewId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final reviewDoc = FirebaseFirestore.instance.collection('reviews').doc(reviewId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(reviewDoc);

        if (!snapshot.exists) throw Exception("Отзыв не найден");

        final data = snapshot.data() as Map<String, dynamic>;
        final List<dynamic> likedBy = List.from(data['liked_by'] ?? []);
        final isLiked = likedBy.contains(userId);

        if (isLiked) {
          // Удаляем лайк
          likedBy.remove(userId);
        } else {
          // Добавляем лайк
          likedBy.add(userId);
        }

        // Обновляем документ
        transaction.update(reviewDoc, {
          'liked_by': likedBy,
          'likes': likedBy.length, // Обновляем количество лайков
        });
      });
    } catch (e) {
      print('Ошибка при переключении лайка: $e');
    }
  }
  Future<int> getLikesCount(String reviewId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('isLiked')
          .where('idReview', isEqualTo: reviewId)
          .count()
          .get();

      // Проверяем, что count не равен null, иначе возвращаем 0
      return snapshot.count ?? 0;
    } catch (e) {
      print('Ошибка при получении количества лайков: $e');
      return 0;
    }
  }
  Future<bool> isReviewLikedByUser(String reviewId, String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .doc(reviewId)
          .get();

      if (!snapshot.exists) return false;

      final data = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> likedBy = data['liked_by'] ?? [];

      return likedBy.contains(userId);
    } catch (e) {
      print('Ошибка при проверке лайка: $e');
      return false;
    }
  }
  Widget buildLikeButton(String reviewId) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return IconButton(
        icon: Icon(Icons.thumb_up_off_alt_rounded, color: Colors.grey),
        onPressed: () => print('Требуется авторизация'),
      );
    }

    return FutureBuilder<bool>(
      future: isReviewLikedByUser(reviewId, user.uid),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;

        return IconButton(
          icon: Icon(
            isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_off_alt_rounded,
            color: isLiked ? Colors.blue : Colors.grey,
          ),
          onPressed: () => _toggleLikeReview(reviewId),
        );
      },
    );
  }

  Future<List<File>> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 70);
    if (pickedFiles != null) {
      return pickedFiles.map((file) => File(file.path)).toList();
    }
    return [];
  }

  String formatPrice(dynamic price) {
    double priceDouble;

    // Преобразование цены в число
    if (price is double) {
      priceDouble = price;
    } else if (price is int) {
      priceDouble = price.toDouble();
    } else if (price is String) {
      priceDouble = double.tryParse(price) ?? 0.0;
    } else {
      priceDouble = 0.0;
    }

    // Форматирование цены в белорусских рублях
    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();

    if (kopecks == 0) {
      return '$rubles BYN'; // Без копеек
    } else {
      String kopecksStr = kopecks.toString().padLeft(2, '0');
      return '$rubles.$kopecksStr BYN'; // С копейками
    }
  }

  String getReviewsText(int count) {
    if (count == 0) return 'Нет оценок';
    int lastDigit = count % 10;
    int lastTwoDigits = count % 100;
    if (lastTwoDigits >= 11 && lastTwoDigits <= 19) return '$count оценок';
    if (lastDigit == 1) return '$count оценка';
    if (lastDigit >= 2 && lastDigit <= 4) return '$count оценки';
    return '$count оценок';
  }

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 && ModalRoute.of(context)?.settings.name != '/productList') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProductListScreen(),
          settings: RouteSettings(name: '/productList'),
        ),
      );
    } else if (index == 1 && ModalRoute.of(context)?.settings.name != '/cart') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(),
          settings: RouteSettings(name: '/cart'),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message,
      {Duration duration = const Duration(seconds: 3)}) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent.shade200,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.1,
              left: 16,
              right: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // --- ИСПРАВЛЕНО: Метод добавлен обратно в класс ---
  Color _getColorFromString(String colorString) {
    String lowerColor = colorString.toLowerCase().trim();
    switch (lowerColor) {
      case 'red':
      case 'красный':
        return Colors.red.shade400;
      case 'blue':
      case 'синий':
        return Colors.blue.shade400;
      case 'green':
      case 'зеленый':
        return Colors.green.shade400;
      case 'black':
      case 'черный':
        return Colors.black;
      case 'white':
      case 'белый':
        return Colors.white;
      case 'grey':
      case 'серый':
        return Colors.grey.shade600;
      case 'yellow':
      case 'желтый':
        return Colors.yellow.shade600;
      case 'orange':
      case 'оранжевый':
        return Colors.orange.shade400;
      case 'purple':
      case 'фиолетовый':
        return Colors.purple.shade400;
      case 'pink':
      case 'розовый':
        return Colors.pink.shade300;
      case 'beige':
      case 'бежевый':
        return Color(0xFFF5F5DC);
      default:
        if (lowerColor.startsWith('#') &&
            (lowerColor.length == 7 || lowerColor.length == 9)) {
          try {
            return Color(int.parse(lowerColor.substring(1), radix: 16) +
                (lowerColor.length == 7 ? 0xFF000000 : 0));
          } catch (e) {}
        }
        return Colors.grey.shade700;
    }
  }

  Widget _buildNetworkImage(String? imageUrl,
      {BoxFit fit = BoxFit.cover,
      double? width,
      double? height,
      BorderRadius? borderRadius,
      Widget? placeholder}) {
    final effectivePlaceholder = placeholder ??
        Container(
            width: width,
            height: height,
            color: ProductDetailScreen.lighterBg,
            child: Center(
                child: Icon(Icons.image_not_supported_outlined,
                    color: Colors.grey[600], size: 40)));
    if (imageUrl == null || imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: effectivePlaceholder);
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: ProductDetailScreen.lighterBg,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: ProductDetailScreen.primaryColor,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return effectivePlaceholder;
        },
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: _buildNetworkImage(imageUrl, fit: BoxFit.contain),
              ),
              Positioned(
                top: 15,
                right: 15,
                child: Material(
                  color: Colors.black.withOpacity(0.6),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 16.0 + 5.0, right: 16.0, bottom: 12.0, top: 10),
      child: Row(
        children: [
          Icon(icon,
              color: ProductDetailScreen.primaryColor.withOpacity(0.8),
              size: 20),
          SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0 + 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _productData!['name'] ?? 'Название товара',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold, height: 1.25),
          ),
          SizedBox(height: 14),
          _buildPriceSection(),
          SizedBox(height: 20),
          ExpandableText(_productData!['description'] ?? '',
              trimLines: 4,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.55),
              linkStyle: TextStyle(
                  fontSize: 15,
                  color: ProductDetailScreen.primaryColor,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    final price = _productData?['price'] as num?;
    final discount = _productData?['discount'] as num?;
    if (price == null) return SizedBox.shrink();
    final double originalPrice = price.toDouble();
    double currentPrice = originalPrice;
    bool hasDiscount = false;
    if (discount != null && discount > 0 && discount <= 100) {
      currentPrice = originalPrice * (1 - discount / 100.0);
      hasDiscount = true;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          formatPrice(currentPrice),
          style: TextStyle(
              fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        SizedBox(width: 10),
        if (hasDiscount)
          Text(
            formatPrice(originalPrice),
            style: TextStyle(
                fontSize: 17,
                color: Colors.grey[500],
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.lineThrough,
                decorationThickness: 1.5),
          ),
        SizedBox(width: 8),
        if (hasDiscount)
          Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: ProductDetailScreen.accentColor,
                  borderRadius: BorderRadius.circular(6)),
              child: Text("-$discount%",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildProductImageSection() {
    return GestureDetector(
      onTap: (_currentDisplayedImageUrl != null)
          ? () => _showFullScreenImage(_currentDisplayedImageUrl!)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Hero(
            tag: 'product_image_${widget.productId}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.0),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5))
                ],
              ),
              child: _buildNetworkImage(
                _currentDisplayedImageUrl,
                borderRadius: BorderRadius.circular(18.0),
                placeholder: Container(
                    color: ProductDetailScreen.lighterBg,
                    child: Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey[600], size: 60))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeSelector() {
    final availableSizes = _availableSizes;
    if (availableSizes.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Размер", Icons.straighten_rounded),
          Padding(
            padding: const EdgeInsets.only(left: 5.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: availableSizes.map((size) {
                final bool isSelected = _selectedSize == size;
                return ChoiceChip(
                  label: Text(size),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) _onSizeSelected(size);
                  },
                  selectedColor: ProductDetailScreen.primaryColor,
                  backgroundColor: ProductDetailScreen.lighterBg,
                  labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide.none),
                  side: isSelected
                      ? BorderSide(
                          color:
                              ProductDetailScreen.primaryColor.withOpacity(0.7),
                          width: 1.5)
                      : BorderSide(color: Colors.grey.shade800, width: 1),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: isSelected ? 2 : 0,
                  pressElevation: 4,
                  showCheckmark: false,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector() {
    if (_selectedSize == null) return SizedBox.shrink();
    final availableColors = _availableColorsPerSize[_selectedSize!] ?? [];
    if (availableColors.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Цвет", Icons.color_lens_outlined),
          Padding(
            padding: const EdgeInsets.only(left: 5.0),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              children: availableColors.map((color) {
                final bool isSelected = _selectedColor == color;
                final bool isInStock =
                    (_availableQuantities[_selectedSize!]?[color] ?? 0) > 0;
                String? colorImageUrl = _productColorImageUrls[color];
                Color displayColor = _getColorFromString(color);
                return GestureDetector(
                  onTap: () => _onColorSelected(color),
                  child: Tooltip(
                    message: color,
                    preferBelow: false,
                    verticalOffset: 25,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? ProductDetailScreen.primaryColor
                              : (isInStock
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade700),
                          width: isSelected ? 3.0 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: ProductDetailScreen.primaryColor
                                        .withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1)
                              ]
                            : [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 3,
                                    spreadRadius: 0)
                              ],
                      ),
                      child: CircleAvatar(
                        radius: 21,
                        backgroundColor: ProductDetailScreen.lighterBg,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            (colorImageUrl != null)
                                ? _buildNetworkImage(colorImageUrl,
                                    borderRadius: BorderRadius.circular(19),
                                    width: 38,
                                    height: 38)
                                : Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: displayColor,
                                        shape: BoxShape.circle)),
                            if (isSelected && isInStock)
                              CircleAvatar(
                                  radius: 10,
                                  backgroundColor:
                                      Colors.black.withOpacity(0.6),
                                  child: Icon(Icons.check,
                                      color: Colors.white, size: 14)),
                            if (!isInStock)
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    shape: BoxShape.circle),
                                child: Icon(Icons.close,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  IconData _getSeasonIcon(String season) {
    switch (season.toLowerCase()) {
      case "лето":
        return Icons.wb_sunny_rounded; // Иконка для лета
      case "зима":
        return Icons.ac_unit_rounded; // Иконка для зимы
      case "осень":
        return Icons.park_rounded; // Иконка для осени
      case "весна":
        return Icons.grass_rounded; // Иконка для весны
      default:
        return Icons.public_rounded; // Иконка для универсального сезона
    }
  }
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildProductDetailsSection() {
    final brand = _productData?['brand'] as String?;
    final material = _productData?['material'] as String?;
    final season = _productData?['season'] as String?;
    final weight = _productData?['weight'];
    final categoryId = _productData?['category_id'];
    final gender = _productData?['gender'];

    List<Widget> details = [];

    if (brand != null && brand.isNotEmpty) {
      details.add(_buildDetailRow(Icons.label_outline_rounded, "Бренд", brand));
    }
    if (material != null && material.isNotEmpty) {
      details.add(_buildDetailRow(Icons.texture_rounded, "Материал", material));
    }
    if (season != null && season.isNotEmpty) {
      details.add(_buildDetailRow(
          _getSeasonIcon(season), "Сезон", _capitalizeFirstLetter(season)));
    }
    if (weight != null && weight > 0) {
      details.add(_buildDetailRow(Icons.scale_outlined, "Вес", "$weight г"));
    }
    if (categoryId != null) {
      details.add(FutureBuilder<String?>(
        future: _getCategoryNameById(categoryId), // Получаем имя категории
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildDetailRow(Icons.category_outlined, "Категория", "Загрузка...");
          } else if (snapshot.hasError || !snapshot.hasData) {
            return _buildDetailRow(Icons.category_outlined, "Категория", "Ошибка");
          } else {
            return _buildDetailRow(Icons.category_outlined, "Категория", snapshot.data!);
          }
        },
      ));
    }
    if (gender != null) {
      details.add(_buildDetailRow(Icons.person_outline, "Пол", gender));
    }

    if (details.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Card(
          elevation: 0,
          color: ProductDetailScreen.lightBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            initiallyExpanded: false,
            iconColor: Colors.white70,
            collapsedIconColor: Colors.white70,
            trailing: Icon(Icons.keyboard_arrow_down_rounded),
            tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              "Характеристики",
              style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 16, top: 0),
                child: Column(
                    children: details
                        .map((e) => Column(children: [
                      e,
                      Divider(
                          color: Colors.grey.shade800,
                          height: 1,
                          thickness: 0.5)
                    ]))
                        .toList()
                      ..removeLast()),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание по верхнему краю
        children: [
          Icon(icon, color: Colors.white70, size: 20), // Иконка
          SizedBox(width: 14),
          Text(
            "$label:",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          Spacer(),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis, // Обрезка текста с "..."
              maxLines: 2, // Максимум 2 строки
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: reviewsCount > 0 ? _showReviewsBottomSheet : null,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: ProductDetailScreen.lightBg,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            children: [
              Icon(Icons.star_half_rounded,
                  color: Colors.yellow.shade700, size: 26),
              SizedBox(width: 10),
              Text(
                _hasReviews ? _averageRating.toStringAsFixed(1) : 'Нет оценок',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(width: 8),
              if (_hasReviews)
                Text(
                  '(${getReviewsText(reviewsCount)})',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              Spacer(),
              if (reviewsCount > 0)
                Text(
                  'Все отзывы ',
                  style: TextStyle(
                      fontSize: 15,
                      color: ProductDetailScreen.primaryColor,
                      fontWeight: FontWeight.w500),
                ),
              if (reviewsCount > 0)
                Icon(Icons.arrow_forward_ios_rounded,
                    color: ProductDetailScreen.primaryColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: ProductDetailScreen.lightBg,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Text(
              'Оставить отзыв',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 14),

            // Рейтинг
            Row(
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
                    padding: const EdgeInsets.all(5.0),
                    child: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.yellow.shade700,
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 18),

            // Поле ввода комментария
            Stack(
              children: [
                TextField(
                  controller: _commentController,
                  focusNode: _focusNode,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  textAlign: TextAlign.start,
                  decoration: InputDecoration(
                    hintText: 'Поделитесь вашим мнением...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: ProductDetailScreen.lighterBg,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 14.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(
                        color: ProductDetailScreen.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                // Кнопка "Прикрепить фото"
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: InkWell(
                    onTap: () async {
                      final images = await _pickImages();
                      if (!mounted) return;
                      setState(() => _selectedImages
                          .addAll(images.take(5 - _selectedImages.length)));
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined,
                            color: ProductDetailScreen.primaryColor, size: 24),
                        SizedBox(width: 4),
                        Text(
                          'Прикрепить фото',
                          style: TextStyle(
                            color: ProductDetailScreen.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Превью прикрепленных изображений
            if (_selectedImages.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _selectedImages.map((file) {
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -2,
                          right: -2,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedImages.remove(file)),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black.withOpacity(0.7),
                              child: Icon(Icons.close,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            if (_selectedImages.isNotEmpty) SizedBox(height: 16),

            // Кнопка отправки
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.send_rounded, size: 20),
                label: Text('Отправить'),
                onPressed: _addReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProductDetailScreen.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Прикрепить фото (до 5):',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._selectedImages.map((file) {
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        )),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: InkWell(
                          onTap: () =>
                              setState(() => _selectedImages.remove(file)),
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black.withOpacity(0.7),
                            child: Icon(Icons.close,
                                color: Colors.white, size: 12),
                          )),
                    )
                  ],
                );
              }).toList(),
              if (_selectedImages.length < 5)
                InkWell(
                  onTap: () async {
                    final images = await _pickImages();
                    if (!mounted) return;
                    setState(() => _selectedImages
                        .addAll(images.take(5 - _selectedImages.length)));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                        color: Colors.grey[800]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!, width: 1)),
                    child: Icon(Icons.add_a_photo_outlined,
                        color: Colors.white70, size: 28),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              left: 16.0 + 5.0, right: 16.0, top: 30.0, bottom: 16.0),
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
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(
                  child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                    color: ProductDetailScreen.primaryColor, strokeWidth: 2),
              ));
            if (snapshot.hasError)
              return Center(
                  child: Text('Ошибка загрузки',
                      style: TextStyle(color: Colors.grey)));
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return Center(
                  child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Нет похожих товаров.',
                    style: TextStyle(color: Colors.grey)),
              ));
            final similarProducts = snapshot.data!;
            return Container(
              height: 295,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: 16.0 + 5.0, right: 6.0),
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  final product = similarProducts[index];
                  final thumbnailUrl = product['thumbnail_url'] as String?;
                  return Container(
                    width: 170,
                    margin: EdgeInsets.only(right: 12.0),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: ProductDetailScreen.lighterBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      child: InkWell(
                        onTap: () {
                          final nextProductId =
                              product['product_id']?.toString();
                          if (nextProductId != null)
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                    productId: nextProductId),
                              ),
                            );
                          else
                            _showErrorSnackBar("Не удалось открыть товар.");
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag:
                                  'similar_product_image_${product['product_id']}',
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: _buildNetworkImage(thumbnailUrl,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12))),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? 'Без имени',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    formatPrice(product['price'] ?? 0),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0, vertical: 8.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final nextProductId =
                                        product['product_id']?.toString();
                                    if (nextProductId != null)
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ProductDetailScreen(
                                                  productId: nextProductId),
                                        ),
                                      );
                                    else
                                      _showErrorSnackBar(
                                          "Не удалось открыть товар.");
                                  },
                                  child: Text(
                                    'Подробнее',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ProductDetailScreen
                                        .primaryColor
                                        .withOpacity(0.15),
                                    foregroundColor:
                                        ProductDetailScreen.primaryColor,
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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

  void _showReviewsBottomSheet() {
    final currentProductId = _productData?['product_id']?.toString();
    if (currentProductId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: ProductDetailScreen.lightBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 10.0),
                    child: Text(
                      'Отзывы (${reviewsCount})',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  Divider(color: Colors.grey[800], height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('reviews')
                          .where('product_id', isEqualTo: currentProductId)
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white));
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Ошибка загрузки отзывов.',
                                  style: TextStyle(color: Colors.grey)));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text('Будьте первым, кто оставит отзыв!',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                              ));
                        }
                        final reviews = snapshot.data!.docs;
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: reviews.length,
                          padding:
                          EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 30.0),
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final reviewDoc = reviews[index];
                            final review =
                            reviewDoc.data() as Map<String, dynamic>;
                            final reviewId = reviewDoc.id;
                            final userId = review['user_id'];
                            final rating = review['rating'] ?? 0;
                            final comment = review['comment'] ?? '';
                            final timestamp =
                            review['created_at'] as Timestamp?;
                            final imageUrls =
                            List<String>.from(review['images'] ?? []);
                            final likes = review['likes'] ?? 0;
                            final likedBy =
                            List<String>.from(review['liked_by'] ?? []);
                            final verified =
                                review['verified_purchase'] ?? false;
                            final dateString = timestamp != null
                                ? '${timestamp.toDate().day.toString().padLeft(2, '0')}.${timestamp.toDate().month.toString().padLeft(2, '0')}.${timestamp.toDate().year}'
                                : '';
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            final bool isLikedByCurrentUser =
                                currentUser != null &&
                                    likedBy.contains(currentUser.uid);

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .get(),
                              builder: (context, userSnapshot) {
                                String username = 'Аноним';
                                if (userSnapshot.connectionState ==
                                    ConnectionState.done &&
                                    userSnapshot.hasData &&
                                    userSnapshot.data!.exists) {
                                  final userData = userSnapshot.data!.data()
                                  as Map<String, dynamic>;
                                  username = userData['username'] ?? 'Аноним';
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    color: ProductDetailScreen.lighterBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.shade800,
                                        width: 0.8),
                                  ),
                                  padding: EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // Строка с именем, датой, редактированием и удалением
                                      Row(
                                        children: [
                                          // Имя пользователя
                                          Text(
                                            username,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Spacer(),
                                          // Дата
                                          Text(
                                            dateString,
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12),
                                          ),
                                          // Редактирование и удаление
                                          if (currentUser != null &&
                                              currentUser.uid == userId)
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.edit,
                                                      color: Colors.grey,
                                                      size: 20),
                                                  onPressed: () {
                                                    _showEditReviewDialog(
                                                        context,
                                                        reviewId,
                                                        comment,
                                                        imageUrls);
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete,
                                                      color: Colors.redAccent,
                                                      size: 20),
                                                  onPressed: () {
                                                    _showDeleteReviewDialog(
                                                        context, reviewId);
                                                  },
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),

                                      // Пометка "Проверенная покупка" под строкой
                                      if (verified)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 4.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.verified_user_outlined,
                                                color: Colors.green.shade300,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Проверенная покупка',
                                                style: TextStyle(
                                                  color: Colors.green.shade300,
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      SizedBox(height: 8),

                                      // Рейтинг
                                      Row(
                                        children: List.generate(5,
                                                (starIndex) {
                                              return Icon(
                                                starIndex < rating
                                                    ? Icons.star_rounded
                                                    : Icons.star_outline_rounded,
                                                color: Colors.yellow.shade700,
                                                size: 18,
                                              );
                                            }),
                                      ),

                                      // Текст комментария
                                      if (comment.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 10),
                                          child: Text(
                                            comment,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.85),
                                              fontSize: 14.5,
                                              height: 1.45,
                                            ),
                                          ),
                                        ),

                                      // Превью изображений
                                      if (imageUrls.isNotEmpty)
                                        Padding(
                                          padding:
                                          const EdgeInsets.only(
                                              top: 12.0),
                                          child: SizedBox(
                                            height: 75,
                                            child: ListView.builder(
                                              scrollDirection:
                                              Axis.horizontal,
                                              itemCount:
                                              imageUrls.length,
                                              itemBuilder:
                                                  (ctx, imgIndex) {
                                                return Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 8.0),
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        _showFullScreenImage(
                                                            imageUrls[
                                                            imgIndex]),
                                                    child: Hero(
                                                      tag:
                                                      'review_image_${reviewId}_$imgIndex',
                                                      child:
                                                      _buildNetworkImage(
                                                        imageUrls[
                                                        imgIndex],
                                                        width: 75,
                                                        height: 75,
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                            8),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),

                                      SizedBox(height: 0),
                                      Row(
                                        children: [
                                          Spacer(),
                                          IconButton(
                                            onPressed: () =>
                                                _toggleLikeReview(
                                                    reviewId),
                                            icon: Icon(
                                              isLikedByCurrentUser
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isLikedByCurrentUser
                                                  ? Colors.redAccent
                                                  : Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '$likes',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
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
  void _showEditReviewDialog(BuildContext context, String reviewId, String currentComment, List<String> imageUrls) {
    final TextEditingController _editController = TextEditingController(text: currentComment);
    List<String> updatedImages = List.from(imageUrls); // Копируем текущие изображения
    bool isUploading = false; // Флаг для отображения загрузки

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Используем StatefulBuilder для управления состоянием в диалоге
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: ProductDetailScreen.lightBg,
              title: Text(
                'Редактировать комментарий',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _editController,
                      maxLines: 5,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Введите новый комментарий...',
                        hintStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: ProductDetailScreen.lighterBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(
                            color: ProductDetailScreen.primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Отображение текущих изображений с возможностью удаления
                        ...updatedImages.map((url) {
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              _buildNetworkImage(url,
                                  width: 70, height: 70, borderRadius: BorderRadius.circular(8)),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: InkWell(
                                  onTap: () {
                                    setState(() => updatedImages.remove(url)); // Удаляем изображение
                                  },
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black.withOpacity(0.7),
                                    child: Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        // Кнопка для добавления новых изображений
                        InkWell(
                          onTap: () async {
                            final images = await _pickImages(); // Выбор новых изображений
                            if (images.isNotEmpty) {
                              setState(() => isUploading = true); // Устанавливаем загрузку
                              for (var imageFile in images) {
                                String? imageUrl = await ImageKitService.uploadImage(imageFile); // Загрузка изображения
                                if (imageUrl != null) {
                                  setState(() => updatedImages.add(imageUrl)); // Добавляем новое изображение
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка загрузки изображения'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                              setState(() => isUploading = false); // Завершаем загрузку
                            }
                          },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[800]?.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[700]!, width: 1),
                            ),
                            child: isUploading
                                ? Center(
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2,
                              ),
                            )
                                : Icon(Icons.add_a_photo_outlined,
                                color: Colors.white70, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Отмена', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newComment = _editController.text.trim();
                    if (newComment.isNotEmpty) {
                      try {
                        // Обновляем Firestore
                        await FirebaseFirestore.instance
                            .collection('reviews')
                            .doc(reviewId)
                            .update({
                          'comment': newComment,
                          'images': updatedImages, // Сохраняем обновленные изображения
                        });
                        Navigator.of(context).pop(); // Закрываем диалог
                      } catch (e) {
                        print('Ошибка редактирования комментария: $e');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProductDetailScreen.primaryColor,
                  ),
                  child: Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct)
      return Scaffold(
        backgroundColor: ProductDetailScreen.darkBg,
        body: Center(
            child: CircularProgressIndicator(
                color: ProductDetailScreen.primaryColor)),
        appBar: AppBar(
            elevation: 0,
            backgroundColor: ProductDetailScreen.darkBg,
            leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop())),
      );
    if (_errorMessage != null)
      return Scaffold(
        backgroundColor: ProductDetailScreen.darkBg,
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Text(_errorMessage!, style: TextStyle(color: Colors.redAccent)),
        )),
        appBar: AppBar(
            elevation: 0,
            backgroundColor: ProductDetailScreen.darkBg,
            leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop())),
      );
    if (_productData == null)
      return Scaffold(
        backgroundColor: ProductDetailScreen.darkBg,
        body: Center(
            child:
                Text("Товар не найден", style: TextStyle(color: Colors.grey))),
        appBar: AppBar(
            elevation: 0,
            backgroundColor: ProductDetailScreen.darkBg,
            leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop())),
      );

    final bool canAddToCart = _selectedSize != null &&
        _selectedColor != null &&
        _getMaxQuantity() > 0;
    final double discountedPrice = _calculateDiscountedPrice();

    return Scaffold(
      backgroundColor: ProductDetailScreen.darkBg,
      appBar: AppBar(
        backgroundColor: ProductDetailScreen.darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
              onPressed: () {},
              icon: Icon(Icons.favorite_border_rounded, color: Colors.white))
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 130.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductImageSection(),
            SizedBox(height: 24),
            _buildProductHeader(),
            SizedBox(height: 28),
            _buildSizeSelector(),
            SizedBox(height: 24),
            _buildColorSelector(),
            SizedBox(height: 30),
            _buildProductDetailsSection(),
            SizedBox(height: 30),
            _buildRatingSummary(),
            SizedBox(height: 30),
            _buildReviewInputSection(),
            SizedBox(height: 15),
            _buildSimilarProductsSection(),
            SizedBox(height: 10),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 14.0,
          bottom: MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom + 8
              : 22.0,
        ),
        decoration: BoxDecoration(
          color: ProductDetailScreen.lightBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: Offset(0, -3),
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
                  'Итого:',
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 14, height: 1.0),
                ),
                SizedBox(height: 5),
                Text(
                  formatPrice(discountedPrice),
                  style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.0),
                ),
              ],
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.shopping_cart_checkout_rounded, size: 20),
                label: Text(
                  _selectedSize == null
                      ? 'Выберите размер'
                      : _selectedColor == null
                          ? 'Выберите цвет'
                          : !canAddToCart
                              ? 'Нет в наличии'
                              : 'В корзину',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                onPressed: canAddToCart ? _addToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProductDetailScreen.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade700,
                  disabledForegroundColor: Colors.grey.shade400,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
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
        selectedItemColor: ProductDetailScreen.primaryColor,
        unselectedItemColor: Colors.grey[400],
        backgroundColor: ProductDetailScreen.lightBg,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: onItemTapped,
      ),
    );
  }
}

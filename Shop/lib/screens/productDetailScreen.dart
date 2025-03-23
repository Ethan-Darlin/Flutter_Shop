import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails(); // Обновляем данные о продукте при загрузке экрана
  }

  // Метод для получения актуальных данных о продукте
  Future<void> _fetchProductDetails() async {
    final productQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('product_id', isEqualTo: widget.product['product_id'])
        .get();

    if (productQuery.docs.isNotEmpty) {
      final productData = productQuery.docs.first.data() as Map<String, dynamic>;
      setState(() {
        widget.product['size_stock'] = productData['size_stock']; // Обновляем остатки
        _selectedSize = null; // Сброс выбора размера
        _quantity = 1; // Сбрасываем количество
      });
    }
  }

  // Метод для добавления отзыва
  Future<void> _addReview() async {
    final user = FirebaseAuth.instance.currentUser; // Получаем текущего пользователя
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы должны быть авторизованы для добавления отзыва.')),
      );
      return;
    }

    // Сохраняем отзыв в Firestore
    await FirebaseFirestore.instance.collection('reviews').add({
      'product_id': widget.product['product_id'], // ID продукта
      'user_id': user.uid, // ID текущего пользователя
      'rating': _rating, // Рейтинг
      'comment': _commentController.text, // Текст комментария
      'created_at': FieldValue.serverTimestamp(), // Время создания
    });

    // Очистка поля комментария
    _commentController.clear();
    setState(() {}); // Обновление экрана
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.product['image_url'];
    Uint8List? imageBytes;

    // Декодирование изображения из base64
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
      appBar: AppBar(
        title: Text(widget.product['name']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Отображение изображения товара
            if (imageBytes != null)
              Image.memory(
                imageBytes,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            SizedBox(height: 16),

            // Название товара
            Text(
              widget.product['name'],
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            // Цена товара
            Text(
              'Цена: ${widget.product['price']}',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
            SizedBox(height: 16),

            // Описание товара
            Text(
              'Описание:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              widget.product['description'],
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),

            // Размеры и остатки
            Text(
              'Размеры и остатки:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedSize,
              hint: Text('Выберите размер'),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedSize = newValue;
                });
              },
              items: widget.product['size_stock'].entries.map<DropdownMenuItem<String>>((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text('Размер: ${entry.key}, Остаток: ${entry.value}'),
                );
              }).toList(),
            ),
            SizedBox(height: 16),

            // Количество
            Text(
              'Количество:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_quantity > 1) {
                      setState(() {
                        _quantity--;
                      });
                    }
                  },
                ),
                Text('$_quantity'),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    if (_selectedSize != null && _quantity < (widget.product['size_stock'][_selectedSize] ?? 0)) {
                      setState(() {
                        _quantity++;
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 16),

            // Кнопка для добавления в корзину
            ElevatedButton(
              onPressed: _selectedSize != null ? () async {
                await _firebaseService.addToCart({
                  ...widget.product,
                  'selected_size': _selectedSize,
                  'quantity': _quantity,
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Товар добавлен в корзину'),
                ));
              } : null,
              child: Text('Добавить в корзину'),
            ),

            SizedBox(height: 16),

            // Заголовок для отзывов
            Text(
              'Отзывы:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            // Контейнер для отзывов с фиксированной высотой
            SizedBox(
              height: 200, // Укажите подходящую высоту
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('product_id', isEqualTo: widget.product['product_id']) // Фильтрация по ID продукта
                    .orderBy('created_at', descending: true) // Сортировка по времени
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print('No reviews found for product ID: ${widget.product['product_id']}');
                    return Center(child: Text('Отзывов пока нет.'));
                  }

                  final reviews = snapshot.data!.docs;
                  print('Reviews found: ${reviews.length}');

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: AlwaysScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index].data() as Map<String, dynamic>;
                      print('Review: $review');
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text('Рейтинг: ${review['rating']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(review['comment']),
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
              ),
            ),

            SizedBox(height: 16),

            // Заголовок для добавления отзыва
            Text(
              'Добавить отзыв:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            // Выбор рейтинга
            DropdownButton<int>(
              value: _rating,
              onChanged: (value) {
                setState(() {
                  _rating = value!;
                });
              },
              items: List.generate(5, (index) => index + 1)
                  .map((value) => DropdownMenuItem<int>(
                value: value,
                child: Text('$value звезда${value > 1 ? 'ы' : ''}'),
              ))
                  .toList(),
            ),

            // Поле для комментария
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Ваш комментарий',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),

            // Кнопка для добавления отзыва
            ElevatedButton(
              onPressed: _addReview,
              child: Text('Добавить отзыв'),
            ),
          ],
        ),
      ),
    );
  }
}
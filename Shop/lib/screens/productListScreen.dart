import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'dart:convert'; // Для декодирования Base64
import 'dart:typed_data'; // Для работы с Uint8List
class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = FirebaseService().getProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Продукты'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/add-product'); // Переход на экран добавления продукта
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

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final imageUrl = product['image_url']; // Получаем Base64 строку

              Uint8List? imageBytes;

              if (imageUrl != null) {
                // Пробуем декодировать изображение
                try {
                  // Удаляем лишние пробелы и проверяем, является ли строка корректной
                  String cleanedImageUrl = imageUrl.trim();
                  imageBytes = base64Decode(cleanedImageUrl);
                } catch (e) {
                  print('Ошибка декодирования изображения: $e');
                  imageBytes = null; // Или вы можете установить значение по умолчанию
                }
              }

              return ListTile(
                title: Text(product['name']),
                subtitle: Text('Описание: ${product['description']}'),
                trailing: Text('Цена: ${product['price']}'),
                leading: imageBytes != null
                    ? Image.memory(
                  imageBytes,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover, // Обрезаем изображение по размеру
                )
                    : null, // Если изображение отсутствует, не показываем его
              );
            },
          );
        },
      ),
    );
  }
}
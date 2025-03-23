import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shop/firebase_service.dart';
import 'dart:convert'; // Для кодирования и декодирования Base64

class AddProductScreen extends StatefulWidget {
  final String creatorId; // Добавляем creatorId для передачи идентификатора пользователя

  AddProductScreen({required this.creatorId}); // Изменяем конструктор

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  String _imageUrl = '';
  double _price = 0.0;
  int _selectedCategoryId = -1; // Идентификатор выбранной категории
  XFile? _imageFile; // Для хранения выбранного изображения
  int _newProductId = 0; // Для хранения нового product_id
  List<Map<String, dynamic>> _categories = []; // Список категорий
  List<Map<String, dynamic>> _sizeStock = []; // Список размеров и остатков

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // Получаем категории при инициализации
  }

  Future<void> _fetchCategories() async {
    QuerySnapshot snapshot = await FirebaseService().firestore.collection('categories').get();
    setState(() {
      _categories = snapshot.docs.map((doc) {
        return {
          'id': doc['category_id'],
          'name': doc['name'],
        };
      }).toList();
    });
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
          _imageUrl = pickedFile.path; // Сохраняем путь к изображению
        });
      }
    } catch (e) {
      print('Ошибка при выборе изображения: $e');
    }
  }

  Future<void> _generateNewProductId() async {
    QuerySnapshot snapshot = await FirebaseService().firestore.collection('products').get();
    if (snapshot.docs.isNotEmpty) {
      List<int> productIds = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return data['product_id'] as int; // Получаем product_id из данных документа
      }).toList();
      _newProductId = (productIds.isNotEmpty ? productIds.reduce((a, b) => a > b ? a : b) : 0) + 1;
    } else {
      _newProductId = 1; // Если нет продуктов, начинаем с 1
    }
  }

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedCategoryId == -1) {
        // Проверяем, выбрана ли категория
        print('Ошибка: категория не выбрана!');
        return;
      }

      if (_imageFile == null) {
        print('Ошибка: изображение не выбрано!');
        return;
      }

      // Чтение файла изображения и кодирование в Base64
      final bytes = await File(_imageFile!.path).readAsBytes();
      String base64Image = base64Encode(bytes);

      // Генерация нового product_id
      await _generateNewProductId();

      // Преобразование _sizeStock в объект для Firestore
      Map<String, int> sizeStockMap = {};
      for (var sizeItem in _sizeStock) {
        if (sizeItem['size'] != null && sizeItem['stock'] != null) {
          sizeStockMap[sizeItem['size'].toString()] = sizeItem['stock'];
        }
      }

      // Проверка: size_stock не должен быть пустым
      if (sizeStockMap.isEmpty) {
        print('Ошибка: добавьте хотя бы один размер с количеством!');
        return;
      }

      // Добавление продукта в Firestore
      await FirebaseService().firestore.collection('products').add({
        'product_id': _newProductId, // Сохраняем product_id
        'name': _name,
        'description': _description,
        'image_url': base64Image, // Сохраняем изображение в формате Base64
        'price': _price,
        'category_id': _selectedCategoryId, // Сохраняем category_id
        'creator_id': widget.creatorId, // Сохраняем creator_id
        'created_at': FieldValue.serverTimestamp(), // Временная метка создания
        'size_stock': sizeStockMap, // Сохраняем размеры и их остатки
      });

      Navigator.pop(context); // Возвращаемся на предыдущую страницу
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Добавить продукт')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'Название'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите название продукта';
                    }
                    return null;
                  },
                  onSaved: (value) => _name = value!,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Описание'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите описание продукта';
                    }
                    return null;
                  },
                  onSaved: (value) => _description = value!,
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: _pickImage,
                  child: Text('Выбрать изображение'),
                ),
                if (_imageFile != null)
                  Image.file(File(_imageFile!.path), height: 100), // Отображаем выбранное изображение
                TextFormField(
                  decoration: InputDecoration(labelText: 'Цена'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите цену продукта';
                    }
                    return null;
                  },
                  onSaved: (value) => _price = double.parse(value!),
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId == -1 ? null : _selectedCategoryId,
                  decoration: InputDecoration(labelText: 'Выберите категорию'),
                  items: _categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category['id'],
                      child: Text(category['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value!;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Выберите категорию';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Добавить размеры и остатки',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _sizeStock.length,
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(labelText: 'Размер'),
                                initialValue: _sizeStock[index]['size']?.toString() ?? '',
                                keyboardType: TextInputType.text,
                                onChanged: (value) {
                                  setState(() {
                                    _sizeStock[index]['size'] = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(labelText: 'Количество'),
                                initialValue: _sizeStock[index]['stock']?.toString() ?? '',
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _sizeStock[index]['stock'] = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  _sizeStock.removeAt(index);
                                });
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _sizeStock.add({'size': null, 'stock': null});
                        });
                      },
                      child: Text('Добавить размер'),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addProduct,
                  child: Text('Добавить продукт'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shop/firebase_service.dart';
import 'dart:convert'; // Для кодирования и декодирования Base64
import 'dart:typed_data'; // Для работы с Uint8List

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  String _imageUrl = '';
  double _price = 0.0;
  int _stockQuantity = 0;
  XFile? _imageFile; // Для хранения выбранного изображения

  final ImagePicker _picker = ImagePicker();

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

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Чтение файла изображения и кодирование в Base64
      final bytes = await File(_imageFile!.path).readAsBytes();
      String base64Image = base64Encode(bytes);

      await FirebaseService().firestore.collection('products').add({
        'name': _name,
        'description': _description,
        'image_url': base64Image, // Сохраняем изображение в формате Base64
        'price': _price,
        'stock_quantity': _stockQuantity,
        'created_at': FieldValue.serverTimestamp(),
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
              TextFormField(
                decoration: InputDecoration(labelText: 'Количество на складе'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите количество на складе';
                  }
                  return null;
                },
                onSaved: (value) => _stockQuantity = int.parse(value!),
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
    );
  }
}
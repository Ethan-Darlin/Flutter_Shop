import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCategoryScreen extends StatefulWidget {
  @override
  _AddCategoryScreenState createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  String _categoryName = '';
  int _newCategoryId = 1; // Начальное значение для category_id

  @override
  void initState() {
    super.initState();
    _fetchNewCategoryId(); // Получаем новый category_id при инициализации
  }

  Future<void> _fetchNewCategoryId() async {
    QuerySnapshot snapshot = await FirebaseService().firestore.collection('categories').get();
    if (snapshot.docs.isNotEmpty) {
      List<int> categoryIds = snapshot.docs.map((doc) {
        return doc['category_id'] as int; // Получаем category_id из данных документа
      }).toList();
      _newCategoryId = (categoryIds.isNotEmpty ? categoryIds.reduce((a, b) => a > b ? a : b) : 0) + 1;
    }
  }

  Future<void> _addCategory() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Добавление категории в Firestore
      await FirebaseService().firestore.collection('categories').add({
        'category_id': _newCategoryId, // Используем новый category_id
        'name': _categoryName,
      });

      // Возвращаемся на предыдущий экран
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Добавить категорию')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Название категории'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите название категории';
                  }
                  return null;
                },
                onSaved: (value) => _categoryName = value!,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addCategory,
                child: Text('Добавить категорию'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
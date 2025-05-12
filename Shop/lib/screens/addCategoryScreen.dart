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
  int _newCategoryId = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchNewCategoryId();
  }

  Future<void> _fetchNewCategoryId() async {
    QuerySnapshot snapshot = await FirebaseService().firestore.collection('categories').get();
    if (snapshot.docs.isNotEmpty) {
      List<int> categoryIds = snapshot.docs.map((doc) {
        return doc['category_id'] as int;
      }).toList();
      setState(() {
        _newCategoryId = (categoryIds.isNotEmpty ? categoryIds.reduce((a, b) => a > b ? a : b) : 0) + 1;
      });
    }
  }

  Future<void> _addCategory() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      await FirebaseService().firestore.collection('categories').add({
        'category_id': _newCategoryId,
        'name': _categoryName,
      });

      setState(() => _isLoading = false);

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18171c),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18171c),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Добавить категорию',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), 
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 24),
                    Text(
                      'Введите название новой категории:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 18),
                    TextFormField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Название категории',
                        labelStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Color(0xFF232129),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFFEE3A57), width: 2),
                        ),
                        errorStyle: TextStyle(color: Color(0xFFEE3A57)),
                      ),
                      cursorColor: Color(0xFFEE3A57),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите название категории';
                        }
                        return null;
                      },
                      onSaved: (value) => _categoryName = value!.trim(),
                    ),
                    SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEE3A57),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : Text('Добавить категорию'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
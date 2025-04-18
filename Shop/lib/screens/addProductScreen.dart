import 'dart:io';
import 'dart:convert'; // Нужен для jsonDecode и base64Encode
import 'package:http/http.dart' as http; // <--- Используем http
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shop/firebase_service.dart'; // Убедись, что путь правильный

// --- Измененная структура ProductColor ---
class ProductColor {
  String name;
  XFile? imageFile; // Файл для превью и ИСТОЧНИК для загрузки
  String? imageUrl; // СЮДА будем сохранять URL из ImageKit

  ProductColor({
    this.name = '',
    this.imageFile,
    this.imageUrl,
  });

  // Хелпер для проверки валидности (имя не пустое)
  bool get isValid => name.trim().isNotEmpty;
  // Хелпер для проверки, есть ли ФАЙЛ для ЗАГРУЗКИ
  bool get hasImageForUpload => imageFile != null;
  // Хелпер для проверки, есть ли готовый URL для показа (после загрузки)
  bool get hasImageDisplay => (imageUrl != null && imageUrl!.isNotEmpty);
}

// Представляет количество конкретного цвета для конкретного размера
class SizeColorQuantity {
  String colorName; // Имя цвета, ссылается на ProductColor.name
  int quantity;

  SizeColorQuantity({required this.colorName, this.quantity = 0});
}

// Представляет размер и наличие цветов для него
class SizeVariant {
  String size;
  List<SizeColorQuantity> colorQuantities;

  SizeVariant({this.size = '', this.colorQuantities = const []});

  // Хелпер для проверки валидности (размер не пустой)
  bool get isValid => size.trim().isNotEmpty;
}
// --- Конец структур данных ---

class AddProductScreen extends StatefulWidget {
  final String creatorId;

  AddProductScreen({required this.creatorId, Key? key}) : super(key: key);

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  double _price = 0.0;
  int _selectedCategoryId = -1;
  XFile? _mainImageFile; // Основное изображение (файл)
  int _newProductId = 0;
  List<Map<String, dynamic>> _categories = [];
  //
  String _brand = '';
  String _material = '';
  int _popularityScore = 0;
  int _discount = 0;
  double _weight = 0.0;
  String _season = '';

  List<ProductColor> _productColors = []; // Список определенных цветов для продукта
  List<SizeVariant> _sizeVariants = [];   // Список размеров продукта

  String? _selectedGender;
  final List<String> _genderOptions = const ['Мужской', 'Женский', 'Унисекс'];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // --- Конфигурация ImageKit ---
  // !!! ЗАМЕНИ НА СВОИ РЕАЛЬНЫЕ ДАННЫЕ из ImageKit Dashboard !!!
  // !!! ПРЕДУПРЕЖДЕНИЕ: НЕ ХРАНИ privateKey В КЛИЕНТСКОМ КОДЕ В ПРОДАКШЕНЕ !!!
  static const String _imageKitPublicKey = 'public_0EblotM8xHzpWNJUXWiVtRnHbGA='; // <--- ТВОЙ Public Key
  static const String _imageKitPrivateKey = 'private_ZKL7E/ailo8o7MHqrvHIpxQRIiE='; // <--- ТВОЙ Private Key (ОПАСНО!)
  static const String _imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';


  @override
  void initState() {
    super.initState();
    _fetchCategories();
    // _addProductColor(); // Раскомментируй, если нужно начинать с пустого цвета
    // _addSizeEntry();   // Раскомментируй, если нужно начинать с пустого размера
  }

  // _fetchCategories остается без изменений
  Future<void> _fetchCategories() async {
    try {
      QuerySnapshot snapshot = await FirebaseService().firestore.collection('categories').get();
      if (mounted) {
        setState(() {
          _categories = snapshot.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return {
              'id': data['category_id'] as int,
              'name': data['name'] as String,
            };
          }).toList();
          _categories.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        });
      }
    } catch (e) {
      print("Ошибка получения категорий: $e");
      _showErrorSnackBar('Не удалось загрузить категории: $e');
    }
  }

  // _pickMainImage остается без изменений
  Future<void> _pickMainImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null && mounted) {
        setState(() {
          _mainImageFile = pickedFile;
        });
      }
    } catch (e) {
      print('Ошибка при выборе основного изображения: $e');
      _showErrorSnackBar('Ошибка выбора изображения: $e');
    }
  }

  // --- Методы для управления ProductColor ---
  void _addProductColor() {
    if (mounted) {
      setState(() {
        _productColors.add(ProductColor());
      });
    }
  }

  void _removeProductColor(int index) {
    if (mounted) {
      String removedColorName = _productColors[index].name.trim();
      setState(() {
        _productColors.removeAt(index);
        for (var sizeVariant in _sizeVariants) {
          sizeVariant.colorQuantities.removeWhere((cq) => cq.colorName == removedColorName);
        }
      });
      setState(() {}); // Обновить UI
    }
  }

  // Выбирает изображение для ProductColor, сбрасывает старый URL
  Future<void> _pickProductColorImage(int colorIndex) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null && mounted) {
        setState(() {
          _productColors[colorIndex].imageFile = pickedFile;
          _productColors[colorIndex].imageUrl = null; // Сбрасываем URL, т.к. файл новый
        });
      }
    } catch (e) {
      print('Ошибка при выборе изображения цвета: $e');
      _showErrorSnackBar('Ошибка выбора изображения цвета: $e');
    }
  }

  // --- Методы для управления SizeVariant ---
  void _addSizeEntry() {
    if (mounted) {
      setState(() {
        _sizeVariants.add(SizeVariant(size: '', colorQuantities: []));
      });
    }
  }

  void _removeSizeEntry(int index) {
    if (mounted) {
      setState(() {
        _sizeVariants.removeAt(index);
      });
    }
  }

  void _addColorQuantityToSize(int sizeIndex) {
    if (mounted) {
      List<String> availableColorNames = _getAvailableColorsForSize(sizeIndex);
      if (availableColorNames.isEmpty) {
        _showErrorSnackBar('Все определенные цвета уже добавлены к этому размеру или нет определенных цветов.');
        return;
      }
      setState(() {
        _sizeVariants[sizeIndex].colorQuantities.add(
            SizeColorQuantity(colorName: availableColorNames.first, quantity: 0)
        );
      });
    }
  }

  void _removeColorQuantityFromSize(int sizeIndex, int colorQuantityIndex) {
    if (mounted) {
      setState(() {
        _sizeVariants[sizeIndex].colorQuantities.removeAt(colorQuantityIndex);
      });
    }
  }

  List<String> _getAvailableColorsForSize(int sizeIndex) {
    final definedColors = _productColors
        .where((pc) => pc.isValid)
        .map((pc) => pc.name.trim())
        .toSet();
    final colorsInThisSize = _sizeVariants[sizeIndex]
        .colorQuantities
        .map((cq) => cq.colorName)
        .toSet();
    return definedColors.difference(colorsInThisSize).toList()..sort();
  }

  // _generateNewProductId остается без изменений
  Future<void> _generateNewProductId() async {
    try {
      QuerySnapshot snapshot = await FirebaseService().firestore.collection('products')
          .orderBy('product_id', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data() as Map<String, dynamic>?;
        int lastId = data?['product_id'] as int? ?? 0;
        _newProductId = lastId + 1;
      } else { _newProductId = 1; }
      if (_newProductId <= 0) throw Exception("Не удалось сгенерировать корректный ID продукта.");
    } catch (e) {
      print("Ошибка генерации ID продукта: $e");
      _newProductId = 0;
      _showErrorSnackBar('Ошибка генерации ID продукта: $e');
      throw e;
    }
  }

  // --- Новая функция для загрузки изображения в ImageKit ---
  Future<String?> _uploadImageToImageKit(XFile imageFile) async {
    // Настройка запроса для загрузки в ImageKit
    var request = http.MultipartRequest('POST', Uri.parse(_imageKitUploadUrl));
    String credentials = base64Encode(utf8.encode('$_imageKitPrivateKey:'));
    request.headers['Authorization'] = 'Basic $credentials';
    request.fields['publicKey'] = _imageKitPublicKey;
    request.fields['fileName'] = imageFile.name;
    request.fields['useUniqueFileName'] = 'true';
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        return responseData['url']; // Возвращаем URL
      } else {
        print('Ошибка загрузки в ImageKit: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Ошибка при загрузке: $e');
      return null;
    }
  }

  // --- Основная функция добавления продукта ---
  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Некоторые поля заполнены некорректно.');
      return;
    }
    _formKey.currentState!.save();
    // Валидация формы и других данных остается без изменений...
    print('Final product data:');
    print('name: $_name');
    print('description: $_description');
    print('price: $_price');
    print('category_id: $_selectedCategoryId');
    print('gender: $_selectedGender');
    print('brand: $_brand');
    print('material: $_material');
    print('popularity_score: $_popularityScore');
    print('discount: $_discount');
    print('weight: $_weight');
    print('season: $_season');

    // Начало процесса сохранения
    if (mounted) setState(() => _isLoading = true);

    String? mainImageUrl;
    Map<String, String?> colorImageUrlsForFirestore = {};
    Map<String, dynamic> sizesDataForFirestore = {};

    try {
      // Генерация нового ID продукта
      await _generateNewProductId();

      // Загрузка основного изображения
      mainImageUrl = await _uploadImageToImageKit(_mainImageFile!);
      if (mainImageUrl == null) throw Exception("Не удалось загрузить основное изображение.");

      // Загрузка изображений цветов
      for (var color in _productColors.where((c) => c.isValid && c.hasImageForUpload)) {
        String? uploadedUrl = await _uploadImageToImageKit(color.imageFile!);
        if (uploadedUrl != null) {
          color.imageUrl = uploadedUrl; // Сохраняем URL в объекте
          colorImageUrlsForFirestore[color.name.trim()] = uploadedUrl; // Добавляем в карту для Firestore
        }
      }

      // Подготовка данных размеров
      for (var sizeVariant in _sizeVariants.where((s) => s.isValid)) {
        String currentSize = sizeVariant.size.trim();
        Map<String, int> colorQuantitiesForFirestore = {};
        for (var cq in sizeVariant.colorQuantities) {
          if (cq.quantity > 0 && colorImageUrlsForFirestore.containsKey(cq.colorName)) {
            colorQuantitiesForFirestore[cq.colorName] = cq.quantity;
          }
        }
        if (colorQuantitiesForFirestore.isNotEmpty) {
          sizesDataForFirestore[currentSize] = {'color_quantities': colorQuantitiesForFirestore};
        }
      }

// Добавление документа продукта в Firestore
      DocumentReference docRef = await FirebaseService().firestore.collection('products').add({
        'product_id': _newProductId,
        'name': _name,
        'description': _description,
        'price': _price,
        'category_id': _selectedCategoryId,
        'gender': _selectedGender,
        'creator_id': widget.creatorId,
        'created_at': FieldValue.serverTimestamp(),
        'main_image_url': mainImageUrl,
        'colors': colorImageUrlsForFirestore,
        'sizes': sizesDataForFirestore,
        'brand': _brand,
        'material': _material,
        'popularity_score': _popularityScore,
        'discount': _discount,
        'weight': _weight,
        'season': _season,
      });

      // Успешное завершение
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Продукт успешно добавлен!'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      print('Критическая ошибка при добавлении продукта: $e');
      _showErrorSnackBar('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // _showErrorSnackBar остается без изменений
  void _showErrorSnackBar(String message, {int durationSeconds = 4}) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: durationSeconds),
        ),
      );
    }
  }


  // --- МЕТОД build() ---
  @override
  Widget build(BuildContext context) {
    // Получаем список имен ВАЛИДНЫХ цветов (с именем) для использования в Dropdown'ах размеров
    final validColorNames = _productColors
        .where((c) => c.isValid)
        .map((c) => c.name.trim())
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Добавить продукт')),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Основные поля товара ---
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Название'),
                        validator: (value) => (value == null || value.isEmpty) ? 'Введите название' : null,
                        onSaved: (value) => _name = value!,
                      ),
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Описание'),
                        maxLines: 3,
                        validator: (value) => (value == null || value.isEmpty) ? 'Введите описание' : null,
                        onSaved: (value) => _description = value!,
                      ),
                      // Поле для бренда
                      TextFormField(
                          decoration: InputDecoration(labelText: 'Бренд'),
                        maxLength: 50, // Ограничение на количество символов
                        validator: (value) => (value == null || value.isEmpty) ? 'Введите бренд' : null,
                        onSaved: (value) => _brand = value!.trim(), // Сохраняем значение, удаляя лишние пробелы
                      ),

                      TextFormField(
                        decoration: InputDecoration(labelText: 'Материал'),
                        validator: (value) => (value == null || value.isEmpty) ? 'Введите материал' : null,
                        onSaved: (value) => _material = value!,
                      ),

// Поле для рейтинга популярности
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Рейтинг популярности'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите рейтинг';
                          final score = int.tryParse(value);
                          if (score == null || score < 0 || score > 100) return 'Рейтинг должен быть от 0 до 100';
                          return null;
                        },
                        onSaved: (value) => _popularityScore = int.parse(value!),
                      ),

// Поле для скидки
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Скидка (%)'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите скидку';
                          final discount = int.tryParse(value);
                          if (discount == null || discount < 0 || discount > 100) return 'Скидка должна быть от 0 до 100';
                          return null;
                        },
                        onSaved: (value) => _discount = int.parse(value!),
                      ),

// Поле для веса
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Вес (в кг)'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите вес';
                          final weight = double.tryParse(value.replaceAll(',', '.'));
                          if (weight == null || weight <= 0) return 'Вес должен быть положительным числом';
                          return null;
                        },
                        onSaved: (value) => _weight = double.parse(value!.replaceAll(',', '.')),
                      ),

// Поле для сезона
                      DropdownButtonFormField<String>(
                        value: _season.isEmpty ? null : _season,
                        decoration: InputDecoration(labelText: 'Сезон'),
                        items: ['Зима', 'Лето', 'Осень', 'Весна']
                            .map((season) => DropdownMenuItem<String>(value: season, child: Text(season)))
                            .toList(),
                        onChanged: (value) => _season = value ?? '',
                        validator: (value) => (value == null || value.isEmpty) ? 'Выберите сезон' : null,
                      ),
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Цена'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите цену';
                          final price = double.tryParse(value.replaceAll(',', '.'));
                          if (price == null) return 'Некорректная цена';
                          if (price <= 0) return 'Цена должна быть > 0';
                          return null;
                        },
                        onSaved: (value) => _price = double.parse(value!.replaceAll(',', '.')),
                      ),
                      SizedBox(height: 20),

                      // --- Основное изображение ---
                      Text("Основное изображение*", style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(Icons.image),
                            label: Text('Выбрать'),
                            onPressed: _pickMainImage,
                          ),
                          SizedBox(width: 10),
                          if (_mainImageFile != null)
                            Image.file(File(_mainImageFile!.path), height: 60, width: 60, fit: BoxFit.cover),
                        ],
                      ),
                      SizedBox(height: 20),

                      // --- Категория и Пол ---
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId == -1 ? null : _selectedCategoryId,
                        decoration: InputDecoration(labelText: 'Категория*'),
                        items: _categories.map((category) {
                          return DropdownMenuItem<int>( value: category['id'], child: Text(category['name']), );
                        }).toList(),
                        onChanged: (value) { if (value != null) setState(() => _selectedCategoryId = value); },
                        validator: (value) => (value == null) ? 'Выберите категорию' : null,
                      ),
                      SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(labelText: 'Пол*'),
                        items: _genderOptions.map((String gender) { return DropdownMenuItem<String>( value: gender, child: Text(gender), ); }).toList(),
                        onChanged: (value) { if (value != null) setState(() => _selectedGender = value); },
                        validator: (value) => (value == null) ? 'Выберите пол' : null,
                      ),
                      SizedBox(height: 20),

                      Divider(height: 30),

                      // --- Секция Определения Цветов Продукта ---
                      Text("Цвета продукта*", style: Theme.of(context).textTheme.titleLarge),
                      Text("Добавьте цвета, доступные для этого товара, и их изображения.", style: Theme.of(context).textTheme.bodySmall),
                      SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _productColors.length,
                        itemBuilder: (context, colorIndex) {
                          var color = _productColors[colorIndex];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 6.0),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: color.name,
                                      decoration: InputDecoration(labelText: 'Название цвета*', isDense: true),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Нужно имя';
                                        String currentInputName = value.trim().toLowerCase();
                                        bool isDuplicate = _productColors.any((pc) {
                                          return pc != color && pc.isValid && pc.name.trim().toLowerCase() == currentInputName;
                                        });
                                        if (isDuplicate) {
                                          return 'Имя не уникально';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          color.name = value;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Tooltip(
                                    message: 'Выбрать изображение для цвета "${color.name.isNotEmpty ? color.name : 'Новый цвет'}"',
                                    child: IconButton(
                                      icon: Icon(color.hasImageForUpload ? Icons.image_search : Icons.add_photo_alternate_outlined, size: 28),
                                      onPressed: () => _pickProductColorImage(colorIndex),
                                      color: color.hasImageForUpload ? Theme.of(context).primaryColor : null,
                                    ),
                                  ),
                                  // Превью загруженного изображения
                                  if (color.hasImageDisplay)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Image.network(color.imageUrl!, height: 28, width: 28, fit: BoxFit.cover),
                                    ),
                                  // Кнопка удаления цвета
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, size: 20),
                                    color: Colors.redAccent,
                                    tooltip: 'Удалить этот цвет',
                                    onPressed: () => _removeProductColor(colorIndex),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 5),
                      // Кнопка "Добавить цвет"
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: Icon(Icons.add_circle_outline, size: 18),
                          label: Text('Добавить цвет'),
                          onPressed: _addProductColor,
                        ),
                      ),
                      Divider(height: 30),

                      // --- Секция Определения Размеров и Количества ---
                      Text("Размеры и Наличие*", style: Theme.of(context).textTheme.titleLarge),
                      Text("Укажите размеры и количество каждого цвета для этого размера.", style: Theme.of(context).textTheme.bodySmall),
                      SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _sizeVariants.length,
                        itemBuilder: (context, sizeIndex) {
                          var sizeVariant = _sizeVariants[sizeIndex];
                          // Доступные цвета для ДОБАВЛЕНИЯ к этому размеру (те, что определены, но еще не в этом размере)
                          List<String> availableColorsToAdd = _getAvailableColorsForSize(sizeIndex);

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Ввод имени размера
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: sizeVariant.size,
                                          decoration: InputDecoration(labelText: 'Размер* (напр. 46, M, L)'),
                                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Нужен размер' : null,
                                          onChanged: (value) => sizeVariant.size = value,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: 'Удалить этот размер',
                                        onPressed: () => _removeSizeEntry(sizeIndex),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 15),
                                  Text("Наличие цветов для этого размера:", style: Theme.of(context).textTheme.titleMedium),
                                  SizedBox(height: 5),

                                  // Список "цвет-количество" для текущего размера
                                  if (sizeVariant.colorQuantities.isNotEmpty)
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: sizeVariant.colorQuantities.length,
                                      itemBuilder: (context, cqIndex) {
                                        var colorQuantity = sizeVariant.colorQuantities[cqIndex];

                                        // Опции для Dropdown: текущий + доступные для добавления
                                        List<String> dropdownOptions = [
                                          colorQuantity.colorName,
                                          ...availableColorsToAdd
                                        ].toSet().toList()..sort(); // Уникальные и отсортированные

                                        // --- НАЧАЛО ВТОРОЙ ЧАСТИ КОДА ИЗ ЗАПРОСА ---
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Выпадающий список для ВЫБОРА ЦВЕТА
                                              Expanded(
                                                flex: 3,
                                                child: DropdownButtonFormField<String>(
                                                  value: dropdownOptions.contains(colorQuantity.colorName) ? colorQuantity.colorName : null, // Текущее значение (или null, если цвет удалили)
                                                  items: dropdownOptions.map((String colorName) {
                                                    return DropdownMenuItem<String>(
                                                      value: colorName,
                                                      child: Text(colorName, overflow: TextOverflow.ellipsis),
                                                    );
                                                  }).toList(),
                                                  onChanged: (newValue) {
                                                    if (newValue != null) {
                                                      setState(() {
                                                        colorQuantity.colorName = newValue;
                                                      });
                                                    }
                                                  },
                                                  decoration: InputDecoration(labelText: 'Цвет*', isDense: true),
                                                  validator: (value) => (value == null || value.isEmpty) ? 'Выберите' : null,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              // Поле ввода КОЛИЧЕСТВА
                                              Expanded(
                                                flex: 2,
                                                child: TextFormField(
                                                  initialValue: colorQuantity.quantity > 0 ? colorQuantity.quantity.toString() : '',
                                                  decoration: InputDecoration(labelText: 'Кол-во*', isDense: true),
                                                  keyboardType: TextInputType.number,
                                                  validator: (value) {
                                                    if (value == null || value.isEmpty) return 'Нужно';
                                                    if ((int.tryParse(value) ?? -1) < 0) return '>= 0';
                                                    return null;
                                                  },
                                                  onChanged: (value) => colorQuantity.quantity = int.tryParse(value) ?? 0,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              // Кнопка удаления этой связки цвет-количество
                                              IconButton(
                                                icon: Icon(Icons.remove_circle_outline, size: 20),
                                                color: Colors.redAccent,
                                                tooltip: 'Удалить этот цвет из размера',
                                                onPressed: () => _removeColorQuantityFromSize(sizeIndex, cqIndex),
                                              ),
                                            ],
                                          ),
                                        );
                                        // --- КОНЕЦ ВТОРОЙ ЧАСТИ КОДА ИЗ ЗАПРОСА ---
                                      },
                                    ),
                                  if (sizeVariant.colorQuantities.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text("Нет цветов для этого размера.", style: TextStyle(fontStyle: FontStyle.italic)),
                                    ),

                                  // Кнопка "Добавить цвет к размеру"
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      icon: Icon(Icons.add_circle_outline, size: 18),
                                      label: Text('Добавить цвет к размеру'),
                                      // Активна, если есть цвета, которые можно добавить
                                      onPressed: availableColorsToAdd.isNotEmpty && validColorNames.isNotEmpty
                                          ? () => _addColorQuantityToSize(sizeIndex)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 10),
                      // Кнопка "Добавить новый размер"
                      OutlinedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('Добавить размер'),
                        onPressed: _addSizeEntry,
                      ),
                      Divider(height: 30),

                      // --- Кнопка Сохранения ---
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addProduct,
                        child: Text(_isLoading ? 'Добавление...' : 'Добавить продукт'),
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 15)),
                      ),
                      SizedBox(height: 20), // Отступ снизу
                    ],
                  ),
                ),
              ),
            ),

            // --- Индикатор загрузки (оверлей) ---
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center( child: CircularProgressIndicator(), ),
              ),
          ],
        ),
      ),
    );
  }
}
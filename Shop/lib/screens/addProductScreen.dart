import 'dart:io';
import 'dart:convert'; // Нужен для jsonDecode и base64Encode
import 'package:http/http.dart' as http; // <--- Используем http
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shop/firebase_service.dart'; // Убедись, что путь правильный

// --- Цвета темы ---
const Color _backgroundColor = Color(0xFF18171c); // Фон
const Color _surfaceColor = Color(0xFF1f1f24); // Цвет карточек, панелей
const Color _primaryColor = Color(0xFFEE3A57); // Акцентный цвет
const Color _secondaryTextColor = Color(0xFFa0a0a0); // Серый текст
const Color _textFieldFillColor = Color(0xFF2a2a2e); // Заливка полей ввода
const Color _errorColor = Color(0xFFD32F2F); // Темно-красный для ошибок

// --- Структуры данных (ProductColor, SizeColorQuantity, SizeVariant) остаются без изменений ---
class ProductColor {
  String name;
  XFile? imageFile; // Файл для превью и ИСТОЧНИК для загрузки
  String? imageUrl; // СЮДА будем сохранять URL из ImageKit

  ProductColor({
    this.name = '',
    this.imageFile,
    this.imageUrl,
  });

  bool get isValid => name.trim().isNotEmpty;
  bool get hasImageForUpload => imageFile != null;
  bool get hasImageDisplay => imageUrl != null && imageUrl!.isNotEmpty;
  // Проверка, что есть либо файл для загрузки, либо уже загруженный URL
  bool get hasImageSource => hasImageForUpload || hasImageDisplay;
}
class SizeColorQuantity {
  String colorName;
  int quantity;
  SizeColorQuantity({required this.colorName, this.quantity = 0});
}
class SizeVariant {
  String size;
  List<SizeColorQuantity> colorQuantities;
  SizeVariant({this.size = '', this.colorQuantities = const []});
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
  XFile? _mainImageFile;
  int _newProductId = 0;
  List<Map<String, dynamic>> _categories = [];
  String _brand = '';
  String _material = '';
  int _popularityScore = 0;
  int _discount = 0;
  double _weight = 0.0;
  String _season = '';
  List<ProductColor> _productColors = [];
  List<SizeVariant> _sizeVariants = [];
  String? _selectedGender;
  final List<String> _genderOptions = const ['Мужской', 'Женский', 'Унисекс'];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // --- ImageKit Config (ОСТАВЛЯЕМ ТАК ЖЕ, но помните о безопасности ключа!) ---
  static const String _imageKitPublicKey = 'public_0EblotM8xHzpWNJUXWiVtRnHbGA=';
  static const String _imageKitPrivateKey = 'private_ZKL7E/ailo8o7MHqrvHIpxQRIiE=';
  static const String _imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  // --- Функции (_fetchCategories, _pickMainImage, _addProductColor, _removeProductColor, _pickProductColorImage, _addSizeEntry, _removeSizeEntry, _addColorQuantityToSize, _removeColorQuantityFromSize, _getAvailableColorsForSize, _generateNewProductId, _uploadImageToImageKit, _addProduct) остаются без изменений в своей ЛОГИКЕ ---
  // ... (весь код этих функций остается прежним) ...
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

  Future<String?> _uploadImageToImageKit(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse(_imageKitUploadUrl));
    String credentials = base64Encode(utf8.encode('$_imageKitPrivateKey:'));
    request.headers['Authorization'] = 'Basic $credentials';
    request.fields['publicKey'] = _imageKitPublicKey;
    request.fields['fileName'] = imageFile.name;
    request.fields['useUniqueFileName'] = 'true'; // Рекомендуется
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        print('ImageKit Upload Success: ${responseData['url']}');
        return responseData['url'];
      } else {
        print('Ошибка загрузки в ImageKit (${response.statusCode}): ${response.body}');
        throw Exception('Ошибка загрузки в ImageKit: Статус ${response.statusCode}');
      }
    } catch (e) {
      print('Исключение при загрузке в ImageKit: $e');
      throw Exception('Не удалось подключиться к сервису изображений: $e');
    }
  }


  Future<void> _addProduct() async {
    // 1. Валидация основной формы
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в форме.');
      return;
    }
    _formKey.currentState!.save();

    // 2. Валидация основного изображения
    if (_mainImageFile == null) {
      _showErrorSnackBar('Необходимо выбрать основное изображение продукта.');
      return;
    }

    // 3. Валидация цветов: хотя бы один цвет должен быть добавлен, иметь имя и изображение
    if (_productColors.isEmpty || !_productColors.any((c) => c.isValid && c.hasImageSource)) {
      _showErrorSnackBar('Добавьте хотя бы один цвет с именем и изображением.');
      return;
    }
    // Проверка валидности *каждого* добавленного цвета (имя + наличие изображения)
    for (int i = 0; i < _productColors.length; i++) {
      final color = _productColors[i];
      if (!color.isValid) {
        _showErrorSnackBar('Цвет #${i + 1}: Пожалуйста, введите название цвета.');
        return;
      }
      if (!color.hasImageSource) {
        _showErrorSnackBar('Цвет "${color.name}": Пожалуйста, выберите изображение.');
        return;
      }
      // Проверка уникальности имен (дополнительно)
      bool isDuplicate = _productColors.where((pc) => pc.isValid && pc.name.trim().toLowerCase() == color.name.trim().toLowerCase()).length > 1;
      if (isDuplicate) {
        _showErrorSnackBar('Названия цветов должны быть уникальными. Найден дубликат для "${color.name}".');
        return;
      }
    }

    // 4. Валидация размеров: хотя бы один размер должен быть добавлен
    if (_sizeVariants.isEmpty || !_sizeVariants.any((s) => s.isValid)) {
      _showErrorSnackBar('Добавьте хотя бы один размер для продукта.');
      return;
    }
    // Проверка валидности *каждого* добавленного размера (имя + хотя бы один цвет с количеством > 0)
    for (int i = 0; i < _sizeVariants.length; i++) {
      final sizeVariant = _sizeVariants[i];
      if (!sizeVariant.isValid) {
        _showErrorSnackBar('Размер #${i + 1}: Пожалуйста, введите название размера.');
        return;
      }
      if (sizeVariant.colorQuantities.isEmpty) {
        _showErrorSnackBar('Размер "${sizeVariant.size}": Добавьте хотя бы один цвет и укажите его количество.');
        return;
      }
      // Проверка, что для каждого цвета указано количество > 0
      bool hasValidQuantity = sizeVariant.colorQuantities.any((cq) => cq.quantity > 0);
      if (!hasValidQuantity) {
        _showErrorSnackBar('Размер "${sizeVariant.size}": Укажите количество (больше 0) хотя бы для одного цвета.');
        return;
      }
      // Проверка, что все цвета, добавленные к размеру, существуют в списке _productColors
      for(var cq in sizeVariant.colorQuantities) {
        if (!_productColors.any((pc) => pc.isValid && pc.name.trim() == cq.colorName)) {
          _showErrorSnackBar('Размер "${sizeVariant.size}": Обнаружен цвет "${cq.colorName}", который не определен в списке цветов продукта. Удалите его или добавьте/исправьте в секции "Цвета продукта".');
          return;
        }
      }
    }


    // --- Если все проверки пройдены ---
    if (mounted) setState(() => _isLoading = true);

    String? mainImageUrl;
    // Используем Map для хранения финальных URL изображений цветов (ключ - имя цвета)
    Map<String, String> finalColorImageUrls = {};
    Map<String, dynamic> sizesDataForFirestore = {};

    try {
      await _generateNewProductId(); // Генерируем ID

      // Загрузка основного изображения
      print('Загрузка основного изображения...');
      mainImageUrl = await _uploadImageToImageKit(_mainImageFile!);
      if (mainImageUrl == null || mainImageUrl.isEmpty) {
        throw Exception("Не удалось загрузить основное изображение.");
      }
      print('Основное изображение загружено: $mainImageUrl');

      // Загрузка изображений цветов (только если есть НОВЫЙ файл)
      for (var color in _productColors.where((c) => c.isValid)) {
        String colorNameTrimmed = color.name.trim();
        if (color.hasImageForUpload) {
          print('Загрузка изображения для цвета "${colorNameTrimmed}"...');
          String? uploadedUrl = await _uploadImageToImageKit(color.imageFile!);
          if (uploadedUrl == null || uploadedUrl.isEmpty) {
            throw Exception('Не удалось загрузить изображение для цвета "$colorNameTrimmed".');
          }
          color.imageUrl = uploadedUrl; // Сохраняем URL в объекте
          finalColorImageUrls[colorNameTrimmed] = uploadedUrl; // Добавляем в карту для Firestore
          print('Изображение для цвета "$colorNameTrimmed" загружено: $uploadedUrl');
        } else if (color.hasImageDisplay) {
          // Если файла нет, но есть URL (например, при редактировании), используем его
          finalColorImageUrls[colorNameTrimmed] = color.imageUrl!;
          print('Используется существующее изображение для цвета "$colorNameTrimmed": ${color.imageUrl!}');
        } else {
          // Эта ситуация не должна возникать из-за валидации выше, но на всякий случай
          throw Exception('Для цвета "$colorNameTrimmed" нет ни файла для загрузки, ни существующего URL.');
        }
      }

      // Подготовка данных размеров для Firestore
      for (var sizeVariant in _sizeVariants.where((s) => s.isValid)) {
        String currentSize = sizeVariant.size.trim();
        Map<String, int> colorQuantitiesForFirestore = {};

        for (var cq in sizeVariant.colorQuantities) {
          // Убедимся, что цвет с таким именем СУЩЕСТВУЕТ в карте finalColorImageUrls
          // и количество > 0
          if (cq.quantity > 0 && finalColorImageUrls.containsKey(cq.colorName)) {
            colorQuantitiesForFirestore[cq.colorName] = cq.quantity;
          } else if (cq.quantity <= 0) {
            print('Пропуск цвета "${cq.colorName}" для размера "$currentSize", так как количество <= 0.');
          } else {
            print('Предупреждение: Цвет "${cq.colorName}" указан для размера "$currentSize", но для него не найдено изображение. Этот цвет не будет добавлен для данного размера.');
            // Можно добавить более строгую обработку ошибки, если это критично
          }
        }

        if (colorQuantitiesForFirestore.isNotEmpty) {
          // Убедимся, что у каждого добавленного цвета есть изображение в finalColorImageUrls
          // (теоретически, проверка выше должна это гарантировать)
          sizesDataForFirestore[currentSize] = {'color_quantities': colorQuantitiesForFirestore};
        } else {
          print('Размер "$currentSize" не будет добавлен, так как для него нет допустимых цветов с количеством > 0.');
        }
      }

      // Финальная проверка, что есть хотя бы один размер с данными для сохранения
      if (sizesDataForFirestore.isEmpty) {
        throw Exception('Не удалось подготовить данные о размерах. Убедитесь, что у вас есть хотя бы один размер с корректно указанными цветами и их количеством (> 0).');
      }


      // Формирование данных продукта
      Map<String, dynamic> productData = {
        'product_id': _newProductId,
        'name': _name.trim(),
        'description': _description.trim(),
        'price': _price,
        'category_id': _selectedCategoryId,
        'gender': _selectedGender,
        'creator_id': widget.creatorId,
        'created_at': FieldValue.serverTimestamp(),
        'main_image_url': mainImageUrl,
        'colors': finalColorImageUrls, // Карта 'имя_цвета': 'url_изображения'
        'sizes': sizesDataForFirestore, // Карта 'имя_размера': {'color_quantities': {'имя_цвета': количество}}
        'brand': _brand.trim(),
        'material': _material.trim(),
        'popularity_score': _popularityScore,
        'discount': _discount,
        'weight': _weight,
        'season': _season,
        // Добавляем поле для поиска без учета регистра
        'search_name': _name.trim().toLowerCase(),
      };

      print("\n--- Данные для Firestore ---");
      productData.forEach((key, value) {
        print("$key: $value");
      });
      print("---------------------------\n");


      // Добавление документа продукта в Firestore
      print('Добавление документа в Firestore...');
      DocumentReference docRef = await FirebaseService().firestore.collection('products').add(productData);
      print('Продукт успешно добавлен с ID документа: ${docRef.id}');

      // Успешное завершение
      if (mounted) {
        Navigator.pop(context); // Возвращаемся назад
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Продукт успешно добавлен!'),
            backgroundColor: Colors.green, // Или использовать цвет из темы
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      print('Критическая ошибка при добавлении продукта: $e');
      // Показываем детальную ошибку пользователю
      _showErrorSnackBar('Ошибка при добавлении продукта: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  // --- Вспомогательные функции (остаются без изменений) ---

  // _showErrorSnackBar остается без изменений, но можно настроить цвет
  void _showErrorSnackBar(String message, {int durationSeconds = 5}) { // Увеличил длительность
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: Colors.white)),
          backgroundColor: _errorColor, // Используем наш цвет ошибки
          duration: Duration(seconds: durationSeconds),
          behavior: SnackBarBehavior.floating, // Немного приподнимем
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          margin: EdgeInsets.all(8.0),
        ),
      );
    }
  }

  // --- МЕТОД build() ---
  @override
  Widget build(BuildContext context) {
    // Определяем тему внутри build или получаем из MaterialApp
    final theme = _buildThemeData(); // Создаем нашу тему

    final validColorNames = _productColors
        .where((c) => c.isValid)
        .map((c) => c.name.trim())
        .toList();

    // Обертка в Theme, чтобы применить стили ко всем дочерним элементам
    return Theme(
      data: theme,
      child: Scaffold(
        // appBar уже будет использовать цвета из theme.appBarTheme
        appBar: AppBar(
          title: Text('Добавить продукт'),
          elevation: 0, // Убираем тень для чистоты
        ),
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
                        // Используют стиль из theme.inputDecorationTheme
                        _buildTextField(label: 'Название*', onSaved: (v) => _name = v!, validator: (v) => _validateNotEmpty(v, 'Введите название')),
                        _buildTextField(label: 'Описание*', maxLines: 3, onSaved: (v) => _description = v!, validator: (v) => _validateNotEmpty(v, 'Введите описание')),
                        _buildTextField(label: 'Бренд*', maxLength: 50, onSaved: (v) => _brand = v!.trim(), validator: (v) => _validateNotEmpty(v, 'Введите бренд')),
                        _buildTextField(label: 'Материал*', onSaved: (v) => _material = v!, validator: (v) => _validateNotEmpty(v, 'Введите материал')),
                        _buildTextField(
                          label: 'Рейтинг популярности (0-100)',
                          keyboardType: TextInputType.number,
                          onSaved: (v) => _popularityScore = int.tryParse(v!) ?? 0,
                          validator: (v) => _validateIntRange(v, 0, 100, 'Введите рейтинг от 0 до 100'),
                        ),
                        _buildTextField(
                          label: 'Скидка (%)',
                          keyboardType: TextInputType.number,
                          onSaved: (v) => _discount = int.tryParse(v!) ?? 0,
                          validator: (v) => _validateIntRange(v, 0, 100, 'Введите скидку от 0 до 100'),
                        ),
                        _buildTextField(
                          label: 'Вес (в кг)*',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onSaved: (v) => _weight = double.tryParse(v!.replaceAll(',', '.')) ?? 0.0,
                          validator: (v) => _validatePositiveDouble(v, 'Введите корректный положительный вес'),
                        ),
                        _buildTextField(
                          label: 'Цена*',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onSaved: (v) => _price = double.tryParse(v!.replaceAll(',', '.')) ?? 0.0,
                          validator: (v) => _validatePositiveDouble(v, 'Введите корректную положительную цену'),
                        ),

                        SizedBox(height: 16),
                        _buildDropdownField<String>(
                          label: 'Сезон*',
                          value: _season.isEmpty ? null : _season,
                          items: ['Зима', 'Лето', 'Осень', 'Весна'],
                          itemTextBuilder: (season) => season,
                          onChanged: (value) {
                            setState(() {
                              _season = value ?? '';
                            });
                          },
                          validator: (value) => value == null || value.isEmpty ? 'Выберите сезон' : null,
                        ),
                        SizedBox(height: 16),
                        _buildDropdownField<int>(
                          label: 'Категория*',
                          value: _selectedCategoryId == -1 ? null : _selectedCategoryId,
                          items: _categories.map((category) => category['id'] as int).toList(),
                          itemTextBuilder: (id) {
                            final category = _categories.firstWhere((c) => c['id'] == id);
                            return category['name'] as String;
                          },
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategoryId = value;
                              });
                            }
                          },
                          validator: (value) => value == null ? 'Выберите категорию' : null,
                        ),
                        SizedBox(height: 16),
                        _buildDropdownField<String>(
                          label: 'Пол*',
                          value: _selectedGender,
                          items: _genderOptions,
                          itemTextBuilder: (gender) => gender,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedGender = value;
                              });
                            }
                          },
                          validator: (value) => value == null ? 'Выберите пол' : null,
                        ),

                        SizedBox(height: 24),

                        // --- Основное изображение ---
                        Text("Основное изображение*", style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.image_search), // Иконка поиска
                              label: Text('Выбрать'),
                              onPressed: _pickMainImage,
                            ),
                            SizedBox(width: 16),
                            if (_mainImageFile != null)
                              ClipRRect( // Закругленные углы
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.file(
                                    File(_mainImageFile!.path),
                                    height: 60, width: 60, fit: BoxFit.cover
                                ),
                              ),
                          ],
                        ),
                        // Валидация изображения показывается через SnackBar при попытке сохранения

                        SizedBox(height: 24),
                        Divider(thickness: 1), // Разделитель использует цвет из темы
                        SizedBox(height: 16),

                        // --- Секция Цветов ---
                        Text("Цвета продукта*", style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        Text("Добавьте цвета и их изображения.", style: theme.textTheme.bodySmall?.copyWith(color: _secondaryTextColor)),
                        SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _productColors.length,
                          itemBuilder: (context, colorIndex) {
                            var color = _productColors[colorIndex];
                            return Card( // Карточка использует цвет из темы
                              // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // Закругление
                              margin: EdgeInsets.symmetric(vertical: 8.0),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: color.name,
                                        // Стиль из темы
                                        decoration: InputDecoration(
                                          labelText: 'Название цвета*',
                                          isDense: true,
                                          // Подсветка ошибки, если поле невалидно
                                          errorText: !color.isValid && color.name.isEmpty ? 'Нужно имя' : null,
                                        ),
                                        onChanged: (value) {
                                          // Проверка на уникальность при вводе (опционально, но полезно)
                                          String currentInputName = value.trim().toLowerCase();
                                          bool isDuplicate = _productColors.any((pc) => pc != color && pc.isValid && pc.name.trim().toLowerCase() == currentInputName);

                                          setState(() {
                                            color.name = value;
                                            // Можно сразу показывать ошибку дубликата, если нужно
                                            // if (isDuplicate) { ... }
                                          });
                                        },
                                        // Валидация при сохранении формы
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) return 'Нужно имя';
                                          String currentInputName = value.trim().toLowerCase();
                                          bool isDuplicate = _productColors.any((pc) => pc != color && pc.isValid && pc.name.trim().toLowerCase() == currentInputName);
                                          if (isDuplicate) return 'Имя не уникально';
                                          return null;
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Превью или кнопка добавления изображения
                                    if (color.imageFile != null) // Показываем выбранный файл
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4.0),
                                          child: Image.file(File(color.imageFile!.path), height: 36, width: 36, fit: BoxFit.cover),
                                        ),
                                      )
                                    else if (color.hasImageDisplay) // Показываем загруженный URL
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4.0),
                                          child: Image.network(color.imageUrl!, height: 36, width: 36, fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 36, color: _secondaryTextColor),
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return SizedBox(
                                                width: 36,
                                                height: 36,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.0,
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    // Кнопка выбора/замены изображения
                                    Tooltip(
                                      message: color.hasImageSource
                                          ? 'Заменить изображение для "${color.name.isNotEmpty ? color.name : 'Новый цвет'}"'
                                          : 'Выбрать изображение для цвета',
                                      child: IconButton(
                                        icon: Icon(color.hasImageSource ? Icons.sync /* Заменить */ : Icons.add_photo_alternate_outlined, size: 28),
                                        color: color.hasImageSource ? _primaryColor : _secondaryTextColor, // Акцентный или серый
                                        onPressed: () => _pickProductColorImage(colorIndex),
                                      ),
                                    ),
                                    // Кнопка удаления цвета
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, size: 22),
                                      color: theme.colorScheme.error, // Используем цвет ошибки из темы
                                      tooltip: 'Удалить этот цвет',
                                      onPressed: () => _removeProductColor(colorIndex),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon( // Текстовая кнопка использует цвета темы
                            icon: Icon(Icons.add_circle_outline, size: 20),
                            label: Text('Добавить цвет'),
                            onPressed: _addProductColor,
                          ),
                        ),

                        SizedBox(height: 24),
                        Divider(thickness: 1),
                        SizedBox(height: 16),

                        // --- Секция Размеров ---
                        Text("Размеры и Наличие*", style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        Text("Укажите размеры и количество каждого цвета.", style: theme.textTheme.bodySmall?.copyWith(color: _secondaryTextColor)),
                        SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _sizeVariants.length,
                          itemBuilder: (context, sizeIndex) {
                            var sizeVariant = _sizeVariants[sizeIndex];
                            List<String> availableColorsToAdd = _getAvailableColorsForSize(sizeIndex);

                            return Card(
                              // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              margin: EdgeInsets.symmetric(vertical: 8.0),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: sizeVariant.size,
                                            decoration: InputDecoration(labelText: 'Размер* (напр. 46, M, L)'),
                                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Нужен размер' : null,
                                            onChanged: (value) => setState(() => sizeVariant.size = value), // Обновляем стейт для перерисовки
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline),
                                          color: theme.colorScheme.error,
                                          tooltip: 'Удалить этот размер',
                                          onPressed: () => _removeSizeEntry(sizeIndex),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    Text("Наличие цветов:", style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.9))),
                                    SizedBox(height: 8),

                                    if (sizeVariant.colorQuantities.isNotEmpty)
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: sizeVariant.colorQuantities.length,
                                        itemBuilder: (context, cqIndex) {
                                          var colorQuantity = sizeVariant.colorQuantities[cqIndex];
                                          List<String> dropdownOptions = [
                                            if (validColorNames.contains(colorQuantity.colorName)) colorQuantity.colorName, // Текущий, если он еще валиден
                                            ...availableColorsToAdd
                                          ].toSet().toList()..sort();

                                          // Проверка, существует ли выбранный цвет в общем списке валидных цветов
                                          bool isCurrentColorValid = validColorNames.contains(colorQuantity.colorName);
                                          String? currentValue = isCurrentColorValid ? colorQuantity.colorName : null;


                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание по верху для сообщений об ошибках
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: DropdownButtonFormField<String>(
                                                    value: currentValue,
                                                    // Используем стиль темы
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
                                                    decoration: InputDecoration(
                                                      labelText: 'Цвет*',
                                                      isDense: true,
                                                      // Показываем ошибку, если текущий цвет стал невалидным
                                                      errorText: !isCurrentColorValid && colorQuantity.colorName.isNotEmpty ? 'Цвет удален' : null,
                                                    ),
                                                    validator: (value) => (value == null || value.isEmpty) ? 'Выберите' : null,
                                                  ),
                                                ),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  flex: 2,
                                                  child: TextFormField(
                                                    initialValue: colorQuantity.quantity > 0 ? colorQuantity.quantity.toString() : '',
                                                    decoration: InputDecoration(labelText: 'Кол-во*', isDense: true),
                                                    keyboardType: TextInputType.number,
                                                    validator: (value) {
                                                      if (value == null || value.isEmpty) return 'Нужно';
                                                      final qty = int.tryParse(value);
                                                      if (qty == null || qty < 0) return '>= 0';
                                                      // Валидация: если это последняя строка цвет-количество для размера, она должна иметь кол-во > 0
                                                      if (sizeVariant.colorQuantities.length == 1 && qty <= 0) {
                                                        return 'Хотя бы 1';
                                                      }
                                                      return null;
                                                    },
                                                    onChanged: (value) => setState(() => colorQuantity.quantity = int.tryParse(value) ?? 0),
                                                  ),
                                                ),
                                                SizedBox(width: 4), // Меньше отступ
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8.0), // Сдвигаем иконку чуть вниз
                                                  child: IconButton(
                                                    icon: Icon(Icons.remove_circle_outline, size: 22),
                                                    color: theme.colorScheme.error.withOpacity(0.8),
                                                    tooltip: 'Удалить этот цвет из размера',
                                                    onPressed: () => _removeColorQuantityFromSize(sizeIndex, cqIndex),
                                                    padding: EdgeInsets.zero, // Убираем лишние отступы у иконки
                                                    constraints: BoxConstraints(), // Убираем мин/макс размеры
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    else // Если нет строк цвет-количество
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                                        child: Text(
                                          validColorNames.isEmpty
                                              ? "Сначала определите цвета в секции выше."
                                              : "Нажмите 'Добавить цвет к размеру'.",
                                          style: TextStyle(color: _secondaryTextColor, fontStyle: FontStyle.italic),
                                        ),
                                      ),

                                    SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: Icon(Icons.add_circle_outline, size: 18),
                                        label: Text('Добавить цвет к размеру'),
                                        // Кнопка неактивна, если нет ВАЛИДНЫХ цветов для добавления
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
                        SizedBox(height: 12),
                        OutlinedButton.icon( // Кнопка с обводкой использует цвета темы
                          icon: Icon(Icons.add),
                          label: Text('Добавить размер'),
                          onPressed: _addSizeEntry,
                        ),

                        SizedBox(height: 24),
                        Divider(thickness: 1),
                        SizedBox(height: 24),

                        // --- Кнопка Сохранения ---
                        ElevatedButton(
                          onPressed: _isLoading ? null : _addProduct,
                          // Стиль из темы
                          style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                          ),
                          child: Text(_isLoading ? 'ДОБАВЛЕНИЕ...' : 'ДОБАВИТЬ ПРОДУКТ'),
                        ),
                        SizedBox(height: 30), // Дополнительный отступ снизу
                      ],
                    ),
                  ),
                ),
              ),

              // --- Индикатор загрузки (оверлей) ---
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.75), // Более темный оверлей
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_primaryColor), // Акцентный цвет
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Вспомогательные виджеты и валидаторы ---

  // Хелпер для создания TextFormField в едином стиле
  Widget _buildTextField({
    required String label,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    int? maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? initialValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Добавляем вертикальный отступ
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          counterText: maxLength != null ? "" : null, // Скрываем счетчик символов по умолчанию
        ),
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }

  // Хелпер для создания DropdownButtonFormField в едином стиле
  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required FormFieldValidator<T> validator,
    DropdownMenuItem<T> Function(T item)? itemBuilder, // Пользовательский билдер
    String Function(T item)? itemTextBuilder, // Альтернативный билдер для текста
  }) {
    // Проверка: должен быть передан либо itemBuilder, либо itemTextBuilder
    assert(itemBuilder != null || itemTextBuilder != null, 'Provide either itemBuilder or itemTextBuilder');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items.map((item) {
          // Если передан itemBuilder, используем его для генерации DropdownMenuItem
          if (itemBuilder != null) {
            return itemBuilder(item);
          }
          // Если передан itemTextBuilder, создаём стандартный DropdownMenuItem с текстом
          return DropdownMenuItem<T>(
            value: item,
            child: Text(itemTextBuilder!(item)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  // Базовый валидатор на пустое значение
  String? _validateNotEmpty(String? value, String errorMessage) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage;
    }
    return null;
  }

  // Валидатор для положительных чисел (int/double)
  String? _validatePositiveDouble(String? value, String errorMessage) {
    if (value == null || value.isEmpty) return errorMessage;
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null || number <= 0) return errorMessage;
    return null;
  }

  // Валидатор для целых чисел в диапазоне
  String? _validateIntRange(String? value, int min, int max, String errorMessage) {
    if (value == null || value.isEmpty) return errorMessage; // Или вернуть null, если поле необязательное
    final number = int.tryParse(value);
    if (number == null || number < min || number > max) {
      return errorMessage;
    }
    return null;
  }


  // --- Метод для создания ThemeData ---
  ThemeData _buildThemeData() {
    final baseTheme = ThemeData.dark(); // Берем за основу темную тему Flutter

    return baseTheme.copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        primaryColor: _primaryColor,
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: _primaryColor,
          secondary: _primaryColor, // Можно использовать тот же акцентный цвет
          surface: _surfaceColor,
          background: _backgroundColor,
          onPrimary: Colors.white, // Текст на primary цвете
          onSecondary: Colors.white,
          onSurface: Colors.white, // Основной текст на surface (карточках и т.д.)
          onBackground: Colors.white, // Основной текст на фоне
          error: _errorColor, // Цвет для ошибок
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _surfaceColor, // AppBar чуть светлее фона
          foregroundColor: Colors.white, // Цвет заголовка и иконок в AppBar
          elevation: 0, // Убрать тень по умолчанию
          titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _textFieldFillColor,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Комфортные отступы
          hintStyle: TextStyle(color: _secondaryTextColor.withOpacity(0.7)),
          labelStyle: TextStyle(color: _secondaryTextColor), // Цвет метки поля ввода
          // Границы полей ввода
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none, // Без видимой границы по умолчанию
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: _surfaceColor, width: 1.0), // Тонкая граница в цвет поверхности
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: _primaryColor, width: 1.5), // Акцентная граница при фокусе
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: _errorColor, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: _errorColor, width: 1.5),
          ),
          errorStyle: TextStyle(color: _errorColor, fontSize: 12), // Стиль текста ошибки
        ),
        cardTheme: CardTheme(
          elevation: 1.0, // Небольшая тень для отделения
          color: _surfaceColor,
          margin: EdgeInsets.symmetric(vertical: 6.0), // Стандартный отступ для карточек
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // Более скругленные углы
            // Можно добавить тонкую границу, если нужно
            // side: BorderSide(color: _textFieldFillColor, width: 1.0)
          ),
        ),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: Colors.white.withOpacity(0.9), // Основной цвет текста
          displayColor: Colors.white,
        ).copyWith(
          // Стили для заголовков секций
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600),
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(color: _secondaryTextColor), // Для подсказок
          labelLarge: baseTheme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), // Текст на кнопках
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: _primaryColor, // Цвет текста/иконки
              textStyle: TextStyle(fontWeight: FontWeight.w600)
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor, // Фон кнопки
              foregroundColor: Colors.white, // Текст/иконка на кнопке
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor, // Цвет текста/иконки/обводки
              side: BorderSide(color: _primaryColor, width: 1.5), // Обводка
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              textStyle: TextStyle(fontWeight: FontWeight.w600)
          ),
        ),
        dividerTheme: DividerThemeData(
          color: _secondaryTextColor.withOpacity(0.3), // Цвет разделителя
          thickness: 1,
          space: 32, // Отступы сверху и снизу у Divider
        ),
        iconTheme: IconThemeData(
          color: _secondaryTextColor, // Цвет иконок по умолчанию
          size: 24.0,
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: _textFieldFillColor, // Фон подсказки
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: TextStyle(color: Colors.white, fontSize: 12),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _surfaceColor, // Фон SnackBar по умолчанию
          contentTextStyle: TextStyle(color: Colors.white),
          actionTextColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          elevation: 4.0,
        )
      // Можно добавить другие настройки темы: chipTheme, dialogTheme и т.д.
    );
  }
}
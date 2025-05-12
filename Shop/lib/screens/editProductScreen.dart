import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shop/firebase_service.dart';

const Color _backgroundColor = Color(0xFF18171c);
const Color _surfaceColor = Color(0xFF1f1f24);
const Color _primaryColor = Color(0xFFEE3A57);
const Color _secondaryTextColor = Color(0xFFa0a0a0);
const Color _textFieldFillColor = Color(0xFF2a2a2e);
const Color _errorColor = Color(0xFFD32F2F);

class ProductColor {
  String name;
  XFile? imageFile;
  String? imageUrl;

  ProductColor({this.name = '', this.imageFile, this.imageUrl});

  bool get isValid => name.trim().isNotEmpty;
  bool get hasImageForUpload => imageFile != null;
  bool get hasImageDisplay => imageUrl != null && imageUrl!.isNotEmpty;
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

class EditProductScreen extends StatefulWidget {
  final String productDocId;
  final String creatorId;

  const EditProductScreen({required this.productDocId, required this.creatorId, Key? key}) : super(key: key);

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  static const double kFieldSpacing = 16.0;

  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  double _price = 0.0;
  int _selectedCategoryId = -1;
  XFile? _mainImageFile;
  String? _mainImageUrl;
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

  static const String _imageKitPublicKey = 'public_0EblotM8xHzpWNJUXWiVtRnHbGA=';
  static const String _imageKitPrivateKey = 'private_ZKL7E/ailo8o7MHqrvHIpxQRIiE=';
  static const String _imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadProduct();
  }

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

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseService().firestore.collection('products').doc(widget.productDocId).get();
      if (!doc.exists) throw Exception("Товар не найден");
      final data = doc.data()!;
      _name = data['name'] ?? '';
      _description = data['description'] ?? '';
      _price = (data['price'] ?? 0).toDouble();
      _selectedCategoryId = data['category_id'] ?? -1;
      _mainImageUrl = data['main_image_url'];
      _brand = data['brand'] ?? '';
      _material = data['material'] ?? '';
      _popularityScore = data['popularity_score'] ?? 0;
      _discount = data['discount'] ?? 0;
      _weight = (data['weight'] ?? 0).toDouble();
      _season = data['season'] ?? '';
      _selectedGender = data['gender'];
      // цвета
      final colorsMap = Map<String, dynamic>.from(data['colors'] ?? {});
      _productColors = colorsMap.entries.map((e) => ProductColor(name: e.key, imageUrl: e.value as String?)).toList();
      // размеры
      final sizesMap = Map<String, dynamic>.from(data['sizes'] ?? {});
      _sizeVariants = sizesMap.entries.map((sizeEntry) {
        final size = sizeEntry.key;
        final colorQuantities = sizeEntry.value['color_quantities'] as Map<String, dynamic>? ?? {};
        return SizeVariant(
          size: size,
          colorQuantities: colorQuantities.entries.map((cq) => SizeColorQuantity(colorName: cq.key, quantity: (cq.value ?? 0) as int)).toList(),
        );
      }).toList();
      setState(() {});
    } catch (e) {
      print('Ошибка загрузки товара: $e');
      _showErrorSnackBar('Ошибка загрузки товара: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Остальной код такой же, как у AddProductScreen, только изменяем firestore update
  Future<void> _pickMainImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null && mounted) {
        setState(() {
          _mainImageFile = pickedFile;
          _mainImageUrl = null; // после выбора файла, старый url уже не показываем
        });
      }
    } catch (e) {
      print('Ошибка при выборе основного изображения: $e');
      _showErrorSnackBar('Ошибка выбора изображения: $e');
    }
  }

  void _addProductColor() {
    setState(() => _productColors.add(ProductColor()));
  }

  void _removeProductColor(int index) {
    String removedColorName = _productColors[index].name.trim();
    setState(() {
      _productColors.removeAt(index);
      for (var sizeVariant in _sizeVariants) {
        sizeVariant.colorQuantities.removeWhere((cq) => cq.colorName == removedColorName);
      }
    });
  }

  Future<void> _pickProductColorImage(int colorIndex) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null && mounted) {
        setState(() {
          _productColors[colorIndex].imageFile = pickedFile;
          _productColors[colorIndex].imageUrl = null;
        });
      }
    } catch (e) {
      print('Ошибка при выборе изображения цвета: $e');
      _showErrorSnackBar('Ошибка выбора изображения цвета: $e');
    }
  }

  void _addSizeEntry() {
    setState(() => _sizeVariants.add(SizeVariant(size: '', colorQuantities: [])));
  }

  void _removeSizeEntry(int index) {
    setState(() => _sizeVariants.removeAt(index));
  }

  void _addColorQuantityToSize(int sizeIndex) {
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

  void _removeColorQuantityFromSize(int sizeIndex, int colorQuantityIndex) {
    setState(() {
      _sizeVariants[sizeIndex].colorQuantities.removeAt(colorQuantityIndex);
    });
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

  Future<String?> _uploadImageToImageKit(XFile imageFile) async {
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
        return responseData['url'];
      } else {
        throw Exception('Ошибка загрузки в ImageKit: Статус ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Не удалось подключиться к сервису изображений: $e');
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в форме.');
      return;
    }
    _formKey.currentState!.save();

    if (_mainImageFile == null && (_mainImageUrl == null || _mainImageUrl!.isEmpty)) {
      _showErrorSnackBar('Необходимо выбрать основное изображение продукта.');
      return;
    }

    if (_productColors.isEmpty || !_productColors.any((c) => c.isValid && c.hasImageSource)) {
      _showErrorSnackBar('Добавьте хотя бы один цвет с именем и изображением.');
      return;
    }
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
      bool isDuplicate = _productColors.where((pc) => pc.isValid && pc.name.trim().toLowerCase() == color.name.trim().toLowerCase()).length > 1;
      if (isDuplicate) {
        _showErrorSnackBar('Названия цветов должны быть уникальными. Найден дубликат для "${color.name}".');
        return;
      }
    }

    if (_sizeVariants.isEmpty || !_sizeVariants.any((s) => s.isValid)) {
      _showErrorSnackBar('Добавьте хотя бы один размер для продукта.');
      return;
    }
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
      bool hasValidQuantity = sizeVariant.colorQuantities.any((cq) => cq.quantity > 0);
      if (!hasValidQuantity) {
        _showErrorSnackBar('Размер "${sizeVariant.size}": Укажите количество (больше 0) хотя бы для одного цвета.');
        return;
      }
      for(var cq in sizeVariant.colorQuantities) {
        if (!_productColors.any((pc) => pc.isValid && pc.name.trim() == cq.colorName)) {
          _showErrorSnackBar('Размер "${sizeVariant.size}": Обнаружен цвет "${cq.colorName}", который не определен в списке цветов продукта. Удалите его или добавьте/исправьте в секции "Цвета продукта".');
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    String? mainImageUrl = _mainImageUrl;
    Map<String, String> finalColorImageUrls = {};
    Map<String, dynamic> sizesDataForFirestore = {};

    try {
      // если меняли основное фото — загружаем новое, иначе оставляем старое
      if (_mainImageFile != null) {
        mainImageUrl = await _uploadImageToImageKit(_mainImageFile!);
      }

      // если меняли фото цвета — загружаем новое, иначе оставляем старое
      for (var color in _productColors.where((c) => c.isValid)) {
        String colorNameTrimmed = color.name.trim();
        if (color.hasImageForUpload) {
          String? uploadedUrl = await _uploadImageToImageKit(color.imageFile!);
          if (uploadedUrl == null || uploadedUrl.isEmpty) {
            throw Exception('Не удалось загрузить изображение для цвета "$colorNameTrimmed".');
          }
          color.imageUrl = uploadedUrl;
          finalColorImageUrls[colorNameTrimmed] = uploadedUrl;
        } else if (color.hasImageDisplay) {
          finalColorImageUrls[colorNameTrimmed] = color.imageUrl!;
        } else {
          throw Exception('Для цвета "$colorNameTrimmed" нет ни файла для загрузки, ни существующего URL.');
        }
      }

      // формируем размеры/цвета
      for (var sizeVariant in _sizeVariants.where((s) => s.isValid)) {
        String currentSize = sizeVariant.size.trim();
        Map<String, int> colorQuantitiesForFirestore = {};
        for (var cq in sizeVariant.colorQuantities) {
          if (cq.quantity > 0 && finalColorImageUrls.containsKey(cq.colorName)) {
            colorQuantitiesForFirestore[cq.colorName] = cq.quantity;
          }
        }
        if (colorQuantitiesForFirestore.isNotEmpty) {
          sizesDataForFirestore[currentSize] = {'color_quantities': colorQuantitiesForFirestore};
        }
      }
      if (sizesDataForFirestore.isEmpty) {
        throw Exception('Не удалось подготовить данные о размерах. Убедитесь, что у вас есть хотя бы один размер с корректно указанными цветами и их количеством (> 0).');
      }

      Map<String, dynamic> productData = {
        'name': _name.trim(),
        'description': _description.trim(),
        'price': _price,
        'category_id': _selectedCategoryId,
        'gender': _selectedGender,
        'main_image_url': mainImageUrl,
        'colors': finalColorImageUrls,
        'sizes': sizesDataForFirestore,
        'brand': _brand.trim(),
        'material': _material.trim(),
        'popularity_score': _popularityScore,
        'discount': _discount,
        'weight': _weight,
        'season': _season,
        'search_name': _name.trim().toLowerCase(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseService().firestore.collection('products').doc(widget.productDocId).update(productData);

      if (mounted) {
        Navigator.pop(context, true); // можно вернуть true, чтобы обновить список товаров
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Продукт успешно обновлён!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Ошибка при обновлении продукта: $e');
      _showErrorSnackBar('Ошибка при обновлении продукта: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message, {int durationSeconds = 5}) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: _errorColor,
          duration: Duration(seconds: durationSeconds),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          margin: const EdgeInsets.all(8.0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _buildThemeData();
    final validColorNames = _productColors
        .where((c) => c.isValid)
        .map((c) => c.name.trim())
        .toList();

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _surfaceColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          elevation: 0,
          title: const Text(
            'Редактировать продукт',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: false,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primaryColor))
            : AbsorbPointer(
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
                        _buildTextField(
                          label: 'Название*',
                          initialValue: _name,
                          onSaved: (v) => _name = v!,
                          validator: (v) => _validateNotEmpty(v, 'Введите название'),
                        ),
                        SizedBox(height: kFieldSpacing),
                        _buildTextField(
                          label: 'Описание*',
                          maxLines: 3,
                          initialValue: _description,
                          onSaved: (v) => _description = v!,
                          validator: (v) => _validateNotEmpty(v, 'Введите описание'),
                        ),
                        SizedBox(height: kFieldSpacing),
                        _buildTextField(
                          label: 'Бренд*',
                          maxLength: 50,
                          initialValue: _brand,
                          onSaved: (v) => _brand = v!.trim(),
                          validator: (v) => _validateNotEmpty(v, 'Введите бренд'),
                        ),
                        SizedBox(height: kFieldSpacing),
                        _buildTextField(
                          label: 'Материал*',
                          initialValue: _material,
                          onSaved: (v) => _material = v!,
                          validator: (v) => _validateNotEmpty(v, 'Введите материал'),
                        ),
                        SizedBox(height: kFieldSpacing),
                        _buildTextField(
                          label: 'Рейтинг популярности (0-100)',
                          keyboardType: TextInputType.number,
                          initialValue: _popularityScore.toString(),
                          onSaved: (v) => _popularityScore = int.tryParse(v!) ?? 0,
                          validator: (v) => _validateIntRange(v, 0, 100, 'Введите рейтинг от 0 до 100'),
                        ),
                        SizedBox(height: kFieldSpacing),
                        _buildTextField(
                          label: 'Скидка (%)',
                          keyboardType: TextInputType.number,
                          initialValue: _discount.toString(),
                          onSaved: (v) => _discount = int.tryParse(v!) ?? 0,
                          validator: (v) => _validateIntRange(v, 0, 100, 'Введите скидку от 0 до 100'),
                        ),
                        SizedBox(height: kFieldSpacing),
                        _buildTextField(
                          label: 'Вес (в кг)*',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          initialValue: _weight > 0 ? _weight.toString() : '',
                          onSaved: (v) => _weight = double.tryParse(v!.replaceAll(',', '.')) ?? 0.0,
                          validator: (v) => _validatePositiveDouble(v, 'Введите корректный положительный вес'),
                        ),
                        SizedBox(height: kFieldSpacing),
                        _buildTextField(
                          label: 'Цена*',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          initialValue: _price > 0 ? _price.toString() : '',
                          onSaved: (v) => _price = double.tryParse(v!.replaceAll(',', '.')) ?? 0.0,
                          validator: (v) => _validatePositiveDouble(v, 'Введите корректную положительную цену'),
                        ),
                        SizedBox(height: kFieldSpacing),
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
                        SizedBox(height: kFieldSpacing),
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
                        SizedBox(height: kFieldSpacing),
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

                        SizedBox(height: kFieldSpacing * 1.5),
                        Text("Основное изображение*", style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.image_search),
                              label: const Text('Выбрать'),
                              onPressed: _pickMainImage,
                            ),
                            const SizedBox(width: 16),
                            if (_mainImageFile != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.file(
                                    File(_mainImageFile!.path),
                                    height: 60, width: 60, fit: BoxFit.cover
                                ),
                              )
                            else if (_mainImageUrl != null && _mainImageUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(_mainImageUrl!,
                                  height: 60, width: 60, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 60, color: _secondaryTextColor),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: kFieldSpacing * 1.5),
                        const Divider(thickness: 1),
                        SizedBox(height: kFieldSpacing),

                        Text("Цвета продукта*", style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        Text("Добавьте цвета и их изображения.", style: theme.textTheme.bodySmall?.copyWith(color: _secondaryTextColor)),
                        SizedBox(height: kFieldSpacing),
                        ..._productColors.asMap().entries.map((entry) {
                          int colorIndex = entry.key;
                          var color = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: kFieldSpacing),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: color.name,
                                        decoration: InputDecoration(
                                          labelText: 'Название цвета*',
                                          isDense: true,
                                          errorText: !color.isValid && color.name.isEmpty ? 'Нужно имя' : null,
                                        ),
                                        onChanged: (value) {
                                          String currentInputName = value.trim().toLowerCase();
                                          bool isDuplicate = _productColors.any((pc) => pc != color && pc.isValid && pc.name.trim().toLowerCase() == currentInputName);
                                          setState(() {
                                            color.name = value;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) return 'Нужно имя';
                                          String currentInputName = value.trim().toLowerCase();
                                          bool isDuplicate = _productColors.any((pc) => pc != color && pc.isValid && pc.name.trim().toLowerCase() == currentInputName);
                                          if (isDuplicate) return 'Имя не уникально';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (color.imageFile != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4.0),
                                          child: Image.file(File(color.imageFile!.path), height: 36, width: 36, fit: BoxFit.cover),
                                        ),
                                      )
                                    else if (color.hasImageDisplay)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4.0),
                                          child: Image.network(color.imageUrl!,
                                            height: 36, width: 36, fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 36, color: _secondaryTextColor),
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
                                    Tooltip(
                                      message: color.hasImageSource
                                          ? 'Заменить изображение для "${color.name.isNotEmpty ? color.name : 'Новый цвет'}"'
                                          : 'Выбрать изображение для цвета',
                                      child: IconButton(
                                        icon: Icon(color.hasImageSource ? Icons.sync : Icons.add_photo_alternate_outlined, size: 28),
                                        color: color.hasImageSource ? _primaryColor : _secondaryTextColor,
                                        onPressed: () => _pickProductColorImage(colorIndex),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                                      color: theme.colorScheme.error,
                                      tooltip: 'Удалить этот цвет',
                                      onPressed: () => _removeProductColor(colorIndex),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            label: const Text('Добавить цвет'),
                            onPressed: _addProductColor,
                          ),
                        ),

                        SizedBox(height: kFieldSpacing * 1.5),
                        const Divider(thickness: 1),
                        SizedBox(height: kFieldSpacing),

                        Text("Размеры и Наличие*", style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        Text("Укажите размеры и количество каждого цвета.", style: theme.textTheme.bodySmall?.copyWith(color: _secondaryTextColor)),
                        SizedBox(height: kFieldSpacing),
                        ..._sizeVariants.asMap().entries.map((entry) {
                          int sizeIndex = entry.key;
                          var sizeVariant = entry.value;
                          List<String> availableColorsToAdd = _getAvailableColorsForSize(sizeIndex);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: kFieldSpacing),
                            child: Card(
                              margin: EdgeInsets.zero,
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
                                            decoration: const InputDecoration(labelText: 'Размер* (напр. 46, M, L)'),
                                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Нужен размер' : null,
                                            onChanged: (value) => setState(() => sizeVariant.size = value),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          color: theme.colorScheme.error,
                                          tooltip: 'Удалить этот размер',
                                          onPressed: () => _removeSizeEntry(sizeIndex),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text("Наличие цветов:", style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.9))),
                                    const SizedBox(height: 8),
                                    if (sizeVariant.colorQuantities.isNotEmpty)
                                      ...sizeVariant.colorQuantities.asMap().entries.map((cqEntry) {
                                        int cqIndex = cqEntry.key;
                                        var colorQuantity = cqEntry.value;
                                        List<String> dropdownOptions = [
                                          if (validColorNames.contains(colorQuantity.colorName)) colorQuantity.colorName,
                                          ...availableColorsToAdd
                                        ].toSet().toList()..sort();
                                        bool isCurrentColorValid = validColorNames.contains(colorQuantity.colorName);
                                        String? currentValue = isCurrentColorValid ? colorQuantity.colorName : null;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: DropdownButtonFormField<String>(
                                                  value: currentValue,
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
                                                    errorText: !isCurrentColorValid && colorQuantity.colorName.isNotEmpty ? 'Цвет удален' : null,
                                                  ),
                                                  validator: (value) => (value == null || value.isEmpty) ? 'Выберите' : null,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 2,
                                                child: TextFormField(
                                                  initialValue: colorQuantity.quantity > 0 ? colorQuantity.quantity.toString() : '',
                                                  decoration: const InputDecoration(labelText: 'Кол-во*', isDense: true),
                                                  keyboardType: TextInputType.number,
                                                  validator: (value) {
                                                    if (value == null || value.isEmpty) return 'Нужно';
                                                    final qty = int.tryParse(value);
                                                    if (qty == null || qty < 0) return '>= 0';
                                                    if (sizeVariant.colorQuantities.length == 1 && qty <= 0) {
                                                      return 'Хотя бы 1';
                                                    }
                                                    return null;
                                                  },
                                                  onChanged: (value) => setState(() => colorQuantity.quantity = int.tryParse(value) ?? 0),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                                                  color: theme.colorScheme.error.withOpacity(0.8),
                                                  tooltip: 'Удалить этот цвет из размера',
                                                  onPressed: () => _removeColorQuantityFromSize(sizeIndex, cqIndex),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    if (sizeVariant.colorQuantities.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                                        child: Text(
                                          validColorNames.isEmpty
                                              ? "Сначала определите цвета в секции выше."
                                              : "Нажмите 'Добавить цвет к размеру'.",
                                          style: const TextStyle(color: _secondaryTextColor, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        label: const Text('Добавить цвет к размеру'),
                                        onPressed: availableColorsToAdd.isNotEmpty && validColorNames.isNotEmpty
                                            ? () => _addColorQuantityToSize(sizeIndex)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить размер'),
                          onPressed: _addSizeEntry,
                        ),
                        SizedBox(height: kFieldSpacing * 1.5),
                        const Divider(thickness: 1),
                        SizedBox(height: kFieldSpacing * 1.5),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _updateProduct,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                          ),
                          child: Text(_isLoading ? 'СОХРАНЕНИЕ...' : 'СОХРАНИТЬ ИЗМЕНЕНИЯ'),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.75),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Остальные методы (buildTextField, buildDropdownField, validate) такие же как в AddProductScreen

  Widget _buildTextField({
    required String label,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    int? maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? initialValue,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        counterText: maxLength != null ? "" : null,
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required FormFieldValidator<T> validator,
    DropdownMenuItem<T> Function(T item)? itemBuilder,
    String Function(T item)? itemTextBuilder,
  }) {
    assert(itemBuilder != null || itemTextBuilder != null, 'Provide either itemBuilder or itemTextBuilder');
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) {
        if (itemBuilder != null) {
          return itemBuilder(item);
        }
        return DropdownMenuItem<T>(
          value: item,
          child: Text(itemTextBuilder!(item)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  String? _validateNotEmpty(String? value, String errorMessage) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage;
    }
    return null;
  }

  String? _validatePositiveDouble(String? value, String errorMessage) {
    if (value == null || value.isEmpty) return errorMessage;
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null || number <= 0) return errorMessage;
    return null;
  }

  String? _validateIntRange(String? value, int min, int max, String errorMessage) {
    if (value == null || value.isEmpty) return errorMessage;
    final number = int.tryParse(value);
    if (number == null || number < min || number > max) {
      return errorMessage;
    }
    return null;
  }

  ThemeData _buildThemeData() {
    final baseTheme = ThemeData.dark();
    return baseTheme.copyWith(
      scaffoldBackgroundColor: _backgroundColor,
      primaryColor: _primaryColor,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: _primaryColor,
        secondary: _primaryColor,
        surface: _surfaceColor,
        background: _backgroundColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        error: _errorColor,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _textFieldFillColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        hintStyle: TextStyle(color: _secondaryTextColor.withOpacity(0.7)),
        labelStyle: TextStyle(color: _secondaryTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: _surfaceColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: _errorColor, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: _errorColor, width: 1.5),
        ),
        errorStyle: TextStyle(color: _errorColor, fontSize: 12),
      ),
      cardTheme: CardTheme(
        elevation: 1.0,
        color: _surfaceColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: Colors.white.withOpacity(0.9),
        displayColor: Colors.white,
      ).copyWith(
        titleLarge: baseTheme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: baseTheme.textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600),
        bodySmall: baseTheme.textTheme.bodySmall?.copyWith(color: _secondaryTextColor),
        labelLarge: baseTheme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: _primaryColor,
            textStyle: const TextStyle(fontWeight: FontWeight.w600)
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: _primaryColor,
            side: BorderSide(color: _primaryColor, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            textStyle: const TextStyle(fontWeight: FontWeight.w600)
        ),
      ),
      dividerTheme: DividerThemeData(
        color: _secondaryTextColor.withOpacity(0.3),
        thickness: 1,
        space: 32,
      ),
      iconTheme: IconThemeData(
        color: _secondaryTextColor,
        size: 24.0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _textFieldFillColor,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 4.0,
      ),
    );
  }
}
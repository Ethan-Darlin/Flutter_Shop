import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/profileScreen.dart';
import 'package:shop/screens/cartScreen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shop/screens/productDetailScreen.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  int _selectedIndex = 0;
  String _searchQuery = "";

  int? _selectedCategory;
  String? _selectedGender;
  String? _selectedSize;
  String? _selectedColor;
  String? _selectedSeason;
  String? _selectedBrand;
  String? _otherBrandName;
  String? _selectedMaterial;
  bool _isFiltersVisible = false;
  RangeValues _tempWeightRange = const RangeValues(0, 5);
  RangeValues _weightRange = const RangeValues(0, 5);
  RangeValues _priceRange = const RangeValues(0, 3000);
  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedSize = null;
      _selectedColor = null;
      _selectedSeason = null;
      _selectedBrand = null;
      _selectedMaterial = null;
      _priceRange = const RangeValues(0, 10000);
      _weightRange = const RangeValues(0, 20);
      _searchQuery = "";
    });
  }


  final List<String> _genderOptions = ['Мужской', 'Женский', 'Унисекс'];

  final Color _backgroundColor = Color(0xFF18171c);
  final Color _surfaceColor = Color(0xFF25252C);
  final Color _primaryColor = Color(0xFFEE3A57);
  final Color _secondaryTextColor = Colors.grey[400]!;
  final Color _textFieldFillColor = Color(0xFF25252C);

  final List<String> _colors = ['Красный', 'Синий', 'Зелёный', 'Черный', 'Белый'];
  final List<String> _seasons = ['Зима', 'Лето', 'Осень', 'Весна'];
  final List<String> _brands = ['Nike', 'Adidas', 'Puma', 'Reebok'];
  final List<String> _materials = ['Хлопок', 'Полиэстер', 'Кожа', 'Шерсть'];

  @override

  void initState() {

    super.initState();

    _productsFuture = FirebaseService().getProducts();

    _categoriesFuture = FirebaseService().getCategories();

  }

  void _showPriceRangeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _backgroundColor,
          title: Text('Выберите диапазон цен',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RangeSlider(
                values: _weightRange.start < 0 || _weightRange.end > 5
                    ? const RangeValues(0, 5)
                    : _weightRange,
                min: 0,
                max: 5,
                divisions: 50,
                onChanged: (range) {
                  setState(() {
                    _weightRange = range;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Применить', style: TextStyle(color: _primaryColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Поиск товаров...',
                    hintStyle: TextStyle(color: _secondaryTextColor),
                    filled: true,
                    fillColor: _surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    prefixIcon:
                    Icon(Icons.search, color: _secondaryTextColor),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isFiltersVisible
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isFiltersVisible = !_isFiltersVisible;
                  });
                },
              ),
            ],
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isFiltersVisible ? null : 0,
            child: Visibility(
              visible: _isFiltersVisible,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FutureBuilder<List<Map<String, dynamic>>>(

                        future: _categoriesFuture,

                        builder: (context, snapshot) {

                          if (snapshot.connectionState == ConnectionState.waiting) {

                            return DropdownButton<String>(

                              value: null,

                              hint: Text('Загрузка...', style: TextStyle(color: _secondaryTextColor)),

                              items: null,

                              onChanged: null,

                              style: TextStyle(color: Colors.white),

                              icon: Icon(Icons.arrow_drop_down, color: _secondaryTextColor),

                              underline: SizedBox.shrink(),

                            );

                          } else if (snapshot.hasError) {

                            return Text('Ошибка загрузки категорий', style: TextStyle(color: Colors.red));

                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {

                            return DropdownButton<String>(

                              value: null,

                              hint: Text('Нет категорий', style: TextStyle(color: _secondaryTextColor)),

                              items: null,

                              onChanged: null,

                              style: TextStyle(color: Colors.white),

                              icon: Icon(Icons.arrow_drop_down, color: _secondaryTextColor),

                              underline: SizedBox.shrink(),

                            );

                          }

                          final categories = snapshot.data!;

                          return DropdownButton<int>(
                            value: _selectedCategory,
                            hint: Text('Категория', style: TextStyle(color: _secondaryTextColor)),
                            dropdownColor: _surfaceColor,
                            items: categories.map((category) {
                              return DropdownMenuItem<int>(
                                value: category['category_id'], // Используем ID категории
                                child: Text(category['name'], style: TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value; // Сохраняем ID категории
                              });
                            },
                            style: TextStyle(color: Colors.white),
                            icon: Icon(Icons.arrow_drop_down, color: _secondaryTextColor),
                            underline: SizedBox.shrink(),
                          );

                        },

                      ),
                      Container(
                        width: 150,
                        child: TextFormField(
                          initialValue: _selectedSize,
                          decoration: InputDecoration(
                            hintText: 'Размер',
                            hintStyle:
                            TextStyle(color: _secondaryTextColor),
                            filled: true,
                            fillColor: _surfaceColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          style: TextStyle(color: Colors.white),
                          onChanged: (value) {
                            setState(() {
                              _selectedSize = value.trim();
                            });
                          },
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedColor,
                        hint: Text('Цвет',
                            style: TextStyle(color: _secondaryTextColor)),
                        dropdownColor: _surfaceColor,
                        items: _colors.map((color) {
                          return DropdownMenuItem(
                            value: color,
                            child: Text(color,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedColor = value;
                          });
                        },
                        style: TextStyle(color: Colors.white),
                        icon: Icon(Icons.arrow_drop_down,
                            color: _secondaryTextColor),
                        underline: SizedBox.shrink(),
                      ),
                      DropdownButton<String>(
                        value: _selectedSeason,
                        hint: Text('Сезон',
                            style: TextStyle(color: _secondaryTextColor)),
                        dropdownColor: _surfaceColor,
                        items: _seasons.map((season) {
                          return DropdownMenuItem(
                            value: season,
                            child: Text(season,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSeason = value;
                          });
                        },
                        style: TextStyle(color: Colors.white),
                        icon: Icon(Icons.arrow_drop_down,
                            color: _secondaryTextColor),
                        underline: SizedBox.shrink(),
                      ),
                      DropdownButton<String>(
                        value: _selectedBrand,
                        hint: Text('Бренд',
                            style: TextStyle(color: _secondaryTextColor)),
                        dropdownColor: _surfaceColor,
                        items: [..._brands, 'Другой'].map((brand) {
                          return DropdownMenuItem(
                            value: brand,
                            child: Text(brand,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBrand = value;
                            if (value == 'Другой') {
                              _otherBrandName = '';
                            }
                          });
                        },
                        style: TextStyle(color: Colors.white),
                        icon: Icon(Icons.arrow_drop_down,
                            color: _secondaryTextColor),
                        underline: SizedBox.shrink(),
                      ),
                      if (_selectedBrand == 'Другой')
                        Container(
                          width: 200,
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: 'Введите бренд',
                              hintStyle:
                              TextStyle(color: _secondaryTextColor),
                              filled: true,
                              fillColor: _surfaceColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            style: TextStyle(color: Colors.white),
                            onChanged: (value) {
                              setState(() {
                                _otherBrandName = value.trim();
                              });
                            },
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Вес (кг): ${_tempWeightRange.start.toStringAsFixed(2)} - ${_tempWeightRange.end.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.white),
                          ),
                          RangeSlider(
                            values: _tempWeightRange,
                            min: 0,
                            max: 5,
                            divisions: 20,
                            activeColor: _primaryColor,
                            inactiveColor: _secondaryTextColor,
                            labels: RangeLabels(
                              _tempWeightRange.start.toStringAsFixed(2),
                              _tempWeightRange.end.toStringAsFixed(2),
                            ),
                            onChanged: (range) {
                              setState(() {
                                _tempWeightRange = range;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Новая кнопка сброса
                        ElevatedButton.icon(
                          onPressed: _resetFilters,
                          icon: Icon(Icons.refresh, color: Colors.white),
                          label: Text('Сбросить', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        // Существующая кнопка поиска
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _weightRange = _tempWeightRange;
                            });
                          },
                          icon: Icon(Icons.search, color: Colors.white),
                          label: Text('Поиск', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWeightRangeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _backgroundColor,
              title: Text('Выберите диапазон веса',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RangeSlider(
                    values: _weightRange,
                    min: 0,
                    max: 20,
                    divisions: 40,
                    activeColor: _primaryColor,
                    inactiveColor: _secondaryTextColor,
                    labels: RangeLabels(
                      '${_weightRange.start.toInt()} кг',
                      '${_weightRange.end.toInt()} кг',
                    ),
                    onChanged: (range) {
                      setDialogState(() {
                        _weightRange = range;
                      });
                      setState(() {
                        _weightRange = range;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                  Text('Применить', style: TextStyle(color: _primaryColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String formatPrice(dynamic price) {
    double priceDouble;
    if (price is double) {
      priceDouble = price;
    } else if (price is int) {
      priceDouble = price.toDouble();
    } else if (price is String) {
      priceDouble = double.tryParse(price) ?? 0.0;
    } else {
      priceDouble = 0.0;
    }

    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();

    if (kopecks == 0) {
      return '$rubles BYN';
    } else {
      String kopecksStr = kopecks.toString().padLeft(2, '0');
      return '$rubles.$kopecksStr BYN';
    }
  }

  void onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => CartScreen()))
            .then((_) {});
        break;
      case 2:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => ProfileScreen()));
        break;
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: TextField(
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Поиск товаров...',
          hintStyle: TextStyle(color: _secondaryTextColor),
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _primaryColor.withOpacity(0.5), width: 1)),
          prefixIcon: Icon(Icons.search, color: _secondaryTextColor),
          contentPadding: EdgeInsets.symmetric(vertical: 14.0),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products) {
    final query = _searchQuery.trim().toLowerCase();

    final List<Map<String, dynamic>> nameMatches = [];
    final List<Map<String, dynamic>> descriptionMatches = [];
    final List<Map<String, dynamic>> brandMatches = [];

    for (final product in products) {
      final bool categoryMatches = _selectedCategory == null ||
          (product['category_id'] != null &&
              product['category_id'] == _selectedCategory); // Сравниваем int с int

      final bool sizeMatches = _selectedSize == null ||
          ((product['sizes'] as Map<String, dynamic>?)?.containsKey(_selectedSize) == true);

      final bool colorMatches = _selectedColor == null ||
          ((product['sizes'] as Map<String, dynamic>?)?.values.any((sizeData) {
            final Map<String, dynamic>? colorQuantities =
            sizeData['color_quantities'] as Map<String, dynamic>?;
            return colorQuantities != null &&
                colorQuantities.containsKey(_selectedColor);
          }) ??
              false);

      final bool seasonMatches = _selectedSeason == null ||
          product['season'] == _selectedSeason;

      final bool brandFilterMatches = _selectedBrand == null ||
          (_selectedBrand == 'Другой'
              ? (_otherBrandName != null && _otherBrandName!.isNotEmpty
              ? product['brand']?.toString().toLowerCase() ==
              _otherBrandName!.toLowerCase()
              : true)
              : product['brand'] == _selectedBrand);

      final bool materialMatches = _selectedMaterial == null ||
          product['material'] == _selectedMaterial;

      final bool weightMatches = product['weight'] != null &&
          product['weight'] >= _weightRange.start &&
          product['weight'] <= _weightRange.end;

      final bool priceMatches = product['price'] != null &&
          product['price'] >= _priceRange.start &&
          product['price'] <= _priceRange.end;

      if (!(categoryMatches &&
          sizeMatches &&
          colorMatches &&
          seasonMatches &&
          brandFilterMatches &&
          materialMatches &&
          weightMatches &&
          priceMatches)) {
        continue;
      }

      final String name = (product['name']?.toString().toLowerCase() ?? '');
      final String description =
      (product['description']?.toString().toLowerCase() ?? '');
      final String brand =
      (product['brand']?.toString().toLowerCase() ?? '');

      if (query.isEmpty) {
        nameMatches.add(product);
      } else if (name.contains(query)) {
        nameMatches.add(product);
      } else if (description.contains(query)) {
        descriptionMatches.add(product);
      } else if (brand.contains(query)) {
        brandMatches.add(product);
      }
    }

    final filteredProducts = [
      ...nameMatches,
      ...descriptionMatches,
      ...brandMatches,
    ];

    if (filteredProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Нет товаров, соответствующих вашим критериям.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryTextColor),
          ),
        ),
      );
    }

    return GridView.builder(
      padding:
      const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.54,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(filteredProducts[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = product['main_image_url'] as String?;
    int totalQuantity = 0;
    final sizesData = product['sizes'] as Map<String, dynamic>?;
    if (sizesData != null) {
      sizesData.forEach((size, sizeValue) {
        if (sizeValue is Map<String, dynamic>) {
          final colorsData =
          sizeValue['color_quantities'] as Map<String, dynamic>?;
          if (colorsData != null) {
            colorsData.forEach((color, quantity) {
              if (quantity is int) {
                totalQuantity += quantity;
              }
            });
          }
        }
      });
    }

    final bool isOutOfStock = totalQuantity <= 0;
    final productId = product['product_id']?.toString();

    return Card(
      elevation: 0,
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (productId != null) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ProductDetailScreen(productId: productId)));
          } else {
            print(
                "Error: Product ID is null for product ${product['name']}");
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Не удалось открыть товар.'),
                backgroundColor: Colors.red));
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                color: _textFieldFillColor,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image,
                        color: _secondaryTextColor,
                        size: 40))
                    : Center(
                    child: Icon(Icons.image_not_supported,
                        color: _secondaryTextColor, size: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatPrice(product['price']),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  SizedBox(height: 6),
                  Text(
                    product['name'] ?? 'Название товара',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    product['description'] ?? '',
                    style: TextStyle(
                        color: _secondaryTextColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (productId == null || isOutOfStock)
                          ? null
                          : () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    ProductDetailScreen(productId: productId)));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock
                            ? Colors.grey[700]
                            : _primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                        Colors.grey[700]?.withOpacity(0.7),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        elevation: 0,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                          isOutOfStock ? 'Нет в наличии' : 'Подробнее'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child:
                        CircularProgressIndicator(color: _primaryColor));
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'Ошибка загрузки товаров: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text('Товаров пока нет.',
                              style: TextStyle(
                                  color: _secondaryTextColor, fontSize: 16)),
                        ));
                  }
                  return SingleChildScrollView(
                    child: _buildProductGrid(snapshot.data!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Корзина'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: _primaryColor,
        unselectedItemColor: _secondaryTextColor,
        backgroundColor: Color(0xFF1f1f24),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: onItemTapped,
      ),
    );
  }
}
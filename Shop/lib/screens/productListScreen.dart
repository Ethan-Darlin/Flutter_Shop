import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';
import 'package:shop/screens/cartScreen.dart';
import 'package:shop/screens/profileScreen.dart'; // Импортируйте экран профиля
import 'dart:convert';
import 'dart:typed_data';
import 'package:shop/screens/productDetailScreen.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  int _selectedIndex = 0; // 0: Home, 1: Cart, 2: Profile
  String _searchQuery = "";

  // --- Цвета в стиле экрана Профиля ---
  final Color _backgroundColor = Color(0xFF18171c); // Основной фон
  final Color _surfaceColor = Color(0xFF25252C); // Цвет карточек, полей
  final Color _primaryColor = Color(0xFFEE3A57); // Акцентный цвет (кнопки и т.д.)
  final Color _secondaryTextColor = Colors.grey[400]!; // Вторичный текст
  final Color _textFieldFillColor = Color.fromRGBO(50, 37, 67, 1); // Фон поля поиска (можно сделать = _surfaceColor)
  // final Color _textFieldFillColor = Color(0xFF25252C); // Альтернатива для поля поиска

  @override
  void initState() {
    super.initState();
    _productsFuture = FirebaseService().getProducts();
  }

  // --- Функции (без существенных изменений) ---

  Future<void> _addToCart(Map<String, dynamic> product) async {
    // Добавляем try-catch для обработки возможных ошибок Firebase
    try {
      await FirebaseService().addToCart(product);
      if (mounted) { // Проверяем, что виджет все еще в дереве
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} (${product['selected_size']}) добавлен в корзину'),
            backgroundColor: Colors.green, // Успешное добавление
          ),
        );
      }
    } catch (e) {
      print("Ошибка добавления в корзину: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка добавления товара в корзину.'),
            backgroundColor: Colors.redAccent, // Ошибка
          ),
        );
      }
    }
  }

  // Форматирование цены (можно улучшить для обработки не-double)
  String formatPrice(dynamic price) {
    // Попытка конвертировать в double
    double priceDouble;
    if (price is double) {
      priceDouble = price;
    } else if (price is int) {
      priceDouble = price.toDouble();
    } else if (price is String) {
      priceDouble = double.tryParse(price) ?? 0.0;
    } else {
      priceDouble = 0.0; // Значение по умолчанию, если тип неизвестен
    }

    int rubles = priceDouble.toInt();
    int kopecks = ((priceDouble - rubles) * 100).round();

    if (kopecks == 0) {
      return '$rubles ₽'; // Используем символ рубля
    } else {
      // Форматируем копейки, чтобы всегда было 2 знака (05, 10, 50)
      String kopecksStr = kopecks.toString().padLeft(2, '0');
      return '$rubles.$kopecksStr ₽'; // Например: 123.50 ₽
    }
  }

  void onItemTapped(int index) {
    // Предотвращаем ненужную навигацию на текущий экран
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Главная (уже здесь)
      // Ничего не делаем или перезагружаем данные, если нужно
      // setState(() {
      //   _productsFuture = FirebaseService().getProducts();
      // });
        break;
      case 1: // Корзина
        Navigator.push( // Используем push, чтобы можно было вернуться
          context,
          MaterialPageRoute(builder: (context) => CartScreen()),
        ).then((_) {
          // Сбрасываем индекс на "Главная" при возвращении из корзины,
          // если это желаемое поведение.
          // Если нужно оставаться на индексе корзины, убери этот .then
          if (mounted) {
            setState(() { _selectedIndex = 0; });
          }
        });
        break;
      case 2: // Профиль
        Navigator.pushReplacement( // Заменяем текущий экран, без возврата сюда
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        );
        break;
    }
  }

  // --- Модальные окна с обновленным стилем ---
  void _showSizeSelectionDialog(Map<String, dynamic> product) {
    final sizeStock = product['size_stock'] as Map<String, dynamic>? ?? {};
    // Фильтруем размеры, которых нет в наличии (количество > 0)
    final availableSizes = sizeStock.entries
        .where((entry) => (entry.value is int && entry.value > 0) || (entry.value is String && int.tryParse(entry.value) != null && int.parse(entry.value) > 0))
        .toList();


    // Если нет доступных размеров, показываем сообщение и не открываем окно
    if (availableSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('К сожалению, все размеры этого товара закончились.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Делаем фон прозрачным
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(top: 20, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20), // Отступы + учет клавиатуры
          decoration: BoxDecoration(
              color: _surfaceColor, // Используем цвет фона карточек
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)
              )
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Высота по контенту
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Выберите размер',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 12),
              Divider(color: _secondaryTextColor.withOpacity(0.3), height: 1),
              SizedBox(height: 16),
              Wrap( // Используем Wrap для кнопок размеров
                spacing: 10, // Горизонтальный отступ
                runSpacing: 10, // Вертикальный отступ
                children: availableSizes.map<Widget>((entry) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _textFieldFillColor, // Фон кнопок
                      foregroundColor: Colors.white, // Цвет текста
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Закрываем окно выбора размера
                      _showQuantityDialog(product, entry.key); // Открываем окно количества
                    },
                    child: Text(entry.key),
                  );
                }).toList(),
              ),
              SizedBox(height: 10), // Небольшой отступ снизу
            ],
          ),
        );
      },
    );
  }

  void _showQuantityDialog(Map<String, dynamic> product, String selectedSize) {
    int quantity = 1;
    final sizeStock = product['size_stock'] as Map<String, dynamic>? ?? {};
    final maxQuantity = (sizeStock[selectedSize] is int)
        ? sizeStock[selectedSize]
        : int.tryParse(sizeStock[selectedSize]?.toString() ?? '0') ?? 0;


    if (maxQuantity < 1) {
      // Дополнительная проверка, если вдруг вызвали для отсутствующего размера
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Размер $selectedSize не доступен.'), backgroundColor: Colors.redAccent),
      );
      return;
    }


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(top: 20, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)
              )
          ),
          child: StatefulBuilder( // Нужен для обновления счетчика
            builder: (BuildContext context, StateSetter setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Количество для размера: $selectedSize',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 12),
                  Divider(color: _secondaryTextColor.withOpacity(0.3), height: 1),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Кнопка Минус
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _textFieldFillColor,
                          foregroundColor: Colors.white,
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                        onPressed: quantity > 1 ? () { // Не даем уйти ниже 1
                          setStateModal(() { quantity--; });
                        } : null, // Делаем неактивной, если quantity = 1
                        child: Icon(Icons.remove),
                      ),
                      SizedBox(width: 24),
                      // Текст Количество
                      Text(
                          '$quantity',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      SizedBox(width: 24),
                      // Кнопка Плюс
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _textFieldFillColor,
                          foregroundColor: Colors.white,
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                        onPressed: quantity < maxQuantity ? () { // Не даем выбрать больше, чем есть
                          setStateModal(() { quantity++; });
                        } : null, // Делаем неактивной, если достигли максимума
                        child: Icon(Icons.add),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Кнопка Добавить в корзину
                  SizedBox( // Растягиваем кнопку
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.shopping_cart_checkout),
                      label: Text('Добавить в корзину'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor, // Основной акцентный цвет
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        _addToCart({
                          ...product, // Копируем данные продукта
                          'selected_size': selectedSize,
                          'quantity': quantity,
                        });
                        Navigator.of(context).pop(); // Закрываем окно
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              );
            },
          ),
        );
      },
    );
  }


  // --- Методы построения UI ---

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: TextField(
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Поиск товаров...',
          hintStyle: TextStyle(color: _secondaryTextColor),
          filled: true,
          fillColor: _surfaceColor, // Фон поля
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // Убираем границу
          ),
          focusedBorder: OutlineInputBorder( // Граница при фокусе (можно сделать акцентной)
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1)
          ),
          prefixIcon: Icon(Icons.search, color: _secondaryTextColor),
          contentPadding: EdgeInsets.symmetric(vertical: 14.0), // Вертикальный отступ внутри поля
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
    // Фильтрация продуктов по поисковому запросу
    final filteredProducts = products
        .where((product) =>
    (product['name']?.toString().toLowerCase() ?? '')
        .contains(_searchQuery) ||
        (product['description']?.toString().toLowerCase() ?? '')
            .contains(_searchQuery))
        .toList();


    if (filteredProducts.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'По запросу "$_searchQuery" ничего не найдено.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryTextColor, fontSize: 16),
          ),
        ),
      );
    }
    if (filteredProducts.isEmpty && products.isNotEmpty) {
      // Случай, когда товары есть, но поиск их все отфильтровал
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Товары не найдены.',
            style: TextStyle(color: _secondaryTextColor, fontSize: 16),
          ),
        ),
      );
    }


    return GridView.builder(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0), // Отступы для сетки
      shrinkWrap: true, // Важно для GridView внутри SingleChildScrollView/Column
      physics: NeverScrollableScrollPhysics(), // Отключаем собственную прокрутку сетки
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Два товара в ряду
        childAspectRatio: 0.556, // Соотношение сторон карточки (ширина / высота), подбирай экспериментально
        crossAxisSpacing: 12, // Горизонтальный отступ между карточками
        mainAxisSpacing: 12, // Вертикальный отступ между карточками
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(filteredProducts[index]); // Используем отдельный метод
      },
    );
  }


  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = product['image_url'];
    Uint8List? imageBytes;


    if (imageUrl is String && imageUrl.isNotEmpty) {
      try {
        // Убираем возможные префиксы data:image/...;base64,
        final base64String = imageUrl.split(',').last;
        imageBytes = base64Decode(base64String);
      } catch (e) {
        print('Ошибка декодирования изображения для ${product['name']}: $e');
        imageBytes = null; // Оставляем null в случае ошибки
      }
    }


    // Подсчет общего количества всех размеров
    final sizeStock = product['size_stock'] as Map<String, dynamic>? ?? {};
    final totalQuantity = sizeStock.values
        .map((q) => (q is int) ? q : int.tryParse(q?.toString() ?? '0') ?? 0) // Безопасное преобразование
        .fold<int>(0, (sum, quantity) => sum + quantity); // Явное указание типа для fold
    final bool isLowStock = totalQuantity > 0 && totalQuantity < 10; // Флаг "мало товара"
    final bool isOutOfStock = totalQuantity <= 0; // Флаг "нет в наличии"


    return Card(
      elevation: 0, // Убираем стандартную тень
      color: _surfaceColor, // Цвет фона карточки из темы
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Скругление углов
      ),
      clipBehavior: Clip.antiAlias, // Обрезка содержимого (важно для ClipRRect внутри)
      child: InkWell( // Делаем карточку кликабельной
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание контента по левому краю
          children: [
            // --- Изображение ---
            AspectRatio( // Задает соотношение сторон для области изображения
              aspectRatio: 1.0, // Квадратное изображение (1/1)
              child: Container(
                color: _textFieldFillColor, // Фон-заглушка
                child: imageBytes != null
                    ? Image.memory(
                  imageBytes,
                  fit: BoxFit.cover, // Масштабирование изображения
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: _secondaryTextColor, size: 40),
                )
                    : Center(child: Icon(Icons.image_not_supported, color: _secondaryTextColor, size: 40)), // Иконка-заглушка
              ),
            ),


            // --- Информация о товаре (с отступами) ---
            Padding(
              padding: const EdgeInsets.all(5.0), // Внутренние отступы для текста и кнопки
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Цена и индикатор наличия ---
                  Row(
                    children: [
                      Text(
                        formatPrice(product['price']),
                        style: TextStyle(
                            color: isLowStock ? _primaryColor : Colors.white, // Красный цвет цены при малом остатке
                            fontWeight: FontWeight.bold,
                            fontSize: 15
                        ),
                      ),
                      SizedBox(width: 6),
                      if (isLowStock) // Иконка "огонь" или "%", если мало товара
                        Image.asset(
                          'assets/images/procent.png', // Убедись, что путь правильный
                          height: 16,
                          width: 16,
                          color: _primaryColor, // Можно окрасить иконку в цвет акцента
                        ),
                      if (isOutOfStock)
                        Text(
                          '(нет)',
                          style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                        ),
                    ],
                  ),
                  SizedBox(height: 6),


                  // --- Название товара ---
                  Text(
                    product['name'] ?? 'Название товара',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2, // Максимум 2 строки
                    overflow: TextOverflow.ellipsis, // Многоточие при переполнении
                  ),
                  SizedBox(height: 4),


                  // --- Краткое Описание (опционально) ---
                  Text(
                    product['description'] ?? '',
                    style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                    maxLines: 1, // Максимум 1 строка для краткости
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8), // Отступ перед кнопкой


                  // --- Кнопка "В корзину" ---
                  SizedBox( // Растягиваем кнопку на всю ширину паддинга
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isOutOfStock ? null : () => _showSizeSelectionDialog(product), // Блокируем, если нет в наличии
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock ? Colors.grey[700] : _primaryColor, // Серый цвет, если нет в наличии
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        elevation: 0, // Убираем тень кнопки
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Уменьшает область нажатия
                      ),
                      child: Text(isOutOfStock ? 'Нет в наличии' : 'В корзину'),
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
      backgroundColor: _backgroundColor, // Используем цвет фона из темы
      body: SafeArea( // Отступы от системных элементов (статус бар)
        child: Column( // Основная колонка для поиска и сетки
          children: [
            _buildSearchBar(), // Строка поиска
            Expanded( // Занимает все оставшееся место для скроллящегося контента
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Более красивый индикатор загрузки
                    return Center(child: CircularProgressIndicator(color: _primaryColor));
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text('Ошибка загрузки товаров: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.redAccent)),
                        ));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text('Товаров пока нет.',
                              style: TextStyle(color: _secondaryTextColor, fontSize: 16)),
                        ));
                  }


                  // Используем SingleChildScrollView ЗДЕСЬ, чтобы скроллилась только сетка
                  return SingleChildScrollView(
                    child: _buildProductGrid(snapshot.data!), // Сетка товаров
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
            icon: Icon(Icons.home_outlined), // Иконки в стиле outline
            activeIcon: Icon(Icons.home), // Активная иконка
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Корзина',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFFEE3A57), // Цвет активного элемента
        unselectedItemColor: Colors.grey[400], // Цвет неактивных элементов
        backgroundColor: Color(0xFF1f1f24), // Фон панели (чуть светлее основного)
        type: BottomNavigationBarType.fixed, // Чтобы все элементы отображались
        selectedFontSize: 12, // Размер шрифта активного
        unselectedFontSize: 12, // Размер шрифта неактивного
        onTap: onItemTapped, // Используем ваш обработчик нажатий
      ),
    );
  }
}
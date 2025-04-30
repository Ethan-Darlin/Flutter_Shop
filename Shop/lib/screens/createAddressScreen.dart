import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shop/firebase_service.dart';

class CreateAddressScreen extends StatefulWidget {
  @override
  _CreateAddressScreenState createState() => _CreateAddressScreenState();
}

class _CreateAddressScreenState extends State<CreateAddressScreen> {
  final TextEditingController _addressController = TextEditingController();
  LatLng? _selectedLocation; // Выбранное местоположение на карте

  Future<void> _addDeliveryAddress() async {
    final deliveryAddress = _addressController.text.trim();

    if (deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, введите адрес.')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, выберите местоположение на карте.')),
      );
      return;
    }

    print('Добавляем адрес: $deliveryAddress');
    print('Координаты: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}');

    String? deliveryId = await FirebaseService().addDelivery({
      'delivery_address': deliveryAddress,
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
    });

    if (deliveryId != null) {
      print('Адрес успешно добавлен. ID: $deliveryId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Адрес успешно добавлен!')),
      );
      Navigator.pop(context); // Возвращаемся на предыдущий экран
    } else {
      print('Ошибка при добавлении адреса.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при добавлении адреса.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Создать новый адрес'),
        backgroundColor: const Color(0xFF18171c),
      ),
      body: Column(
        children: [
          // Поле ввода адреса
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Введите адрес доставки',
                errorText: _addressController.text.isEmpty ? 'Адрес не может быть пустым' : null,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Карта для выбора местоположения
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(53.9006, 27.5590),
                zoom: 12.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point; // Сохраняем выбранное место
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        builder: (ctx) => Icon(
                          Icons.location_pin,
                          size: 40.0,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Кнопка добавления адреса
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _addDeliveryAddress,
              child: Text('Добавить адрес'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFFEE3A57),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
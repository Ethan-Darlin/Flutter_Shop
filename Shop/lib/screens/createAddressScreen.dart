import 'package:flutter/material.dart';
import 'package:shop/firebase_service.dart';

class CreateAddressScreen extends StatefulWidget {
  @override
  _CreateAddressScreenState createState() => _CreateAddressScreenState();
}

class _CreateAddressScreenState extends State<CreateAddressScreen> {
  final TextEditingController _addressController = TextEditingController();

  Future<void> _addDeliveryAddress() async {
    final deliveryAddress = _addressController.text.trim();

    if (deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, введите адрес.')),
      );
      return;
    }

    String? deliveryId = await FirebaseService().addDelivery(deliveryAddress);
    if (deliveryId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Адрес успешно добавлен!')),
      );
      Navigator.pop(context); // Возвращаемся на предыдущий экран
    } else {
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Введите адрес доставки',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addDeliveryAddress,
              child: Text('Добавить адрес'),
            ),
          ],
        ),
      ),
    );
  }
}
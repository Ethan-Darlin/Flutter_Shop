import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRScanPage extends StatefulWidget {
  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  MobileScannerController cameraController = MobileScannerController();
  String? scannedOrderId; // Теперь хранит ID документа Firestore
  Map<String, dynamic>? orderData;
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderData(String orderId) async {
    try {
      final orderSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .doc(orderId) // Используем orderId напрямую как ID документа
          .get();

      if (orderSnapshot.exists) {
        setState(() {
          orderData = orderSnapshot.data()!;
        });
      } else {
        setState(() {
          orderData = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Заказ с ID $orderId не найден.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки данных заказа: $e')),
      );
    }
  }

  Future<void> _updateOrderStatus() async {
    if (scannedOrderId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('order_items')
            .doc(scannedOrderId!) // Используем сохраненный ID документа
            .update({'item_status': 'completed'});

        setState(() {
          if (orderData != null) {
            orderData!['item_status'] = 'completed';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Статус заказа обновлен на "Завершено".')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления статуса: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось определить ID заказа для обновления.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканирование QR-кода'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (barcodeCapture) async {
                if (isScanning) {
                  final List<Barcode> barcodes = barcodeCapture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? code = barcodes.first.rawValue;
                    if (code != scannedOrderId) {
                      setState(() {
                        scannedOrderId = code;
                        orderData = null;
                      });
                      if (scannedOrderId != null) {
                        await _fetchOrderData(scannedOrderId!);
                        if (orderData != null) {
                          setState(() => isScanning = false);
                          cameraController.stop();
                        }
                      }
                    }
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: orderData != null
                ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Информация о заказе:',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('Название: ${orderData!['name'] ?? 'Неизвестно'}'),
                  Text(
                      'Статус: ${orderData!['item_status'] ?? 'Неизвестно'}'),
                  Text(
                      'Количество: ${orderData!['quantity'] ?? 'Неизвестно'}'),
                  Text('Цена: ${orderData!['price'] ?? 'Не указана'}'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await _updateOrderStatus();
                    },
                    child: Text('Изменить статус на "Завершено"'),
                  ),
                ],
              ),
            )
                : Center(
              child: Text(
                'Отсканируйте QR-код, чтобы отобразить информацию о заказе.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
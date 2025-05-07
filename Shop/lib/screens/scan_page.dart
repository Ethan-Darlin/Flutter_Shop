import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _backgroundColor = Color(0xFF18171c); 
const Color _surfaceColor = Color(0xFF1f1f24); 
const Color _primaryColor = Color(0xFFEE3A57); 
const Color _secondaryTextColor = Color(0xFFa0a0a0); 
const Color _textFieldFillColor = Color(0xFF2a2a2e); 
const Color _errorColor = Color(0xFFD32F2F); 

class QRScanPage extends StatefulWidget {
  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  MobileScannerController cameraController = MobileScannerController();
  String? scannedOrderId;
  Map<String, dynamic>? orderData;
  bool isScanning = true;
  String? selectedStatus; 

  final List<String> _statusOptions = ['Возврат', 'Выдан', 'Доставлен', 'В пути'];

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
          .doc(orderId)
          .get();

      if (orderSnapshot.exists) {
        setState(() {
          orderData = orderSnapshot.data()!;
        });
      } else {
        setState(() {
          orderData = null;
        });
        _showSnackBar('Заказ с ID $orderId не найден.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Ошибка загрузки данных заказа: $e', isError: true);
    }
  }

  Future<void> _updateOrderStatus() async {
    if (scannedOrderId != null && selectedStatus != null) {
      try {
        await FirebaseFirestore.instance
            .collection('order_items')
            .doc(scannedOrderId!)
            .update({'item_status': selectedStatus});

        setState(() {
          if (orderData != null) {
            orderData!['item_status'] = selectedStatus;
          }
        });

        _showSnackBar('Статус заказа обновлен на "$selectedStatus".');
      } catch (e) {
        _showSnackBar('Ошибка обновления статуса: $e', isError: true);
      }
    } else {
      _showSnackBar(
        'Не удалось определить ID заказа или статус для обновления.',
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _surfaceColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        margin: EdgeInsets.all(16.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Сканирование QR-кода',
          style: TextStyle(color: Colors.white), 
        ),
        backgroundColor: _surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white, 
        ),

      ),
      body: Column(
        children: <Widget>[

          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
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
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: _primaryColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Отсканируйте QR-код',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: orderData != null
                    ? _buildOrderDetails()
                    : Center(
                  child: Text(
                    'Отсканируйте QR-код, чтобы отобразить информацию о заказе.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondaryTextColor),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Информация о заказе:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 10),
        _buildInfoRow('Название:', orderData!['name'] ?? 'Неизвестно'),
        _buildInfoRow('Статус:', orderData!['item_status'] ?? 'Неизвестно'),
        _buildInfoRow('Количество:', orderData!['quantity']?.toString() ?? 'Неизвестно'),
        _buildInfoRow('Цена:', '${orderData!['price'] ?? 'Не указана'} ₽'),
        SizedBox(height: 20),

        DropdownButtonFormField<String>(
          value: selectedStatus,
          decoration: InputDecoration(
            labelText: 'Изменить статус',
            labelStyle: TextStyle(color: _secondaryTextColor),
            filled: true,
            fillColor: _textFieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: _backgroundColor, 
          items: _statusOptions.map((status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Text(
                status,
                style: TextStyle(color: Colors.white), 
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedStatus = value;
            });
          },
        ),
        SizedBox(height: 20),

        Center(
          child: ElevatedButton.icon(
            onPressed: _updateOrderStatus,
            icon: Icon(Icons.check_circle_outline, color: Colors.white),
            label: Text(
              'Применить статус',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: _secondaryTextColor, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
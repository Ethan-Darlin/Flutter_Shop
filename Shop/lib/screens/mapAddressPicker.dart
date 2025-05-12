import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shop/firebase_service.dart';

class MapAddressPicker extends StatefulWidget {
  @override
  _MapAddressPickerState createState() => _MapAddressPickerState();
}

class _MapAddressPickerState extends State<MapAddressPicker> {
  late Future<List<Map<String, dynamic>>> _deliveryAddressesFuture;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _deliveryAddressesFuture = FirebaseService().getAllDeliveryAddresses();
  }

  @override
  Widget build(BuildContext context) {
    const Color _surfaceColor = Color(0xFF1f1f24);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        title: const Text(
          'Выберите адрес',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _deliveryAddressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки адресов',
                style: TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Нет доступных адресов.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final addresses = snapshot.data!;
          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  center: LatLng(53.9006, 27.5590),
                  zoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: addresses.map((address) {
                      final latitude = address['latitude'] as double;
                      final longitude = address['longitude'] as double;
                      final deliveryAddress = address['delivery_address'] as String;

                      return Marker(
                        point: LatLng(latitude, longitude),
                        width: 40,
                        height: 40,
                        builder: (ctx) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocation = LatLng(latitude, longitude);
                            });
                            print('Выбран адрес: $deliveryAddress');
                          },
                          child: Icon(
                            Icons.location_pin,
                            color: _selectedLocation == LatLng(latitude, longitude)
                                ? Colors.blue
                                : Colors.red,
                            size: 40,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              if (_selectedLocation != null)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(_selectedLocation);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEE3A57),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                    ),
                    child: Text(
                      'Выбрать этот адрес',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
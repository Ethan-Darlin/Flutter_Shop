import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class SupplierApplicationsScreen extends StatefulWidget {
  static const Color _backgroundColor = Color(0xFF18171c);
  static const Color _surfaceColor = Color(0xFF1f1f24);
  static const Color _primaryColor = Color(0xFFEE3A57);
  static const Color _secondaryTextColor = Color(0xFFa0a0a0);

  @override
  State<SupplierApplicationsScreen> createState() => _SupplierApplicationsScreenState();
}

class _SupplierApplicationsScreenState extends State<SupplierApplicationsScreen> {
  String? _imageDialogUrl;

  @override
  Widget build(BuildContext context) {
    const Color _surfaceColor = Color(0xFF1f1f24);
    return Scaffold(
      backgroundColor: SupplierApplicationsScreen._backgroundColor,

      appBar: AppBar(
        backgroundColor: _surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        title: const Text(
          'Заявки поставщиков',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('supplier_applications')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Center(child: CircularProgressIndicator(color: SupplierApplicationsScreen._primaryColor));
              if (snapshot.hasError)
                return Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: Colors.redAccent)));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return Center(child: Text('Заявок пока нет', style: TextStyle(color: SupplierApplicationsScreen._secondaryTextColor)));

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String fio = data['fio'] ?? '';
                  final String phone = data['phone'] ?? '';
                  final String email = data['email'] ?? '';
                  final String description = data['description'] ?? '';
                  final String status = data['status'] ?? '';
                  final String? photoUrl = data['document_photo'];
                  final Timestamp? createdAt = data['created_at'];
                  final String dateStr = createdAt != null
                      ? _formatDate(createdAt)
                      : 'неизвестно';
                  final String userId = data['user_id'] ?? '';

                  List<Map<String, dynamic>> statusOptions = [
                    {
                      'value': 'pending',
                      'label': 'Проверка',
                      'color': Colors.orange[700],
                    },
                    {
                      'value': 'approved',
                      'label': 'Одобрено',
                      'color': Colors.green[700],
                    },
                    {
                      'value': 'rejected',
                      'label': 'Отклонено',
                      'color': Colors.red[700],
                    }
                  ];

                  return Card(
                    color: SupplierApplicationsScreen._surfaceColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: EdgeInsets.only(bottom: 18.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          GestureDetector(
                            onTap: photoUrl != null && photoUrl.isNotEmpty
                                ? () {
                              setState(() {
                                _imageDialogUrl = photoUrl;
                              });
                            }
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: photoUrl != null && photoUrl.isNotEmpty
                                  ? Image.network(
                                photoUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.grey[800],
                                  child: Icon(Icons.broken_image, color: SupplierApplicationsScreen._secondaryTextColor, size: 36),
                                ),
                              )
                                  : Container(
                                width: 90,
                                height: 90,
                                color: Colors.grey[900],
                                child: Icon(Icons.image_not_supported, color: SupplierApplicationsScreen._secondaryTextColor, size: 36),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fio, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(Icons.email, color: SupplierApplicationsScreen._secondaryTextColor, size: 16),
                                    SizedBox(width: 5),
                                    Flexible(child: Text(email, style: TextStyle(color: SupplierApplicationsScreen._secondaryTextColor, fontSize: 14))),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.phone, color: SupplierApplicationsScreen._secondaryTextColor, size: 16),
                                    SizedBox(width: 5),
                                    Flexible(child: Text(phone, style: TextStyle(color: SupplierApplicationsScreen._secondaryTextColor, fontSize: 14))),
                                  ],
                                ),
                                SizedBox(height: 8),
                                if (description.isNotEmpty)
                                  Text(
                                    description,
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('Статус: ', style: TextStyle(color: SupplierApplicationsScreen._secondaryTextColor, fontSize: 13)),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: status,
                                        dropdownColor: SupplierApplicationsScreen._surfaceColor,
                                        iconEnabledColor: Colors.white,
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        items: statusOptions.map((opt) {
                                          return DropdownMenuItem<String>(
                                            value: opt['value'],
                                            child: Container(
                                              padding: EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: opt['color'],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                opt['label'],
                                                style: TextStyle(color: Colors.white, fontSize: 13),
                                              ),
                                            ),
                                          );
                                        }).toList(),

                                        onChanged: (newValue) async {
                                          if (newValue == null || newValue == status) return;
                                          await FirebaseFirestore.instance.collection('supplier_applications').doc(doc.id).update({
                                            'status': newValue,
                                          });

                                          if (newValue == 'approved' && userId.isNotEmpty) {
                                            final users = FirebaseFirestore.instance.collection('users');
                                            await users.doc(userId).update({'role': 'Supplier'});
                                          }

                                          try {
                                            final response = await http.post(
                                              Uri.parse('https://server-yugj.onrender.com/change_supplier_status'), // Замени на свой адрес!
                                              headers: {'Content-Type': 'application/json'},
                                              body: jsonEncode({
                                                'userId': userId,
                                                'newStatus': newValue,
                                              }),
                                            );
                                            if (response.statusCode == 200) {
                                              print('Push отправлен');
                                            } else {
                                              print('Ошибка пуша: ${response.body}');
                                            }
                                          } catch (e) {
                                            print('Ошибка отправки пуша: $e');
                                          }

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Статус изменён"),
                                              backgroundColor: SupplierApplicationsScreen._primaryColor,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text('Создано: $dateStr', style: TextStyle(color: SupplierApplicationsScreen._secondaryTextColor, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_imageDialogUrl != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.95),
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        child: Image.network(
                          _imageDialogUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.broken_image, color: Colors.white, size: 100),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 110,
                      right: 50,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white, size: 36),
                        onPressed: () {
                          setState(() {
                            _imageDialogUrl = null;
                          });
                        },
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

  static String _formatDate(Timestamp ts) {
    final date = ts.toDate();
    final months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
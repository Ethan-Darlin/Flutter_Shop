import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop/screens/productDetailScreen.dart';

class AdminProductModerationScreen extends StatefulWidget {
  const AdminProductModerationScreen({Key? key}) : super(key: key);

  @override
  State<AdminProductModerationScreen> createState() => _AdminProductModerationScreenState();
}

class _AdminProductModerationScreenState extends State<AdminProductModerationScreen> {
  String _search = "";

  void _showDeleteDialog(String docId, String productName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1f1f24),
        title: Text('Удалить товар?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Вы уверены, что хотите удалить "${productName.length > 40 ? productName.substring(0, 40) + "..." : productName}"?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Отмена", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('products').doc(docId).delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Товар удалён!'),
                  backgroundColor: Colors.green,
                ));
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Ошибка: $e'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: Text("Удалить"),
          ),
        ],
      ),
    );
  }

  void _showImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 250,
                      height: 250,
                      color: Colors.grey[800],
                      child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 44),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withOpacity(0.7),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Icon(Icons.close, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(DocumentSnapshot product) {
    final data = product.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Без имени';

    final String desc = data['description'] ?? '';
    final String? imageUrl = data['main_image_url'];
    final double? price = (data['price'] is num) ? data['price'].toDouble() : null;
    final productId = data['product_id']?.toString();

    // Переход на оригинальную карточку товара
    void _openProductDetail() {
      if (productId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProductDetailScreen(productId: productId)),
        );
      }
    }

    return Card(
      color: const Color(0xFF25252C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 100, height: 100,
            color: const Color(0xFF2a2a2e),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? GestureDetector(
              onTap: () => _showImageFullScreen(imageUrl),
              child: Hero(
                tag: imageUrl,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey, size: 40),
                ),
              ),
            )
                : Center(child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 40)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _openProductDetail,
                    child: Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.pinkAccent.withOpacity(0.4),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 5),
                  InkWell(
                    onTap: _openProductDetail,
                    child: Text(
                      desc,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.pinkAccent.withOpacity(0.2),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 7),
                  if (price != null)
                    Text(
                      "${price.toStringAsFixed(2)} BYN",
                      style: TextStyle(color: Colors.pink[300], fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _showDeleteDialog(product.id, name),
            tooltip: "Удалить товар",
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color _surfaceColor = Color(0xFF1f1f24);
    return Scaffold(
      backgroundColor: const Color(0xFF18171c),
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        title: const Text(
          'Модерация товаров',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Поиск по названию или описанию...",
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF25252C),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').orderBy('created_at', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Colors.pink));
                }
                if (snap.hasError) {
                  return Center(child: Text('Ошибка: ${snap.error}', style: TextStyle(color: Colors.redAccent)));
                }
                final docs = snap.data?.docs ?? [];
                final filtered = _search.isEmpty
                    ? docs
                    : docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final desc = (data['description'] ?? '').toString().toLowerCase();
                  return name.contains(_search) || desc.contains(_search);
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Text(
                        "Нет товаров по вашему запросу.",
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _buildProductCard(filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
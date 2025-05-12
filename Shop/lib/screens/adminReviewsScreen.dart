import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({Key? key}) : super(key: key);

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  Future<Map<String, String>> _fetchUsernames(List<String> userIds) async {
    Map<String, String> userMap = {};
    if (userIds.isEmpty) return userMap;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds.take(30).toList())
        .get();
    for (final doc in snapshot.docs) {
      userMap[doc.id] = doc.data()['username'] ?? 'Аноним';
    }
    return userMap;
  }

  void _showDeleteDialog(String reviewId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1f1f24),
        title: const Text('Удалить комментарий?', style: TextStyle(color: Colors.white)),
        content: const Text('Вы уверены, что хотите удалить этот комментарий?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('reviews').doc(reviewId).delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Комментарий удалён!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 250,
                      height: 250,
                      color: Colors.grey[800],
                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 44),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.black.withOpacity(0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
          'Модерация комментариев',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.pink));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Нет комментариев', style: TextStyle(color: Colors.white70)));
          }

          final reviews = snapshot.data!.docs;
          final userIds = reviews.map((doc) => doc['user_id'] as String).toSet().toList();

          return FutureBuilder<Map<String, String>>(
            future: _fetchUsernames(userIds),
            builder: (context, userSnapshot) {
              final userMap = userSnapshot.data ?? {};

              return ListView.separated(
                itemCount: reviews.length,
                separatorBuilder: (_, __) => Divider(color: Colors.grey[800], height: 1),
                itemBuilder: (context, index) {
                  final review = reviews[index].data() as Map<String, dynamic>;
                  final reviewId = reviews[index].id;
                  final userId = review['user_id'] as String;
                  final username = userMap[userId] ?? 'Аноним';
                  final comment = review['comment'] ?? '';
                  final rating = review['rating'] ?? 0;
                  final createdAt = review['created_at'] as Timestamp?;
                  final dateString = createdAt != null
                      ? '${createdAt.toDate().day.toString().padLeft(2, '0')}.${createdAt.toDate().month.toString().padLeft(2, '0')}.${createdAt.toDate().year}'
                      : '';
                  final images = List<String>.from(review['images'] ?? []);

                  return ListTile(
                    tileColor: const Color(0xFF1f1f24),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Row(
                      children: [
                        Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(dateString, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 22),
                          onPressed: () => _showDeleteDialog(reviewId),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.yellow.shade700, size: 18,
                          )),
                        ),
                        const SizedBox(height: 6),
                        Text(comment, style: TextStyle(color: Colors.white.withOpacity(0.85))),
                        if (images.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                itemBuilder: (context, imgIdx) {
                                  final url = images[imgIdx];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: GestureDetector(
                                      onTap: () => _showFullScreenImage(url),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          url,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 60, height: 60,
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
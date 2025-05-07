  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter/cupertino.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:google_sign_in/google_sign_in.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  class FirebaseService {
    static final FirebaseService _singleton = FirebaseService._internal();

    factory FirebaseService() => _singleton;

    FirebaseService._internal();

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    void onListenUser(void Function(User?)? doListen) {
      auth.authStateChanges().listen(doListen);
    }

    Future<void> rememberUser(bool remember) async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isLoggedIn', remember);
    }

    Future<bool> checkIfUserIsLoggedIn() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isLoggedIn') ?? false;  // Если значение отсутствует, вернем false
    }
    Future<List<Map<String, dynamic>>> getRecentlyViewedProductCards({int limit = 10}) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('[recently_viewed] Нет userId!');
        return [];
      }

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('recently_viewed')
          .orderBy('viewed_at', descending: true)
          .limit(limit)
          .get();

      final idsRaw = snapshot.docs.map((doc) => doc['product_id'] ?? '').toList();
      print('[recently_viewed] Найдено id просмотренных: $idsRaw');

      if (idsRaw.isEmpty) {
        print('[recently_viewed] Список просмотренных пуст.');
        return [];
      }

      final idsInt = idsRaw.map((e) {
        final asInt = int.tryParse(e.toString());
        return asInt ?? e;
      }).toList();
      print('[recently_viewed] После приведения типов: $idsInt');

      final productsSnapshot = await firestore
          .collection('products')
          .where('product_id', whereIn: idsInt)
          .get();

      print('[recently_viewed] Найдено товаров: ${productsSnapshot.docs.length}');
      for (var doc in productsSnapshot.docs) {
        print('[recently_viewed] Товар product_id=${doc['product_id']}, name=${doc['name']}');
      }

      final productsMap = {
        for (var doc in productsSnapshot.docs)
          doc['product_id'].toString(): {
            'product_id': doc['product_id'].toString(),
            ...doc.data() as Map<String, dynamic>
          }
      };

      print('[recently_viewed] productsMap keys: ${productsMap.keys}');

      final finalList = [
        for (var id in idsRaw)
          if (productsMap.containsKey(id.toString())) productsMap[id.toString()]!
      ];
      print('[recently_viewed] Итоговый список для вывода (${finalList.length}): ${finalList.map((e) => e['name']).toList()}');

      return finalList;
    }
    Future<void> onLogin({required String email, required String password}) async {
      try {
        final credential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        await rememberUser(true);
      } on FirebaseAuthException catch (e) {

        switch (e.code) {
          case 'user-not-found':
            throw 'Пользователь с таким email не найден.';
          case 'wrong-password':
            throw 'Неверный пароль.';
          case 'invalid-email':
            throw 'Некорректный email.';
          case 'user-disabled':
            throw 'Пользователь отключён.';
          default:
            throw 'Ошибка входа: ${e.code}';
        }
      } catch (e) {
        throw 'Ошибка входа: $e';
      }
    }
    Future<void> updateUserData(Map<String, dynamic> updates) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await firestore.collection('users').doc(userId).update(updates);
      } else {
        print('Ошибка: пользователь не аутентифицирован.');
      }
    }
    Future<void> updateCartItem(String docId, Map<String, dynamic> updates) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('cart')
            .doc(docId)
            .update(updates);
      } else {
        print('Ошибка: пользователь не аутентифицирован.');
      }
    }
    Future<void> savePushToken(String userId) async {
      final token = await FirebaseMessaging.instance.getToken();
      print('Получен push_token: $token');
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'push_token': token});
      }
    }
    Future<void> onRegister({
      required String email,
      required String password,
      required String username,
      String role = "user"
    }) async {
      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        String userId = credential.user!.uid;
        await firestore.collection('users').doc(userId).set({
          'username': username,
          'email': email,
          'role': role,
          'card_token': '',
          'created_at': FieldValue.serverTimestamp(),
          'loyalty_points': ''
        });
        await savePushToken(userId);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          throw 'Слишком слабый пароль (минимум 6 символов)';
        } else if (e.code == 'email-already-in-use') {
          throw 'Аккаунт с этим email уже существует.';
        } else if (e.code == 'invalid-email') {
          throw 'Некорректный email.';
        } else {
          throw e.message ?? 'Ошибка регистрации.';
        }
      } catch (e) {
        throw 'Ошибка регистрации: $e';
      }
    }
    final GoogleSignIn googleSignIn = GoogleSignIn();

    Future<void> signInWithGoogle(BuildContext context) async {
      try {

        await googleSignIn.signOut(); // Это удалит текущие учетные записи, если есть

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {

          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          final DocumentSnapshot userDoc = await firestore.collection('users').doc(user.uid).get();
          if (!userDoc.exists) {
            await firestore.collection('users').doc(user.uid).set({
              'username': user.displayName ?? 'Google User',
              'email': user.email,
              'role': 'user',
              'card_token': '',
              'created_at': FieldValue.serverTimestamp(),
              'loyalty_points': ''
            });
          }
          await savePushToken(user.uid); // <--- ДОБАВЬ ЭТУ СТРОКУ

          await rememberUser(true);
          Navigator.pushReplacementNamed(context, '/products');
        }
      } catch (e) {
        print('Google Sign-In error: $e');
      }
    }

    Future<void> logOut() async {
      await auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isLoggedIn', false);
      prefs.remove('email');  // Удаляем email при выходе из аккаунта
    }


    Future<void> onVerifyEmail() async {
      User? currentUser = auth.currentUser;
      await currentUser?.sendEmailVerification();
    }

    Future<Map<String, dynamic>?> getUserData() async {
      User? currentUser = auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          return userDoc.data() as Map<String, dynamic>?;
        }
      }
      return null;
    }

    Future<List<Map<String, dynamic>>> getProducts() async {
      QuerySnapshot<Map<String, dynamic>> productSnapshot = await firestore.collection('products').get();
      return productSnapshot.docs.map((doc) => doc.data()).toList();
    }

    Future<void> addToCart(Map<String, dynamic> product) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {

        final productId = product['product_id'];
        final selectedSize = product['selected_size'];
        final selectedColor = product['selected_color'];

        final productDoc = await firestore
            .collection('products')
            .where('product_id', isEqualTo: productId)
            .limit(1)
            .get();

        if (productDoc.docs.isEmpty) {
          throw Exception("Товар с ID $productId не найден.");
        }

        final productData = productDoc.docs.first.data();
        final sizes = productData['sizes'] as Map<String, dynamic>?;

        int availableQuantity = 1; // Значение по умолчанию
        if (sizes != null &&
            sizes.containsKey(selectedSize) &&
            sizes[selectedSize]['color_quantities'] != null) {
          final colorQuantities = sizes[selectedSize]['color_quantities'] as Map<String, dynamic>;
          availableQuantity = colorQuantities[selectedColor] ?? 1;
        }

        await firestore.collection('users').doc(userId).collection('cart').add({
          'product_id': productId,
          'name': product['name'],
          'description': product['description'],
          'price': product['price'],
          'image_url': product['image_url'],
          'selected_size': selectedSize,
          'selected_color': selectedColor,
          'quantity': product['quantity'],
          'available_quantity': availableQuantity, // Сохраняем максимальное количество
        });

        print("Товар добавлен в корзину с доступным количеством: $availableQuantity");
      }
    }

    Future<List<Map<String, dynamic>>> getCartItems() async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        QuerySnapshot cartSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('cart')
            .get();

        return cartSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id;
          print('Cart Item: $data'); // Отладочный вывод
          return data;
        }).toList();
      }
      return [];
    }
    Future<void> removeFromCart(String docId) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        print('Удаление продукта с docId: $docId');

        final docRef = firestore
            .collection('users')
            .doc(userId)
            .collection('cart')
            .doc(docId);

        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          await docRef.delete();
          print('Продукт с docId $docId удален из корзины.');
        } else {
          print('Ошибка: Документ с docId $docId не найден.');
        }
      } else {
        print('Ошибка: Пользователь не аутентифицирован.');
      }
    }

    Future<void> updateProductStock(
        int productId, String size, String color, int quantityChange) async {
      final productQuery = await firestore
          .collection('products')
          .where('product_id', isEqualTo: productId)
          .limit(1)
          .get();

      if (productQuery.docs.isNotEmpty) {
        final productDoc = productQuery.docs.first;
        final productRef = productDoc.reference;
        final productData = productDoc.data() as Map<String, dynamic>;

        final sizes = productData['sizes'] as Map<String, dynamic>?;
        if (sizes != null && sizes.containsKey(size)) {
          final sizeData = sizes[size] as Map<String, dynamic>;
          final colorQuantities = sizeData['color_quantities'] as Map<String, dynamic>?;

          if (colorQuantities != null && colorQuantities.containsKey(color)) {
            final currentStock = colorQuantities[color] as int;

            final newStock = currentStock + quantityChange;
            if (newStock >= 0) {

              await productRef.update({
                'sizes.$size.color_quantities.$color': newStock,
              });
              print('Количество обновлено: $color -> $newStock');
            } else {
              print('Ошибка: Недостаточно товара на складе для $color.');
            }
          } else {
            print('Ошибка: Цвет $color не найден для размера $size.');
          }
        } else {
          print('Ошибка: Размер $size не найден.');
        }
      } else {
        print('Ошибка: Товар с ID $productId не найден.');
      }
    }
    Future<List<Map<String, dynamic>>> getUserOrders() async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        QuerySnapshot ordersSnapshot = await firestore
            .collection('orders')
            .where('user_id', isEqualTo: userId)
            .get();

        return ordersSnapshot.docs.map((doc) {
          return {
            'order_id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();
      }
      return [];
    }
    Future<void> placeOrder(
        List<Map<String, dynamic>> cartItems, double totalPrice, String deliveryId) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId != null) {

        DocumentReference orderRef = await firestore.collection('orders').add({
          'user_id': userId,
          'total_price': totalPrice,
          'created_at': FieldValue.serverTimestamp(),
          'delivery_id': deliveryId,
        });

        for (var item in cartItems) {
          await firestore.collection('order_items').add({
            'order_id': orderRef.id,
            'product_id': item['product_id'],
            'name': item['name'],
            'price': item['price'],
            'quantity': item['quantity'],
            'selected_size': item['selected_size'],
            'selected_color': item['selected_color'],
            'item_status': 'В пути',
          });
        }

        double loyaltyPoints = totalPrice * 0.02;

        DocumentSnapshot userDoc = await firestore.collection('users').doc(userId).get();
        dynamic currentPointsDynamic = userDoc['loyalty_points'] ?? '0';

        double currentPoints;
        if (currentPointsDynamic is String) {
          currentPoints = double.tryParse(currentPointsDynamic) ?? 0.0;
        } else if (currentPointsDynamic is double) {
          currentPoints = currentPointsDynamic;
        } else if (currentPointsDynamic is int) {
          currentPoints = currentPointsDynamic.toDouble();
        } else {
          currentPoints = 0.0; // Если тип неизвестен, устанавливаем 0
        }

        double newPoints = currentPoints + loyaltyPoints;

        await firestore.collection('users').doc(userId).update({
          'loyalty_points': newPoints.toStringAsFixed(2), // Сохраняем с точностью до сотых
        });

        print('Начислено ${loyaltyPoints.toStringAsFixed(2)} баллов лояльности. Всего: ${newPoints.toStringAsFixed(2)}');
      }
    }


    Future<void> changePassword({required String currentPassword, required String newPassword}) async {
      User? user = auth.currentUser;

      if (user != null) {

        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );

        try {

          await user.reauthenticateWithCredential(credential);

          await user.updatePassword(newPassword);
          print('Пароль успешно изменен');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password') {
            print('Неверный текущий пароль');
          } else {
            print('Ошибка: ${e.message}');
          }
        }
      }
    }
    Future<void> resetPassword(String email) async {
      try {
        await auth.sendPasswordResetEmail(email: email);
        print('Письмо для сброса пароля отправлено на $email');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          print('Пользователь с этим адресом электронной почты не найден.');
        } else {
          print('Ошибка: ${e.message}');
        }
      }
    }
    Future<void> clearCart() async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        QuerySnapshot cartSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('cart')
            .get();

        for (var doc in cartSnapshot.docs) {
          await doc.reference.delete();
        }
      }
    }

    Future<void> addRecentlyViewedProduct(String productId) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recently_viewed')
          .doc(productId);

      await docRef.set({
        'product_id': productId,
        'viewed_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    Future<List<Map<String, dynamic>>> getRecentlyViewedOrRandomProducts({int limit = 4}) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final recentlyViewedSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('recently_viewed')
          .orderBy('viewed_at', descending: true)
          .limit(limit)
          .get();

      final viewedIds = recentlyViewedSnapshot.docs
          .map((doc) => doc['product_id'].toString())
          .toList();

      List<Map<String, dynamic>> result = [];

      if (viewedIds.isNotEmpty) {

        final viewedProductsSnapshot = await firestore
            .collection('products')
            .where('product_id', whereIn: viewedIds.map((e) => int.tryParse(e) ?? e).toList())
            .get();

        final productsMap = {
          for (var doc in viewedProductsSnapshot.docs)
            doc['product_id'].toString(): {
              'product_id': doc['product_id'].toString(),
              ...doc.data() as Map<String, dynamic>
            }
        };

        for (var id in viewedIds) {
          if (productsMap.containsKey(id)) {
            result.add(productsMap[id]!);
            if (result.length >= limit) break;
          }
        }
      }

      if (result.length < limit) {

        final productsSnapshot = await firestore.collection('products').get();
        final allProducts = productsSnapshot.docs
            .map((doc) => {
          'product_id': doc['product_id'].toString(),
          ...doc.data() as Map<String, dynamic>
        })
            .where((product) => !viewedIds.contains(product['product_id'].toString()))
            .toList();

        allProducts.shuffle();

        for (var product in allProducts) {
          result.add(product);
          if (result.length >= limit) break;
        }
      }

      return result.take(limit).toList();
    }

    Future<String?> addDelivery(Map<String, dynamic> deliveryData) async {
      try {

        final docRef = await FirebaseFirestore.instance
            .collection('delivery') // Корневая коллекция
            .add(deliveryData);

        print('Данные успешно добавлены. ID документа: ${docRef.id}');
        return docRef.id; // Возвращаем ID добавленного документа
      } catch (e) {
        print('Ошибка при добавлении адреса: $e');
        return null;
      }
    }
    Future<List<Map<String, dynamic>>> getUserDeliveryAddresses() async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        QuerySnapshot deliverySnapshot = await firestore
            .collection('delivery')
            .where('user_id', isEqualTo: userId)
            .get();

        return deliverySnapshot.docs.map((doc) {
          return {
            'doc_id': doc.id,
            'delivery_address': doc['delivery_address'],
          };
        }).toList();
      }
      return [];
    }
    Future<List<Map<String, dynamic>>> getAllDeliveryAddresses() async {
      QuerySnapshot deliverySnapshot = await firestore.collection('delivery').get();

      return deliverySnapshot.docs.map((doc) {
        return {
          'doc_id': doc.id,
          'delivery_address': doc['delivery_address'],
          'latitude': doc['latitude'], // Добавляем широту
          'longitude': doc['longitude'], // Добавляем долготу
        };
      }).toList();
    }
  }

  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:google_sign_in/google_sign_in.dart';
  class FirebaseService {
    static final FirebaseService _singleton = FirebaseService._internal();

    factory FirebaseService() => _singleton;

    FirebaseService._internal();

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    void onListenUser(void Function(User?)? doListen) {
      auth.authStateChanges().listen(doListen);
    }

    // Функция для запоминания пользователя
    Future<void> rememberUser(bool remember) async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isLoggedIn', remember);
    }

    // Проверка, был ли пользователь авторизован ранее
    Future<bool> checkIfUserIsLoggedIn() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isLoggedIn') ?? false;  // Если значение отсутствует, вернем false
    }

    Future<void> onLogin({required String email, required String password}) async {
      try {
        final credential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print(credential);

        // Сохранение состояния авторизации
        await rememberUser(true);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          print('No user found for that email.');
        } else if (e.code == 'wrong-password') {
          print('Wrong password provided for that user.');
        }
      }
    }

    Future<void> onRegister({required String email, required String password, required String username, String role = "user"}) async {
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
        });

        print("User registered and added to Firestore.");
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          print('The password provided is too weak.');
        } else if (e.code == 'email-already-in-use') {
          print('The account already exists for that email.');
        }
      } catch (e) {
        print(e);
      }
    }
    final GoogleSignIn googleSignIn = GoogleSignIn();

    Future<void> signInWithGoogle(BuildContext context) async {
      try {
        // Принудительно выход из текущего аккаунта
        await googleSignIn.signOut(); // Это удалит текущие учетные записи, если есть

        // Теперь начнем процесс входа
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // Если пользователь отменил вход
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
            });
          }

          await rememberUser(true);
          Navigator.pushReplacementNamed(context, '/products');
        }
      } catch (e) {
        print('Google Sign-In error: $e');
      }
    }

    Future<void> logOut() async {
      await auth.signOut();
      // Очистить флаг о запоминании
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
        await firestore.collection('users').doc(userId).collection('cart').add({
          'product_id': product['product_id'],
          'name': product['name'],
          'description': product['description'],
          'price': product['price'],
          'image_url': product['image_url'],
          'selected_size': product['selected_size'],
          'quantity': product['quantity'],
        });
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
          data['docId'] = doc.id; // Добавляем docId в данные
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

    Future<void> updateProductStock(int productId, String size, int quantity) async {
      final productQuery = await firestore
          .collection('products')
          .where('product_id', isEqualTo: productId)
          .get();

      if (productQuery.docs.isNotEmpty) {
        final productDoc = productQuery.docs.first; // Берем первый найденный документ
        final productRef = productDoc.reference;
        final productData = productDoc.data() as Map<String, dynamic>;
        final sizeStock = productData['size_stock'] as Map<String, dynamic>?;

        if (sizeStock != null && sizeStock.containsKey(size)) {
          final currentStock = sizeStock[size] as int?;

          if (currentStock != null) {
            final newStock = currentStock + quantity; // Увеличиваем или уменьшаем количество

            if (newStock >= 0) {
              await productRef.update({
                'size_stock.$size': newStock,
              });
              print('Количество товара обновлено: $size -> $newStock');
            } else {
              print('Ошибка: недостаточно товара на складе для размера $size');
            }
          } else {
            print('Ошибка: текущее количество товара для размера $size равно null');
          }
        } else {
          print('Ошибка: размер $size не найден в size_stock');
        }
      } else {
        print('Ошибка: товар с ID $productId не найден');
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
    Future<void> placeOrder(List<Map<String, dynamic>> cartItems, double totalPrice) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId != null) {
        // Создание заказа в таблице Orders
        DocumentReference orderRef = await firestore.collection('orders').add({
          'user_id': userId,
          'total_price': totalPrice,
          'created_at': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        // Добавление товаров в таблицу Order_Items
        for (var item in cartItems) {
          await firestore.collection('order_items').add({
            'order_id': orderRef.id,  // Сохраняем идентификатор заказа
            'product_id': item['product_id'],
            'name': item['name'],
            'price': item['price'],
            'quantity': item['quantity'],
            'selected_size': item['selected_size'],
          });

          // Обновление количества товара в Firestore
          await updateProductStock(
            item['product_id'] as int,
            item['selected_size'],
            -item['quantity'],
          );
        }

        // Очистка корзины после оформления заказа
        await clearCart();
      }
    }

    Future<void> changePassword({required String currentPassword, required String newPassword}) async {
      User? user = auth.currentUser;

      if (user != null) {
        // Получаем текущий идентификатор токена
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );

        try {
          // Перепроверяем текущий пароль
          await user.reauthenticateWithCredential(credential);
          // Смена пароля
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
    //отзывы
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

    Future<List<Map<String, dynamic>>> getRecentlyViewedProducts() async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        QuerySnapshot snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('recently_viewed')
            .orderBy('viewed_at', descending: true)
            .get();

        return snapshot.docs.map((doc) {
          return {
            'doc_id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();
      }
      return [];
    }
  }
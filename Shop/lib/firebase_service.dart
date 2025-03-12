import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseService _singleton = FirebaseService._internal();

  factory FirebaseService() => _singleton;

  FirebaseService._internal();

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  void onListenUser(void Function(User?)? doListen) {
    auth.authStateChanges().listen(doListen);
  }

  Future<void> onLogin({required String email, required String password}) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print(credential);
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

      // Получаем UID пользователя
      String userId = credential.user!.uid;

      // Добавляем пользователя в Firestore
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

  Future<void> logOut() async {
    await auth.signOut();
  }

  Future<void> onVerifyEmail() async {
    User? currentUser = auth.currentUser; // Обновляем получение текущего пользователя
    await currentUser?.sendEmailVerification();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    User? currentUser = auth.currentUser; // Получаем текущего пользователя
    if (currentUser != null) {
      DocumentSnapshot userDoc = await firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>?;
      }
    }
    return null; // Возвращаем null, если пользователь не аутентифицирован
  }


  // prodcuts
  Future<List<Map<String, dynamic>>> getProducts() async {
    QuerySnapshot<Map<String, dynamic>> productSnapshot =
    await firestore.collection('products').get();

    return productSnapshot.docs
        .map((doc) => doc.data())
        .toList();
  }
}
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'package:flutter/foundation.dart'; 
import 'package:google_sign_in/google_sign_in.dart'; 

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance; 
  final GoogleSignIn _googleSignIn = GoogleSignIn(); 

  Future<User?> SignInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleInUser = await _googleSignIn.signIn();
      if (googleInUser == null) {
        return Future.error('El usuario ha cancelado el inicio de sesión');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleInUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      if (kDebugMode) {
        print('Error a autenticarse con Google');
      }
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }
}

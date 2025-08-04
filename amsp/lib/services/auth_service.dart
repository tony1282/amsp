import 'package:firebase_auth/firebase_auth.dart'; // Para autenticación con Firebase
import 'package:firebase_core/firebase_core.dart'; // Inicialización de Firebase
import 'package:flutter/foundation.dart'; // Para kDebugMode (modo debug)
import 'package:google_sign_in/google_sign_in.dart'; // Para autenticación con Google

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance; // Instancia de Firebase Auth
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // Instancia para Google Sign In

  // Método para iniciar sesión con Google y devolver el usuario autenticado
  Future<User?> SignInWithGoogle() async {
    try {
      // Abre el diálogo para seleccionar cuenta Google
      final GoogleSignInAccount? googleInUser = await _googleSignIn.signIn();
      if (googleInUser == null) {
        // Si el usuario cancela el inicio de sesión, se lanza error
        return Future.error('El usuario ha cancelado el inicio de sesión');
      }

      // Obtiene el token de acceso y el token de id de Google
      final GoogleSignInAuthentication googleAuth =
          await googleInUser.authentication;

      // Crea las credenciales para Firebase con los tokens de Google
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Usa las credenciales para iniciar sesión en Firebase
      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      // Devuelve el usuario autenticado
      return userCredential.user;
    } catch (e) {
      // Si ocurre algún error y estamos en modo debug, imprime el error
      if (kDebugMode) {
        print('Error a autenticarse con Google');
      }
      // Devuelve null si falla la autenticación
      return null;
    }
  }

  // Método para cerrar sesión tanto de Firebase como de Google
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }
}

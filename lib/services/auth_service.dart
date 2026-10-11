import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signUp({required String email, required String password}) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateErrorCode(e.code));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateErrorCode(e.code));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateErrorCode(e.code));
    }
  }

  // แปลง code ของ FirebaseAuthException เป็นข้อความภาษาไทย
  String _translateErrorCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้สมัครสมาชิกไปแล้ว';
      case 'weak-password':
        return 'รหัสผ่านสั้นหรือคาดเดาง่ายเกินไป (ต้องมีอย่างน้อย 6 ตัวอักษร)';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีนี้ถูกระงับการใช้งาน';
      case 'too-many-requests':
        return 'ลองบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
      case 'network-request-failed':
        return 'ไม่สามารถเชื่อมต่อเครือข่ายได้ กรุณาตรวจสอบอินเทอร์เน็ต';
      case 'operation-not-allowed':
        return 'ยังไม่ได้เปิดใช้งานวิธีเข้าสู่ระบบนี้ใน Firebase Console';
      default:
        return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง ($code)';
    }
  }
}

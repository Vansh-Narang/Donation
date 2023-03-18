// ignore_for_file: body_might_complete_normally_catch_error

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ngo/homepage/home_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

// Creating account
// Future<User?> createAccount(String email, String password) async {
//   try {
//     User? user = (await _auth.createUserWithEmailAndPassword(
//             email: email, password: password))
//         .user;
//     return user;
//   } on FirebaseAuthException catch (e) {
//     if (e.code == 'weak-password') {
//       Fluttertoast.showToast(msg: "Password Is Too Weak");
//     } else if (e.code == 'email-already-in-use') {
//       Fluttertoast.showToast(msg: "Account Already Exist For That Email");
//     }
//   }
//   return null;
// }
Future createAccount(String emailAddress, String password) async {
  try {
    UserCredential usercredential = await _auth.createUserWithEmailAndPassword(
        email: emailAddress, password: password);
    print(emailAddress);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'weak-password') {
      print('The password provided is too weak.');
    } else if (e.code == 'email-already-in-use') {
      print('The account already exists for that email.');
    }
  } catch (e) {
    print(e.toString());
  }
}

// Email Login
Future<User?> login(String email, String password) async {
  try {
    User? user = (await _auth.signInWithEmailAndPassword(
            email: email, password: password))
        .user;
    return user;
  } on FirebaseAuthException catch (error) {
    if (error.code == 'user-not-found') {
      Fluttertoast.showToast(msg: 'No user found for that email');
    } else if (error.code == 'wrong-password') {
      Fluttertoast.showToast(msg: 'Wrong password provided for the user.');
    }
  }
  return null;
}

// Logout
Future logout() async {
  try {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userType');
  } catch (error) {
    Fluttertoast.showToast(msg: "Failed to logout. Try again after sometime");
  }
}

// Username and Password Login
Future<User?> getEmail(
    {required String username, required String password}) async {
  User? user;
  await FirebaseFirestore.instance
      .collection('users')
      .where('username', isEqualTo: username)
      .get()
      .then(
    (snapshot) async {
      user = await login(snapshot.docs[0].data()['email'], password);
    },
  );
  return user;
}

// Reset Password
Future<void> resetPassword(String email) async {
  FirebaseAuth auth = FirebaseAuth.instance;
  await auth.sendPasswordResetEmail(email: email);
}

Future<Map<String, dynamic>> getUserInfo(String uid) async {
  late Map<String, dynamic> userInfo;
  await FirebaseFirestore.instance
      .collection('users')
      .where('uid', isEqualTo: uid)
      .limit(1)
      .get()
      .then(
    (field) {
      return userInfo = {
        'username': field.docs.single.data()['username'],
        'email': field.docs.single.data()['email'],
      };
    },
  ).catchError((err) {
    Fluttertoast.showToast(msg: '$err');
  });
  return userInfo;
}

// Delete user from collection
Future<void> deleteUser(String uid) async {
  FirebaseFirestore.instance.collection('users').doc(uid).delete();
}

Future<User?> verifyotp(otp, verificationid) async {
  // Create a PhoneAuthCredential with the code
  try {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationid, smsCode: otp.text);

    UserCredential id = await _auth.signInWithCredential(credential);
    return id.user;
  } catch (e) {
    Fluttertoast.showToast(msg: 'Token expired');
    return null;
  }
}

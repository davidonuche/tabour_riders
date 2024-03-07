import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tabour_riders/auth/auth_screen.dart';
import 'package:tabour_riders/global/global.dart';
import 'package:tabour_riders/mainscreens/home_screen.dart';
import 'package:tabour_riders/widgets/custom_text_field.dart';
import 'package:tabour_riders/widgets/error_dialog.dart';
import 'package:tabour_riders/widgets/loading_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  formValidation() {
    if (_emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      //login
      loginNow();
    } else {
      showDialog(
          context: context,
          builder: (c) {
            return ErrorDialog(
              message: "Please write email/password",
            );
          });
    }
  }

  loginNow() async {
    showDialog(
        context: context,
        builder: (c) {
          return LoadingDialog(
            message: "Checking Credentials",
          );
        });
    User? currentUser;
    await firebaseAuth
        .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim())
        .then((auth) {
      currentUser = auth.user!;
    }).catchError((error) {
      Navigator.pop(context);
      showDialog(
          context: context,
          builder: (c) {
            return ErrorDialog(
              message: error.message.toString(),
            );
          });
    });
    if (currentUser != null) {
      readDataAndSetDataLocally(currentUser!);
    }
  }

  Future readDataAndSetDataLocally(User currentUser) async {
    await FirebaseFirestore.instance
        .collection("riders")
        .doc(currentUser.uid)
        .get()
        .then((snapshot) async {
      if (snapshot.exists) {
        await sharedPreferences!.setString('uid', currentUser.uid);
        await sharedPreferences!
            .setString('email', snapshot.data()!['riderEmail']);
        await sharedPreferences!
            .setString('name', snapshot.data()!['riderName']);
        await sharedPreferences!
            .setString('photoUrl', snapshot.data()!['riderAvatarUrl']);
        Navigator.pop(context);
        Navigator.push(
            context, MaterialPageRoute(builder: (c) => HomeScreen()));
      } else {
        firebaseAuth.signOut();
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const AuthScreen()),
        );
        showDialog(
            context: context,
            builder: (c) {
              return ErrorDialog(
                message: "No record exists. please register",
              );
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Image.asset(
                "images/signup.png",
                height: 270,
                width: 270,
              ),
            ),
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  controller: _emailController,
                  data: Icons.email,
                  hintText: 'Email',
                  isObsecre: false,
                  enabled: true,
                ),
                CustomTextField(
                  controller: _passwordController,
                  data: Icons.lock,
                  hintText: 'Password',
                  isObsecre: true,
                  enabled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              formValidation();
            },
            child: Text(
              "Login",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              primary: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

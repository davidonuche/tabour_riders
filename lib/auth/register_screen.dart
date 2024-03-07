import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fstorage;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabour_riders/global/global.dart';
import 'package:tabour_riders/mainscreens/home_screen.dart';
import 'package:tabour_riders/widgets/custom_text_field.dart';
import 'package:tabour_riders/widgets/loading_dialog.dart';
import '../widgets/error_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();

  Position? position;
  List<Placemark>? placeMarks;

  String sellerImageUrl = "";
  String completeAddress = "";

  Future<void> _getImage() async {
    imageXFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 150,
      maxHeight: 150,
    );
    setState(() {
      imageXFile;
    });
  }

  getCurrentLocation() async {
    if (await Permission.location.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
      Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      position = newPosition;

      placeMarks = await placemarkFromCoordinates(
        position!.latitude,
        position!.longitude,
      );
      Placemark pMark = placeMarks![0];

      completeAddress =
          '${pMark.subThoroughfare}, ${pMark.thoroughfare}, ${pMark.subLocality}, ${pMark.locality}, ${pMark.subAdministrativeArea}, ${pMark.administrativeArea}, ${pMark.postalCode}, ${pMark.country}';

      print("Address: $completeAddress");
      _locationController.text = completeAddress;
    } else {
      print("Permission denied");
      // You can request the permission again here
      getCurrentLocation();
    }
  }

  Future<void> formValidation() async {
    if (imageXFile == null) {
      showDialog(
          context: context,
          builder: (c) {
            return ErrorDialog(
              message: "Please select an image.",
            );
          });
    } else {
      if (_passwordController.text == _confirmPasswordController.text) {
        if (_confirmPasswordController.text.isNotEmpty &&
            _emailController.text.isNotEmpty &&
            _nameController.text.isNotEmpty &&
            _phoneController.text.isNotEmpty &&
            _locationController.text.isNotEmpty) {
          //start uploading image
          showDialog(
              context: context,
              builder: (c) {
                return const LoadingDialog(
                  message: "Registering, Plase wait...",
                );
              });
          String fileName = DateTime.now().millisecondsSinceEpoch.toString();
          fstorage.Reference reference = fstorage.FirebaseStorage.instance
              .ref()
              .child('riders')
              .child(fileName);
          fstorage.UploadTask uploadTask =
              reference.putFile(File(imageXFile!.path));
          fstorage.TaskSnapshot taskSnapshot =
              await uploadTask.whenComplete(() {});
          await taskSnapshot.ref.getDownloadURL().then((url) {
            sellerImageUrl = url;
            //save info to firestore
            authenticateSellerAndSignUp();
          });
        } else {
          showDialog(
              context: context,
              builder: (c) {
                return const ErrorDialog(
                    message:
                        "Please write the complete required info for Registration.");
              });
        }
      } else {
        showDialog(
            context: context,
            builder: (c) {
              return const ErrorDialog(
                message: "Password do not match.",
              );
            });
      }
    }
  }

  void authenticateSellerAndSignUp() async {
    // User? currentUser;

    await firebaseAuth
        .createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    )
        .then((auth) {
      print(auth.user!.uid);
      // currentUser = auth.user;
      saveDataToFirestore(auth.user!).then((value) {
        Navigator.pop(context);
        // send user to home page
        Route newRoute = MaterialPageRoute(builder: (c) => const HomeScreen());
        Navigator.pushReplacement(context, newRoute);
      });
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
    // if (currentUser != null) {
    //   saveDataToFirestore(currentUser!).then((value) {
    //     Navigator.pop(context);
    //     // send user to home page
    //     Route newRoute = MaterialPageRoute(builder: (c) => HomeScreen());
    //     Navigator.pushReplacement(context, newRoute);
    //   });
    // }
  }

  Future saveDataToFirestore(User currentUser) async {
    FirebaseFirestore.instance.collection('riders').doc(currentUser.uid).set({
      "riderUID": currentUser.uid,
      "riderEmail": currentUser.email,
      "riderName": _nameController.text.trim(),
      "riderAvatarUrl": sellerImageUrl,
      "phone": _phoneController.text.trim(),
      "address": completeAddress,
      "status": "approved",
      "earnings": 0.0,
      "lat": position?.latitude,
      "lng": position?.longitude,
    });
    //save data lacally
    sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences!.setString('uid', currentUser.uid);
    await sharedPreferences!.setString('email', currentUser.email.toString());
    await sharedPreferences!.setString('name', _nameController.text.trim());
    await sharedPreferences!.setString('photoUrl', sellerImageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _getImage(),
            child: CircleAvatar(
              radius: MediaQuery.of(context).size.width * 0.20,
              backgroundColor: Colors.white,
              backgroundImage: imageXFile == null
                  ? null
                  : FileImage(
                      File(imageXFile!.path),
                    ),
              child: imageXFile == null
                  ? Icon(Icons.add_photo_alternate,
                      size: MediaQuery.of(context).size.width * 0.20,
                      color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  controller: _nameController,
                  data: Icons.person,
                  hintText: 'Name',
                  isObsecre: false,
                  enabled: true,
                ),
                CustomTextField(
                  controller: _emailController,
                  data: Icons.email,
                  hintText: 'Email',
                  isObsecre: false,
                  enabled: true,
                ),
                CustomTextField(
                  controller: _phoneController,
                  data: Icons.phone,
                  hintText: 'Phone',
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
                CustomTextField(
                  controller: _confirmPasswordController,
                  data: Icons.lock,
                  hintText: 'Confirm Password',
                  isObsecre: true,
                  enabled: true,
                ),
                CustomTextField(
                  controller: _locationController,
                  data: Icons.location_city,
                  hintText: 'My Current Address',
                  isObsecre: false,
                  enabled: true,
                ),
                Container(
                  width: 400,
                  height: 40,
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    label: const Text(
                      "Get my Current Location",
                      style: TextStyle(fontSize: 20),
                    ),
                    icon: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      getCurrentLocation();
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              formValidation();
            },
            child: Text(
              "Sign Up",
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

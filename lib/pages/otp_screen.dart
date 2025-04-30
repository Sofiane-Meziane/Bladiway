import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  void _onOTPChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  Future<String?> _uploadProfileImage(String userId, File imageFile) async {
    try {
      final storageRef = _storage.ref().child('profile_images/$userId.jpg');
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Erreur lors du téléchargement de l\'image: $e');
      return null;
    }
  }

  Future<void> _verifyOTP() async {
    String otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un code OTP complet')),
      );
      return;
    }

    try {
      final Map<String, dynamic>? arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (arguments == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Arguments manquants')),
        );
        return;
      }

      print('Arguments reçus dans OTPScreen : $arguments');

      final String? verificationId = arguments['verificationId'];
      final String? email = arguments['email'];
      final String? password = arguments['password'];
      final String? phoneNumber = arguments['phoneNumber'];
      final String? nom = arguments['nom'];
      final String? prenom = arguments['prenom'];
      final String? dateNaissance = arguments['dateNaissance'];
      final String? genre = arguments['genre'];
      final String? imagePath = arguments['imagePath'];
      File? imageFile;
      if (imagePath != null && imagePath.isNotEmpty) {
        imageFile = File(imagePath);
      }

      if (verificationId == null ||
          email == null ||
          password == null ||
          phoneNumber == null ||
          nom == null ||
          prenom == null ||
          dateNaissance == null ||
          genre == null ||
          imageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Données manquantes')),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Flexible(
                  child: const Text(
                    "Vérification en cours...",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      );

      try {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otp,
        );
        // Authentifier l'utilisateur avec le téléphone
        UserCredential phoneUserCredential = await _auth.signInWithCredential(
          credential,
        );
        User? user = phoneUserCredential.user;
        if (user != null) {
          // Lier l'email/password
          AuthCredential emailCredential = EmailAuthProvider.credential(
            email: email,
            password: password,
          );
          await user.linkWithCredential(emailCredential);
          String? profileImageUrl;
          profileImageUrl = await _uploadProfileImage(user.uid, imageFile);
          await _firestore.collection('users').doc(user.uid).set({
            'nom': nom,
            'prenom': prenom,
            'email': email,
            'phone': phoneNumber,
            'dateNaissance': dateNaissance,
            'genre': genre,
            'id': user.uid,
            'blockStatus': 'no',
            'phoneVerified': true,
            'profileImageUrl': profileImageUrl,
            'isValidated': false,
          });
          if (mounted) Navigator.pop(context);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) Navigator.pop(context);
        String errorMessage;
        switch (e.code) {
          case 'invalid-verification-code':
            errorMessage = 'Code OTP incorrect';
            break;
          case 'session-expired':
            errorMessage =
                'La session a expiré. Veuillez demander un nouveau code';
            break;
          case 'email-already-in-use':
            errorMessage = 'Cet email est déjà utilisé';
            break;
          default:
            errorMessage = 'Une erreur est survenue : \\${e.code}';
            if (e.message != null) {
              errorMessage += '\nMessage: \\${e.message}';
            }
            print(
              'FirebaseAuthException: code=\\${e.code}, message=\\${e.message}, details=\\${e.toString()}',
            );
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur inattendue : ${e.toString()}')),
      );
    }
  }

  void _resendOTP() async {
    final Map<String, dynamic>? arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (arguments == null || arguments['phoneNumber'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro de téléphone manquant pour renvoi'),
        ),
      );
      return;
    }

    final String phoneNumber = arguments['phoneNumber'];

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec du renvoi : ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/otp',
              arguments: {
                'verificationId': verificationId,
                'phoneNumber': arguments['phoneNumber'],
                'nom': arguments['nom'],
                'prenom': arguments['prenom'],
                'email': arguments['email'],
                'password': arguments['password'],
                'dateNaissance': arguments['dateNaissance'],
                'genre': arguments['genre'],
                'imagePath': arguments['imagePath'], // Correction ici
              },
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Code OTP renvoyé'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du renvoi : ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Obtenir la taille de l'écran pour le responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculer la taille adaptative des champs OTP
    final otpFieldWidth = (screenWidth - 64) / 6;
    final otpFieldSize = otpFieldWidth > 50 ? 50.0 : otpFieldWidth - 8;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: screenHeight * 0.04),
                Text(
                  'Vérification OTP',
                  style: TextStyle(
                    fontSize: screenWidth < 360 ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.02),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'Entrez le code de 6 chiffres envoyé à votre numéro de téléphone',
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 14 : 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: otpFieldSize,
                        height: otpFieldSize * 1.2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: TextStyle(
                            fontSize: otpFieldSize * 0.45,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.onSurface.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            errorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) => _onOTPChanged(index, value),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: screenHeight * 0.05),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: Size(screenWidth * 0.8, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _verifyOTP,
                  child: Text(
                    'Vérifier',
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                TextButton(
                  onPressed: _resendOTP,
                  child: Text(
                    'Renvoyer le code',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: screenWidth < 360 ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

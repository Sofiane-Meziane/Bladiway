import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:bladiway/src/features/authentication/controllers/signup_controller.dart';
import 'package:provider/provider.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SignUpController>(context, listen: false);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Créer un compte',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: controller.formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nom Field
                TextFormField(
                  controller: controller.nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.person, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: controller.validateNom,
                ),
                const SizedBox(height: 16),

                // Prénom Field
                TextFormField(
                  controller: controller.prenomController,
                  decoration: InputDecoration(
                    labelText: 'Prénom',
                    prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: controller.validatePrenom,
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: controller.validateEmail,
                ),
                const SizedBox(height: 16),

                // Phone Field
                IntlPhoneField(
                  controller: controller.phoneController,
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  initialCountryCode: 'DZ',
                  validator: controller.validatePhone,
                ),
                const SizedBox(height: 16),

                // Date of Birth Field
                TextFormField(
                  controller: controller.dateNaissanceController,
                  decoration: InputDecoration(
                    labelText: 'Date de naissance',
                    prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_month, color: primaryColor),
                      onPressed: () => controller.selectDate(context),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => controller.selectDate(context),
                  validator: controller.validateDateNaissance,
                ),
                const SizedBox(height: 16),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Genre',
                    prefixIcon: Icon(Icons.people, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  items:
                      controller.genres
                          .map(
                            (genre) => DropdownMenuItem(
                              value: genre,
                              child: Text(genre),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {},
                  validator: controller.validateGenre,
                ),
                const SizedBox(height: 16),

                // Password Field
                Consumer<SignUpController>(
                  builder: (context, controller, _) {
                    return TextFormField(
                      controller: controller.passwordController,
                      obscureText: !controller.isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock, color: primaryColor),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: primaryColor,
                          ),
                          onPressed: controller.togglePasswordVisibility,
                        ),
                      ),
                      validator: controller.validatePassword,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Sign Up Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => controller.submitForm(context),
                  child: const Text(
                    "S'inscrire",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

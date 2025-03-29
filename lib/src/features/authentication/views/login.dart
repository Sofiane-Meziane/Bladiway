import 'package:flutter/material.dart';
import 'package:bladiway/src/features/authentication/controllers/login_controller.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<LoginController>(context, listen: false);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(color: primaryColor),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: controller.formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "Connexion",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/logo.png',
                      height: 120,
                      errorBuilder:
                          (context, error, stackTrace) => Icon(
                            Icons.account_circle,
                            size: 120,
                            color: primaryColor,
                          ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: controller.loginIdentifierController,
                      focusNode: controller.loginIdentifierFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email ou numéro de téléphone',
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                        border: const OutlineInputBorder(),
                        hintText: 'exemple@email.com ou +33612345678',
                      ),
                      validator: controller.validateLoginIdentifier,
                      onFieldSubmitted:
                          (_) => controller.passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),
                    Consumer<LoginController>(
                      builder: (context, controller, _) {
                        return TextFormField(
                          controller: controller.passwordController,
                          focusNode: controller.passwordFocus,
                          obscureText: controller.obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock, color: primaryColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: primaryColor,
                              ),
                              onPressed: controller.togglePasswordVisibility,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: controller.validatePassword,
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Mot de passe oublié?',
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () => controller.submitForm(context),
                      child: const Text(
                        "Se connecter",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: Text.rich(
                        TextSpan(
                          text: 'Vous n\'avez pas de compte? ',
                          style: const TextStyle(color: Colors.grey),
                          children: [
                            TextSpan(
                              text: 'S\'inscrire',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

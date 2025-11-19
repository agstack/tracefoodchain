import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/widgets/status_bar.dart';
import 'package:trace_foodchain_app/widgets/language_selector.dart'; // Neue Import
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/user_profile_setup_screen.dart';
import '../services/open_ral_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _authenticate() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Try to sign in first
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        await _handleSuccessfulAuth(
            userCredential.user!, "Signed in successfully.");
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential') {
          // If user is not found, try to create a new account
          try {
            UserCredential userCredential =
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: _emailController.text,
              password: _passwordController.text,
            );

            await userCredential.user?.sendEmailVerification();
            await _handleSuccessfulAuth(userCredential.user!,
                "Account created successfully. Please check your email for verification.");
          } on FirebaseAuthException catch (signUpError) {
            await _handleAuthError(signUpError);
          }
        } else {
          await _handleAuthError(e);
        }
      }
    }
  }

  Future<void> _handleSuccessfulAuth(User user, String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.uid);

    // Check if this is a new user (account was just created)
    bool isNewUser = message.contains("Account created successfully");
    isNewUser = true;

    if (isNewUser) {
      // For new users, check if they need to complete their profile
      await _checkAndNavigateToProfileSetup(user);
    } else {
      // For existing users, navigate to main app
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<void> _checkAndNavigateToProfileSetup(User user) async {
    try {
      // Check if user profile is already complete
      final userProfile = await OpenRALService.getUserProfile();

      final bool hasFirstName = userProfile.containsKey('firstName') &&
          userProfile['firstName']!.isNotEmpty;
      final bool hasLastName = userProfile.containsKey('lastName') &&
          userProfile['lastName']!.isNotEmpty;
      final bool hasRole = userProfile.containsKey('userRole') &&
          userProfile['userRole']!.isNotEmpty;

      if (!hasFirstName || !hasLastName || !hasRole) {
        // Navigate to profile setup screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const UserProfileSetupScreen(),
          ),
        );
      } else {
        // Profile is already complete, navigate to main app
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      // On error, navigate to profile setup to be safe
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const UserProfileSetupScreen(),
        ),
      );
    }
  }

  Future<void> _handleAuthError(FirebaseAuthException e) async {
    final l10n = AppLocalizations.of(context)!;
    String errorMessage;
    switch (e.code) {
      case 'weak-password':
        errorMessage = l10n.weakPasswordError;
        break;
      case 'email-already-in-use':
        errorMessage = l10n.emailAlreadyInUseError;
        break;
      case 'invalid-email':
        errorMessage = l10n.invalidEmailError;
        break;
      case 'user-disabled':
        errorMessage = l10n.userDisabledError;
        break;
      case 'wrong-password':
        errorMessage = l10n.wrongPasswordError;
        break;
      default:
        errorMessage = l10n.undefinedError;
    }
    await fshowInfoDialog(context, "${l10n.error}: $errorMessage");
  }

  String _getHelpUrl(String languageCode) {
    switch (languageCode) {
      case 'de':
        return 'https://docs.google.com/document/d/1wURF_uGIW3eKHh1qEn380_JE5tOdOyZRfFRQuL46Hn0';
      case 'es':
        return 'https://docs.google.com/document/d/1IVqaR_mJkQKbVobJfYM_EUxYCpd5B5qel0mY2U_KPVg';
      case 'fr':
        return 'https://docs.google.com/document/d/19Z0dMR6CqHqaT2nU9qM4uzHftNFlIeZpd2AlyuHngP4';
      default:
        return "https://docs.google.com/document/d/1JcNxTNEs6nkTDotVzFw-AFU0arB6T8aI1BfzKAuDF0A";
    }
  }

  Future<void> _launchHelp() async {
    final locale = Localizations.localeOf(context);
    final Uri url = Uri.parse(_getHelpUrl(locale.languageCode));
    if (!await launchUrl(url)) {
      await fshowInfoDialog(
          context, AppLocalizations.of(context)!.errorOpeningUrl);
    }
  }

  // Neue Methode: Passwort zurücksetzen
  Future<void> _resetPassword() async {
    final email = _emailController.text;
    if (email.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      await fshowInfoDialog(context, l10n.pleaseEnterEmail);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      final l10n = AppLocalizations.of(context)!;
      await fshowInfoDialog(context, l10n.resetPasswordEmailSent);
    } on FirebaseAuthException catch (e) {
      await fshowInfoDialog(context, e.message ?? "Error");
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF35DB00),
        onPressed: _launchHelp,
        tooltip: l10n.helpButtonTooltip,
        child: const Icon(Icons.menu_book),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.7),
                  BlendMode.dstATop,
                ),
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  const Positioned(
                    top: 16,
                    left: 16,
                    child: LanguageSelector(),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.welcomeToApp,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    l10n.signInMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.black87,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 30),
                                  Form(
                                    key: _formKey,
                                    child: Column(
                                      children: <Widget>[
                                        TextFormField(
                                          style: const TextStyle(
                                              color: Colors.black),
                                          controller: _emailController,
                                          decoration: InputDecoration(
                                            labelText: l10n.email,
                                            prefixIcon: const Icon(Icons.email),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return l10n.pleaseEnterEmail;
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        TextFormField(
                                          onFieldSubmitted: (value) {
                                            // Simuliere das Drücken des Signup-Buttons, wenn Enter gedrückt wird
                                            _authenticate();
                                          },
                                          style: const TextStyle(
                                              color: Colors.black),
                                          controller: _passwordController,
                                          decoration: InputDecoration(
                                            labelText: l10n.password,
                                            prefixIcon: const Icon(Icons.lock),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          obscureText: true,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return l10n.pleaseEnterPassword;
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 30),
                                        TextButton(
                                          onPressed: _resetPassword,
                                          child: Text(
                                            l10n.forgotPasswordQuestion,
                                            style: const TextStyle(
                                              color: Color(0xFF35DB00),
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                        ElevatedButton(
                                          onPressed: _authenticate,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Theme.of(context).primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 50, vertical: 15),
                                            textStyle:
                                                const TextStyle(fontSize: 18),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                          child: Text(l10n.signInSignUp),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 16,
            left: 16,
            child: StatusBar(isSmallScreen: false),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'login_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _attempted = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _attempted = true;
      _errorMessage = null;
    });

    final key = _keyController.text.trim().toUpperCase();

    if (key.isEmpty) {
      setState(() => _errorMessage = 'Please enter your license key.');
      return;
    }

    // Basic format check XXXX-XXXX-YYYY
    final regex = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[0-9]{4}$');
    if (!regex.hasMatch(key)) {
      setState(() => _errorMessage = 'Invalid format. Example: ABCD-1234-2025');
      return;
    }

    setState(() => _isLoading = true);

    final result = await LicenseService().validateLicense(key);

    setState(() => _isLoading = false);

    if (result.success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Activated: ${result.message}'),
          backgroundColor: AppColors.safe,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  size: 65,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'MedStore Manager',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Enter your license key to activate',
                style: TextStyle(
                  color: AppColors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 48),

              // Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'License Key',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _keyController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'XXXX-XXXX-2025',
                        hintStyle: TextStyle(
                          color: AppColors.grey,
                          letterSpacing: 1,
                          fontWeight: FontWeight.normal,
                        ),
                        prefixIcon: const Icon(
                          Icons.vpn_key_rounded,
                          color: AppColors.primary,
                        ),
                        errorText: _attempted ? _errorMessage : null,
                      ),
                      onChanged: (_) {
                        if (_attempted) {
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _activate,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Activate',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Contact support
              Text(
                'Need a license key? Contact us on WhatsApp',
                style: TextStyle(
                  color: AppColors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                    'https://wa.me/${AppConstants.contactWhatsApp.replaceAll('+', '')}',
                  );
                },
                child: Text(
                  AppConstants.contactWhatsApp,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Developed by ${AppConstants.developerName}',
                style: TextStyle(
                  color: AppColors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
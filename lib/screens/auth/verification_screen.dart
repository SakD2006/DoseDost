import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String patientId;
  final String patientName;

  const VerificationScreen({
    super.key,
    required this.email,
    required this.patientId,
    required this.patientName,
  });

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Timer _timer;
  bool _isEmailVerified = false;
  bool _canResendEmail = true;
  int _resendTimerSeconds = 0;
  late Timer _resendTimer;

  @override
  void initState() {
    super.initState();
    // User needs to be re-fetched to get updated email verification status
    _isEmailVerified = _auth.currentUser?.emailVerified ?? false;

    if (!_isEmailVerified) {
      _startVerificationTimer();
      _startResendTimer();
    }
  }

  void _startVerificationTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkEmailVerified(),
    );
  }

  void _startResendTimer() {
    const int resendTimeout = 60; // 60 seconds cooldown
    setState(() {
      _canResendEmail = false;
      _resendTimerSeconds = resendTimeout;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        setState(() {
          _resendTimerSeconds--;
        });
      } else {
        setState(() {
          _canResendEmail = true;
        });
        _resendTimer.cancel();
      }
    });
  }

  Future<void> _checkEmailVerified() async {
    // Reload user data from Firebase
    await _auth.currentUser?.reload();
    final currentUser = _auth.currentUser;

    if (currentUser?.emailVerified ?? false) {
      _timer.cancel();

      // Update verified status in Firestore
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .update({'Email Verified': true});

      setState(() {
        _isEmailVerified = true;
      });

      // Navigate to home screen after verification
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => HomeScreen(
                  patientId: widget.patientId,
                  patientName: widget.patientName,
                ),
          ),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

    try {
      await _auth.currentUser?.sendEmailVerification();
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    if (!_canResendEmail) {
      _resendTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            Text(
              'Verify your email',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We have sent a verification email to:\n${widget.email}',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Please check your inbox and click on the verification link to complete your registration.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _canResendEmail ? _resendVerificationEmail : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  _canResendEmail
                      ? const Text('Resend Email')
                      : Text('Resend in $_resendTimerSeconds seconds'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                await _auth.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Back to Login'),
            ),
            const SizedBox(height: 24),
            const Text(
              'If you don\'t see the email, check your spam folder or try resending it.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

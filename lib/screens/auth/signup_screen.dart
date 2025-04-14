import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay _breakfastTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _dinnerTime = TimeOfDay(hour: 19, minute: 0);

  String? errorMessage;
  bool _isLoading = false;

  // Calculate age based on date of birth
  int _calculateAge(DateTime birthDate) {
    final DateTime now = DateTime.now();
    int age = now.year - birthDate.year;

    // Adjust age if birthday hasn't occurred yet this year
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light().copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context, String meal) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          meal == 'breakfast'
              ? _breakfastTime
              : meal == 'lunch'
              ? _lunchTime
              : _dinnerTime,
    );

    if (picked != null) {
      setState(() {
        if (meal == 'breakfast') {
          _breakfastTime = picked;
        } else if (meal == 'lunch') {
          _lunchTime = picked;
        } else {
          _dinnerTime = picked;
        }
      });
    }
  }

  Future<void> _signup() async {
    // Input validation
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _selectedDate == null) {
      setState(() {
        errorMessage = "Please fill in all required fields";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      // Create the user using Firebase Auth.
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      User? user = userCredential.user;
      if (user != null) {
        // Calculate age from date of birth
        int age = _calculateAge(_selectedDate!);

        // Save additional user details to Firestore under "patients" collection.
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(user.uid)
            .set({
              'Email': _emailController.text.trim(),
              'First Name': _firstNameController.text.trim(),
              'Last Name': _lastNameController.text.trim(),
              'Date of Birth': Timestamp.fromDate(_selectedDate!),
              'Age': age,
              'Height': _heightController.text.trim(),
              'Weight': _weightController.text.trim(),
              'Meal-timing': {
                'Breakfast': _breakfastTime.format(context),
                'Lunch': _lunchTime.format(context),
                'Dinner': _dinnerTime.format(context),
              },
              'Created At': FieldValue.serverTimestamp(),
            });

        // Navigate to HomeScreen passing the patientId and a display name.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => HomeScreen(
                  patientId: user.uid,
                  patientName:
                      "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}",
                ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        errorMessage = "An unexpected error occurred: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Sign up to get started!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Personal Information Section
                    _buildSectionTitle('Personal Information'),
                    _buildInfoRow([
                      Expanded(
                        child: TextField(
                          controller: _firstNameController,
                          decoration: _inputDecoration('First Name*'),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameController,
                          decoration: _inputDecoration('Last Name*'),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // Date of Birth Field
                    GestureDetector(
                      onTap: () => _pickDate(context),
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: _inputDecoration(
                            'Date of Birth*',
                          ).copyWith(
                            suffixIcon: const Icon(Icons.calendar_today),
                            hintText:
                                _selectedDate == null
                                    ? 'Select your date of birth'
                                    : DateFormat(
                                      'MMM d, yyyy',
                                    ).format(_selectedDate!),
                          ),
                        ),
                      ),
                    ),

                    if (_selectedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                        child: Text(
                          'Age: ${_calculateAge(_selectedDate!)} years',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: _inputDecoration('Email Address*'),
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: _inputDecoration(
                        'Password*',
                      ).copyWith(helperText: 'Minimum 6 characters'),
                      obscureText: true,
                    ),

                    const SizedBox(height: 24),

                    // Health Information Section
                    _buildSectionTitle('Health Information'),
                    _buildInfoRow([
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          decoration: _inputDecoration('Height (cm)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          decoration: _inputDecoration('Weight (kg)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Meal Timing Section
                    _buildSectionTitle('Meal Timings'),
                    _buildTimePickerTile(
                      title: 'Breakfast Time',
                      time: _breakfastTime,
                      onTap: () => _pickTime(context, 'breakfast'),
                    ),
                    _buildTimePickerTile(
                      title: 'Lunch Time',
                      time: _lunchTime,
                      onTap: () => _pickTime(context, 'lunch'),
                    ),
                    _buildTimePickerTile(
                      title: 'Dinner Time',
                      time: _dinnerTime,
                      onTap: () => _pickTime(context, 'dinner'),
                    ),

                    const SizedBox(height: 32),

                    // Signup Button
                    ElevatedButton(
                      onPressed: _signup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text('Log in'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildTimePickerTile({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.access_time, color: Colors.blue),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

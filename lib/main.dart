import 'package:flutter/material.dart';
import '/services/api_service.dart';
import 'screen/po_gr.dart';
import 'package:gr_po_oji/models/api_models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAP Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SapLoginPage(),
    );
  }
}

class SapLoginPage extends StatefulWidget {
  const SapLoginPage({Key? key}) : super(key: key);

  @override
  State<SapLoginPage> createState() => _SapLoginPageState();
}

class _SapLoginPageState extends State<SapLoginPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SapApiService _apiService = SapApiService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle login
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.login(
        userId: _userIdController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.success) {
        _navigateToHome();
      } else {
        _showError(response.message);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      
      String errorMessage = e.message;
      
      if (e.statusCode == 401) {
        errorMessage = 'Invalid user ID or password';
      } else if (e.statusCode == 422) {
        errorMessage = 'Please check your input';
      } else if (e.statusCode >= 500) {
        errorMessage = 'Server error. Please try again later';
      }
      
      _showError(errorMessage);
    } catch (e) {
      if (!mounted) return;
      _showError('Connection error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => PoGrScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Mobile layout
            if (constraints.maxWidth < 600) {
              return _buildMobileLayout();
            }
            // Tablet layout
            else if (constraints.maxWidth < 1200) {
              return _buildTabletLayout();
            }
            // Desktop layout
            else {
              return _buildDesktopLayout();
            }
          },
        ),
      ),
    );
  }

  /// Mobile layout
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 40),
            
            // Company Logo
            SizedBox(
              height: 120,
              child: Image.asset(
                'assets/images/oneject_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 48),
            
            _buildUserIdInputField(),
            SizedBox(height: 16),
            
            _buildPasswordInputField(),
            SizedBox(height: 16),
            
            _buildLoginButton(),
            
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Tablet layout
  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height - 
               MediaQuery.of(context).padding.top - 
               MediaQuery.of(context).padding.bottom,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side - Logo
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: 120,
                          maxWidth: 280,
                        ),
                        child: Image.asset(
                          'assets/images/oneject_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(width: 24),
              
              // Right side - Login form
              Expanded(
                flex: 1,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 350),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 20),
                            
                            _buildUserIdInputField(),
                            SizedBox(height: 12),
                            
                            _buildPasswordInputField(),
                            SizedBox(height: 12),
                            
                            _buildLoginButton(),
                          ],
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
    );
  }

  /// Desktop layout
  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Row(
            children: [
              // Left side - Logo
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 250,
                      child: Image.asset(
                        'assets/images/oneject_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
              
              SizedBox(width: 64),
              
              // Right side - Login form
              Expanded(
                flex: 1,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 450),
                  child: Card(
                    elevation: 8,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 32),
                            
                            _buildUserIdInputField(),
                            SizedBox(height: 24),
                            
                            _buildPasswordInputField(),
                            SizedBox(height: 24),
                            
                            _buildLoginButton(),
                          ],
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
    );
  }

  /// Build User ID input field
  Widget _buildUserIdInputField() {
    return TextFormField(
      controller: _userIdController,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'User ID',
        hintText: 'Enter your user ID',
        prefixIcon: const Icon(Icons.person),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your user ID';
        }
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  /// Build Password input field
  Widget _buildPasswordInputField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _login(),
    );
  }

  /// Build Login button
  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/api_service.dart';
import '/services/auth_service.dart';
import 'screen/po_gr.dart';
import 'package:gr_po_oji/models/api_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final authService = AuthService();
  final apiService = SapApiService();
  
  await authService.initialize();
  await apiService.initialize();
  
  runApp(MyApp(isAuthenticated: authService.isAuthenticated));
}

class MyApp extends StatelessWidget {
  final bool isAuthenticated;
  
  const MyApp({Key? key, required this.isAuthenticated}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAP Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Auto-route based on authentication status
      home: isAuthenticated ? PoGrScreen() : const SapLoginPage(),
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
  final TextEditingController _rfidController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SapApiService _apiService = SapApiService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRfidMode = false;
  
  final FocusNode _rfidFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Setup auto-logout callback
    _apiService.onUnauthorized = _handleUnauthorized;
    
    // Auto-focus RFID field when in RFID mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isRfidMode) {
        _rfidFocusNode.requestFocus();
      }
    });
    
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _rfidController.dispose();
    _rfidFocusNode.dispose();
    super.dispose();
  }

  /// Handle automatic logout when session expires
  void _handleUnauthorized() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please login again.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
    
    // Already on login page, just clear the form
    setState(() {
      _userIdController.clear();
      _passwordController.clear();
      _rfidController.clear();
      _isLoading = false;
    });
  }

  /// Handle normal login (username + password)
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

  /// Handle RFID login
  Future<void> _loginWithRfid() async {
    final rfidValue = _rfidController.text.trim();
    
    if (rfidValue.isEmpty) {
      _showError('Please tap your RFID card');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.loginWithRfid(
        idCard: rfidValue,
      );

      if (!mounted) return;

      if (response.success) {
        _navigateToHome();
      } else {
        _showError(response.message);
        _rfidController.clear();
        _rfidFocusNode.requestFocus();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      
      String errorMessage = e.message;
      
      if (e.statusCode == 401) {
        errorMessage = 'Invalid RFID card';
      } else if (e.statusCode == 404) {
        errorMessage = 'RFID card not registered';
      } else if (e.statusCode >= 500) {
        errorMessage = 'Server error. Please try again later';
      }
      
      _showError(errorMessage);
      _rfidController.clear();
      _rfidFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      _showError('Connection error: ${e.toString()}');
      _rfidController.clear();
      _rfidFocusNode.requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  void _toggleLoginMode() {
    setState(() {
      _isRfidMode = !_isRfidMode;
      _userIdController.clear();
      _passwordController.clear();
      _rfidController.clear();
    });
    
    if (_isRfidMode) {
      Future.delayed(Duration(milliseconds: 100), () {
        _rfidFocusNode.requestFocus();
      });
    }
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildMobileLayout();
            } else if (constraints.maxWidth < 1200) {
              return _buildTabletLayout();
            } else {
              return _buildDesktopLayout();
            }
          },
        ),
        ),
    );
  }

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
            SizedBox(
              height: 120,
              child: Image.asset(
                'assets/images/oneject_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 48),
            _buildLoginModeToggle(),
            SizedBox(height: 24),
            if (_isRfidMode) ...[
              _buildRfidInputField(),
              SizedBox(height: 16),
              _buildRfidLoginButton(),
            ] else ...[
              _buildUserIdInputField(),
              SizedBox(height: 16),
              _buildPasswordInputField(),
              SizedBox(height: 16),
              _buildLoginButton(),
            ],
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
                            _buildLoginModeToggle(),
                            SizedBox(height: 20),
                            if (_isRfidMode) ...[
                              _buildRfidInputField(),
                              SizedBox(height: 12),
                              _buildRfidLoginButton(),
                            ] else ...[
                              _buildUserIdInputField(),
                              SizedBox(height: 12),
                              _buildPasswordInputField(),
                              SizedBox(height: 12),
                              _buildLoginButton(),
                            ],
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

  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Row(
            children: [
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
                            _buildLoginModeToggle(),
                            SizedBox(height: 24),
                            if (_isRfidMode) ...[
                              _buildRfidInputField(),
                              SizedBox(height: 24),
                              _buildRfidLoginButton(),
                            ] else ...[
                              _buildUserIdInputField(),
                              SizedBox(height: 24),
                              _buildPasswordInputField(),
                              SizedBox(height: 24),
                              _buildLoginButton(),
                            ],
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

  Widget _buildLoginModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isRfidMode) _toggleLoginMode();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isRfidMode ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      color: !_isRfidMode ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Username',
                      style: TextStyle(
                        color: !_isRfidMode ? Colors.white : Colors.grey[600],
                        fontWeight: !_isRfidMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isRfidMode) _toggleLoginMode();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isRfidMode ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: _isRfidMode ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'RFID Card',
                      style: TextStyle(
                        color: _isRfidMode ? Colors.white : Colors.grey[600],
                        fontWeight: _isRfidMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRfidInputField() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.tap_and_play, color: Colors.blue, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isLoading 
                    ? 'Processing...' 
                    : 'Tap your RFID card on the reader',
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _rfidController,
          focusNode: _rfidFocusNode,
          enabled: !_isLoading,
          autofocus: _isRfidMode,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: 'RFID Card Number',
            hintText: 'Scan or enter RFID card',
            prefixIcon: const Icon(Icons.credit_card),
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
          onFieldSubmitted: (_) => _loginWithRfid(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please tap your RFID card';
            }
            return null;
          },
        ),
      ],
    );
  }

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

  Widget _buildRfidLoginButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _loginWithRfid,
        icon: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.tap_and_play, color: Colors.white),
        label: Text(
          _isLoading ? 'Processing...' : 'Login with Card',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
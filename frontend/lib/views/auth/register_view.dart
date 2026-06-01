import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../chat/inbox_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _profileImageController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  late AnimationController _shakeController;

  bool _isNameValid = false;
  bool _isEmailValid = false;
  int _passwordStrength = 0; // 0 to 4 strength meter scale

  String _selectedAvatarUrl = '';

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  bool _hasSpecialChar = false;

  final List<Map<String, String>> _mockAvatars = [
    {
      'name': 'Luna',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=Luna',
    },
    {
      'name': 'Dexter',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=Dexter',
    },
    {
      'name': 'Nova',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=Nova',
    },
    {
      'name': 'Shadow',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=Shadow',
    },
    {
      'name': 'Felix',
      'url': 'https://api.dicebear.com/7.x/pixel-art/png?seed=Felix',
    },
    {'name': 'Zoe', 'url': 'https://api.dicebear.com/7.x/lorelei/png?seed=Zoe'},
  ];

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _nameController.addListener(_validateName);
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);

    _nameFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _profileImageController.dispose();

    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    _shakeController.dispose();
    super.dispose();
  }

  void _validateName() {
    final text = _nameController.text.trim();
    final valid = text.isNotEmpty && text.length >= 2;
    if (valid != _isNameValid) {
      setState(() => _isNameValid = valid);
    }
  }

  void _validateEmail() {
    final text = _emailController.text.trim();
    final emailRegex = RegExp(r'^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$');
    final valid = text.isNotEmpty && emailRegex.hasMatch(text);
    if (valid != _isEmailValid) {
      setState(() => _isEmailValid = valid);
    }
  }

  void _validatePassword() {
    final text = _passwordController.text;

    _hasMinLength = text.length >= 8;
    _hasUppercase = text.contains(RegExp(r'[A-Z]'));
    _hasLowercase = text.contains(RegExp(r'[a-z]'));
    _hasDigits = text.contains(RegExp(r'[0-9]'));
    _hasSpecialChar = text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int strength = 0;
    if (text.isNotEmpty) {
      if (_hasMinLength) strength++;
      if (_hasUppercase && _hasLowercase) strength++;
      if (_hasDigits) strength++;
      if (_hasSpecialChar) strength++;
    }

    if (strength != _passwordStrength) {
      setState(() => _passwordStrength = strength);
    } else {
      setState(() {});
    }
  }

  void _triggerErrorShake() {
    _shakeController.forward(from: 0.0);
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _triggerErrorShake();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      profileImage: _profileImageController.text.trim().isEmpty
          ? null
          : _profileImageController.text.trim(),
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const InboxView(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
          (route) => false,
        );
      } else {
        _triggerErrorShake();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authProvider.errorMessage ?? 'Registration failed.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        );
      }
    }
  }

  Color _getPasswordStrengthColor() {
    switch (_passwordStrength) {
      case 1:
        return const Color(0xFFFF4A5A); // Red (Weak)
      case 2:
        return const Color(0xFFFFB300); // Amber (Fair)
      case 3:
        return const Color(0xFF10B981); // Emerald (Good)
      case 4:
        return const Color(0xFF00E5FF); // Neon Cyan (Bulletproof)
      default:
        return Colors.grey.withValues(alpha: 0.24);
    }
  }

  String _getPasswordStrengthLabel() {
    switch (_passwordStrength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Bulletproof';
      default:
        return '';
    }
  }

  Color _getColorFromHash(String name, int index) {
    if (name.isEmpty) return index == 0 ? Colors.blueGrey : Colors.grey;
    final int hash = name.hashCode;
    final List<Color> colors = [
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFFD946EF), // Pink/Magenta
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF3B82F6), // Bright Blue
    ];
    final int offset = (hash.abs() + index * 5) % colors.length;
    return colors[offset];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Column(
                      children: [
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your details to create a secure account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final double shakeOffset =
                          math.sin(_shakeController.value * 3 * math.pi) *
                          (1.0 - _shakeController.value) *
                          8.0;
                      return Transform.translate(
                        offset: Offset(shakeOffset, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(28.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAvatarPickerSection(theme),
                            const SizedBox(height: 24),

                            _buildNameField(theme),
                            const SizedBox(height: 20),

                            _buildEmailField(theme),
                            const SizedBox(height: 20),

                            _buildPasswordField(theme),

                            _buildPasswordStrengthIndicatorSection(theme),
                            const SizedBox(height: 32),

                            _buildSubmitButton(authProvider, theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Navigate to Sign In screen',
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPickerSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.face_retouching_natural_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Select Profile Character',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: Semantics(
            label: 'Profile character selector',
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mockAvatars.length + 1,
              itemBuilder: (context, index) {
                final isInitialsAvatar = index == 0;
                final isSelected = isInitialsAvatar
                    ? _selectedAvatarUrl.isEmpty
                    : _selectedAvatarUrl == _mockAvatars[index - 1]['url'];

                return Semantics(
                  button: true,
                  label: isInitialsAvatar ? 'Default character avatar' : 'Character avatar ${index}',
                  selected: isSelected,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isInitialsAvatar) {
                          _selectedAvatarUrl = '';
                          _profileImageController.text = '';
                        } else {
                          final url = _mockAvatars[index - 1]['url']!;
                          _selectedAvatarUrl = url;
                          _profileImageController.text = url;
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: isInitialsAvatar
                          ? _buildDynamicInitialsAvatarCircle(isSelected)
                          : ClipOval(
                              child: Image.network(
                                _mockAvatars[index - 1]['url']!,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.person_rounded,
                                      color: Colors.grey,
                                    ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicInitialsAvatarCircle(bool isSelected) {
    final name = _nameController.text.trim();
    final String initials = name.isEmpty
        ? '?'
        : name.split(' ').map((e) => e[0].toUpperCase()).take(2).join('');

    final Color gradStart = _getColorFromHash(name, 0);
    final Color gradEnd = _getColorFromHash(name, 1);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [gradStart, gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: isSelected && name.isNotEmpty
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return Semantics(
      label: 'Full Name field',
      child: TextFormField(
        controller: _nameController,
        focusNode: _nameFocusNode,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Full Name',
          prefixIcon: const Icon(Icons.person_outline_rounded),
          suffixIcon: _buildValidIndicator(_isNameValid),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your name';
          }
          if (value.trim().length < 2) {
            return 'Name must be at least 2 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme) {
    return Semantics(
      label: 'Email Address field',
      child: TextFormField(
        controller: _emailController,
        focusNode: _emailFocusNode,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Email Address',
          prefixIcon: const Icon(Icons.email_outlined),
          suffixIcon: _buildValidIndicator(_isEmailValid),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your email';
          }
          final emailRegex = RegExp(
            r'^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$',
          );
          if (!emailRegex.hasMatch(value.trim())) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return Semantics(
      label: 'Password field',
      child: TextFormField(
        controller: _passwordController,
        focusNode: _passwordFocusNode,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submitForm(),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outlined),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPasswordStrengthIndicatorSection(ThemeData theme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _passwordController.text.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                Row(
                  children: List.generate(4, (index) {
                    final active = index < _passwordStrength;
                    final color = _getPasswordStrengthColor();
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.only(
                          left: index == 0 ? 0 : 3,
                          right: index == 3 ? 0 : 3,
                        ),
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: active
                              ? color
                              : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Strength:',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _getPasswordStrengthLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getPasswordStrengthColor(),
                      ),
                    ),
                  ],
                ),

                if (_passwordFocusNode.hasFocus) ...[
                  const SizedBox(height: 12),
                  _buildRequirementRow(
                    'At least 8 characters long',
                    _hasMinLength,
                    theme,
                  ),
                  _buildRequirementRow(
                    'Uppercase and lowercase letter',
                    _hasUppercase && _hasLowercase,
                    theme,
                  ),
                  _buildRequirementRow(
                    'At least one digit (0-9)',
                    _hasDigits,
                    theme,
                  ),
                  _buildRequirementRow(
                    r'At least one symbol (e.g. !@#$)',
                    _hasSpecialChar,
                    theme,
                  ),
                ],
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildRequirementRow(String text, bool met, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: met
                    ? const Icon(
                        Icons.check,
                        size: 9,
                        color: Color(0xFF10B981),
                        key: ValueKey('check'),
                      )
                    : Icon(
                        Icons.lens,
                        size: 3.5,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        key: const ValueKey('dot'),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: met
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: met ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidIndicator(bool isValid) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: isValid
          ? const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              key: ValueKey('valid'),
            )
          : const SizedBox.shrink(key: ValueKey('invalid')),
    );
  }

  Widget _buildSubmitButton(
    AuthProvider authProvider,
    ThemeData theme,
  ) {
    return Semantics(
      button: true,
      label: 'Sign up button',
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: authProvider.isLoading ? null : _submitForm,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: authProvider.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Login fields
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginPasswordVisible = false;

  // Signup fields
  final _signupFormKey = GlobalKey<FormState>();
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  bool _signupPasswordVisible = false;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await context.read<AppState>().login(
            _loginEmailCtrl.text.trim(),
            _loginPasswordCtrl.text,
          );
      if (!mounted) return;
      _goToShell();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!(_signupFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await context.read<AppState>().signup(
            _signupNameCtrl.text.trim(),
            _signupEmailCtrl.text.trim(),
            _signupPasswordCtrl.text,
          );
      if (!mounted) return;
      _goToShell();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToShell() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D2137), Color(0xFF1D4E89), Color(0xFF2B6CB0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo / branding ─────────────────────────────
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.route_rounded,
                        color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'RoadWatch AI',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Civic road intelligence platform',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Card ────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tab bar
                        Container(
                          decoration: BoxDecoration(
                            color: AppConfig.paper,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28)),
                          ),
                          child: TabBar(
                            controller: _tabs,
                            labelColor: AppConfig.deepNavy,
                            unselectedLabelColor:
                                AppConfig.deepNavy.withValues(alpha: 0.45),
                            labelStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppConfig.deepNavy.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            padding: const EdgeInsets.all(8),
                            tabs: const [
                              Tab(text: 'Sign In'),
                              Tab(text: 'Sign Up'),
                            ],
                          ),
                        ),

                        // Error banner
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppConfig.dangerRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppConfig.dangerRed
                                      .withValues(alpha: 0.28)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: AppConfig.dangerRed, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                        color: AppConfig.dangerRed,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Tab views
                        SizedBox(
                          height: _tabs.index == 0 ? 300 : 370,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _LoginForm(
                                formKey: _loginFormKey,
                                emailCtrl: _loginEmailCtrl,
                                passwordCtrl: _loginPasswordCtrl,
                                passwordVisible: _loginPasswordVisible,
                                onTogglePassword: () => setState(() =>
                                    _loginPasswordVisible =
                                        !_loginPasswordVisible),
                                onSubmit: _handleLogin,
                                isLoading: _isLoading,
                              ),
                              _SignupForm(
                                formKey: _signupFormKey,
                                nameCtrl: _signupNameCtrl,
                                emailCtrl: _signupEmailCtrl,
                                passwordCtrl: _signupPasswordCtrl,
                                passwordVisible: _signupPasswordVisible,
                                onTogglePassword: () => setState(() =>
                                    _signupPasswordVisible =
                                        !_signupPasswordVisible),
                                onSubmit: _handleSignup,
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'By continuing you agree to our terms of service.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Login Form ──────────────────────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final bool isLoading;

  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.passwordVisible,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordCtrl,
              obscureText: !passwordVisible,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConfig.deepNavy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Sign In',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Signup Form ─────────────────────────────────────────────────────────────

class _SignupForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final bool isLoading;

  const _SignupForm({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.passwordVisible,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordCtrl,
              obscureText: !passwordVisible,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Password (min 8 chars)',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConfig.deepNavy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Create Account',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

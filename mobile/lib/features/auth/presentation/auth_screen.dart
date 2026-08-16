import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/state/app_state.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialSignUp = false});

  final bool initialSignUp;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late bool _signUp;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _signUp = widget.initialSignUp;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 18 : 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Card(
                  color: Theme.of(context).colorScheme.surface,
                  child: compact
                      ? Column(
                          children: [
                            const _AuthStory(compact: true),
                            _buildForm(appState, compact: true),
                          ],
                        )
                      : IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(child: _AuthStory()),
                              Expanded(child: _buildForm(appState)),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppState appState, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.all(compact ? 24 : 42),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _signUp ? 'Create your account' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _signUp
                  ? 'Save favorites, trips, charging receipts, and preferences on this browser.'
                  : appState.hasLocalAccount
                      ? 'Sign in to continue to your saved VoltMapEV workspace.'
                      : 'Create an account only when you want to save personal activity.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 26),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Login'),
                  icon: Icon(Icons.login_rounded),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Sign up'),
                  icon: Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
              selected: {_signUp},
              onSelectionChanged: (selection) {
                setState(() {
                  _signUp = selection.first;
                  _serverError = null;
                });
              },
            ),
            const SizedBox(height: 24),
            if (_signUp) ...[
              TextFormField(
                key: const Key('authNameField'),
                controller: _nameController,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              key: const Key('authIdentifierField'),
              controller: _identifierController,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email or India mobile (+91)',
                hintText: 'name@example.com or +91 9392788714',
                prefixIcon: Icon(Icons.contact_mail_outlined),
                helperText:
                    'India mobile numbers use +91 by default; email also works.',
              ),
              validator: (value) {
                return AppState.normalizeAccountIdentifier(value ?? '') != null
                    ? null
                    : 'Enter a valid email or phone number';
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('authPasswordField'),
              controller: _passwordController,
              autofillHints: _signUp
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              obscureText: _obscurePassword,
              textInputAction:
                  _signUp ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _signUp ? null : (_) => _submit(appState),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                final password = value ?? '';
                if (!_signUp) {
                  return password.isEmpty ? 'Enter your password' : null;
                }
                final strongEnough = password.length >= 8 &&
                    RegExp('[A-Z]').hasMatch(password) &&
                    RegExp('[a-z]').hasMatch(password) &&
                    RegExp('[0-9]').hasMatch(password);
                return strongEnough
                    ? null
                    : 'Use 8+ characters with upper, lower, and a number';
              },
            ),
            if (_signUp) ...[
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('authConfirmField'),
                controller: _confirmController,
                autofillHints: const [AutofillHints.newPassword],
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(appState),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'Passwords do not match',
              ),
            ],
            if (_serverError != null) ...[
              const SizedBox(height: 14),
              Text(
                _serverError!,
                key: const Key('authError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('authSubmitButton'),
                onPressed: _submitting ? null : () => _submit(appState),
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _signUp
                            ? Icons.arrow_forward_rounded
                            : Icons.login_rounded,
                      ),
                label: Text(_signUp ? 'Create account' : 'Login securely'),
              ),
            ),
            if (!_signUp) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('continueWithoutAccountButton'),
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Continue without an account'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Privacy: your salted password hash and account data stay in this browser. Never enter payment credentials you use elsewhere.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(AppState appState) async {
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final error = _signUp
        ? await appState.signUp(
            name: _nameController.text,
            identifier: _identifierController.text,
            password: _passwordController.text,
          )
        : await appState.signIn(
            identifier: _identifierController.text,
            password: _passwordController.text,
          );
    if (!mounted) return;
    if (error == null && appState.isRegisteredAccount) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() {
      _submitting = false;
      _serverError = error;
    });
  }
}

class _AuthStory extends StatelessWidget {
  const _AuthStory({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 24 : 42),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2C22), AppTheme.brandNavy],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandLime, AppTheme.brandGreen],
              ),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppTheme.brandNavy,
              size: 32,
            ),
          ),
          SizedBox(height: compact ? 18 : 34),
          Text(
            'VoltMapEV',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontSize: compact ? 36 : 52,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Discover India’s verified charging footprint and plan your next charge with confidence.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFC4D8CF),
                  fontSize: compact ? 15 : 18,
                ),
          ),
          if (!compact) ...[
            const SizedBox(height: 32),
            const _StoryPoint(
              icon: Icons.public_rounded,
              title: '29,277 verified public stations',
              subtitle: 'Official state totals from the Government of India',
            ),
            const SizedBox(height: 18),
            const _StoryPoint(
              icon: Icons.search_rounded,
              title: 'Search any PIN or area',
              subtitle: 'Find official charger results across India',
            ),
            const SizedBox(height: 18),
            const _StoryPoint(
              icon: Icons.receipt_long_outlined,
              title: 'Your charging workspace',
              subtitle: 'Keep trips, favorites, and demo receipts together',
            ),
          ],
        ],
      ),
    );
  }
}

class _StoryPoint extends StatelessWidget {
  const _StoryPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.brandLime),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9FB7AD),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

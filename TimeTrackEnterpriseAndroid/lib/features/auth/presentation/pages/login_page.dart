import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/i18n/app_locale.dart';
import '../../../../app/i18n/app_strings.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).login(
          username: _usernameController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final strings = AppStrings.of(context);
    final fieldErrors = state.fieldErrors;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _LoginBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => toggleAppLocale(ref),
                          child: Text(strings.languageSwitch),
                        ),
                      ),
                      Center(
                        child: AppLogo(
                          size: 82,
                          background: Colors.white.withValues(alpha: 0.14),
                          showShadow: false,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.appTagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                      ),
                      const SizedBox(height: 26),
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        border: false,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                strings.loginTitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.loginDescription,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              if (state.errorMessage != null) ...<Widget>[
                                AppBanner(
                                  message: state.errorMessage!,
                                  tone: Theme.of(context).colorScheme.error,
                                  icon: Icons.error_outline_rounded,
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _usernameController,
                                enabled: !state.isSubmitting,
                                textInputAction: TextInputAction.next,
                                autofillHints: const <String>[
                                  AutofillHints.username,
                                ],
                                decoration: InputDecoration(
                                  labelText: strings.username,
                                  hintText: strings.usernameHint,
                                  prefixIcon:
                                      const Icon(Icons.person_outline_rounded),
                                  errorText: fieldErrors['username'],
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return strings.usernameRequired;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !state.isSubmitting,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const <String>[
                                  AutofillHints.password,
                                ],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: strings.password,
                                  hintText: strings.passwordHint,
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  errorText: fieldErrors['password'],
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? strings.showPassword
                                        : strings.hidePassword,
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return strings.passwordRequired;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              GradientButton(
                                label: strings.signIn,
                                icon: Icons.login_rounded,
                                loading: state.isSubmitting,
                                onPressed: state.isSubmitting ? null : _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.shield_moon_outlined,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              strings.offlineHint,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${AppConfig.appName} · ${AppConfig.version}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: AppColors.headerGradient,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -110,
            left: -70,
            child: _Glow(
              size: 300,
              color: AppColors.gold.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -80,
            child: _Glow(
              size: 340,
              color: AppColors.mint.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

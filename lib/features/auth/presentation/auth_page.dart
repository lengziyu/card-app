import 'dart:async';

import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/widgets/app_feedback.dart';
import 'package:cardfi/core/motion/celebration_effects.dart';
import 'package:cardfi/features/auth/data/auth_controller.dart';
import 'package:cardfi/features/catalog/domain/card_summary.dart';
import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

enum AuthMode { login, passwordRecovery }

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.controller,
    required this.onBack,
    required this.celebrationCards,
    this.referralEnabled = false,
    this.onReferralCodeAccepted,
    super.key,
  });

  final AuthController controller;
  final VoidCallback onBack;
  final List<CardSummary> celebrationCards;
  final bool referralEnabled;
  final Future<void> Function(String code)? onReferralCodeAccepted;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _referralCodeController = TextEditingController();
  bool _usePassword = false;
  bool _obscurePassword = true;
  bool _otpSent = false;
  bool _passwordRecoveryOtpSent = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  late int _registrationCelebrationVersion;
  bool _showRegistrationCelebration = false;

  @override
  void initState() {
    super.initState();
    _registrationCelebrationVersion =
        widget.controller.registrationCelebrationVersion;
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _accountController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _referralCodeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _handleControllerChanged() {
    final nextVersion = widget.controller.registrationCelebrationVersion;
    if (nextVersion != _registrationCelebrationVersion) {
      _registrationCelebrationVersion = nextVersion;
      _showRegistrationCelebration = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    final email = _accountController.text.trim();
    if (_passwordRecoveryOtpSent) {
      await widget.controller.verifyPasswordRecoveryOtp(
        email: email,
        token: _otpController.text,
      );
      return;
    }
    if (_usePassword) {
      final signedIn = await widget.controller.signIn(
        email: email,
        password: _passwordController.text,
      );
      if (signedIn) _passwordController.clear();
      return;
    }
    if (!_otpSent) {
      await _savePendingReferralCode();
      final sent = await widget.controller.sendEmailOtp(email);
      if (sent && mounted) {
        setState(() => _otpSent = true);
        _startResendTimer();
      }
      return;
    }
    await widget.controller.verifyEmailOtp(
      email: email,
      token: _otpController.text,
    );
    if (widget.controller.isVerified) _otpController.clear();
  }

  Future<void> _savePendingReferralCode() async {
    final code = _referralCodeController.text.trim();
    if (code.isNotEmpty) await widget.onReferralCodeAccepted?.call(code);
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || widget.controller.loading) return;
    final emailError = _validateAccount(_accountController.text);
    if (emailError != null) {
      AppNotice.info(context, emailError, title: '邮箱验证码');
      return;
    }
    final sent = _passwordRecoveryOtpSent
        ? await widget.controller.resetPassword(_accountController.text.trim())
        : await widget.controller.sendEmailOtp(_accountController.text.trim());
    if (sent) _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    if (mounted) setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    widget.controller.resetAuthenticationFlow();
    _otpController.clear();
    setState(() {
      _otpSent = false;
      _passwordRecoveryOtpSent = false;
      _resendSeconds = 0;
    });
  }

  void _switchEmailLoginMethod() {
    _resendTimer?.cancel();
    widget.controller.resetAuthenticationFlow();
    _otpController.clear();
    _passwordController.clear();
    setState(() {
      _usePassword = !_usePassword;
      _otpSent = false;
      _passwordRecoveryOtpSent = false;
      _resendSeconds = 0;
      _obscurePassword = true;
    });
  }

  Future<void> _resetPassword() async {
    final emailError = _validateAccount(_accountController.text);
    if (emailError != null) {
      AppNotice.info(context, emailError, title: '重置密码');
      return;
    }
    FocusScope.of(context).unfocus();
    final sent = await widget.controller.resetPassword(
      _accountController.text.trim(),
    );
    if (!sent || !mounted) return;
    _passwordController.clear();
    _otpController.clear();
    setState(() => _passwordRecoveryOtpSent = true);
    _startResendTimer();
  }

  Future<void> _signInWithGoogle() async {
    await _savePendingReferralCode();
    await widget.controller.signInWithGoogle();
  }

  Future<void> _signInWithApple() async {
    final continueWithApple = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('使用 Apple 继续'),
        content: const Text(
          '如果你已有 CardFi 邮箱账号，请先取消并使用邮箱验证码登录，再到设置中绑定 Apple，避免 Apple 隐藏邮箱生成独立账号。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('使用邮箱登录'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('继续使用 Apple'),
          ),
        ],
      ),
    );
    if (continueWithApple != true) return;
    await _savePendingReferralCode();
    await widget.controller.signInWithApple();
  }

  String? _validateAccount(String? value) {
    final account = value?.trim() ?? '';
    if (account.isEmpty) return '请输入邮箱地址';
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(account)) return '请输入有效的邮箱地址';
    return null;
  }

  String? _validateOtp(String? value) {
    if (!_otpSent && !_passwordRecoveryOtpSent) return null;
    final token = value?.trim() ?? '';
    if (!RegExp(r'^\d{6}$').hasMatch(token)) return '请输入 6 位验证码';
    return null;
  }

  String? _validatePassword(String? value) {
    if (!_usePassword || _passwordRecoveryOtpSent) return null;
    if (value == null || value.isEmpty) return '请输入密码';
    // This is a compatibility login for existing accounts. Do not impose new
    // password-strength rules that could reject a valid historical password.
    return null;
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.line),
    );
    return InputDecoration(
      hintText: AppLocalizations.of(context).text(hint),
      hintStyle: TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.glassStrong,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: AppColors.cyan, width: 1.4),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: Color(0xFFFF8496)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: Color(0xFFFF8496), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final compactLayout =
        MediaQuery.textScalerOf(context).scale(1) > 1.35 ||
        MediaQuery.sizeOf(context).width < 340;
    return Stack(
      children: [
        CustomScrollView(
          key: const Key('login-page'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                topInset + 24,
                20,
                28 + bottomInset,
              ),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: const Alignment(0, -0.12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      decoration: _authPanelDecoration(),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (compactLayout)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _BrandMark(),
                                  const SizedBox(height: 14),
                                  _HomeButton(
                                    key: const Key('auth-home'),
                                    onPressed: widget.onBack,
                                  ),
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(child: _BrandMark()),
                                  const SizedBox(width: 12),
                                  _HomeButton(
                                    key: const Key('auth-home'),
                                    onPressed: widget.onBack,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 28),
                            TextFormField(
                              key: const Key('auth-account-field'),
                              controller: _accountController,
                              readOnly:
                                  (!_usePassword && _otpSent) ||
                                  _passwordRecoveryOtpSent,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: _decoration(
                                hint: '邮箱地址',
                                icon: Icons.mail_outline_rounded,
                                suffixIcon:
                                    ((!_usePassword && _otpSent) ||
                                        _passwordRecoveryOtpSent)
                                    ? TextButton(
                                        key: const Key('auth-change-email'),
                                        onPressed: _changeEmail,
                                        child: const Text('更换'),
                                      )
                                    : null,
                              ),
                              validator: _validateAccount,
                            ),
                            if (_usePassword && !_passwordRecoveryOtpSent) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('auth-password-field'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                keyboardType: TextInputType.visiblePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                autocorrect: false,
                                enableSuggestions: false,
                                onFieldSubmitted: (_) => unawaited(_submit()),
                                decoration: _decoration(
                                  hint: '密码',
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    key: const Key('auth-toggle-password'),
                                    tooltip: AppLocalizations.of(
                                      context,
                                    ).text(_obscurePassword ? '显示密码' : '隐藏密码'),
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
                                validator: _validatePassword,
                              ),
                            ] else if (_otpSent ||
                                _passwordRecoveryOtpSent) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('auth-otp-field'),
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                maxLength: 6,
                                onFieldSubmitted: (_) => unawaited(_submit()),
                                decoration: _decoration(
                                  hint: _passwordRecoveryOtpSent
                                      ? '6 位密码重置验证码'
                                      : '6 位邮箱验证码',
                                  icon: Icons.password_rounded,
                                ),
                                validator: _validateOtp,
                              ),
                            ],
                            if (widget.referralEnabled &&
                                !_usePassword &&
                                !_otpSent) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('auth-referral-code-field'),
                                controller: _referralCodeController,
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.characters,
                                autocorrect: false,
                                enableSuggestions: false,
                                maxLength: 8,
                                decoration: _decoration(
                                  hint: '邀请码（可选）',
                                  icon: Icons.card_giftcard_rounded,
                                ),
                                validator: (value) {
                                  final code = value?.trim() ?? '';
                                  if (code.isEmpty) return null;
                                  return RegExp(
                                        r'^[A-Za-z2-9]{8}$',
                                      ).hasMatch(code)
                                      ? null
                                      : '请输入 8 位邀请码';
                                },
                              ),
                            ],
                            if (widget.controller.message
                                case final message?) ...[
                              const SizedBox(height: 12),
                              _AuthStatusCard(message: message),
                            ],
                            const SizedBox(height: 16),
                            _GradientSubmitButton(
                              key: const Key('auth-submit'),
                              onPressed: widget.controller.loading
                                  ? null
                                  : _submit,
                              label: widget.controller.loading
                                  ? '请稍候…'
                                  : _passwordRecoveryOtpSent
                                  ? '验证重置码'
                                  : _usePassword
                                  ? '登录'
                                  : _otpSent
                                  ? '验证并登录'
                                  : '获取验证码',
                            ),
                            if (_usePassword && !_passwordRecoveryOtpSent) ...[
                              const SizedBox(height: 8),
                              Row(
                                key: const Key('auth-password-links'),
                                children: [
                                  TextButton(
                                    key: const Key('auth-forgot-password'),
                                    onPressed: widget.controller.loading
                                        ? null
                                        : _resetPassword,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                    ),
                                    child: const Text('忘记密码'),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    key: const Key('auth-use-email-otp'),
                                    onPressed: widget.controller.loading
                                        ? null
                                        : _switchEmailLoginMethod,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerRight,
                                    ),
                                    child: const Text('使用邮箱验证码登录'),
                                  ),
                                ],
                              ),
                            ] else if (!_otpSent &&
                                !_passwordRecoveryOtpSent) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  key: const Key('auth-use-password'),
                                  onPressed: widget.controller.loading
                                      ? null
                                      : _switchEmailLoginMethod,
                                  child: const Text('使用密码登录'),
                                ),
                              ),
                            ],
                            if (_otpSent || _passwordRecoveryOtpSent) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                key: const Key('auth-resend-otp'),
                                onPressed:
                                    _resendSeconds == 0 &&
                                        !widget.controller.loading
                                    ? _resendOtp
                                    : null,
                                child: Text(
                                  _resendSeconds > 0
                                      ? '$_resendSeconds 秒后可重新发送'
                                      : '重新发送验证码',
                                ),
                              ),
                            ],
                            if (!_otpSent &&
                                !_passwordRecoveryOtpSent &&
                                (widget.controller.appleConfigured ||
                                    widget.controller.googleConfigured)) ...[
                              const SizedBox(height: 18),
                              const _AuthDivider(label: '或使用以下方式登录'),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (widget.controller.appleConfigured)
                                    _SocialAuthButton(
                                      key: const Key('auth-apple'),
                                      icon: Icons.apple,
                                      label: '使用 Apple 登录',
                                      onPressed: widget.controller.loading
                                          ? null
                                          : _signInWithApple,
                                    ),
                                  if (widget.controller.appleConfigured &&
                                      widget.controller.googleConfigured)
                                    const SizedBox(width: 14),
                                  if (widget.controller.googleConfigured)
                                    _SocialAuthButton(
                                      key: const Key('auth-google'),
                                      leading: const _GoogleMark(),
                                      label: '使用 Google 登录',
                                      onPressed: widget.controller.loading
                                          ? null
                                          : _signInWithGoogle,
                                    ),
                                ],
                              ),
                            ],
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
        if (_showRegistrationCelebration)
          Positioned.fill(
            child: CardBurstCelebration(
              key: ValueKey(
                'registration-success-card-burst-$_registrationCelebrationVersion',
              ),
              trigger: _registrationCelebrationVersion,
              cards: widget.celebrationCards,
              onFinished: () {
                if (mounted) {
                  setState(() => _showRegistrationCelebration = false);
                }
              },
            ),
          ),
      ],
    );
  }

  BoxDecoration _authPanelDecoration() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.isDark
          ? const [Color(0xE30A1238), Color(0xE30A102D), Color(0xE31B1758)]
          : const [Color(0xF2FFFFFF), Color(0xE8F7F9FF), Color(0xE1F0ECFF)],
    ),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: AppColors.isDark
          ? const Color(0x6B6578DD)
          : const Color(0xE8DFE6FF),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.isDark
            ? const Color(0x52040715)
            : const Color(0x337787C9),
        blurRadius: 54,
        offset: const Offset(0, 22),
      ),
    ],
  );
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    required this.controller,
    required this.onBack,
    super.key,
  });

  final AuthController controller;
  final VoidCallback onBack;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PasswordRecoveryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '请输入密码';
    if (password.length < 8) return '密码至少需要 8 位';
    return null;
  }

  String? _validateConfirmation(String? value) {
    if ((value ?? '').isEmpty) return '请再次输入新密码';
    if (value != _passwordController.text) return '两次输入的密码不一致';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final updated = await widget.controller.updateRecoveredPassword(
      _passwordController.text,
    );
    if (updated) {
      _passwordController.clear();
      _confirmationController.clear();
    }
  }

  Future<void> _cancel() async {
    await widget.controller.cancelPasswordRecovery();
    if (mounted) widget.onBack();
  }

  InputDecoration _decoration({required String hint, required IconData icon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.line),
    );
    return InputDecoration(
      hintText: AppLocalizations.of(context).text(hint),
      hintStyle: TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 21),
      suffixIcon: IconButton(
        key: Key('password-recovery-visibility-$hint'),
        tooltip: AppLocalizations.of(
          context,
        ).text(_obscurePassword ? '显示密码' : '隐藏密码'),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
      filled: true,
      fillColor: AppColors.glassStrong,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: AppColors.cyan, width: 1.4),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFFF8496)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFFF8496), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.isDark
          ? const [Color(0xE30A1238), Color(0xE30A102D), Color(0xE31B1758)]
          : const [Color(0xF2FFFFFF), Color(0xE8F7F9FF), Color(0xE1F0ECFF)],
    ),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: AppColors.isDark
          ? const Color(0x6B6578DD)
          : const Color(0xE8DFE6FF),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.isDark
            ? const Color(0x52040715)
            : const Color(0x337787C9),
        blurRadius: 54,
        offset: const Offset(0, 22),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final compactLayout =
        MediaQuery.textScalerOf(context).scale(1) > 1.35 ||
        MediaQuery.sizeOf(context).width < 340;
    return CustomScrollView(
      key: const Key('password-recovery-page'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, topInset + 24, 20, 28 + bottomInset),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: const Alignment(0, -0.12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: _panelDecoration(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (compactLayout)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _BrandMark(),
                              const SizedBox(height: 14),
                              _HomeButton(
                                key: const Key('password-recovery-home'),
                                onPressed: () => unawaited(_cancel()),
                              ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(child: _BrandMark()),
                              const SizedBox(width: 12),
                              _HomeButton(
                                key: const Key('password-recovery-home'),
                                onPressed: () => unawaited(_cancel()),
                              ),
                            ],
                          ),
                        const SizedBox(height: 28),
                        const Text(
                          '设置新密码',
                          key: Key('password-recovery-title'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请输入至少 8 位的新密码。更新后，账号和已同步数据不会改变。',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          key: const Key('password-recovery-password'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: _decoration(
                            hint: '新密码',
                            icon: Icons.lock_outline_rounded,
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('password-recovery-confirmation'),
                          controller: _confirmationController,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          autocorrect: false,
                          enableSuggestions: false,
                          onFieldSubmitted: (_) => unawaited(_submit()),
                          decoration: _decoration(
                            hint: '确认新密码',
                            icon: Icons.verified_user_outlined,
                          ),
                          validator: _validateConfirmation,
                        ),
                        if (widget.controller.message case final message?) ...[
                          const SizedBox(height: 12),
                          _AuthStatusCard(message: message),
                        ],
                        const SizedBox(height: 16),
                        _GradientSubmitButton(
                          key: const Key('password-recovery-submit'),
                          onPressed: widget.controller.loading ? null : _submit,
                          label: widget.controller.loading ? '请稍候…' : '更新密码',
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const Key('password-recovery-cancel'),
                          onPressed: widget.controller.loading
                              ? null
                              : () => unawaited(_cancel()),
                          child: const Text('取消并返回'),
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
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Row(
        children: [
          ClipRRect(
            key: const Key('auth-brand-logo'),
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/branding/cardfi-icon-master.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CardFi',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'card.lengziyu.cn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined, size: 18),
        label: const Text('返回首页'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.isDark
              ? const Color(0x75111C46)
              : const Color(0xD6FFFFFF),
          side: BorderSide(color: AppColors.line),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          onPressed: onPressed,
          tooltip: label,
          icon: leading ?? Icon(icon, size: 28),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.text,
            backgroundColor: AppColors.isDark
                ? const Color(0x7A111936)
                : const Color(0xEFFFFFFF),
            side: BorderSide(color: AppColors.line),
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      child: ShaderMask(
        shaderCallback: (bounds) => const SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: const Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}

class _GradientSubmitButton extends StatelessWidget {
  const _GradientSubmitButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : .52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.isDark
                ? const [
                    Color(0xFFA276FF),
                    Color(0xFF6C72FF),
                    Color(0xFF3C65E8),
                  ]
                : const [
                    Color(0xFF8A6CFF),
                    Color(0xFF625FFF),
                    Color(0xFF5136E8),
                  ],
          ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .24)),
          boxShadow: [
            const BoxShadow(
              color: Color(0x485A5FFF),
              blurRadius: 28,
              offset: Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.white.withValues(
                alpha: AppColors.isDark ? .03 : .42,
              ),
              blurRadius: 2,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(17),
            child: SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(
                          color: Color(0x450E145C),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                    shadows: [
                      Shadow(
                        color: Color(0x450E145C),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
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

class _AuthStatusCard extends StatelessWidget {
  const _AuthStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('auth-status-message'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet.withValues(alpha: AppColors.isDark ? .20 : .13),
            AppColors.cyan.withValues(alpha: AppColors.isDark ? .12 : .08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.violet.withValues(alpha: .34)),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: .09),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            color: AppColors.violet,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.isDark
                    ? const Color(0xFFD6DBF5)
                    : const Color(0xFF626D89),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

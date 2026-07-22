import 'dart:async';

import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:card_app/features/auth/data/auth_controller.dart';
import 'package:card_app/core/localization/localized_text.dart';
import 'package:flutter/material.dart' hide Text;

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.controller,
    required this.mode,
    required this.onBack,
    required this.onModeChanged,
    super.key,
  });

  final AuthMode mode;
  final AuthController controller;
  final VoidCallback onBack;
  final ValueChanged<AuthMode> onModeChanged;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool get _isLogin => widget.mode == AuthMode.login;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    final email = _accountController.text.trim();
    final password = _passwordController.text;
    final awaitingEmailVerification =
        widget.controller.user?.emailVerified == false;
    if (awaitingEmailVerification) {
      await widget.controller.confirmEmailVerification(
        email: email,
        password: password,
      );
    } else if (_isLogin) {
      await widget.controller.signIn(email: email, password: password);
    } else {
      await widget.controller.register(email: email, password: password);
    }
    if (widget.controller.isVerified) _passwordController.clear();
    if (mounted) setState(() => _passwordVisible = false);
  }

  Future<void> _checkEmailVerification() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await widget.controller.confirmEmailVerification(
      email: _accountController.text.trim(),
      password: _passwordController.text,
    );
    if (widget.controller.isVerified) _passwordController.clear();
    if (mounted) setState(() => _passwordVisible = false);
  }

  Future<void> _switchMode() async {
    FocusScope.of(context).unfocus();
    await widget.controller.resetAuthenticationFlow();
    _formKey.currentState?.reset();
    _accountController.clear();
    _passwordController.clear();
    if (!mounted) return;
    setState(() => _passwordVisible = false);
    widget.onModeChanged(_isLogin ? AuthMode.register : AuthMode.login);
  }

  Future<void> _resetPassword() async {
    final emailError = _validateAccount(_accountController.text);
    if (emailError != null) {
      AppNotice.info(context, emailError, title: '重置密码');
      return;
    }
    FocusScope.of(context).unfocus();
    await widget.controller.resetPassword(_accountController.text.trim());
  }

  String? _validateAccount(String? value) {
    final account = value?.trim() ?? '';
    if (account.isEmpty) return '请输入邮箱地址';
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(account)) return '请输入有效的邮箱地址';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '请输入密码';
    if (!_isLogin && password.length < 8) return '密码至少需要 8 位';
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
      hintText: hint,
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
    final awaitingEmailVerification =
        widget.controller.user?.emailVerified == false;
    return CustomScrollView(
      key: Key(_isLogin ? 'login-page' : 'register-page'),
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
                          key: Key('auth-account-field'),
                          controller: _accountController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: _decoration(
                            hint: '用户名 / 邮箱',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: _validateAccount,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: Key('auth-password-field'),
                          controller: _passwordController,
                          textInputAction: _isLogin
                              ? TextInputAction.done
                              : TextInputAction.next,
                          autofillHints: [
                            _isLogin
                                ? AutofillHints.password
                                : AutofillHints.newPassword,
                          ],
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: !_passwordVisible,
                          onFieldSubmitted: _isLogin
                              ? (_) => unawaited(_submit())
                              : null,
                          decoration: _decoration(
                            hint: _isLogin ? '密码' : '至少 8 位',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: _VisibilityButton(
                              key: Key('password-visibility'),
                              visible: _passwordVisible,
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 12),
                        _AuthOptions(
                          compact: compactLayout,
                          isLogin: _isLogin,
                          onForgotPassword: _resetPassword,
                          onModeChanged: () => unawaited(_switchMode()),
                        ),
                        if (widget.controller.message case final message?) ...[
                          const SizedBox(height: 8),
                          _AuthStatusCard(message: message),
                        ],
                        if (widget.controller.user case final user?
                            when !user.emailVerified) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _VerificationSecondaryButton(
                                  key: const Key('auth-resend-verification'),
                                  onPressed: widget.controller.loading
                                      ? null
                                      : widget.controller.resendVerification,
                                  label: '重发验证邮件',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _VerificationPrimaryButton(
                                  key: const Key('auth-refresh-verification'),
                                  onPressed: widget.controller.loading
                                      ? null
                                      : _checkEmailVerification,
                                  label: '我已完成验证',
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        _GradientSubmitButton(
                          key: Key('auth-submit'),
                          onPressed: widget.controller.loading ? null : _submit,
                          label: widget.controller.loading
                              ? '请稍候…'
                              : awaitingEmailVerification
                              ? '检查验证并登录'
                              : _isLogin
                              ? '登录'
                              : '注册并验证邮箱',
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.violet, AppColors.cyan],
              ),
            ),
            child: const Icon(
              Icons.credit_card_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '集卡',
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

class _AuthOptions extends StatelessWidget {
  const _AuthOptions({
    required this.compact,
    required this.isLogin,
    required this.onModeChanged,
    required this.onForgotPassword,
  });

  final bool compact;
  final bool isLogin;
  final VoidCallback onModeChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final leading = isLogin
        ? TextButton(
            key: const Key('auth-forgot-password'),
            onPressed: onForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.textMuted,
            ),
            child: const Text('忘记密码'),
          )
        : TextButton(
            onPressed: onModeChanged,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.textMuted,
            ),
            child: const Text('返回'),
          );
    final trailing = TextButton(
      key: Key(isLogin ? 'switch-to-register' : 'switch-to-login'),
      onPressed: onModeChanged,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        foregroundColor: AppColors.cyan,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
      child: Text(isLogin ? '创建账号' : '已有账号'),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                Align(alignment: Alignment.centerRight, child: trailing),
              ],
            )
          : Row(children: [leading, const Spacer(), trailing]),
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

class _VerificationSecondaryButton extends StatelessWidget {
  const _VerificationSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.mark_email_read_outlined, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.isDark
            ? const Color(0xFFE7E9FF)
            : const Color(0xFF5667D4),
        backgroundColor: AppColors.isDark
            ? const Color(0x4D1D294F)
            : const Color(0xCFFFFFFF),
        side: BorderSide(
          color: AppColors.isDark
              ? const Color(0x806E7DF0)
              : const Color(0xA08E96FF),
          width: 1.25,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        elevation: 0,
        shadowColor: const Color(0x305A68B8),
      ),
    );
  }
}

class _VerificationPrimaryButton extends StatelessWidget {
  const _VerificationPrimaryButton({
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
      opacity: enabled ? 1 : .5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.isDark
                ? const [Color(0xFF777BFF), Color(0xFF515BB7)]
                : const [Color(0xFF6E78F3), Color(0xFF535DB6)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x42535DCD),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Color(0x500D174F),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
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

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: visible ? '隐藏密码' : '显示密码',
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.textMuted,
      ),
    );
  }
}

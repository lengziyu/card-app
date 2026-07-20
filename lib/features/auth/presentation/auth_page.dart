import 'package:card_app/core/theme/app_colors.dart';
import 'package:card_app/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.mode,
    required this.onBack,
    required this.onModeChanged,
    super.key,
  });

  final AuthMode mode;
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
  bool _submittedPreview = false;

  bool get _isLogin => widget.mode == AuthMode.login;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submittedPreview = false);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    _passwordController.clear();
    setState(() {
      _passwordVisible = false;
      _submittedPreview = true;
    });
  }

  void _previewSocialAuth(String provider) {
    FocusScope.of(context).unfocus();
    AppNotice.info(
      context,
      '$provider 授权入口已就绪，服务端 OAuth 配置完成后即可正式使用。',
      title: '授权预览',
    );
  }

  String? _validateAccount(String? value) {
    final account = value?.trim() ?? '';
    if (account.isEmpty) return '请输入用户名或邮箱';
    if (account.contains('@')) {
      final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailPattern.hasMatch(account)) return '请输入有效的邮箱地址';
    } else if (!RegExp(r'^[A-Za-z0-9_]{3,18}$').hasMatch(account)) {
      return '用户名需为 3–18 位字母、数字或下划线';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '请输入密码';
    if (!_isLogin && password.length < 6) return '密码至少需要 6 位';
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
                          onFieldSubmitted: _isLogin ? (_) => _submit() : null,
                          decoration: _decoration(
                            hint: _isLogin ? '密码' : '至少 6 位',
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
                          onModeChanged: () => widget.onModeChanged(
                            _isLogin ? AuthMode.register : AuthMode.login,
                          ),
                        ),
                        if (_submittedPreview) ...[
                          SizedBox(height: 8),
                          const _PreviewResult(),
                        ],
                        SizedBox(height: 16),
                        _GradientSubmitButton(
                          key: Key('auth-submit'),
                          onPressed: _submit,
                          label: _isLogin ? '登录' : '注册并登录',
                        ),
                        const SizedBox(height: 16),
                        const _AuthDivider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SocialAuthButton(
                                key: const Key('auth-google'),
                                provider: 'Google',
                                onPressed: () => _previewSocialAuth('Google'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SocialAuthButton(
                                key: const Key('auth-apple'),
                                provider: 'Apple',
                                onPressed: () => _previewSocialAuth('Apple'),
                              ),
                            ),
                          ],
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
  });

  final bool compact;
  final bool isLogin;
  final VoidCallback onModeChanged;

  @override
  Widget build(BuildContext context) {
    final leading = isLogin
        ? const SizedBox.shrink()
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.isDark
              ? const [Color(0xFF9A63FF), Color(0xFF5D73FF), Color(0xFF3476FF)]
              : const [Color(0xFF7D66FF), Color(0xFF5C5DFF), Color(0xFF5D39FF)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D5F5DFF),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '或',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.provider,
    required this.onPressed,
    super.key,
  });

  final String provider;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isApple = provider == 'Apple';
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.isDark
              ? const Color(0x5C161F48)
              : const Color(0xB8FFFFFF),
          side: BorderSide(color: AppColors.line),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              child: isApple
                  ? Icon(Icons.apple, color: AppColors.text, size: 22)
                  : const Text(
                      'G',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                provider,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewResult extends StatelessWidget {
  const _PreviewResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('auth-preview-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.28)),
      ),
      child: Text(
        '登录服务正在进行安全升级，暂不能提交账号或创建会话。',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12.5,
          height: 1.4,
        ),
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

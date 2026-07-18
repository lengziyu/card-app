import 'package:card_app/core/theme/app_colors.dart';
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
  final _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _rememberAccount = true;
  bool _submittedPreview = false;

  bool get _isLogin => widget.mode == AuthMode.login;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submittedPreview = false);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _passwordVisible = false;
      _confirmPasswordVisible = false;
      _submittedPreview = true;
    });
  }

  void _previewSocialAuth(String provider) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$provider 授权入口已就绪，服务端 OAuth 配置完成后即可正式使用。'),
          behavior: SnackBarBehavior.floating,
        ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final title = _isLogin ? '欢迎回来' : '创建账号';
    final subtitle = _isLogin ? '登录后同步你的卡片收藏' : '使用邮箱、Google 或 Apple 开始集卡';

    return CustomScrollView(
      key: Key(_isLogin ? 'login-page' : 'register-page'),
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
          sliver: SliverList.list(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: Key('auth-back'),
                  onPressed: widget.onBack,
                  tooltip: '返回',
                  icon: Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: Size(48, 48),
                    backgroundColor: AppColors.glass,
                    side: BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              SizedBox(height: 22),
              const _BrandMark(),
              SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              SizedBox(height: 20),
              const _ServiceNotice(),
              SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3D000000),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          hint: '邮箱（支持 Gmail）或用户名',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: _validateAccount,
                      ),
                      SizedBox(height: 14),
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
                          hint: _isLogin ? '密码' : '密码（至少 8 位）',
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
                      if (!_isLogin) ...[
                        SizedBox(height: 14),
                        TextFormField(
                          key: Key('auth-confirm-field'),
                          controller: _confirmPasswordController,
                          textInputAction: TextInputAction.done,
                          autofillHints: [AutofillHints.newPassword],
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: !_confirmPasswordVisible,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: _decoration(
                            hint: '再次输入密码',
                            icon: Icons.verified_user_outlined,
                            suffixIcon: _VisibilityButton(
                              visible: _confirmPasswordVisible,
                              onPressed: () => setState(
                                () => _confirmPasswordVisible =
                                    !_confirmPasswordVisible,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) return '请再次输入密码';
                            if (value != _passwordController.text) {
                              return '两次输入的密码不一致';
                            }
                            return null;
                          },
                        ),
                      ],
                      SizedBox(height: 12),
                      if (_isLogin)
                        Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            key: Key('remember-account'),
                            value: _rememberAccount,
                            onChanged: (value) => setState(
                              () => _rememberAccount = value ?? false,
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              '记住账号（正式接入后启用）',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            '继续即表示你已了解：当前仅预览注册流程，不会创建真实账号。',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      if (_submittedPreview) ...[
                        SizedBox(height: 8),
                        const _PreviewResult(),
                      ],
                      SizedBox(height: 16),
                      FilledButton.icon(
                        key: Key('auth-submit'),
                        onPressed: _submit,
                        iconAlignment: IconAlignment.end,
                        icon: Icon(Icons.arrow_forward_rounded),
                        label: Text(_isLogin ? '预览登录' : '预览注册'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: Colors.white,
                          backgroundColor: AppColors.violet,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      TextButton(
                        key: Key(
                          _isLogin ? 'switch-to-register' : 'switch-to-login',
                        ),
                        onPressed: () => widget.onModeChanged(
                          _isLogin ? AuthMode.register : AuthMode.login,
                        ),
                        child: Text(
                          _isLogin ? '还没有账号？预览注册' : '已有账号？返回登录',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.cyan),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.line)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '其他方式',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.line)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SocialAuthButton(
                        key: const Key('auth-google'),
                        provider: 'Google',
                        label: _isLogin ? '使用 Google 登录' : '使用 Google 注册',
                        onPressed: () => _previewSocialAuth('Google'),
                      ),
                      const SizedBox(height: 10),
                      _SocialAuthButton(
                        key: const Key('auth-apple'),
                        provider: 'Apple',
                        label: _isLogin ? '使用 Apple 登录' : '使用 Apple 注册',
                        onPressed: () => _previewSocialAuth('Apple'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.cyan, AppColors.violet],
            ),
          ),
          child: Icon(Icons.style_rounded, color: Colors.white),
        ),
        SizedBox(width: 12),
        Text(
          '集卡',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.provider,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String provider;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isApple = provider == 'Apple';
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.glassStrong,
        side: BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 28,
              child: isApple
                  ? Icon(Icons.apple, color: AppColors.text, size: 23)
                  : const Text(
                      'G',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ServiceNotice extends StatelessWidget {
  const _ServiceNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('auth-service-notice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.cyan, size: 21),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              '账号安全服务升级中。当前表单仅供界面预览，输入内容不会发送或保存。',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
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
        color: AppColors.mint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.28)),
      ),
      child: Text(
        '界面校验已完成。密码已清空，未创建会话或账号。',
        style: TextStyle(color: AppColors.mint, fontSize: 12.5, height: 1.4),
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

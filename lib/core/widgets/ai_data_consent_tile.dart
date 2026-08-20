import 'package:cardfi/core/localization/app_localizations.dart';
import 'package:cardfi/core/localization/localized_text.dart';
import 'package:cardfi/core/privacy/ai_data_consent.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/features/profile/data/legal_config.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

class AiDataConsentTile extends StatelessWidget {
  const AiDataConsentTile({
    required this.kind,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final AiDataConsentKind kind;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final privacyUri = LegalConfig.httpsUri(LegalConfig.privacyPolicyUrl);
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            value: value,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              context.tr(_title),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                context.tr(_details),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (privacyUri != null)
            TextButton.icon(
              key: const Key('ai-data-consent-privacy'),
              onPressed: () =>
                  launchUrl(privacyUri, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.privacy_tip_outlined, size: 16),
              label: Text(context.tr('查看隐私政策')),
            ),
        ],
      ),
    );
  }

  String get _title => switch (kind) {
    AiDataConsentKind.cardMatch =>
      '我同意将上述居住国家或地区、证件类型（不含号码或图片）、用途、KYC 偏好和可选备注，经 CardFi 服务器发送给阿里云百炼，仅用于生成本次选卡建议。',
    AiDataConsentKind.applicationPrep =>
      '我同意将上述目标卡片、申请主体、居住或注册国家和地区、材料类型、当前阶段和可选问题，经 CardFi 服务器发送给阿里云百炼，仅用于生成本次准备清单。',
    AiDataConsentKind.billVision =>
      '我已移除完整卡号、姓名、订单号、地址和二维码，并同意将所选截图经 CardFi 服务器发送给 OpenAI，仅用于本次账单字段识别。',
  };

  String get _details => switch (kind) {
    AiDataConsentKind.cardMatch || AiDataConsentKind.applicationPrep =>
      'CardFi 不保存本次输入或模型结果；阿里云百炼不会将数据用于模型训练，但会依其服务条款和法律要求处理并保存调用数据。',
    AiDataConsentKind.billVision =>
      'CardFi 不把原图保存到账单记录；OpenAI API 默认不使用输入和输出训练模型，但可能保留滥用监测日志最多 30 天。',
  };
}

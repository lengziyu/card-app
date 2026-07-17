import 'package:card_app/features/catalog/domain/card_detail.dart';
import 'package:card_app/features/catalog/domain/card_summary.dart';

class LocalCardDetailRepository implements CardDetailRepository {
  const LocalCardDetailRepository();

  @override
  CardDetail detailFor(CardSummary card) {
    return _details[card.id] ?? _fallback(card);
  }
}

const _defaultFees = <FeeLine>[
  FeeLine(label: '开卡费', value: '以官网为准'),
  FeeLine(label: '年费', value: '以官网为准'),
  FeeLine(label: '外汇手续费', value: '以官网为准'),
  FeeLine(label: 'ATM 取现', value: '以官网为准'),
];

const _details = <String, CardDetail>{
  'etherfi-core': CardDetail(
    cardId: 'etherfi-core',
    tags: ['U 卡', 'DeFi', 'Visa', '演示资料'],
    region: '美国、英国、欧盟等开放地区',
    funding: 'ether.fi Cash / DeFi 账户',
    availability: '按产品开放与等级规则',
    features: [
      DetailFeature(icon: DetailFeatureIcon.wallet, text: '链上账户与消费体验联动'),
      DetailFeature(icon: DetailFeatureIcon.shield, text: '产品规则强调自托管体验'),
      DetailFeature(icon: DetailFeatureIcon.payments, text: 'Visa 网络日常消费'),
      DetailFeature(icon: DetailFeatureIcon.globe, text: '多地区开放，资格以官网为准'),
    ],
    fees: [
      FeeLine(label: '开卡费', value: '公开资料显示免费'),
      FeeLine(label: '年费', value: '公开资料显示免年费'),
      FeeLine(label: '返现', value: '按等级与活动规则'),
      FeeLine(label: '法币与加密转账', value: '按会员等级说明'),
    ],
    kycNote: '可能支持身份证或护照，实际材料、地区和审核结果以官方申请流程为准。',
    paymentChannels: {PaymentChannel.applePay, PaymentChannel.googlePay},
    sourceLabel: '本地演示资料 · 来源待复核',
    note: '等级、返现和转账额度可能随官方规则变化，本页不构成申请建议。',
  ),
  'bybit-card': CardDetail(
    cardId: 'bybit-card',
    tags: ['U 卡', 'Mastercard', '虚拟卡', '演示资料'],
    region: '按 Bybit Card 开放地区',
    funding: 'Bybit 账户可用余额',
    availability: '按账号地区与 KYC 状态',
    features: [
      DetailFeature(icon: DetailFeatureIcon.wallet, text: '与平台账户余额配合使用'),
      DetailFeature(icon: DetailFeatureIcon.payments, text: 'Mastercard 网络消费'),
      DetailFeature(icon: DetailFeatureIcon.shield, text: '需遵循平台账号安全规则'),
      DetailFeature(icon: DetailFeatureIcon.globe, text: '不同地区开放情况不同'),
    ],
    fees: _defaultFees,
    kycNote: '演示资料标记为护照路径；实际身份材料与可申请地区以官方流程为准。',
    paymentChannels: {PaymentChannel.applePay, PaymentChannel.googlePay},
    sourceLabel: '本地演示资料 · 来源待复核',
    note: '费用、返现、卡片形式和支持地区可能变化，请查阅官方最新规则。',
  ),
  'redotpay': CardDetail(
    cardId: 'redotpay',
    tags: ['U 卡', 'Visa', '虚拟卡', '演示资料'],
    region: '按 RedotPay 开放地区',
    funding: '平台账户余额',
    availability: '完成官方要求后申请',
    features: [
      DetailFeature(icon: DetailFeatureIcon.wallet, text: '平台账户与卡片消费联动'),
      DetailFeature(icon: DetailFeatureIcon.payments, text: 'Visa 网络消费'),
      DetailFeature(icon: DetailFeatureIcon.shield, text: '身份与风控规则以平台为准'),
      DetailFeature(icon: DetailFeatureIcon.globe, text: '地区能力可能存在差异'),
    ],
    fees: _defaultFees,
    kycNote: '演示资料包含身份证和护照标签，不代表所有地区均可使用相同材料。',
    paymentChannels: {PaymentChannel.applePay, PaymentChannel.googlePay},
    sourceLabel: '本地演示资料 · 来源待复核',
    note: '本页仅展示信息结构，不保证产品可申请或可在特定地区使用。',
  ),
  'metamask-card': CardDetail(
    cardId: 'metamask-card',
    tags: ['U 卡', 'Mastercard', '钱包', '演示资料'],
    region: '按 MetaMask Card 开放地区',
    funding: '支持的钱包资产与账户',
    availability: '按官方候补与开放规则',
    features: [
      DetailFeature(icon: DetailFeatureIcon.wallet, text: '钱包资产与消费体验联动'),
      DetailFeature(icon: DetailFeatureIcon.payments, text: 'Mastercard 网络消费'),
      DetailFeature(icon: DetailFeatureIcon.shield, text: '钱包授权与风控需谨慎确认'),
      DetailFeature(icon: DetailFeatureIcon.globe, text: '分地区逐步开放'),
    ],
    fees: _defaultFees,
    kycNote: '演示资料标记为护照路径；实际 KYC 要求以官方申请页面为准。',
    paymentChannels: {PaymentChannel.applePay, PaymentChannel.googlePay},
    sourceLabel: '本地演示资料 · 来源待复核',
    note: '钱包、支持资产、费用和开放地区均可能调整，请以官方最新说明为准。',
  ),
};

CardDetail _fallback(CardSummary card) {
  return CardDetail(
    cardId: card.id,
    tags: [card.category.label, card.label, '演示资料'],
    region: '以官方开放地区为准',
    funding: card.category == CardCategory.creditCard ? '信用额度' : '以官网为准',
    availability: '按官方资格与审批流程',
    features: const [
      DetailFeature(icon: DetailFeatureIcon.wallet, text: '账户与卡片信息统一整理'),
      DetailFeature(icon: DetailFeatureIcon.payments, text: '支付网络以卡面信息为准'),
      DetailFeature(icon: DetailFeatureIcon.shield, text: '资格与风控由发卡方决定'),
      DetailFeature(icon: DetailFeatureIcon.globe, text: '地区限制以官方规则为准'),
    ],
    fees: _defaultFees,
    kycNote: card.kycDocuments.isEmpty
        ? '身份材料暂未核验。'
        : '公开信息可能涉及${card.kycDocuments.map((item) => item.label).join('或')}，最终以官方流程为准。',
    paymentChannels: const <PaymentChannel>{},
    sourceLabel: '本地演示资料 · 尚未核验',
    note: '当前为本地 Mock 详情，用于验证页面结构与交互，不代表产品最新规则。',
  );
}

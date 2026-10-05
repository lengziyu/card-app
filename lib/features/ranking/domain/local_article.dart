class LocalArticle {
  const LocalArticle({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.body,
    required this.tags,
    required this.publishedLabel,
    required this.relatedCardIds,
    this.coverImageUrl,
    this.markdown,
    this.inviteCode,
    this.inviteUrl,
    this.author,
    this.isCommunityTip = false,
    this.verifiedLabel,
  });

  final String id;
  final String category;
  final String title;
  final String summary;
  final List<String> body;
  final List<String> tags;
  final String publishedLabel;
  final List<String> relatedCardIds;
  final String? coverImageUrl;

  /// 原始 Markdown 正文。离线演示文章继续使用 [body] 作为兜底。
  final String? markdown;
  final String? inviteCode;
  final String? inviteUrl;
  final String? author;
  final bool isCommunityTip;
  final String? verifiedLabel;
}

const localArticles = <LocalArticle>[
  LocalArticle(
    id: 'how-to-compare-card-fees',
    category: '开卡攻略',
    title: '比较一张卡时，别只看返现比例',
    summary: '从年费、入金、换汇、ATM 与适用地区五个维度建立自己的比较清单。',
    body: [
      '返现是最醒目的数字，却不一定是实际成本中最重要的一项。开卡前应先确认年费、开卡费和最低消费条件。',
      '跨境使用时，还要把换汇价差、外币交易费和 ATM 费用放在一起比较。某一项免费，并不代表完整链路没有成本。',
      '最后核对申请地区、KYC 材料与卡片当前开放状态。公开资料可能变化，申请前仍应查看发卡方最新规则。',
    ],
    tags: ['费用', '开卡', '风险提示'],
    publishedLabel: '2026-07-12',
    relatedCardIds: ['etherfi-core', 'wise-account'],
  ),
  LocalArticle(
    id: 'wallet-payment-support',
    category: '权益指南',
    title: '数字钱包支持怎么看',
    summary: '卡片支持数字钱包，通常还取决于发行地区、卡组织和具体卡产品。',
    body: [
      '“支持数字钱包”并不总是意味着所有地区、所有卡等级都可以绑定。应优先查看发卡方针对具体产品发布的说明。',
      '如果资料只写了卡组织能力，而没有明确产品支持，CardFi 会将状态标记为待确认，避免把推测当成事实。',
    ],
    tags: ['数字钱包', '支付'],
    publishedLabel: '2026-07-08',
    relatedCardIds: ['bybit-card', 'metamask-card'],
  ),
  LocalArticle(
    id: 'kyc-documents-guide',
    category: '行业资讯',
    title: 'KYC 标签代表什么',
    summary: '身份证、护照和地址证明是不同维度，页面标签不等于保证可以申请。',
    body: [
      'CardFi 只整理公开披露的身份材料信息，不接收、不上传也不保存任何证件。',
      '同一产品可能因居住地、发行实体或申请时间不同而要求不同材料，最终结果以官方流程为准。',
    ],
    tags: ['KYC', '隐私', '资料来源'],
    publishedLabel: '2026-07-03',
    relatedCardIds: ['n26-standard', 'hsbc-premier'],
  ),
];

const localCommunityTipArticles = <LocalArticle>[
  LocalArticle(
    id: 'community-tip-check-total-cost',
    category: '卡友技巧',
    title: '支付前先核对完整费用链路',
    summary: '不要只看消费手续费，把充值、换汇、支付和退款可能产生的费用放在一起确认。',
    body: [],
    markdown: '''
## 使用场景

准备使用一张卡进行跨境或外币消费时。

## 操作步骤

1. 在官方费用页确认充值方式及充值手续费。
2. 确认消费币种与账户币种不同时采用的换汇规则。
3. 查看卡片消费手续费以及支付渠道可能收取的额外费用。
4. 如果交易可能退款，提前确认退款时间和费用处理方式。

## 适用条件

适合需要比较多张卡实际使用成本的用户。不同地区、卡等级和充值方式可能采用不同规则。

## 风险与限制

公开费率可能调整，支付前仍应查看发卡方最新官方说明。不要根据单次交易结果推断所有地区或商户都适用。
''',
    tags: ['费用核对', '跨境支付', '卡友经验'],
    publishedLabel: '2026-07-25',
    relatedCardIds: ['etherfi-core', 'bybit-card'],
    author: '匿名卡友',
    isCommunityTip: true,
    verifiedLabel: '2026-07-25 基础核验',
  ),
  LocalArticle(
    id: 'community-tip-wallet-binding',
    category: '卡友技巧',
    title: '绑定数字钱包失败时的核对顺序',
    summary: '先确认卡片产品、发行地区和设备地区，再检查官方是否明确支持当前数字钱包。',
    body: [],
    markdown: '''
## 使用场景

卡片无法绑定当前使用的数字钱包，但卡片介绍中提到支持数字钱包。

## 操作步骤

1. 确认说明针对的是当前卡片产品，而不是卡组织的一般能力。
2. 核对卡片发行地区和数字钱包账户地区是否在官方支持范围。
3. 检查卡片是否已激活，以及官方 App 内是否需要先开启相关功能。
4. 仍然失败时，通过发行方官方客服核对具体错误，不要向他人提供验证码或完整卡号。

## 适用条件

仅适用于发卡方已经公开说明支持数字钱包的产品。

## 风险与限制

支持范围可能因地区、卡等级、设备和发行实体变化。任何时候都不要向非官方人员提供验证码、密码或完整卡片资料。
''',
    tags: ['数字钱包', '安全'],
    publishedLabel: '2026-07-24',
    relatedCardIds: ['bybit-card', 'metamask-card'],
    author: '卡片观察员',
    isCommunityTip: true,
    verifiedLabel: '2026-07-24 基础核验',
  ),
];

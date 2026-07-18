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
    title: 'Apple Pay 与 Google Pay 支持怎么看',
    summary: '卡片支持数字钱包，通常还取决于发行地区、卡组织和具体卡产品。',
    body: [
      '“支持 Apple Pay”并不总是意味着所有地区、所有卡等级都可以绑定。应优先查看发卡方针对具体产品发布的说明。',
      '如果资料只写了卡组织能力，而没有明确产品支持，集卡会将状态标记为待确认，避免把推测当成事实。',
    ],
    tags: ['Apple Pay', 'Google Pay', '支付'],
    publishedLabel: '2026-07-08',
    relatedCardIds: ['bybit-card', 'metamask-card'],
  ),
  LocalArticle(
    id: 'kyc-documents-guide',
    category: '行业资讯',
    title: 'KYC 标签代表什么',
    summary: '身份证、护照和地址证明是不同维度，页面标签不等于保证可以申请。',
    body: [
      '集卡只整理公开披露的身份材料信息，不接收、不上传也不保存任何证件。',
      '同一产品可能因居住地、发行实体或申请时间不同而要求不同材料，最终结果以官方流程为准。',
    ],
    tags: ['KYC', '隐私', '资料来源'],
    publishedLabel: '2026-07-03',
    relatedCardIds: ['n26-standard', 'hsbc-premier'],
  ),
];

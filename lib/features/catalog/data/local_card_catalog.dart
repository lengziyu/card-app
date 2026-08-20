import 'package:cardfi/features/catalog/domain/card_summary.dart';

const localCardCatalog = <CardSummary>[
  CardSummary(
    id: 'etherfi-core',
    name: 'EtherFi Cash',
    issuer: 'ether.fi',
    category: CardCategory.uCard,
    label: 'CORE · VISA',
    assetPath: 'assets/cards/etherfi-core.webp',
    tint: 0xFF6DE7C4,
    kycDocuments: {KycDocument.idCard, KycDocument.passport},
    kycSummary: '身份证 / 护照',
    cashbackRate: '3%',
    isNew: true,
  ),
  CardSummary(
    id: 'bybit-card',
    name: 'Bybit Card',
    issuer: 'Bybit',
    category: CardCategory.uCard,
    label: 'VIRTUAL · MASTERCARD',
    assetPath: 'assets/cards/bybit.webp',
    tint: 0xFFFFC65D,
    kycDocuments: {KycDocument.passport},
    kycSummary: '护照',
  ),
  CardSummary(
    id: 'redotpay',
    name: 'RedotPay',
    issuer: 'RedotPay',
    category: CardCategory.uCard,
    label: 'VIRTUAL · VISA',
    assetPath: 'assets/cards/redotpay.webp',
    tint: 0xFF8B7CFF,
    kycDocuments: {KycDocument.idCard, KycDocument.passport},
    kycSummary: '身份证 / 护照',
  ),
  CardSummary(
    id: 'metamask-card',
    name: 'MetaMask Card',
    issuer: 'MetaMask',
    category: CardCategory.uCard,
    label: 'VIRTUAL · MASTERCARD',
    assetPath: 'assets/cards/metamask.webp',
    tint: 0xFFFF8E52,
    kycSummary: '申请条件待确认',
    isNew: true,
  ),
  CardSummary(
    id: 'n26-standard',
    name: 'N26 Standard',
    issuer: 'N26',
    category: CardCategory.debitCard,
    label: 'DEBIT · MASTERCARD',
    tint: 0xFF39C7B5,
    kycDocuments: {KycDocument.passport},
    kycSummary: '护照',
  ),
  CardSummary(
    id: 'hsbc-premier',
    name: 'HSBC Premier',
    issuer: 'HSBC',
    category: CardCategory.creditCard,
    label: 'CREDIT · MASTERCARD',
    tint: 0xFFDB3345,
    kycDocuments: {KycDocument.idCard, KycDocument.passport},
    kycSummary: '身份证 / 护照',
  ),
  CardSummary(
    id: 'wise-account',
    name: 'Wise Account',
    issuer: 'Wise',
    category: CardCategory.bankAccount,
    label: 'MULTI-CURRENCY ACCOUNT',
    tint: 0xFF9FE870,
    sourceUrl: 'https://wise.com/help/articles/2897226/what-is-a-wise-account',
    kycDocuments: {KycDocument.passport},
    isNew: true,
    kind: CatalogItemKind.globalAccount,
  ),
  CardSummary(
    id: 'revolut-personal-account',
    name: 'Revolut Personal Account',
    issuer: 'Revolut',
    category: CardCategory.bankAccount,
    label: '个人多币种账户 · 地区受限',
    tint: 0xFF334E68,
    sourceUrl:
        'https://help.revolut.com/en-LV/help/profile-and-plan/profile-plan/verifying-identity/what-countries-are-supported/',
    kind: CatalogItemKind.globalAccount,
  ),
  CardSummary(
    id: 'payoneer-account',
    name: 'Payoneer Account',
    issuer: 'Payoneer',
    category: CardCategory.bankAccount,
    label: '企业与自由职业者 · 多币种收款',
    tint: 0xFF6D2A78,
    sourceUrl:
        'https://www.payoneer.com/resources/the-ins-and-outs-of-receiving-accounts-how-payoneers-multicurrency-account-can-help-smbs-expand-globally/',
    kind: CatalogItemKind.globalAccount,
  ),
  CardSummary(
    id: 'airwallex-global-account',
    name: 'Airwallex Global Account',
    issuer: 'Airwallex',
    category: CardCategory.bankAccount,
    label: '企业账户 · 全球收款',
    tint: 0xFF4B3DAA,
    sourceUrl:
        'https://www.airwallex.com/en-us/business-account/global-accounts',
    kind: CatalogItemKind.globalAccount,
  ),
  CardSummary(
    id: 'worldfirst-world-account',
    name: 'WorldFirst World Account',
    issuer: 'WorldFirst',
    category: CardCategory.bankAccount,
    label: '企业账户 · 跨境收付款',
    tint: 0xFFCC4125,
    sourceUrl: 'https://www.worldfirst.com/global/?page_id=9034',
    kind: CatalogItemKind.globalAccount,
  ),
];

class LocalCardCatalogRepository implements CardCatalogRepository {
  const LocalCardCatalogRepository({this.simulatedDelay = Duration.zero});

  final Duration simulatedDelay;

  @override
  Future<List<CardSummary>> loadCards({bool force = false}) async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }
    return localCardCatalog;
  }
}

import 'package:card_app/features/catalog/domain/card_summary.dart';

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
  ),
  CardSummary(
    id: 'metamask-card',
    name: 'MetaMask Card',
    issuer: 'MetaMask',
    category: CardCategory.uCard,
    label: 'VIRTUAL · MASTERCARD',
    assetPath: 'assets/cards/metamask.webp',
    tint: 0xFFFF8E52,
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
  ),
  CardSummary(
    id: 'hsbc-premier',
    name: 'HSBC Premier',
    issuer: 'HSBC',
    category: CardCategory.creditCard,
    label: 'CREDIT · MASTERCARD',
    tint: 0xFFDB3345,
    kycDocuments: {KycDocument.idCard, KycDocument.passport},
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

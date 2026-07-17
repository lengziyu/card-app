class MockCard {
  const MockCard({
    required this.id,
    required this.name,
    required this.label,
    required this.assetPath,
    required this.tint,
  });

  final String id;
  final String name;
  final String label;
  final String assetPath;
  final int tint;
}

const mockCards = <MockCard>[
  MockCard(
    id: 'etherfi-core',
    name: 'EtherFi Cash',
    label: 'CORE · VISA',
    assetPath: 'assets/cards/etherfi-core.webp',
    tint: 0xFF6DE7C4,
  ),
  MockCard(
    id: 'bybit-card',
    name: 'Bybit Card',
    label: 'VIRTUAL · MASTERCARD',
    assetPath: 'assets/cards/bybit.webp',
    tint: 0xFFFFC65D,
  ),
  MockCard(
    id: 'redotpay',
    name: 'RedotPay',
    label: 'VIRTUAL · VISA',
    assetPath: 'assets/cards/redotpay.webp',
    tint: 0xFF8B7CFF,
  ),
  MockCard(
    id: 'metamask-card',
    name: 'MetaMask Card',
    label: 'VIRTUAL · MASTERCARD',
    assetPath: 'assets/cards/metamask.webp',
    tint: 0xFFFF8E52,
  ),
];

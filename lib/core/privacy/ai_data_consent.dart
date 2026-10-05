enum AiDataConsentKind { cardMatch, applicationPrep, billVision }

abstract final class AiDataConsent {
  static const version = '2026-08-18';
  static const bailianProviderId = 'alibaba-cloud-bailian';
  static const openAiProviderId = 'openai';

  static Map<String, Object> payload(AiDataConsentKind kind) => {
    'granted': true,
    'version': version,
    'provider': switch (kind) {
      AiDataConsentKind.cardMatch ||
      AiDataConsentKind.applicationPrep => bailianProviderId,
      AiDataConsentKind.billVision => bailianProviderId,
    },
  };
}

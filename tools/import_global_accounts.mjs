#!/usr/bin/env node

/**
 * Seed curated global-account records into card.lengziyu.cn.
 *
 * This is deliberately an API client, not an admin-password login script.
 * Obtain the `token` value from the existing admin session in Local Storage
 * (`card-h5-admin-session-v2`) and pass it through CARD_ADMIN_TOKEN. No
 * credential is recorded in this repository.
 *
 * Examples:
 *   node tools/import_global_accounts.mjs --dry-run
 *   CARD_ADMIN_TOKEN='…' node tools/import_global_accounts.mjs
 *   CARD_ADMIN_TOKEN='…' node tools/import_global_accounts.mjs --publish
 *   CARD_ADMIN_TOKEN='…' node tools/import_global_accounts.mjs --overwrite-existing
 *   CARD_ADMIN_TOKEN='…' node tools/import_global_accounts.mjs --only kraken,neverless
 *   node tools/import_global_accounts.mjs --verify-sources
 */

const reviewedOn = '2026-07-25'
const nextReviewAt = '2026-10-25'
const apiBaseUrl = (process.env.CARD_API_BASE_URL || 'https://card.lengziyu.cn').replace(/\/+$/, '')
const args = new Set(process.argv.slice(2))
const onlyArg = process.argv.find((arg) => arg.startsWith('--only=')) ||
  (process.argv.includes('--only') ? process.argv[process.argv.indexOf('--only') + 1] : '')
const requestedIds = new Set(String(onlyArg || '').replace(/^--only=/, '').split(',').map((id) => id.trim()).filter(Boolean))

const feature = (icon, textZh, textEn) => ({ icon, textZh, textEn })
const fee = (labelZh, valueZh, labelEn = labelZh, valueEn = valueZh) => ({ labelZh, valueZh, labelEn, valueEn })

function cryptoRecord({
  id, name, provider = name, taglineZh, taglineEn, sourceName, sourceUrl,
  regionsZh, regionsEn, availabilityZh, availabilityEn, fundingZh, fundingEn,
  chinaStatus = 'unknown', chinaDocumentZh, chinaDocumentEn, chinaNoteZh,
  chinaNoteEn, supportedCurrencies = [], receivingMethods = ['crypto'],
  coverColors = ['#2B2D42', '#6D5DFB', '#FFFFFF'], accountType = 'cryptoPlatform'
}) {
  return {
    id, name, provider, accountType, taglineZh, taglineEn, coverColors,
    supportedCurrencies, receivingMethods, regionsZh, regionsEn,
    availabilityZh, availabilityEn, fundingZh, fundingEn,
    features: [
      feature('wallet', '可能持有或管理数字资产余额', 'May hold or manage digital-asset balances'),
      feature('payments', '法币、链上转账、卡片或交易功能按地区和资格开放', 'Fiat, on-chain transfer, card or trading features vary by location and eligibility'),
      feature('shield', '需要身份、居住地和合规核验', 'Identity, residence and compliance verification are required')
    ],
    fees: [fee('交易、转账与兑换', '费用、点差和网络成本以官方实时确认页为准', 'Trading, transfers and conversion', 'Fees, spreads and network costs are shown at official confirmation')],
    chinaKyc: {
      status: chinaStatus,
      documentSummaryZh: chinaDocumentZh || '以官方实时申请流程展示为准',
      documentSummaryEn: chinaDocumentEn || 'Follow the official live onboarding flow',
      noteZh: chinaNoteZh || '不要将此记录描述为银行账户或保证中国大陆可用。',
      noteEn: chinaNoteEn || 'Do not describe this record as a bank account or guarantee mainland-China availability.',
      sourceUrl,
      checkedAt: reviewedOn
    },
    safeguardingZh: '该产品不是银行存款账户；数字资产价格、托管、链上转账和地区合规风险以官方条款为准。',
    safeguardingEn: 'This is not a bank-deposit account; digital-asset pricing, custody, on-chain transfer and jurisdictional risks are governed by official terms.',
    sourceName,
    sourceUrl
  }
}

// Sources are first-party product, availability, fee, or terms pages. Empty
// currency/account-detail fields are intentional: they are safer than guessing
// from marketing pages and are ready for a later provider-by-provider update.
const records = [
  {
    id: 'paypal', name: 'PayPal', provider: 'PayPal', accountType: 'onlineWallet',
    taglineZh: '在线支付钱包 · 跨境收付款', taglineEn: 'Online wallet for cross-border payments',
    coverColors: ['#003087', '#009CDE', '#FFFFFF'], supportedCurrencies: ['CNY', 'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'HKD', 'SGD'], receivingMethods: ['wallet', 'local'],
    regionsZh: '服务实体、注册地和可用功能因国家/地区而异。', regionsEn: 'Service entity, registration country and available features vary by location.',
    availabilityZh: '中国大陆官网提供本地服务说明；账户能力以注册流程为准。', availabilityEn: 'Local service information is available for mainland China; follow the live onboarding flow for eligibility.',
    fundingZh: '支持的银行卡、银行账户及余额方式因地区而异。', fundingEn: 'Supported cards, bank accounts and balance methods vary by region.',
    features: [feature('wallet', '用于在线支付和收款的电子钱包', 'Electronic wallet for online payments and receiving money'), feature('payments', '可用币种和支付方式按地区开放', 'Currencies and payment methods vary by region'), feature('shield', '账户与交易受实时合规审核', 'Accounts and transactions are subject to live compliance review')],
    fees: [fee('费用', '费用、汇率及可用服务以确认页和当地费率表为准', 'Fees', 'See the confirmation screen and local fee schedule for fees, exchange rates and services')],
    chinaKyc: { status: 'conditional', documentSummaryZh: '以中国大陆 PayPal 实时注册流程为准', documentSummaryEn: 'Follow the live PayPal China registration flow', noteZh: '不能仅凭国籍或证件推断服务资格。', noteEn: 'Do not infer eligibility from nationality or an ID document alone.', sourceUrl: 'https://www.paypal.com/c2/home', checkedAt: reviewedOn },
    safeguardingZh: '资金保护与服务实体以 PayPal 官方当地条款为准。', safeguardingEn: 'Safeguarding and service entity depend on the applicable PayPal terms.', sourceName: 'PayPal 中国官网', sourceUrl: 'https://www.paypal.com/c2/home'
  },
  {
    id: 'revolut-personal-account', name: 'Revolut Personal Account', provider: 'Revolut', accountType: 'multiCurrency',
    taglineZh: '个人多币种账户 · 支持地区限定', taglineEn: 'Personal multi-currency account with residence restrictions',
    coverColors: ['#191C1F', '#6B7280', '#FFFFFF'], supportedCurrencies: ['AED', 'AUD', 'CAD', 'CHF', 'CNY', 'EUR', 'GBP', 'HKD', 'JPY', 'KRW', 'SGD', 'USD'], receivingMethods: ['local', 'swift'],
    regionsZh: '面向官方列出的澳大利亚、巴西、EEA、日本、新西兰、新加坡、瑞士、英国、美国等居住地。', regionsEn: 'Available to residents of the official supported-country list, including Australia, Brazil, EEA, Japan, New Zealand, Singapore, Switzerland, the UK and US.',
    availabilityZh: '中国大陆未列入个人账户当前支持居住地。', availabilityEn: 'Mainland China is not on the current supported-residence list for personal accounts.',
    fundingZh: '银行转账及注册地支持的入金方式。', fundingEn: 'Bank transfers and locally supported funding methods.',
    features: [feature('wallet', '持有和兑换官方支持的多种货币', 'Hold and exchange officially supported currencies'), feature('globe', '收款账户信息和转账能力按注册地开放', 'Account details and transfer capabilities vary by registration country'), feature('shield', '需要居住地与身份核验', 'Residence and identity verification are required')],
    fees: [fee('套餐与换汇', '套餐、额度、币种和时段会影响费用', 'Plans and FX', 'Plan, allowance, currency and time can affect fees')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '中国大陆居住地未在官方支持列表中', documentSummaryEn: 'Mainland China residence is not on the official supported list', noteZh: '不要以海外地址、国籍或护照替代实际居住地要求。', noteEn: 'Do not substitute an overseas address, nationality or passport for the residence requirement.', sourceUrl: 'https://help.revolut.com/en-GB/help/profile-and-plan/profile-plan/verifying-identity/what-countries-are-supported/', checkedAt: reviewedOn },
    safeguardingZh: '账户类型与资金保障取决于提供服务的 Revolut 实体和注册地。', safeguardingEn: 'Account type and safeguarding depend on the Revolut entity and registration country.', sourceName: 'Revolut Help Centre', sourceUrl: 'https://help.revolut.com/en-GB/help/profile-and-plan/profile-plan/verifying-identity/what-countries-are-supported/'
  },
  {
    id: 'payoneer-account', name: 'Payoneer Account', provider: 'Payoneer', accountType: 'multiCurrency',
    taglineZh: '跨境业务收款 · 多币种收款账户信息', taglineEn: 'Cross-border business payments with multi-currency receiving details',
    coverColors: ['#6D2A78', '#F4A261', '#FFFFFF'], supportedCurrencies: ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'SGD', 'HKD'], receivingMethods: ['local', 'swift'],
    regionsZh: '面向符合资格的跨境企业、自由职业者和数字业务；地区与主体资格以实时注册为准。', regionsEn: 'For eligible cross-border businesses, freelancers and digital businesses; location and entity eligibility are assessed during onboarding.',
    availabilityZh: '需完成身份、业务和收款用途核验。', availabilityEn: 'Identity, business and payment-purpose verification is required.', fundingZh: '客户、平台或企业通过获准的本地转账或国际汇款路径付款。', fundingEn: 'Clients, platforms or businesses pay through approved local or international transfer rails.',
    features: [feature('globe', '可申请多币种本地收款账户信息', 'May provide local receiving account details in multiple currencies'), feature('wallet', '管理支持的币种余额', 'Manage supported currency balances'), feature('shield', '收款来源、用途和地区均受审核', 'Funding source, purpose and region are reviewed')],
    fees: [fee('收款与提现', '币种、付款来源和路径不同，费用可能不同', 'Receiving and withdrawal', 'Fees may vary by currency, payer source and rail')],
    chinaKyc: { status: 'conditional', documentSummaryZh: '可能需要身份及业务资料；大陆主体资格以实时流程为准', documentSummaryEn: 'Identity and business materials may be required; mainland-entity eligibility is determined live', noteZh: '公开资料未给出覆盖所有大陆申请人的统一开户结论。', noteEn: 'Public materials do not provide a single eligibility conclusion for all mainland applicants.', sourceUrl: 'https://www.payoneer.com/resources/the-ins-and-outs-of-receiving-accounts-how-payoneers-multicurrency-account-can-help-smbs-expand-globally/', checkedAt: reviewedOn },
    safeguardingZh: '收款账户信息并非传统银行账户；保障与服务实体以官方条款为准。', safeguardingEn: 'Receiving account details are not conventional bank accounts; see applicable official terms for safeguarding.', sourceName: 'Payoneer 官方资料', sourceUrl: 'https://www.payoneer.com/resources/the-ins-and-outs-of-receiving-accounts-how-payoneers-multicurrency-account-can-help-smbs-expand-globally/'
  },
  {
    id: 'airwallex-global-account', name: 'Airwallex Global Account', provider: 'Airwallex', accountType: 'businessMultiCurrency',
    taglineZh: '企业多币种账户 · 全球收付款', taglineEn: 'Business multi-currency account for global payments',
    coverColors: ['#4B3DAA', '#7868E6', '#FFFFFF'], supportedCurrencies: ['AUD', 'CAD', 'CHF', 'CNY', 'EUR', 'GBP', 'HKD', 'JPY', 'NZD', 'SGD', 'USD'], receivingMethods: ['local', 'swift'],
    regionsZh: '面向获支持注册地区的企业；可开立账户地区和币种按企业所在地及审核结果变化。', regionsEn: 'For businesses in supported registration locations; available account regions and currencies depend on company location and review.',
    availabilityZh: '仅限企业用途，需完成企业与控制人核验。', availabilityEn: 'Business use only; company and controller verification is required.', fundingZh: '客户通过对应本地清算或 SWIFT 账户信息付款。', fundingEn: 'Customers pay through the relevant local-clearing or SWIFT account details.',
    features: [feature('globe', '官方产品页介绍多币种本地账户信息', 'Official product page describes local account details in multiple currencies'), feature('wallet', '集中管理企业多币种余额', 'Centralize business multi-currency balances'), feature('shield', '账户地区与币种需要逐项审核', 'Account regions and currencies are individually reviewed')],
    fees: [fee('开户与账户维护', '不同签约实体、地区和产品版本的定价不同', 'Opening and account maintenance', 'Pricing varies by contracting entity, location and product version')],
    chinaKyc: { status: 'conditional', documentSummaryZh: '需提交企业及相关人员资料', documentSummaryEn: 'Company and relevant-person information is required', noteZh: '中国大陆企业资格与可用产品应以对应地区的官方开户流程为准。', noteEn: 'Mainland China business eligibility and products must be confirmed in the applicable official onboarding flow.', sourceUrl: 'https://www.airwallex.com/en-us/business-account/global-accounts', checkedAt: reviewedOn },
    safeguardingZh: '资金保障及可用功能以适用服务实体、当地条款和账号确认页为准。', safeguardingEn: 'Safeguarding and capabilities depend on the applicable entity, local terms and account confirmation.', sourceName: 'Airwallex 官方产品页', sourceUrl: 'https://www.airwallex.com/en-us/business-account/global-accounts'
  },
  {
    id: 'worldfirst-world-account', name: 'WorldFirst World Account', provider: 'WorldFirst', accountType: 'businessMultiCurrency',
    taglineZh: '企业跨境收付款 · 多币种账户', taglineEn: 'Business cross-border payments with multi-currency accounts',
    coverColors: ['#CC4125', '#FF8B67', '#FFFFFF'], supportedCurrencies: ['USD', 'EUR', 'GBP', 'AUD', 'CAD', 'HKD', 'JPY', 'SGD', 'NZD', 'CNH'], receivingMethods: ['local', 'swift'],
    regionsZh: '面向跨境企业和卖家；实际可注册主体、地区及服务实体以官网地区版本为准。', regionsEn: 'For cross-border businesses and sellers; eligible entities, locations and service providers depend on the regional site.',
    availabilityZh: '企业和相关人员需完成核验。', availabilityEn: 'Business and relevant-person verification is required.', fundingZh: '商城、支付网关、客户和企业可经获准本地或国际转账路径付款。', fundingEn: 'Marketplaces, gateways, customers and businesses may pay through approved local or international rails.',
    features: [feature('globe', '官方全球页介绍 20+ 币种收款能力', 'Official global page describes receiving in 20+ currencies'), feature('payments', '支持向多国/地区付款的企业工作流', 'Business payment workflows for multiple countries and regions'), feature('shield', '平台、币种和地区能力按账户审核开放', 'Platform, currency and regional capabilities are account-review dependent')],
    fees: [fee('收款与付款', '费率、币种和路径以交易确认页为准', 'Receiving and payments', 'Rates, currencies and rails are shown at confirmation')],
    chinaKyc: { status: 'conditional', documentSummaryZh: '需核验企业和相关人员资料', documentSummaryEn: 'Business and relevant-person materials are verified', noteZh: '不同地区版本的要求不同，不保证大陆企业可开通全部能力。', noteEn: 'Requirements differ by regional version and do not guarantee all capabilities for mainland businesses.', sourceUrl: 'https://www.worldfirst.com/uk/blog/foreign-currency-exchange/how-to-hold-foreign-currency/', checkedAt: reviewedOn },
    safeguardingZh: 'WorldFirst 不是银行；资金保护取决于服务实体和适用条款。', safeguardingEn: 'WorldFirst is not a bank; protection depends on the service entity and applicable terms.', sourceName: 'WorldFirst 官方资料', sourceUrl: 'https://www.worldfirst.com/uk/blog/foreign-currency-exchange/how-to-hold-foreign-currency/'
  },
  {
    id: 'skrill-wallet', name: 'Skrill Wallet', provider: 'Skrill', accountType: 'onlineWallet',
    taglineZh: '多币种电子钱包 · 在线支付与转账', taglineEn: 'Multi-currency e-wallet for online payments and transfers',
    coverColors: ['#862165', '#BB4A95', '#FFFFFF'], supportedCurrencies: ['AED', 'AUD', 'CAD', 'CHF', 'EUR', 'GBP', 'HKD', 'JPY', 'SGD', 'USD'], receivingMethods: ['wallet', 'local'],
    regionsZh: '服务国家以注册表中可选择的居住地为准。', regionsEn: 'Serviced countries are those available in the registration form.', availabilityZh: '中国大陆居住地资格需在实时注册流程中确认。', availabilityEn: 'Mainland China residence eligibility must be confirmed in the live registration flow.', fundingZh: '支持的银行卡、银行转账和本地方式因地区而异。', fundingEn: 'Cards, bank transfers and local methods vary by region.',
    features: [feature('wallet', '电子钱包可保存主余额及可用的次级货币余额', 'Wallet can maintain a primary balance and available secondary currency balances'), feature('payments', '在线支付和入金方式按地区开放', 'Online payment and funding methods vary by region'), feature('shield', '账户资格和功能受服务实体及合规限制', 'Eligibility and features are subject to service-entity and compliance limits')],
    fees: [fee('换汇与账户费用', '适用费率和闲置账户规则以官方费用页为准', 'FX and account fees', 'See the official fee page for applicable rates and inactive-account rules')],
    chinaKyc: { status: 'unknown', documentSummaryZh: '公开页未给出适用于中国大陆的固定材料清单', documentSummaryEn: 'No fixed mainland-China document list is published on the cited page', noteZh: '录入为待复核，不应将语言或付款币种视为开户资格。', noteEn: 'Seeded for review; language or payment currency is not evidence of eligibility.', sourceUrl: 'https://www.skrill.com/cz/support/question/11/which-countries-are-serviced-by-skrill/', checkedAt: reviewedOn },
    safeguardingZh: '服务实体和资金安排以适用的 Skrill/Paysafe 条款为准。', safeguardingEn: 'Service entity and funds arrangements depend on applicable Skrill/Paysafe terms.', sourceName: 'Skrill 官方帮助中心', sourceUrl: 'https://www.skrill.com/cz/support/question/11/which-countries-are-serviced-by-skrill/'
  },
  {
    id: 'neteller-wallet', name: 'NETELLER Wallet', provider: 'NETELLER', accountType: 'onlineWallet',
    taglineZh: '多币种电子钱包 · 在线支付与国际转账', taglineEn: 'Multi-currency e-wallet for online payments and international transfers',
    coverColors: ['#2B2D42', '#00A86B', '#FFFFFF'], supportedCurrencies: ['AUD', 'BRL', 'CAD', 'CHF', 'CNY', 'EUR', 'GBP', 'HKD', 'JPY', 'SGD', 'USD'], receivingMethods: ['wallet', 'local'],
    regionsZh: '服务可用性取决于注册地和实际产品。', regionsEn: 'Availability depends on registration location and the specific product.', availabilityZh: '中国大陆居住地资格需在实时注册流程中确认。', availabilityEn: 'Mainland China residence eligibility must be confirmed during live registration.', fundingZh: '支持的银行卡、银行转账和本地方式因地区而异。', fundingEn: 'Cards, bank transfers and local methods vary by region.',
    features: [feature('wallet', '可在账户中添加可用的次级货币余额', 'Can add available secondary currency balances'), feature('payments', '可用转账和商户支付能力按地区与产品变化', 'Transfer and merchant-payment abilities vary by location and product'), feature('shield', '卡片及加密服务可能仅限特定地区', 'Card and crypto services may be limited to selected locations')],
    fees: [fee('换汇', '以官方实时汇率和费用页为准', 'Foreign exchange', 'See official real-time rates and fee page'), fee('闲置账户', '持续登录或交易可避免适用的闲置服务费；规则以官网为准', 'Inactive account', 'Keeping the account active may avoid an applicable service fee; see official terms')],
    chinaKyc: { status: 'unknown', documentSummaryZh: '公开页未给出适用于中国大陆的固定材料清单', documentSummaryEn: 'No fixed mainland-China document list is published on the cited page', noteZh: '待复核；不要把支持 CNY 兑换误写为中国大陆开户可用。', noteEn: 'Needs review; support for CNY conversion is not proof of mainland-China onboarding.', sourceUrl: 'https://www.neteller.com/en/support/question/99/', checkedAt: reviewedOn },
    safeguardingZh: '服务实体、费用和资金安排以适用 NETELLER/Paysafe 条款为准。', safeguardingEn: 'Service entity, fees and funds arrangements depend on applicable NETELLER/Paysafe terms.', sourceName: 'NETELLER 官方帮助中心', sourceUrl: 'https://www.neteller.com/en/support/question/99/'
  },
  {
    id: 'n26-standard', name: 'N26 Standard', provider: 'N26', accountType: 'personalBanking',
    taglineZh: '欧洲个人数字银行账户 · 地区受限', taglineEn: 'European personal digital banking account with residence restrictions',
    coverColors: ['#36C7B5', '#123B3A', '#FFFFFF'], supportedCurrencies: ['EUR'], receivingMethods: ['sepa'],
    regionsZh: '面向 N26 官方支持地区的居民。', regionsEn: 'For residents of N26 officially supported locations.', availabilityZh: '中国大陆不属于 N26 个人账户支持居住地。', availabilityEn: 'Mainland China is not an N26 supported residence for personal accounts.', fundingZh: 'SEPA 转账及注册地区支持的方式。', fundingEn: 'SEPA transfers and methods supported in the registration location.',
    features: [feature('wallet', '个人账户和借记卡能力按注册地区开放', 'Personal account and debit-card capabilities vary by registration location'), feature('payments', '欧元区支付与转账功能', 'Euro-area payment and transfer functionality'), feature('shield', '需完成身份和居住地验证', 'Identity and residence verification are required')],
    fees: [fee('账户套餐', 'Standard 及其他套餐、附加服务的费用以当地官网为准', 'Account plan', 'See local N26 site for Standard, other plans and optional-service fees')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '中国大陆居住地不在产品支持范围', documentSummaryEn: 'Mainland China residence is outside the product support area', noteZh: '不能以护照或国籍替代居住地资格。', noteEn: 'A passport or nationality cannot substitute for residence eligibility.', sourceUrl: 'https://support.n26.com/en-eu/account-and-personal-details/opening-an-account/can-i-open-an-n26-account-in-my-country', checkedAt: reviewedOn },
    safeguardingZh: '存款保障和账户服务实体取决于当地 N26 产品条款。', safeguardingEn: 'Deposit protection and account entity depend on local N26 product terms.', sourceName: 'N26 官方帮助中心', sourceUrl: 'https://support.n26.com/en-eu/account-and-personal-details/opening-an-account/can-i-open-an-n26-account-in-my-country'
  },
  {
    id: 'bunq-personal-account', name: 'bunq Personal Account', provider: 'bunq', accountType: 'multiCurrency',
    taglineZh: '欧洲个人账户 · 多币种与 IBAN 服务', taglineEn: 'European personal account with multi-currency and IBAN services',
    coverColors: ['#03C75A', '#143D2B', '#FFFFFF'], supportedCurrencies: [], receivingMethods: ['sepa'],
    regionsZh: '面向 bunq 当前支持的 EEA 国家居民。', regionsEn: 'For residents of bunq’s currently supported EEA countries.',
    availabilityZh: '中国大陆居住地不在 bunq 个人账户支持范围内。', availabilityEn: 'Mainland China residence is outside bunq’s personal-account support area.',
    fundingZh: '银行转账与其他账户能力以注册地和应用内实时流程为准。', fundingEn: 'Bank transfers and other account capabilities depend on residence and live in-app onboarding.',
    features: [feature('wallet', '个人账户与余额能力按支持居住地开放', 'Personal account and balance features are available by supported residence'), feature('globe', '账户信息和多币种能力以实际产品及居住地为准', 'Account details and multi-currency capabilities depend on the actual product and residence'), feature('shield', '需满足居住地、身份和接受政策要求', 'Residence, identity and acceptance-policy requirements apply')],
    fees: [fee('账户套餐与换汇', '套餐、币种和功能费用以 bunq 当地实时费率为准', 'Account plans and FX', 'See bunq’s local live pricing for plan, currency and feature fees')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '需居住在 bunq 支持的 EEA 国家', documentSummaryEn: 'Residence in a bunq-supported EEA country is required', noteZh: '不能以国籍、护照或海外地址替代实际居住地资格。', noteEn: 'Nationality, passport or an overseas address cannot substitute for residence eligibility.', sourceUrl: 'https://help.bunq.com/fr-fr/articles/who-can-open-a-bunq-personal-account', checkedAt: reviewedOn },
    safeguardingZh: '账户实体、资金保障和可用功能以 bunq 适用条款及注册地为准。', safeguardingEn: 'Account entity, safeguarding and capabilities depend on bunq’s applicable terms and registration location.', sourceName: 'bunq 官方帮助中心', sourceUrl: 'https://help.bunq.com/fr-fr/articles/who-can-open-a-bunq-personal-account'
  },
  {
    id: 'mercury-business-account', name: 'Mercury Business Account', provider: 'Mercury', accountType: 'businessBanking',
    taglineZh: '美国注册企业账户 · 数字化资金管理', taglineEn: 'Digital business account for U.S.-registered companies',
    coverColors: ['#2A2E35', '#7C8CFF', '#FFFFFF'], supportedCurrencies: ['USD'], receivingMethods: [],
    regionsZh: '面向在美国或美国领地注册、且符合审核条件的企业。', regionsEn: 'For companies formed in the United States or a U.S. territory that meet review requirements.',
    availabilityZh: '国际创始人可申请，但企业注册地、经营情况和控制人资格均需审核。', availabilityEn: 'International founders may apply, but entity formation, operations and beneficial owners are reviewed.',
    fundingZh: '账户资金、转账轨道和可用功能以获批企业账户及官方实时流程为准。', fundingEn: 'Funding, transfer rails and capabilities depend on the approved business account and live official flow.',
    features: [feature('wallet', '面向符合条件美国企业的数字化企业账户', 'Digital business account for eligible U.S. companies'), feature('payments', '企业资料、资金来源和经营情况进入审核', 'Business information, source of funds and operations are reviewed'), feature('shield', '国际创始人不等同于自动获批', 'International founders are not automatically approved')],
    fees: [fee('账户与资金服务', '适用费用及可用服务以 Mercury 确认页和企业协议为准', 'Account and funding services', 'See Mercury confirmation screens and business agreements for applicable fees and services')],
    chinaKyc: { status: 'unknown', documentSummaryZh: '公开资料要求美国注册实体及企业、控制人资料', documentSummaryEn: 'Public materials require a U.S.-registered entity and business/beneficial-owner information', noteZh: '国际创始人可申请并不证明中国大陆居住地或主体一定可获批。', noteEn: 'International-founder eligibility does not prove approval for a mainland-China resident or entity.', sourceUrl: 'https://support.mercury.com/hc/en-us/articles/28770467511060-Eligibility', checkedAt: reviewedOn },
    safeguardingZh: 'Mercury 是金融科技服务；具体银行服务、保障和资格以适用合作银行及企业协议为准。', safeguardingEn: 'Mercury is a fintech service; banking services, protections and eligibility depend on the applicable partner bank and business agreements.', sourceName: 'Mercury 官方资格说明', sourceUrl: 'https://support.mercury.com/hc/en-us/articles/28770467511060-Eligibility'
  },
  {
    id: 'qonto-business-account', name: 'Qonto Business Account', provider: 'Qonto', accountType: 'businessBanking',
    taglineZh: '欧洲企业账户 · 本地 IBAN 与支付管理', taglineEn: 'European business account with local IBAN and payment management',
    coverColors: ['#5C43F3', '#241E4F', '#FFFFFF'], supportedCurrencies: ['EUR'], receivingMethods: ['sepa'],
    regionsZh: '面向注册并总部位于法国、意大利、西班牙、德国、葡萄牙、比利时、奥地利或荷兰的企业。', regionsEn: 'For companies registered and headquartered in France, Italy, Spain, Germany, Portugal, Belgium, Austria or the Netherlands.',
    availabilityZh: '中国大陆注册或总部企业不在当前官方支持范围内。', availabilityEn: 'Companies registered or headquartered in mainland China are outside the current official support area.',
    fundingZh: '企业账户、IBAN 和支付能力以注册国家、企业类型及审核结果为准。', fundingEn: 'Business-account, IBAN and payment capabilities depend on registration country, entity type and review outcome.',
    features: [feature('globe', '企业账户和本地 IBAN 能力以注册国家开放范围为准', 'Business-account and local-IBAN capabilities depend on registration-country availability'), feature('payments', '企业结构、授权人和合规资料需审核', 'Company structure, authorised persons and compliance information are reviewed'), feature('shield', '仅列出支持国家不代表所有企业类型均可申请', 'A supported country does not mean every entity type is eligible')],
    fees: [fee('账户套餐与支付', '套餐、付款和换汇费用以 Qonto 对应国家的实时定价为准', 'Account plans and payments', 'See Qonto’s local live pricing for plans, payments and FX')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '企业需注册并总部位于 Qonto 当前支持的欧洲国家', documentSummaryEn: 'The company must be registered and headquartered in a currently supported European country', noteZh: '不能以股东国籍或海外关联公司替代企业注册和总部所在地要求。', noteEn: 'Shareholder nationality or an overseas affiliate cannot substitute for the company registration and headquarters requirements.', sourceUrl: 'https://support-de.qonto.com/hc/en-us/articles/23949292696849-Can-any-organization-open-a-Qonto-account', checkedAt: reviewedOn },
    safeguardingZh: '服务实体、支付功能和资金安排以 Qonto 对应国家条款及审核结果为准。', safeguardingEn: 'Service entity, payment capabilities and funds arrangements depend on Qonto’s local terms and review outcome.', sourceName: 'Qonto 官方帮助中心', sourceUrl: 'https://support-de.qonto.com/hc/en-us/articles/23949292696849-Can-any-organization-open-a-Qonto-account'
  },
  {
    id: 'vivid-money-account', name: 'Vivid Money Account', provider: 'Vivid Money', accountType: 'multiCurrency',
    taglineZh: '欧洲多币种账户 · 支持币种以条款和地区为准', taglineEn: 'European multi-currency account; supported currencies vary by terms and region',
    coverColors: ['#171717', '#FF8A00', '#FFFFFF'], supportedCurrencies: ['AED', 'AUD', 'CAD', 'CHF', 'CNH', 'CZK', 'DKK', 'EUR', 'GBP', 'HKD', 'HUF', 'ILS', 'JPY', 'MXN', 'NOK', 'NZD', 'PLN', 'RON', 'SAR', 'SEK', 'SGD', 'TRY', 'USD', 'ZAR'], receivingMethods: [],
    regionsZh: '服务实体、可注册国家和可用功能以 Vivid 实时注册流程及适用条款为准。', regionsEn: 'Service entity, available countries and capabilities depend on Vivid’s live onboarding and applicable terms.',
    availabilityZh: '中国大陆居住地资格未由所引公开条款确认。', availabilityEn: 'Mainland China residence eligibility is not confirmed by the cited public terms.',
    fundingZh: '账户、支付和换汇能力按获批账户、币种及注册地开放。', fundingEn: 'Account, payment and FX capabilities vary by approved account, currency and registration location.',
    features: [feature('wallet', '官方条款列出多种可支持货币', 'Official terms list multiple potentially supported currencies'), feature('payments', '实际功能按居住地、产品和审核结果开放', 'Actual capabilities vary by residence, product and review result'), feature('shield', '不能把条款中的币种列表视为开户资格承诺', 'A currency list in terms is not an onboarding-eligibility guarantee')],
    fees: [fee('账户与换汇', '费用、汇率和产品可用性以 Vivid 的实时确认页和适用条款为准', 'Account and FX', 'See Vivid’s live confirmation screens and applicable terms for fees, rates and availability')],
    chinaKyc: { status: 'unknown', documentSummaryZh: '所引条款未给出适用于中国大陆的固定开户材料或资格结论', documentSummaryEn: 'The cited terms do not state fixed mainland-China onboarding documents or eligibility', noteZh: '支持币种不代表中国大陆居住地可注册或可使用全部功能。', noteEn: 'Supported currencies do not prove mainland-China registration or access to all functions.', sourceUrl: 'https://website-static.vivid.money/static/legal-docs/en-it/terms-and-conditions-vivid-money-sa.pdf', checkedAt: reviewedOn },
    safeguardingZh: '服务实体、资金安排和功能以 Vivid 的适用条款、地区版本和审核结果为准。', safeguardingEn: 'Service entity, funds arrangements and capabilities depend on Vivid’s applicable terms, regional version and review outcome.', sourceName: 'Vivid Money 官方条款', sourceUrl: 'https://website-static.vivid.money/static/legal-docs/en-it/terms-and-conditions-vivid-money-sa.pdf'
  },
  {
    id: 'monzo-current-account', name: 'Monzo Current Account', provider: 'Monzo', accountType: 'personalBanking',
    taglineZh: '英国个人数字银行账户 · 居住地受限', taglineEn: 'UK personal digital banking account with residence restrictions',
    coverColors: ['#FF5F5F', '#3B1F2B', '#FFFFFF'], supportedCurrencies: ['GBP'], receivingMethods: [],
    regionsZh: '面向居住在英国并拥有英国地址的个人。', regionsEn: 'For individuals who live in the UK and have a UK address.', availabilityZh: '中国大陆居住地不符合该个人账户的公开资格要求。', availabilityEn: 'Mainland China residence does not meet the published personal-account eligibility requirements.', fundingZh: '账户和转账功能以获批英国个人账户及实时产品流程为准。', fundingEn: 'Account and transfer capabilities depend on an approved UK personal account and live product flow.',
    features: [feature('wallet', '英国个人活期账户能力以获批资格为准', 'UK personal current-account capabilities depend on approval'), feature('payments', '卡片、支付和账户功能按英国产品条款开放', 'Card, payment and account capabilities follow UK product terms'), feature('shield', '英国居住地和地址要求不能由国籍替代', 'UK residence and address requirements cannot be replaced by nationality')],
    fees: [fee('账户与支付', '费用和可用功能以 Monzo 对应产品条款及确认页为准', 'Account and payments', 'See Monzo’s applicable product terms and confirmation screens for fees and capabilities')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '需居住在英国并拥有英国地址', documentSummaryEn: 'UK residence and a UK address are required', noteZh: '税务居民身份与实际居住地/地址资格是不同概念。', noteEn: 'Tax residency is distinct from the actual residence/address eligibility requirement.', sourceUrl: 'https://monzo.com/help/legal-stuff/tax-residency-not-uk', checkedAt: reviewedOn },
    safeguardingZh: '账户实体、存款保障和功能以 Monzo 的英国适用条款为准。', safeguardingEn: 'Account entity, deposit protection and capabilities depend on Monzo’s applicable UK terms.', sourceName: 'Monzo 官方帮助中心', sourceUrl: 'https://monzo.com/help/legal-stuff/tax-residency-not-uk'
  },
  {
    id: 'nubank-account', name: 'Nubank Account', provider: 'Nubank', accountType: 'personalBanking',
    taglineZh: '拉丁美洲数字银行账户 · 地区受限', taglineEn: 'Latin American digital banking account with regional restrictions',
    coverColors: ['#820AD1', '#351047', '#FFFFFF'], supportedCurrencies: [], receivingMethods: [],
    regionsZh: 'Nu 官方资料介绍其在巴西、墨西哥和哥伦比亚的客户与服务。', regionsEn: 'Nu’s official materials describe customers and services in Brazil, Mexico and Colombia.', availabilityZh: '中国大陆居住地不在公开的主要服务地区内。', availabilityEn: 'Mainland China residence is outside the publicly described core service regions.', fundingZh: '账户、付款和转账能力以所在国家的获批账户及当地产品条款为准。', fundingEn: 'Account, payment and transfer capabilities depend on the approved local account and country-specific terms.',
    features: [feature('wallet', '账户能力按巴西、墨西哥或哥伦比亚的当地产品开放', 'Account capabilities vary by the local product in Brazil, Mexico or Colombia'), feature('payments', '支付、储蓄和信贷功能按国家及审核条件变化', 'Payments, savings and credit features vary by country and review conditions'), feature('shield', '不将区域客户覆盖表述为全球开户资格', 'Regional customer coverage is not global onboarding eligibility')],
    fees: [fee('账户与支付', '费用和可用功能以对应国家的 Nubank 条款及确认页为准', 'Account and payments', 'See Nubank’s country-specific terms and confirmation screens for fees and availability')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '公开服务覆盖为巴西、墨西哥和哥伦比亚', documentSummaryEn: 'The publicly described service footprint is Brazil, Mexico and Colombia', noteZh: '不能从品牌国际业务或旅行使用场景推断中国大陆可开户。', noteEn: 'International brand operations or travel use do not prove mainland-China onboarding.', sourceUrl: 'https://international.nubank.com.br/pt-br/sobre/', checkedAt: reviewedOn },
    safeguardingZh: '账户实体、保障和功能以客户所在国家的 Nubank 服务实体与当地条款为准。', safeguardingEn: 'Account entity, protections and capabilities depend on the Nubank entity and local terms in the customer’s country.', sourceName: 'Nu 官方介绍', sourceUrl: 'https://international.nubank.com.br/pt-br/sobre/'
  },
  {
    id: 'cash-app-account', name: 'Cash App Account', provider: 'Cash App', accountType: 'onlineWallet',
    taglineZh: '美国支付与余额账户 · 非银行账户', taglineEn: 'U.S. payment and balance account, not a bank account',
    coverColors: ['#00D632', '#102715', '#FFFFFF'], supportedCurrencies: ['USD'], receivingMethods: [],
    regionsZh: 'Cash App 账户条款要求用户为美国居民。', regionsEn: 'Cash App account terms require users to be U.S. residents.', availabilityZh: '中国大陆居住地不符合 Cash App 账户公开资格。', availabilityEn: 'Mainland China residence does not meet the published Cash App account eligibility.', fundingZh: '余额、关联账户和支付能力以美国获批账户及实时产品资格为准。', fundingEn: 'Balance, linked-account and payment capabilities depend on an approved U.S. account and live product eligibility.',
    features: [feature('wallet', '可使用余额、转账和部分金融服务，具体能力按账户等级开放', 'Balance, transfers and selected financial services vary by account tier'), feature('payments', '部分功能需要身份核验和额外账户资格', 'Some capabilities require identity verification and additional account eligibility'), feature('shield', 'Cash App 是金融服务平台而非银行', 'Cash App is a financial-services platform, not a bank')],
    fees: [fee('转账与账户服务', '费用、余额服务和转账方式以 Cash App 实时说明及条款为准', 'Transfers and account services', 'See Cash App’s live disclosures and terms for fees, balance services and transfer methods')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: 'Cash App 账户要求美国居住地', documentSummaryEn: 'Cash App accounts require U.S. residence', noteZh: '国际汇款收款地或跨境数据处理不代表中国大陆可注册账户。', noteEn: 'International remittance destinations or cross-border data processing do not prove mainland-China account registration.', sourceUrl: 'https://cash.app/legal/tos', checkedAt: reviewedOn },
    safeguardingZh: '服务实体、资金安排和适用的银行合作方以 Cash App 条款及产品披露为准。', safeguardingEn: 'Service entity, funds arrangements and applicable bank partners depend on Cash App terms and product disclosures.', sourceName: 'Cash App 服务条款', sourceUrl: 'https://cash.app/legal/tos'
  },
  cryptoRecord({
    id: 'bitpanda', name: 'Bitpanda', provider: 'Bitpanda', taglineZh: '欧洲加密资产与多资产平台 · 非银行账户', taglineEn: 'European crypto and multi-asset platform, not a bank account',
    sourceName: 'Bitpanda 官方帮助中心', sourceUrl: 'https://support.bitpanda.com/hc/en-us/articles/360013898239-Countries-supported-for-verification',
    regionsZh: '官方验证支持国家主要位于欧洲及部分相邻地区。', regionsEn: 'Official verification support is primarily in Europe and selected nearby regions.', availabilityZh: '中国大陆居住地不在当前官方验证支持国家列表中。', availabilityEn: 'Mainland China residence is not on the current official verification-support list.', fundingZh: '法币、数字资产、卡片及投资能力按居住地、产品和验证等级开放。', fundingEn: 'Fiat, crypto, card and investment capabilities vary by residence, product and verification tier.',
    chinaStatus: 'unavailable', chinaDocumentZh: '中国大陆未在官方验证支持国家列表中', chinaDocumentEn: 'Mainland China is not on the official verification-support list', chinaNoteZh: '不要把欧洲可验证资格、资产交易或卡片功能误写为中国大陆可用。', chinaNoteEn: 'Do not treat European verification, asset trading or card availability as mainland-China availability.', supportedCurrencies: [], receivingMethods: ['crypto'], coverColors: ['#F6C144', '#181818', '#FFFFFF'], accountType: 'cryptoPlatform'
  }),
  {
    id: 'etoro-money-account', name: 'eToro Money Account', provider: 'eToro Money', accountType: 'onlineWallet',
    taglineZh: '欧洲资金账户与支付卡 · 地区受限', taglineEn: 'European money account and payment card with regional restrictions',
    coverColors: ['#72C535', '#18351A', '#FFFFFF'], supportedCurrencies: [], receivingMethods: [],
    regionsZh: '本地货币账户条款面向 EEA 居住地及条款中列明的支持地区。', regionsEn: 'Local-currency account terms apply to EEA residence and the supported locations specified in the terms.', availabilityZh: '中国大陆居住地不属于所引欧洲本地货币账户条款的适用范围。', availabilityEn: 'Mainland China residence is outside the cited European local-currency-account terms scope.', fundingZh: '入金、转账、卡片和本地货币功能以居住地、账户实体和实时流程为准。', fundingEn: 'Funding, transfers, card and local-currency features depend on residence, account entity and live flow.',
    features: [feature('wallet', '本地货币账户与支付功能按地区和产品开放', 'Local-currency account and payment features vary by location and product'), feature('payments', '资金转入、转出与卡片能力按账户实体开放', 'Funding, withdrawals and card capabilities vary by account entity'), feature('shield', '资金账户不等于投资账户或投资建议', 'A money account is not an investment account or investment advice')],
    fees: [fee('账户与换汇', '费用、汇率和地区支持以 eToro Money 实时条款及确认页为准', 'Account and FX', 'See eToro Money’s live terms and confirmation screens for fees, rates and regional availability')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '所引本地货币账户条款适用于 EEA 支持居住地', documentSummaryEn: 'The cited local-currency-account terms apply to supported EEA residences', noteZh: '交易平台可访问性、数据处理地点或品牌网站语言不代表中国大陆资金账户可开通。', noteEn: 'Platform access, data-processing location or website language do not prove mainland-China money-account availability.', sourceUrl: 'https://www.etoro.com/wp-content/uploads/2026/03/eToro-Money-Malta-Limited-Local-Currency-Account-Terms-and-Conditions-Effective-Date-31-March-2026.pdf', checkedAt: reviewedOn },
    safeguardingZh: '服务实体、资金账户安排和产品能力以 eToro Money 适用地区条款为准。', safeguardingEn: 'Service entity, money-account arrangements and capabilities depend on eToro Money’s applicable regional terms.', sourceName: 'eToro Money 官方条款', sourceUrl: 'https://www.etoro.com/wp-content/uploads/2026/03/eToro-Money-Malta-Limited-Local-Currency-Account-Terms-and-Conditions-Effective-Date-31-March-2026.pdf'
  },
  cryptoRecord({
    id: 'plutus-account', name: 'Plutus Account', provider: 'Plutus', taglineZh: '欧洲支付卡与加密奖励账户 · 非银行账户', taglineEn: 'European payment-card and crypto-rewards account, not a bank account',
    sourceName: 'Plutus 官方帮助中心', sourceUrl: 'https://www.plutus.it/help/currently-supported-countries',
    regionsZh: '服务面向英国及官方列出的 EEA 合法居民。', regionsEn: 'Services are for legal residents of the UK and the officially listed EEA countries.', availabilityZh: '中国大陆居住地不在当前官方支持国家或地区列表中。', availabilityEn: 'Mainland China residence is not on the current official supported-country list.',
    fundingZh: '银行卡、银行转账、奖励和卡片功能以居住地、账户资格及应用内实时流程为准。', fundingEn: 'Cards, bank transfers, rewards and payment-card capabilities depend on residence, account eligibility and live in-app flow.',
    chinaStatus: 'unavailable', chinaDocumentZh: '服务要求英国或支持 EEA 国家/地区的合法居住地', chinaDocumentEn: 'Services require legal residence in the UK or a supported EEA country/territory', chinaNoteZh: '奖励、代币和卡片功能会变化，不能表述为银行存款或保证收益。', chinaNoteEn: 'Rewards, token and card features can change and are not bank deposits or guaranteed returns.', supportedCurrencies: [], receivingMethods: ['crypto'], coverColors: ['#FFCC00', '#201A00', '#FFFFFF'], accountType: 'cryptoIntegratedAccount'
  }),
  cryptoRecord({
    id: 'strike-account', name: 'Strike Account', provider: 'Strike', taglineZh: '全球比特币与支付应用 · 非银行账户', taglineEn: 'Global bitcoin and payments app, not a bank account',
    sourceName: 'Strike 官方帮助中心', sourceUrl: 'https://strike.me/faq/where-is-strike-available/',
    regionsZh: 'Strike 官方称应用覆盖多个国家/地区；具体产品按居住地、州/地区和账户类型变化。', regionsEn: 'Strike officially describes availability across many countries; products vary by residence, state/region and account type.', availabilityZh: '中国大陆居住地资格未由所引公开可用性页确认。', availabilityEn: 'Mainland China residence eligibility is not confirmed by the cited public availability page.',
    fundingZh: '比特币买卖、持有、转账和法币路径以所在地区、账户验证及实时应用流程为准。', fundingEn: 'Bitcoin buying, holding, transfers and fiat rails depend on location, account verification and live app flow.',
    chinaStatus: 'unknown', chinaDocumentZh: '所引公开页面未列出适用于中国大陆的固定开户材料或资格结论', chinaDocumentEn: 'The cited public page does not state fixed mainland-China documents or eligibility', chinaNoteZh: '“全球覆盖”不等于所有国家可开户或享有相同功能。', chinaNoteEn: '“Global availability” does not mean every country can onboard or access the same features.', supportedCurrencies: [], receivingMethods: ['crypto'], coverColors: ['#F7931A', '#1B1B1B', '#FFFFFF'], accountType: 'cryptoPlatform'
  }),
  {
    id: 'paysera-account', name: 'Paysera Account', provider: 'Paysera', accountType: 'multiCurrency',
    taglineZh: '多币种支付账户 · IBAN 与转账服务', taglineEn: 'Multi-currency payment account with IBAN and transfers',
    coverColors: ['#F6B500', '#1B4B8F', '#FFFFFF'], supportedCurrencies: ['EUR', 'GBP', 'USD'], receivingMethods: ['sepa', 'swift'],
    regionsZh: '服务国家和账户能力按 Paysera 实时开户流程及服务实体确定。', regionsEn: 'Serviced countries and account capabilities are determined by Paysera’s live onboarding and service entity.', availabilityZh: '官方国家列表将中国标注为当前不可注册及客户准入。', availabilityEn: 'The official country list marks China as currently unavailable for registration and client onboarding.', fundingZh: '银行转账和按地区提供的其他方式。', fundingEn: 'Bank transfers and other methods offered by location.',
    features: [feature('wallet', '多币种支付账户能力以实际开户实体为准', 'Multi-currency payment-account capabilities depend on the actual onboarding entity'), feature('globe', '转账轨道与账户信息因地区和币种不同', 'Transfer rails and account details vary by region and currency'), feature('shield', '身份、居住地和用途均需核验', 'Identity, residence and purpose are verified')],
    fees: [fee('账户与转账', '费用按服务实体、币种和转账方式变化', 'Account and transfer', 'Fees vary by service entity, currency and transfer method')],
    chinaKyc: { status: 'unavailable', documentSummaryZh: '官方国家列表将中国标记为当前不可注册及客户准入', documentSummaryEn: 'The official country list marks China as currently unavailable for registration and client onboarding', noteZh: '页面的限制表述针对“中国”及客户准入；发布前如要区分国籍与居住地，应另行复核。', noteEn: 'The page’s restriction is stated for “China” and client onboarding; review separately before distinguishing nationality from residence.', sourceUrl: 'https://www.paysera.com/v2/en/faq/where-paysera-works', checkedAt: reviewedOn },
    safeguardingZh: '账户性质、资金保障和可用币种以 Paysera 适用条款为准。', safeguardingEn: 'Account nature, safeguarding and available currencies depend on applicable Paysera terms.', sourceName: 'Paysera 官方帮助中心', sourceUrl: 'https://www.paysera.com/v2/en/faq/where-paysera-works'
  },
  {
    id: 'kraken', name: 'Kraken', provider: 'Kraken', accountType: 'cryptoPlatform',
    taglineZh: '加密资产交易平台 · 非银行账户', taglineEn: 'Crypto-asset platform, not a bank account',
    coverColors: ['#5741D9', '#9B8CFF', '#FFFFFF'], supportedCurrencies: ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CHF'], receivingMethods: ['local', 'swift', 'crypto'],
    regionsZh: '需居住在 Kraken 支持地区；司法辖区限制和法币功能会变化。', regionsEn: 'Users must reside in a Kraken supported region; jurisdiction restrictions and fiat features can change.', availabilityZh: '中国大陆居住地与法币能力需在实时注册和地区限制页面中确认。', availabilityEn: 'Mainland China residence and fiat capabilities must be confirmed in live onboarding and geographic restrictions.', fundingZh: '获准的法币入金方式及链上加密资产转入；路径按地区开放。', fundingEn: 'Approved fiat funding methods and on-chain crypto deposits; rails vary by region.',
    features: [feature('wallet', '可持有平台支持的法币和加密资产余额', 'Can hold platform-supported fiat and crypto balances'), feature('payments', '法币入出金及交易能力按地区和验证等级变化', 'Fiat funding, withdrawals and trading vary by location and verification level'), feature('shield', '交易前需完成身份和合规核验', 'Identity and compliance verification are required before trading')],
    fees: [fee('交易与入出金', '交易费、网络费和法币路径费用以 Kraken 实时页面为准', 'Trading and funding', 'Trading, network and fiat-rail fees are shown by Kraken in real time')],
    chinaKyc: { status: 'unknown', documentSummaryZh: '官方要求身份资料；可接受的文件和地区限制按居住地显示', documentSummaryEn: 'Kraken requires identity information; acceptable documents and restrictions are shown by residence', noteZh: '不要把此记录描述为银行、支付账户或面向中国大陆开放。', noteEn: 'Do not describe this as a bank/payment account or as available to mainland China.', sourceUrl: 'https://support.kraken.com/hc/en-us/articles/360021973671-how-to-get-verified-on-kraken', checkedAt: reviewedOn },
    safeguardingZh: '加密资产价格波动和平台风险独立于银行存款保障；以 Kraken 风险披露和当地规则为准。', safeguardingEn: 'Crypto-asset volatility and platform risk are separate from bank-deposit protection; see Kraken disclosures and local rules.', sourceName: 'Kraken 官方帮助中心', sourceUrl: 'https://support.kraken.com/hc/en-us/articles/360021973671-how-to-get-verified-on-kraken'
  },
  {
    id: 'neverless', name: 'Neverless', provider: 'Neverless', accountType: 'cryptoPlatform',
    taglineZh: '加密资产与投资平台 · 非银行账户', taglineEn: 'Crypto-asset and investment platform, not a bank account',
    coverColors: ['#121826', '#4F46E5', '#FFFFFF'], supportedCurrencies: [], receivingMethods: ['crypto'],
    regionsZh: '仅面向相关服务可访问且法律允许的居住地；功能按地点和产品变化。', regionsEn: 'Available only where the relevant service is accessible and lawful; features vary by location and product.', availabilityZh: '中国大陆居住地资格未获公开资料确认。', availabilityEn: 'Mainland China residence eligibility is not confirmed by the cited public materials.', fundingZh: '以应用内实时支持的法币或加密资产路径为准。', fundingEn: 'See the app for currently supported fiat or crypto funding rails.',
    features: [feature('wallet', '可用服务可能包括加密资产持有及相关产品', 'Available services may include crypto holding and related products'), feature('payments', '资产、衍生品、奖励和转账功能依地点与资格变化', 'Asset, derivative, rewards and transfer features vary by location and eligibility'), feature('shield', '需要身份、居住地和合规资格核验', 'Identity, residence and compliance eligibility are verified')],
    fees: [fee('交易与转账', '费用、点差和网络成本以应用内确认页及官方条款为准', 'Trading and transfers', 'Fees, spreads and network costs are shown in-app and in official terms')],
    chinaKyc: { status: 'unknown', documentSummaryZh: '公开条款要求居住在服务可访问且合法的国家/地区', documentSummaryEn: 'Public terms require residence where services are accessible and lawful', noteZh: '录入为待复核，不应把其列为国际银行账户或保证可用。', noteEn: 'Seeded for review; do not list it as an international bank account or guarantee availability.', sourceUrl: 'https://neverless.com/en_GB/legal/terms', checkedAt: reviewedOn },
    safeguardingZh: '该产品不是银行账户；投资和加密资产存在损失风险，保护安排以官方条款和服务实体为准。', safeguardingEn: 'This is not a bank account; investments and crypto assets involve loss risk, and protections depend on official terms and the service entity.', sourceName: 'Neverless Client Agreement', sourceUrl: 'https://neverless.com/en_GB/legal/terms'
  },
  cryptoRecord({
    id: 'kast', name: 'KAST', taglineZh: '稳定币全球账户与消费卡 · 非银行账户', taglineEn: 'Stablecoin global account and spending card, not a bank account',
    sourceName: 'KAST 官方网站', sourceUrl: 'https://www.kast.xyz/',
    regionsZh: '服务和卡片仅在 KAST 应用内列出的支持地区开放。', regionsEn: 'Services and cards are available only in regions listed in the KAST app.',
    availabilityZh: '中国大陆资格需在实时 KYC 国家选择中确认。', availabilityEn: 'Mainland China eligibility must be confirmed in the live KYC country selector.',
    fundingZh: '官方页面说明支持稳定币存取及部分法币功能；具体路径以应用为准。', fundingEn: 'Official pages describe stablecoin deposits/withdrawals and selected fiat features; see the app for rails.',
    supportedCurrencies: ['USD'], receivingMethods: ['ach', 'wire', 'crypto'], coverColors: ['#121826', '#3F65FF', '#FFFFFF'], accountType: 'cryptoIntegratedAccount'
  }),
  {
    id: 'starryblu', name: 'Starryblu Global Account', provider: 'Starryblu', accountType: 'multiCurrency',
    taglineZh: '多币种全球支付账户与卡', taglineEn: 'Multi-currency global payment account and card',
    coverColors: ['#1144AA', '#2AB6F6', '#FFFFFF'], supportedCurrencies: [], receivingMethods: ['local', 'swift'],
    regionsZh: '服务能力和支付卡覆盖以注册流程和当地规则为准。', regionsEn: 'Service capabilities and card coverage depend on onboarding and local rules.',
    availabilityZh: '中国大陆居住地资格需要在实时注册流程中确认。', availabilityEn: 'Mainland China residence eligibility must be confirmed in live registration.',
    fundingZh: '多币种账户入金和国际转账能力以应用内流程为准。', fundingEn: 'Multi-currency funding and international transfers are shown in the app.',
    features: [feature('wallet', '官方资料介绍多币种全球账户', 'Official materials describe a multi-currency global account'), feature('payments', '提供跨境转账及实体或虚拟卡能力', 'Offers cross-border transfers and physical or virtual card capabilities'), feature('shield', '身份核验与服务范围按注册地适用', 'Identity verification and service scope depend on registration location')],
    fees: [fee('账户与支付', '费用与可用权益以官方实时页面和条款为准', 'Account and payments', 'See official live pages and terms for fees and benefits')],
    chinaKyc: { status: 'unknown', documentSummaryZh: '以实时注册流程为准', documentSummaryEn: 'Follow the live registration flow', noteZh: '本记录不涉及加密资产标识；中国大陆资格尚待单独核验。', noteEn: 'This record is not crypto-related; mainland-China eligibility needs separate verification.', sourceUrl: 'https://www.starryblu.com/en/', checkedAt: reviewedOn },
    safeguardingZh: '服务实体和资金安排以 Starryblu 官方条款及相应监管实体为准。', safeguardingEn: 'Service entity and funds arrangements depend on Starryblu terms and applicable regulated entity.', sourceName: 'Starryblu 官方网站', sourceUrl: 'https://www.starryblu.com/en/'
  },
  cryptoRecord({
    id: 'dtcpay', name: 'dtcpay Wallet', provider: 'dtcpay', taglineZh: '数字支付代币钱包与支付服务 · 非银行账户', taglineEn: 'Digital payment token wallet and payment service, not a bank account',
    sourceName: 'dtcpay 官方帮助中心', sourceUrl: 'https://dtcpay.com/faqs/not-able-to-serve-jurisdictions',
    regionsZh: '服务地区受客户、企业控制人及授权人员的居住地限制。', regionsEn: 'Service locations are restricted based on residence of clients, company directors and authorised persons.',
    availabilityZh: '官方限制名单包含中国大陆，当前不提供准入或服务。', availabilityEn: 'The official restricted list includes mainland China; onboarding and service are unavailable.',
    fundingZh: '数字资产钱包和支付路径以获批准账户及当地服务为准。', fundingEn: 'Digital-asset wallet and payment rails depend on approved accounts and local service.',
    chinaStatus: 'unavailable', chinaDocumentZh: '官方限制名单包含中华人民共和国', chinaDocumentEn: 'The official restricted list includes the People’s Republic of China', chinaNoteZh: '不应将 dtcpay 列为中国大陆可申请账户。', chinaNoteEn: 'Do not list dtcpay as available for mainland-China applicants.', coverColors: ['#101820', '#F4D03F', '#FFFFFF']
  }),
  cryptoRecord({
    id: 'backpack-exchange', name: 'Backpack Exchange', provider: 'Backpack', taglineZh: '加密资产交易与钱包平台 · 非银行账户', taglineEn: 'Crypto-asset exchange and wallet platform, not a bank account',
    sourceName: 'Backpack Exchange 官方帮助中心', sourceUrl: 'https://support.backpack.exchange/exchange/exchange-account/identity-verification/supported-regions',
    regionsZh: '服务地区以官方支持区域及实时合规限制为准。', regionsEn: 'Service areas depend on official supported regions and live compliance restrictions.',
    availabilityZh: '中国大陆资格未在所引支持区域页中明确说明，需在实时注册流程确认。', availabilityEn: 'Mainland China eligibility is not specified on the cited regions page and must be confirmed live.',
    fundingZh: '链上数字资产和获准法币路径按地区开放。', fundingEn: 'On-chain digital assets and approved fiat rails vary by location.', coverColors: ['#E75643', '#171717', '#FFFFFF']
  }),
  cryptoRecord({
    id: 'wirex', name: 'Wirex', provider: 'Wirex', taglineZh: '多币种与加密资产账户 · 非银行账户', taglineEn: 'Multi-currency and crypto-asset account, not a bank account',
    sourceName: 'Wirex 官方帮助中心', sourceUrl: 'https://help.wirexapp.com//article/supported-countries-1189',
    regionsZh: '官方称平台覆盖多个国家/地区，具体服务按居住地变化。', regionsEn: 'Official materials describe coverage across multiple countries and regions; services vary by residence.',
    availabilityZh: '中国大陆具体账户、加密和卡片能力需按实时产品矩阵确认。', availabilityEn: 'Mainland China account, crypto and card features must be confirmed in the live product matrix.',
    fundingZh: '支持的法币、加密资产及卡片入金方式按地区变化。', fundingEn: 'Supported fiat, crypto and card funding methods vary by location.', coverColors: ['#3E3AEE', '#66E5FF', '#FFFFFF'], accountType: 'cryptoIntegratedAccount'
  }),
  cryptoRecord({
    id: 'gnosis-pay', name: 'Gnosis Pay', provider: 'Gnosis Pay', taglineZh: '链上支付账户与卡 · 非银行账户', taglineEn: 'On-chain payment account and card, not a bank account',
    sourceName: 'Gnosis Pay 官方帮助中心', sourceUrl: 'https://help.gnosispay.com/hc/en-us/articles/39401751918612-Eligible-Countries-for-Gnosis-Pay',
    regionsZh: '支付卡面向官方列出的欧洲及拉丁美洲部分合法居民。', regionsEn: 'The payment card is for legal residents of selected countries in Europe and Latin America.',
    availabilityZh: '中国大陆不在当前公开的支付卡支持居住地列表中。', availabilityEn: 'Mainland China is not on the currently published payment-card residence list.',
    fundingZh: '账户与支付卡功能以应用内可用性为准。', fundingEn: 'Account and payment-card features are shown in the app.',
    chinaStatus: 'unavailable', chinaDocumentZh: '中国大陆未在当前支付卡支持居住地列表中', chinaDocumentEn: 'Mainland China is not on the current payment-card residence list', chinaNoteZh: '不要将卡片可用性与其他 Gnosis 产品资格混同。', chinaNoteEn: 'Do not conflate card availability with eligibility for other Gnosis products.', coverColors: ['#0E76FD', '#2A2D3E', '#FFFFFF'], accountType: 'cryptoCard'
  }),
  cryptoRecord({
    id: 'bleap', name: 'Bleap', provider: 'Bleap', taglineZh: '加密资产消费卡与账户 · 非银行账户', taglineEn: 'Crypto spending card and account, not a bank account',
    sourceName: 'Bleap 官方帮助中心', sourceUrl: 'https://help.bleap.finance/en/articles/11088792-am-i-eligible-for-card',
    regionsZh: '支付卡主要面向 EEA 或瑞士居民，且存在国家和国籍限制。', regionsEn: 'The payment card is primarily for EEA or Swiss residents and has country and nationality restrictions.',
    availabilityZh: '中国大陆不在当前卡片居住地范围内。', availabilityEn: 'Mainland China is outside the current card residence scope.',
    fundingZh: '数字资产交易、卡片和账户能力按实时产品和资格开放。', fundingEn: 'Digital-asset trading, card and account capabilities vary by live product and eligibility.',
    chinaStatus: 'unavailable', chinaDocumentZh: '支付卡要求 EEA 或瑞士居住地', chinaDocumentEn: 'The payment card requires EEA or Swiss residence', chinaNoteZh: '产品功能不等同于银行存款或投资建议。', chinaNoteEn: 'Product features are not bank deposits or investment advice.', coverColors: ['#2BF1B7', '#0D1720', '#FFFFFF'], accountType: 'cryptoCard'
  }),
  cryptoRecord({
    id: 'crypto-com', name: 'Crypto.com App', provider: 'Crypto.com', taglineZh: '加密资产应用与消费卡 · 非银行账户', taglineEn: 'Crypto-asset app and spending card, not a bank account',
    sourceName: 'Crypto.com 官方帮助中心', sourceUrl: 'https://help.crypto.com/en/articles/1341655-which-are-the-available-markets',
    regionsZh: '官方称应用服务覆盖 100+ 市场，卡片分阶段按地区推出。', regionsEn: 'Official materials state the app serves 100+ markets and card rollout is staged by region.',
    availabilityZh: '中国大陆资格及可用产品需在应用实时注册流程中确认。', availabilityEn: 'Mainland China eligibility and available products must be confirmed in live app onboarding.',
    fundingZh: '法币、数字资产和卡片能力按地区与账户资格变化。', fundingEn: 'Fiat, digital-asset and card capabilities vary by region and account eligibility.', coverColors: ['#103D7D', '#1476FF', '#FFFFFF']
  })
]

function usage(exitCode = 0) {
  console.log(`Usage: node tools/import_global_accounts.mjs [--dry-run] [--publish] [--only id,id] [--verify-sources] [--overwrite-existing]

Default mode is --dry-run. To write drafts, set CARD_ADMIN_TOKEN. Existing
records are skipped unless --overwrite-existing is explicit. To publish the
same reviewed records, add --publish. CARD_API_BASE_URL defaults to
https://card.lengziyu.cn.`)
  process.exit(exitCode)
}

if (args.has('--help') || args.has('-h')) usage()
if (args.has('--publish') && args.has('--dry-run')) {
  console.error('--publish and --dry-run cannot be used together.')
  process.exit(2)
}

const selected = records.filter((record) => !requestedIds.size || requestedIds.has(record.id))
const missingIds = [...requestedIds].filter((id) => !records.some((record) => record.id === id))
if (missingIds.length) {
  console.error(`Unknown record id(s): ${missingIds.join(', ')}`)
  process.exit(2)
}
if (!selected.length) {
  console.error('No records selected.')
  process.exit(2)
}

async function verifySources() {
  // Some first-party help centres serve their public page to browsers/search,
  // but reject or time out automated requests. Keep those records explicit so
  // a human can verify the page instead of treating the anti-bot response as a
  // broken source.
  const browserOnlySourceIds = new Set([
    'revolut-personal-account',
    'bunq-personal-account',
    'mercury-business-account',
    'qonto-business-account',
    'nubank-account',
    'bitpanda',
    'strike-account',
    'dtcpay',
    'gnosis-pay'
  ])
  let failures = 0
  for (const record of selected) {
    try {
      const response = await fetch(record.sourceUrl, {
        method: 'GET',
        redirect: 'follow',
        headers: { 'user-agent': 'CardHubCatalogVerifier/1.0 (+https://card.lengziyu.cn)' },
        signal: AbortSignal.timeout(20_000)
      })
      if (response.status === 403 && browserOnlySourceIds.has(record.id)) {
        console.log(`MANUAL 403 ${record.id} ${response.url} (official page blocks automated checks)`)
        continue
      }
      console.log(`${response.ok ? 'OK' : 'FAIL'} ${response.status} ${record.id} ${response.url}`)
      if (!response.ok) failures++
    } catch (error) {
      if (browserOnlySourceIds.has(record.id)) {
        console.log(`MANUAL ${record.id} (official page requires browser verification: ${error instanceof Error ? error.message : String(error)})`)
        continue
      }
      failures++
      console.log(`FAIL ${record.id} ${error instanceof Error ? error.message : String(error)}`)
    }
  }
  if (failures) {
    console.error(`${failures} source check(s) failed. Fix or explicitly review them before writing.`)
    process.exit(1)
  }
}

if (args.has('--verify-sources')) await verifySources()

const publish = args.has('--publish')
const adminToken = String(process.env.CARD_ADMIN_TOKEN || '').trim()
const dryRun = args.has('--dry-run') || !adminToken
const recordsToWrite = selected.map((record) => ({
  ...record,
  status: publish ? 'published' : 'draft',
  logoImageSrc: '',
  coverImageSrc: '',
  accountDetails: [],
  relatedCardIds: [],
  verificationStatus: 'needsReview',
  lastVerifiedAt: reviewedOn,
  nextReviewAt,
  createdAt: `${reviewedOn}T00:00:00.000Z`
}))

if (dryRun) {
  console.log(`Dry run: ${recordsToWrite.length} record(s), target status: ${publish ? 'published' : 'draft'}`)
  for (const record of recordsToWrite) console.log(`${record.id}\t${record.accountType}\t${record.sourceUrl}`)
  if (!adminToken) console.log('Set CARD_ADMIN_TOKEN to execute the PUT requests.')
  process.exit(0)
}

const existingResponse = await fetch(`${apiBaseUrl}/api/admin/global-accounts`, {
  headers: { authorization: `Bearer ${adminToken}`, accept: 'application/json' },
  signal: AbortSignal.timeout(30_000)
})
const existingPayload = await existingResponse.json().catch(() => null)
if (!existingResponse.ok || !Array.isArray(existingPayload?.items)) {
  console.error(`Unable to read existing global accounts: HTTP ${existingResponse.status} ${JSON.stringify(existingPayload)}`)
  process.exit(1)
}
const existingIds = new Set(existingPayload.items.map((record) => record?.id).filter(Boolean))
const overwriteExisting = args.has('--overwrite-existing')
const recordsToImport = overwriteExisting
  ? recordsToWrite
  : recordsToWrite.filter((record) => !existingIds.has(record.id))
const skippedExisting = recordsToWrite.filter((record) => existingIds.has(record.id) && !overwriteExisting)
if (skippedExisting.length) console.log(`Skipped existing record(s): ${skippedExisting.map((record) => record.id).join(', ')}. Use --overwrite-existing to refresh them.`)
if (!recordsToImport.length) {
  console.log('Nothing to import.')
  process.exit(0)
}

for (const record of recordsToImport) {
  const response = await fetch(`${apiBaseUrl}/api/admin/global-accounts/${encodeURIComponent(record.id)}`, {
    method: 'PUT',
    headers: { authorization: `Bearer ${adminToken}`, 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify(record),
    signal: AbortSignal.timeout(30_000)
  })
  const body = await response.json().catch(() => null)
  if (!response.ok) {
    console.error(`Failed to import ${record.id}: HTTP ${response.status} ${JSON.stringify(body)}`)
    process.exitCode = 1
    continue
  }
  console.log(`Imported ${body.id} as ${body.status}; verified ${body.lastVerifiedAt || 'not set'}.`)
}

if (process.exitCode) process.exit(process.exitCode)
console.log(`Completed ${recordsToImport.length} record(s). ${publish ? 'Published records are now public.' : 'All records remain drafts for admin review.'}`)

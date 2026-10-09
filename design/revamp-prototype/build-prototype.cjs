const fs = require('node:fs');
const path = require('node:path');
const dir = __dirname;
const root = path.resolve(dir, '../..');
const oldPublic = path.resolve(root, '../card.lengziyu.cn/public');
const readImage = (file) => {
  const ext = path.extname(file).slice(1).replace('jpg', 'jpeg');
  return `data:image/${ext};base64,${fs.readFileSync(file).toString('base64')}`;
};
const image = (name) => readImage(path.join(oldPublic, 'cardentify-cards', name));
const assets = {
  current: readImage('D:/Devs/cache/card-app/market-regions/final-us.png'),
  apple: image('apple-card.webp'),
  chase: image('chase-freedom-flex.webp'),
  za: image('za-card.webp'),
  hsbc: image('hsbc-hk-mastercard-debit.webp'),
  n26: image('n26-mastercard-virtual.webp'),
  boc: readImage(path.join(oldPublic, 'card-art/bank/cn/webp/boc-cn-t20110630-1437947-hq-27c033c635b0.webp')),
  etherfi: readImage(path.join(root, 'assets/cards/etherfi-core.webp')),
  redotpay: readImage(path.join(root, 'assets/cards/redotpay.webp')),
  bybit: readImage(path.join(root, 'assets/cards/bybit.webp')),
};
// Use the matching local artwork when present; the labeled fallback is local.
const boaMatches = fs.readdirSync(path.join(oldPublic, 'cardentify-cards'))
  .filter((name) => /america.*debit|bofa.*debit/i.test(name));
if (boaMatches.length) assets.boa = image(boaMatches[0]);
const template = fs.readFileSync(path.join(dir, 'prototype.template.html'), 'utf8');
fs.writeFileSync(path.join(dir, 'index.html'), template.replace('__PROTOTYPE_ASSETS__', JSON.stringify(assets)), 'utf8');
console.log('Created self-contained prototype: ' + path.join(dir, 'index.html'));

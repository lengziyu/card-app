import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// App-owned icon aliases.
///
/// Keeping Phosphor names here makes the visual language explicit and prevents
/// third-party identifiers from spreading through feature code.
abstract final class AppIcons {
  static const cards = PhosphorIconsRegular.creditCard;
  static const cardsSelected = PhosphorIconsFill.creditCard;

  static const market = PhosphorIconsRegular.storefront;
  static const marketSelected = PhosphorIconsFill.storefront;

  static const ranking = PhosphorIconsRegular.chartLineUp;
  static const rankingSelected = PhosphorIconsFill.chartLineUp;

  static const profile = PhosphorIconsRegular.user;
  static const profileSelected = PhosphorIconsFill.user;

  static const add = PhosphorIconsRegular.plus;
  static const bill = PhosphorIconsRegular.receipt;

  static const homeStack = PhosphorIconsRegular.stack;
  static const homeFocus = PhosphorIconsRegular.frameCorners;
  static const homeWallet = PhosphorIconsRegular.wallet;

  static const compare = PhosphorIconsRegular.arrowsLeftRight;
  static const canvas = PhosphorIconsRegular.circlesFour;
  static const back = PhosphorIconsRegular.arrowLeft;
  static const close = PhosphorIconsRegular.x;
  static const cloudUnavailable = PhosphorIconsRegular.cloudSlash;
  static const swap = PhosphorIconsRegular.swap;
  static const bookmarkAdd = PhosphorIconsRegular.bookmarkSimple;
  static const export = PhosphorIconsRegular.export;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const check = PhosphorIconsRegular.check;
  static const checkCircle = PhosphorIconsRegular.checkCircle;
  static const applePay = PhosphorIconsRegular.appleLogo;
  static const googlePay = PhosphorIconsRegular.googleLogo;
  static const wechatPay = PhosphorIconsRegular.wechatLogo;
  static const alipay = PhosphorIconsRegular.currencyCny;

  static const canvasExitImmersive = PhosphorIconsRegular.cornersIn;
  static const canvasEnterImmersive = PhosphorIconsRegular.cornersOut;
  static const canvasZoomIn = PhosphorIconsRegular.magnifyingGlassPlus;
  static const canvasZoomOut = PhosphorIconsRegular.magnifyingGlassMinus;
  static const canvasReset = PhosphorIconsRegular.arrowsCounterClockwise;
  static const canvasImages = PhosphorIconsRegular.images;
  static const canvasGrid = PhosphorIconsRegular.gridFour;
  static const canvasGallery = PhosphorIconsRegular.squaresFour;
  static const canvasBackground = PhosphorIconsRegular.circleHalfTilt;
  static const canvasCards = PhosphorIconsRegular.cards;
  static const canvasShuffle = PhosphorIconsRegular.shuffle;
  static const canvasPlay = PhosphorIconsRegular.play;
  static const canvasPause = PhosphorIconsRegular.pause;
  static const canvasWalk = PhosphorIconsRegular.personSimpleWalk;
  static const canvasRun = PhosphorIconsRegular.personSimpleRun;
  static const directionNorthWest = PhosphorIconsRegular.arrowUpLeft;
  static const directionNorth = PhosphorIconsRegular.arrowUp;
  static const directionNorthEast = PhosphorIconsRegular.arrowUpRight;
  static const directionWest = PhosphorIconsRegular.arrowLeft;
  static const directionCenter = PhosphorIconsRegular.circle;
  static const directionEast = PhosphorIconsRegular.arrowRight;
  static const directionSouthWest = PhosphorIconsRegular.arrowDownLeft;
  static const directionSouth = PhosphorIconsRegular.arrowDown;
  static const directionSouthEast = PhosphorIconsRegular.arrowDownRight;
}

class AppIconPair {
  const AppIconPair({required this.regular, required this.fill});

  final IconData regular;
  final IconData fill;
}

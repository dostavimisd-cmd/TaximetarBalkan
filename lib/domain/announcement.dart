/// Tekst glasovne najave na kraju vožnje.
class Announcement {
  static String rideFinished(int totalPrice, {String language = 'sr', String? fixedRouteName}) {
    if (language == 'en') {
      return fixedRouteName == null
          ? 'Total: $totalPrice dinars.'
          : 'Fixed fare $fixedRouteName: $totalPrice dinars.';
    }
    return fixedRouteName == null
        ? 'Ukupno $totalPrice ${_dinara(totalPrice)}.'
        : 'Fiksna cena, $fixedRouteName: $totalPrice ${_dinara(totalPrice)}.';
  }

  /// 1, 21, 101 dinar; sve ostalo (i 11) dinara.
  static String _dinara(int n) => n % 10 == 1 && n % 100 != 11 ? 'dinar' : 'dinara';
}

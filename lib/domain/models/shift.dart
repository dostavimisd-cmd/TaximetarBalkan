/// Smena vozača: od "Počni smenu" do "Završi smenu". Vožnje pripadaju smeni
/// po vremenu početka (nema veze u bazi, pa brisanje smene ne dira vožnje).
class Shift {
  final int id;
  final DateTime start; // UTC
  final DateTime? end; // UTC; null = smena je u toku

  const Shift({required this.id, required this.start, this.end});

  bool get isOpen => end == null;

  @override
  bool operator ==(Object other) => other is Shift && other.id == id && other.end == end;

  @override
  int get hashCode => Object.hash(id, end);

  /// Kraj za upit: otvorena smena traje do [now].
  DateTime endOr(DateTime now) => end ?? now;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/earnings_chart.dart';
import '../../domain/models/tariff_schedule.dart';
import '../l10n/tr.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import 'reports_screen.dart';

const _amber = Color(0xFFF3B23A);
const _cost = Color(0xFFD9534F);
const _goal = Color(0xFF6FCF73);
const _grid = Color(0xFF262B33);
const _mute = Color(0xFF8D949E);

/// Grafikon zarade (D3): stubovi zarade i troškova po danu (godina: po
/// mesecu), prosek, dnevni cilj, zbirovi i najbolji sati. Samo čita istoriju.
class EarningsChartScreen extends ConsumerStatefulWidget {
  const EarningsChartScreen({super.key});

  @override
  ConsumerState<EarningsChartScreen> createState() => _EarningsChartScreenState();
}

class _EarningsChartScreenState extends ConsumerState<EarningsChartScreen> {
  ChartRange _range = ChartRange.containing(ChartPeriod.week, DateTime.now());

  static const _periodLabels = {
    ChartPeriod.week: 'Nedelja',
    ChartPeriod.month: 'Mesec',
    ChartPeriod.year: 'Godina',
  };

  static const _previousLabels = {
    ChartPeriod.week: 'Prema prošloj nedelji',
    ChartPeriod.month: 'Prema prošlom mesecu',
    ChartPeriod.year: 'Prema prošloj godini',
  };

  static const _bestLabels = {true: 'Najbolji dan', false: 'Najbolji mesec'};

  static const _perHourLabels = {
    true: 'Po satu rada (smene)',
    false: 'Po satu vožnje',
  };

  void _openDay(ChartBucket b) {
    if (!_range.daily) {
      setState(() => _range = ChartRange.containing(ChartPeriod.month, b.start));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReportsScreen(initialDay: b.start)),
    );
  }

  String _bucketName(Tr t, ChartBucket b) {
    String two(int v) => v.toString().padLeft(2, '0');
    if (!_range.daily) return '${two(b.start.month)}/${b.start.year}';
    final letters = TariffSchedule.letters(english: t.english);
    return '${letters[b.start.weekday - 1]} ${two(b.start.day)}.${two(b.start.month)}.';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final settings = ref.watch(appSettingsProvider).value;
    final data = ref.watch(earningsChartProvider(_range));
    final canNext = !_range.end.isAfter(DateTime.now());
    final goal = (settings?.goalEnabled ?? false) && _range.daily ? settings!.dailyGoal : 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(t('Grafikon zarade'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final p in ChartPeriod.values)
                ChoiceChip(
                  label: Text(t(_periodLabels[p]!)),
                  selected: _range.period == p,
                  onSelected: (_) => setState(
                    () => _range = ChartRange.containing(p, _range.start),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () => setState(() => _range = _range.previous()),
              ),
              Expanded(
                child: Text(
                  _range.describe(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: canNext ? Colors.white70 : Colors.white24,
                ),
                onPressed: canNext ? () => setState(() => _range = _range.next()) : null,
              ),
            ],
          ),
          data.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              t('Greška: {0}', [e]),
              style: const TextStyle(color: Colors.redAccent),
            ),
            data: (c) => _content(t, c, goal),
          ),
        ],
      ),
    );
  }

  Widget _content(Tr t, EarningsChart c, int goal) {
    final best = c.best;
    final change = c.changePercent;
    final km = (c.stats.distanceMeters / 1000).toStringAsFixed(0);
    final tiles = <Widget>[
      _Tile(t('Zarada'), '${c.earned}', color: _amber),
      _Tile(t('Troškovi'), '${c.expenses}'),
      _Tile(t('Ostaje'), '${c.remaining}', color: _amber),
      _Tile(
        t(_bestLabels[_range.daily]!),
        best == null ? '–' : '${_bucketName(t, best)} · ${best.earned}',
      ),
      _Tile(t(_perHourLabels[c.perHourFromShifts]!), t('{0} din/h', [c.perHour])),
      _Tile(
        t(_previousLabels[_range.period]!),
        change == null ? '–' : '${change > 0 ? '+' : ''}$change%',
        color: change == null ? null : (change >= 0 ? _goal : _cost),
      ),
      _Tile(t('Vožnji · km'), '${c.stats.rideCount} · $km km'),
      _Tile(t('Prosek po vožnji'), '${c.stats.averagePerRide}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final perRow = box.maxWidth >= 600 ? 4 : 2;
            final w = (box.maxWidth - 8 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final tile in tiles) SizedBox(width: w, child: tile)],
            );
          },
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _Legend(_amber, t('Zarada')),
            _Legend(_cost, t('Troškovi')),
            _Legend(_mute, t('Prosek po radnom danu')),
            if (goal > 0) _Legend(_goal, t('Dnevni cilj')),
          ],
        ),
        const SizedBox(height: 8),
        if (c.stats.rideCount == 0 && c.expenses == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              t('Nema vožnji u ovom periodu.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          )
        else ...[
          SizedBox(
            height: 240,
            child: LayoutBuilder(
              builder: (context, box) {
                final painter = _BarPainter(
                  c.buckets,
                  labels: _labels(t),
                  average: c.averagePerActiveBucket,
                  goal: goal,
                );
                return GestureDetector(
                  onTapUp: (d) {
                    final i = painter.indexAt(d.localPosition.dx, box.maxWidth);
                    if (i != null && c.buckets[i].rides > 0) _openDay(c.buckets[i]);
                  },
                  child: CustomPaint(size: Size(box.maxWidth, 240), painter: painter),
                );
              },
            ),
          ),
          Text(
            t('Dodir na stub otvara izveštaj tog dana.'),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 22),
          Text(
            t('Najbolji sati (broj vožnji po satu početka)'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 130,
            child: CustomPaint(
              size: const Size(double.infinity, 130),
              painter: _HourPainter(c.ridesByHour, c.bestHour),
            ),
          ),
        ],
      ],
    );
  }

  /// Oznake ispod stubova: dani u nedelji, dani u mesecu (svaki peti) ili meseci.
  List<String> _labels(Tr t) {
    final n = _range.bucketCount;
    switch (_range.period) {
      case ChartPeriod.week:
        return TariffSchedule.letters(english: t.english);
      case ChartPeriod.month:
        return [
          for (var i = 0; i < n; i++) (i == 0 || (i + 1) % 5 == 0) ? '${i + 1}' : '',
        ];
      case ChartPeriod.year:
        return [for (var i = 1; i <= 12; i++) '$i'];
    }
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Tile(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _mute, fontSize: 10, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _mute, fontSize: 12)),
        ],
      );
}

/// Stubovi zarade (žuto) i troškova (crveno), linija proseka i cilja.
class _BarPainter extends CustomPainter {
  final List<ChartBucket> buckets;
  final List<String> labels;
  final int average;
  final int goal;

  _BarPainter(this.buckets, {required this.labels, required this.average, required this.goal});

  static const double _left = 48, _right = 8, _top = 10, _bottom = 22;

  int? indexAt(double dx, double width) {
    final bw = (width - _left - _right) / buckets.length;
    final i = ((dx - _left) / bw).floor();
    return i < 0 || i >= buckets.length ? null : i;
  }

  /// Gornja granica ose: zaokružena naviše na „lep” korak (1, 2, 2.5, 5 × 10^n).
  static (int max, int step) _scale(int top) {
    if (top <= 0) return (1000, 250);
    for (var unit = 1; ; unit *= 10) {
      for (final m in const [10, 20, 25, 50]) {
        final step = unit * m ~/ 10;
        if (step > 0 && step * 4 >= top) return (step * 4, step);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at, {Color color = _mute, double size = 10, TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    var top = goal;
    for (final b in buckets) {
      if (b.earned > top) top = b.earned;
      if (b.expenses > top) top = b.expenses;
    }
    final (max, step) = _scale(top);
    final ih = size.height - _top - _bottom;
    final iw = size.width - _left - _right;
    double y(int v) => _top + ih - v / max * ih;

    final grid = Paint()..color = _grid;
    for (var v = 0; v <= max; v += step) {
      canvas.drawLine(Offset(_left, y(v)), Offset(size.width - _right, y(v)), grid);
      _text(canvas, '$v', Offset(_left - 6, y(v)), align: TextAlign.right);
    }

    final bw = iw / buckets.length;
    final hasCost = buckets.any((b) => b.expenses > 0);
    final barW = hasCost ? bw * 0.36 : bw * 0.6;
    final earnPaint = Paint()..color = _amber;
    final costPaint = Paint()..color = _cost;
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final x = _left + i * bw;
      final x0 = hasCost ? x + bw * 0.12 : x + bw * 0.2;
      if (b.earned > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(x0, y(b.earned), x0 + barW, y(0), const Radius.circular(3)),
          earnPaint,
        );
      }
      if (b.expenses > 0) {
        final x1 = x + bw * 0.52;
        canvas.drawRRect(
          RRect.fromLTRBR(x1, y(b.expenses), x1 + barW, y(0), const Radius.circular(3)),
          costPaint,
        );
      }
      if (i < labels.length && labels[i].isNotEmpty) {
        _text(canvas, labels[i], Offset(x + bw / 2, size.height - _bottom / 2), size: 11);
      }
    }

    if (average > 0) {
      final p = Paint()
        ..color = _mute
        ..strokeWidth = 1;
      for (var x = _left; x < size.width - _right; x += 8) {
        canvas.drawLine(Offset(x, y(average)), Offset(x + 4, y(average)), p);
      }
    }
    if (goal > 0) {
      canvas.drawLine(
        Offset(_left, y(goal)),
        Offset(size.width - _right, y(goal)),
        Paint()
          ..color = _goal
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.buckets != buckets || old.goal != goal || old.average != average;
}

/// Broj vožnji po satu početka; najjači sat je istaknut.
class _HourPainter extends CustomPainter {
  final List<int> hours;
  final int? best;

  _HourPainter(this.hours, this.best);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 4.0, bottom = 18.0, top = 14.0;
    final max = hours.fold(0, (a, b) => a > b ? a : b);
    if (max == 0) return;
    final bw = (size.width - left * 2) / 24;
    final ih = size.height - bottom - top;
    for (var h = 0; h < 24; h++) {
      final x = left + h * bw;
      if (hours[h] > 0) {
        final hgt = hours[h] / max * ih;
        canvas.drawRRect(
          RRect.fromLTRBR(x + bw * 0.15, top + ih - hgt, x + bw * 0.85, top + ih, const Radius.circular(2)),
          Paint()..color = h == best ? _amber : const Color(0xFF5B6470),
        );
        if (h == best) {
          final tp = TextPainter(
            text: TextSpan(text: '${hours[h]}', style: const TextStyle(color: _amber, fontSize: 10)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, top + ih - hgt - tp.height));
        }
      }
      if (h % 3 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${h.toString().padLeft(2, '0')}h',
            style: const TextStyle(color: _mute, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, size.height - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(_HourPainter old) => old.hours != hours || old.best != best;
}

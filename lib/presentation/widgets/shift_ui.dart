import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/shift_expense.dart';
import '../../domain/shift_balance.dart';
import '../l10n/tr.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';

/// Osvežava sve što zavisi od smena (izveštaj, meni, cilj na glavnom ekranu).
void refreshShifts(WidgetRef ref) {
  ref.invalidate(shiftsProvider);
  ref.invalidate(currentShiftProvider);
  ref.invalidate(goalEarnedProvider);
}

/// Ručni početak smene; ako je cilj uključen, vozač ga može promeniti.
Future<void> startShiftFlow(BuildContext context, WidgetRef ref) async {
  final t = ref.read(trProvider);
  final settings = ref.read(appSettingsProvider).value;
  if (settings != null && settings.goalEnabled) {
    final goal = await _askGoal(context, t, settings.dailyGoal);
    if (goal == null) return; // odustao: smena ne počinje
    if (goal != settings.dailyGoal) {
      await ref
          .read(appSettingsProvider.notifier)
          .change((s) => s.copyWith(dailyGoal: goal));
    }
  }
  await ref.read(shiftRepositoryProvider).start(DateTime.now().toUtc());
  refreshShifts(ref);
}

Future<int?> _askGoal(BuildContext context, Tr t, int current) {
  final controller = TextEditingController(text: current > 0 ? '$current' : '');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(t('Cilj za ovu smenu'), style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: t('Cilj zarade (din)'),
          labelStyle: const TextStyle(color: Colors.white54),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('ODUSTANI'), style: const TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () {
            final v = int.tryParse(controller.text.trim()) ?? 0;
            if (v > 0 && v <= AppSettings.maxDailyGoal) Navigator.pop(ctx, v);
          },
          child: Text(t('POČNI SMENU'), style: const TextStyle(color: Colors.amberAccent)),
        ),
      ],
    ),
  );
}

/// Kraj smene: zarada, troškovi (unos) i koliko ostaje; vozač potvrđuje kraj.
Future<void> endShiftFlow(BuildContext context, WidgetRef ref) async {
  final t = ref.read(trProvider);
  final shift = await ref.read(shiftRepositoryProvider).current();
  if (shift == null || !context.mounted) return;
  final end = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(t('Završi smenu'), style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(child: ShiftBalanceCard(shift: shift)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('ODUSTANI'), style: const TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('ZAVRŠI SMENU'), style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (end != true) return;
  await ref.read(shiftRepositoryProvider).end(DateTime.now().toUtc());
  refreshShifts(ref);
}

/// Unos troška smene: predlozi naziva jednim dodirom ili svoj naziv, pa iznos.
Future<void> addExpenseFlow(BuildContext context, WidgetRef ref, int shiftId) async {
  final t = ref.read(trProvider);
  final name = TextEditingController(text: t(ShiftExpense.suggestedNames.first));
  final amount = TextEditingController();
  String? error;
  final expense = await showDialog<ShiftExpense>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void save() {
          final e = ShiftExpense(
            shiftId: shiftId,
            name: name.text.trim(),
            amount: int.tryParse(amount.text.trim()) ?? 0,
          );
          final err = e.validate();
          if (err != null) {
            setState(() => error = err);
            return;
          }
          Navigator.pop(ctx, e);
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(t('Trošak'), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in ShiftExpense.suggestedNames)
                    ChoiceChip(
                      label: Text(t(n)),
                      selected: name.text == t(n),
                      onSelected: (_) => setState(() => name.text = t(n)),
                    ),
                ],
              ),
              TextField(
                controller: name,
                maxLength: ShiftExpense.maxNameLength,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t('Naziv'),
                  labelStyle: const TextStyle(color: Colors.white54),
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t('Iznos (din)'),
                  labelStyle: const TextStyle(color: Colors.white54),
                ),
                onSubmitted: (_) => save(),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    t.message(error!),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('ODUSTANI'), style: const TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: save,
              child: Text(t('SAČUVAJ'), style: const TextStyle(color: Colors.amberAccent)),
            ),
          ],
        );
      },
    ),
  );
  name.dispose();
  amount.dispose();
  if (expense == null) return;
  await ref.read(shiftRepositoryProvider).addExpense(expense, DateTime.now().toUtc());
  ref.invalidate(shiftExpensesProvider(shiftId));
}

/// Zarada | Troškovi | Ostaje, spisak troškova (× briše) i „Dodaj trošak”.
class ShiftBalanceCard extends ConsumerWidget {
  final Shift shift;
  const ShiftBalanceCard({super.key, required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final rides = ref.watch(shiftRidesProvider(shift)).value ?? const [];
    final expenses = ref.watch(shiftExpensesProvider(shift.id)).value ?? const [];
    final b = ShiftBalance.of(rides, expenses);

    Widget cell(String label, int value, Color color) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  t('{0} din', [value]),
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              cell(t('ZARADA'), b.earnings, Colors.white),
              cell(t('TROŠKOVI'), b.expenses, Colors.redAccent),
              cell(t('OSTAJE'), b.remaining, Colors.greenAccent),
            ],
          ),
          if (expenses.isNotEmpty) const Divider(color: Colors.white12, height: 20),
          for (final e in expenses)
            Row(
              children: [
                Expanded(
                  child: Text(e.name, style: const TextStyle(color: Colors.white70)),
                ),
                Text(t('{0} din', [e.amount]), style: const TextStyle(color: Colors.white70)),
                IconButton(
                  tooltip: t('Ukloni'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                  onPressed: () async {
                    await ref.read(shiftRepositoryProvider).deleteExpense(e.id!);
                    ref.invalidate(shiftExpensesProvider(shift.id));
                  },
                ),
              ],
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => addExpenseFlow(context, ref, shift.id),
            icon: const Icon(Icons.add, color: Colors.amberAccent),
            label: Text(t('Dodaj trošak'), style: const TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
  }
}

/// Cilj na glavnom ekranu: „Cilj 4350 / 6000 din” i traka napretka.
class GoalBar extends ConsumerWidget {
  /// Cena vožnje u toku, dodaje se na zaradu (null kad nema vožnje).
  final int? runningPrice;
  const GoalBar({super.key, this.runningPrice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final s = ref.watch(appSettingsProvider).value;
    if (s == null || !s.goalEnabled || s.dailyGoal <= 0) return const SizedBox.shrink();
    final earned = (ref.watch(goalEarnedProvider).value ?? 0) + (runningPrice ?? 0);
    final progress = ShiftBalance.goalProgress(earned, s.dailyGoal) ?? 0;
    final done = earned >= s.dailyGoal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(done ? Icons.emoji_events : Icons.flag,
                  color: done ? Colors.greenAccent : Colors.amberAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  done
                      ? t('Cilj ostvaren: {0} / {1} din', [earned, s.dailyGoal])
                      : t('Cilj: {0} / {1} din', [earned, s.dailyGoal]),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Text('${(progress * 100).round()} %',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: done ? Colors.greenAccent : Colors.amberAccent,
            ),
          ),
        ],
      ),
    );
  }
}

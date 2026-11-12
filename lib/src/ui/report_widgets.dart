import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import '../core/reporting.dart';
import 'shared.dart';

final homeAccountProvider = NotifierProvider<HomeAccount, String?>(
  HomeAccount.new,
);

class HomeAccount extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

Wallet? activeAccount(
  Ledger ledger,
  String? id, {
  bool includeArchived = false,
}) {
  final options = ledger.wallets.where(
    (wallet) => includeArchived || !wallet.archived,
  );
  return options.where((wallet) => wallet.id == id).firstOrNull ??
      options.firstOrNull;
}

Color categoryColor(Ledger ledger, String id) {
  final category = ledger.category(id);
  if (category == null) return Colors.blueGrey;
  final duplicates =
      ledger.categories
          .where((item) => item.color == category.color)
          .map((item) => item.id)
          .toList()
        ..sort();
  final color = Color(category.color);
  final index = duplicates.indexOf(id);
  if (index < 1) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withHue((hsl.hue + index * 39) % 360)
      .withLightness((hsl.lightness + .08).clamp(.30, .61))
      .toColor();
}

class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector(this.value, this.onChanged, {super.key});
  final ReportRange? value;
  final ValueChanged<ReportRange> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      for (final range in ReportRange.values)
        ChoiceChip(
          label: Text(range.code),
          tooltip: range.label,
          selected: value == range,
          showCheckmark: false,
          onSelected: (_) => onChanged(range),
        ),
    ],
  );
}

class ReportSection extends StatelessWidget {
  const ReportSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.onMore,
    this.moreLabel = 'Show More',
    super.key,
  });
  final String title, moreLabel;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ?action,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
        if (onMore != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onMore,
              label: Text(moreLabel),
              icon: const Icon(Icons.arrow_forward, size: 17),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ],
    ),
  );
}

typedef ReportSlice = ({String id, String name, int value, Color color});
typedef ReportPoint = ({DateTime date, int value});

class SpendingDonut extends StatelessWidget {
  const SpendingDonut({
    required this.slices,
    required this.currency,
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final List<ReportSlice> slices;
  final String currency;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const EmptyPanel(
        Icons.donut_large,
        'No expenses in this range',
        'Recorded expenses will appear here.',
      );
    }
    final active = slices.where((slice) => slice.id == selected).firstOrNull;
    final total = slices.fold(0, (sum, slice) => sum + slice.value);
    void select(String id) => onSelect(selected == id ? null : id);
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 230,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    centerSpaceRadius: 62,
                    sectionsSpace: 3,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent) return;
                        final index =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        if (index >= 0 && index < slices.length) {
                          select(slices[index].id);
                        }
                      },
                    ),
                    sections: [
                      for (final slice in slices)
                        PieChartSectionData(
                          showTitle: false,
                          value: slice.value.toDouble(),
                          radius: active?.id == slice.id ? 33 : 23,
                          color: active == null || active.id == slice.id
                              ? slice.color
                              : slice.color.withValues(alpha: .40),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 122,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        active?.name ?? 'All',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          money(active?.value ?? total, currency),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 4,
          children: [
            for (final slice in slices)
              FilterChip(
                avatar: Icon(Icons.circle, color: slice.color, size: 12),
                label: Text(slice.name),
                tooltip: money(slice.value, currency),
                selected: active?.id == slice.id,
                showCheckmark: false,
                onSelected: (_) => select(slice.id),
              ),
          ],
        ),
        if (active != null)
          TextButton(
            onPressed: () => onSelect(null),
            child: const Text('Clear selection'),
          ),
      ],
    );
  }
}

class TrendChart extends StatelessWidget {
  const TrendChart(
    this.points,
    this.currency, {
    super.key,
    this.label = 'No history in this range',
  });
  final List<ReportPoint> points;
  final String currency, label;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return EmptyPanel(
        Icons.show_chart,
        label,
        'Choose an account or a different range.',
      );
    }
    final color = Theme.of(context).colorScheme.primary;
    final format = DateFormat.MMMd();
    final factor = fractionDigits(currency) == 0 ? 1 : 100;
    final low = points
        .map((point) => point.value)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    final high = points
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final margin = (high - low == 0
        ? (high.abs() * .08 + factor)
        : (high - low) * .12);
    return SizedBox(
      height: 196,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: points.length <= 1 ? 1 : (points.length - 1).toDouble(),
          minY: low - margin,
          maxY: high + margin,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${format.format(points[spot.spotIndex].date)}\n${money(points[spot.spotIndex].value, currency)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 49,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, _) => Text(
                  NumberFormat.compact(locale: 'en').format(value / factor),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 29,
                interval: (points.length / 4).ceilToDouble().clamp(1, 100),
                maxIncluded: false,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  return index >= 0 && index < points.length
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            format.format(points[index].date),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              color: color,
              barWidth: 2.5,
              spots: [
                for (final (index, point) in points.indexed)
                  FlSpot(index.toDouble(), point.value.toDouble()),
              ],
              dotData: FlDotData(show: points.length < 2),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: .10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<ReportSlice> categorySlices(Ledger ledger, Iterable<Entry> entries) {
  final groups = <String, int>{};
  for (final entry in entries) {
    final key = entry.categoryId ?? '';
    groups.update(
      key,
      (amount) => amount + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
  return [
    for (final group in groups.entries)
      (
        id: group.key,
        name: ledger.category(group.key)?.name ?? 'Uncategorized',
        value: group.value,
        color: categoryColor(ledger, group.key),
      ),
  ]..sort((a, b) => b.value.compareTo(a.value));
}

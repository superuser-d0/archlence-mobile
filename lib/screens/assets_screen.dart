import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../widgets/summary_row.dart';
import '../widgets/surfaces.dart';

/// Portfolio: distribution, income/expense trend, savings goals and holdings.
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  static const _periods = ['Today', '1 Week', '1 Month', '1 Year', 'All Time'];
  int _period = 3;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final inset = MediaQuery.paddingOf(context);

    return ListView(
      key: const PageStorageKey('assets'),
      padding: EdgeInsets.only(
        top: inset.top + Spacing.stackMd,
        bottom: inset.bottom + Spacing.stackLg,
      ),
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.containerMargin),
          child: const SummaryRow(
            stats: [
              SummaryStat(
                label: 'Income',
                value: '₺1.634.902,60',
                tone: SummaryTone.positive,
              ),
              SummaryStat(
                label: 'Expense',
                value: '₺1.397.034,10',
                tone: SummaryTone.negative,
              ),
              SummaryStat(
                label: 'Net Balance',
                value: '+₺237.868,50',
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackLg),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.containerMargin),
          child: Text('Details', style: text.titleLarge),
        ),
        const SizedBox(height: Spacing.stackMd),

        // Five period chips genuinely do not fit at 412dp, so this row really
        // does scroll — unlike the summary figures above, no single chip is
        // information the user must not miss.
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.containerMargin,
            ),
            itemCount: _periods.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _PeriodChip(
              label: _periods[i],
              selected: i == _period,
              onTap: () => setState(() => _period = i),
            ),
          ),
        ),
        const SizedBox(height: Spacing.stackLg),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.containerMargin),
          child: const _DistributionCard(),
        ),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.containerMargin),
          child: const _TrendCard(),
        ),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.containerMargin),
          child: const _TotalAssetsCard(),
        ),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.containerMargin),
          child: const _EmergencyFundCard(),
        ),
        const SizedBox(height: Spacing.sectionGap),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.containerMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up, size: 20,
                      color: ObsidianPalette.tertiary),
                  const SizedBox(width: Spacing.stackSm),
                  Expanded(
                    child: Text('My Active Assets', style: text.titleLarge),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add,
                        color: ObsidianPalette.primary),
                  ),
                ],
              ),
              Text(
                'Last updated: 23:00',
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.stackMd),
              const _HoldingTile(
                symbol: '€',
                name: 'Euro (EURTRY=X)',
                purchase: 'Purchase: 37.8000 ₺ × 400',
                current: '47.3000 ₺',
                up: true,
              ),
              const SizedBox(height: Spacing.stackMd),
              const _HoldingTile(
                symbol: '\$',
                name: 'US Dollar (USDTRY=X)',
                purchase: 'Purchase: 40.1000 ₺ × 250',
                current: '39.6000 ₺',
                up: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected
              ? ObsidianPalette.primaryContainer
              : ObsidianPalette.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: ObsidianPalette.cardStroke),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 0,
                color: selected
                    ? ObsidianPalette.onPrimary
                    : ObsidianPalette.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _Slice {
  const _Slice(this.label, this.percent, this.color);
  final String label;
  final double percent;
  final Color color;
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard();

  static const _slices = <_Slice>[
    _Slice('Primary Income', 45.1, Color(0xFF4EDEA3)),
    _Slice('Additional Income', 3.2, Color(0xFF00885D)),
    _Slice('Opening Balance', 10.5, Color(0xFFC0C1FF)),
    _Slice('Essential Expenses', 29.2, Color(0xFFFFB4AB)),
    _Slice('Discretionary Expenses', 12.1, Color(0xFFD0BCFF)),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 58,
                    startDegreeOffset: -90,
                    sections: [
                      for (final slice in _slices)
                        PieChartSectionData(
                          value: slice.percent,
                          color: slice.color,
                          radius: 26,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Asset', style: text.titleLarge),
                    Text(
                      'Distribution',
                      style: text.labelMedium?.copyWith(
                        letterSpacing: 0,
                        color: ObsidianPalette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.stackMd),
          for (final slice in _slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.stackSm),
                  Expanded(
                    child: Text(
                      slice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  Text(
                    '%${slice.percent.toStringAsFixed(1)}',
                    style: text.bodySmall
                        ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard();

  static const _income = <double>[
    95, 88, 92, 80, 60, 55, 65, 70, 58, 62, 60, 60,
  ];
  static const _expense = <double>[
    70, 65, 90, 95, 78, 100, 105, 85, 60, 95, 110, 60,
  ];
  static const _months = ['Sep\'25', 'Jan\'26', 'May\'26', 'Aug\'26'];

  List<FlSpot> _spots(List<double> values) => [
        // The source series is "distance below the top", so invert it into
        // a value that rises with the figure it represents.
        for (var i = 0; i < values.length; i++)
          FlSpot(i.toDouble(), 120 - values[i]),
      ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LegendDot(
                  color: ObsidianPalette.tertiary, label: 'Income'),
              const SizedBox(width: Spacing.stackMd),
              _LegendDot(color: ObsidianPalette.error, label: 'Expense'),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 120,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 30,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: ObsidianPalette.surfaceContainerHigh,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots(_income),
                    color: ObsidianPalette.tertiary,
                    barWidth: 2,
                    isCurved: true,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color:
                          ObsidianPalette.tertiary.withValues(alpha: 0.12),
                    ),
                  ),
                  LineChartBarData(
                    spots: _spots(_expense),
                    color: ObsidianPalette.error,
                    barWidth: 2,
                    isCurved: true,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final month in _months)
                Text(
                  month,
                  style: text.labelMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 2, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 0,
                color: ObsidianPalette.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _TotalAssetsCard extends StatelessWidget {
  const _TotalAssetsCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Total Assets',
            style: text.bodySmall
                ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '₺526.011,80',
                    maxLines: 1,
                    style: text.headlineLarge,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.stackSm),
              const Icon(Icons.visibility_outlined, size: 18),
            ],
          ),
          const SizedBox(height: Spacing.stackSm),
          const TrendChip(
            label: '+₺7.858,53 (+1.52%) Today',
            positive: true,
          ),
        ],
      ),
    );
  }
}

class _EmergencyFundCard extends StatelessWidget {
  const _EmergencyFundCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, size: 20,
                  color: ObsidianPalette.tertiary),
              const SizedBox(width: Spacing.stackSm),
              Expanded(
                child: Text('Emergency Fund', style: text.titleLarge),
              ),
              Text(
                '%74',
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ObsidianPalette.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: const LinearProgressIndicator(
              value: 0.74,
              minHeight: 6,
              backgroundColor: ObsidianPalette.surfaceContainerHigh,
              valueColor:
                  AlwaysStoppedAnimation(ObsidianPalette.tertiary),
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Text(
            'At the current pace, ~4 months left',
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.stackMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _Amount(label: 'Saved', value: '₺260.000,00'),
              ),
              const Expanded(
                child: _Amount(
                  label: 'Target',
                  value: '₺350.000,00',
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          GradientButton(label: 'Save', onPressed: () {}),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({
    required this.symbol,
    required this.name,
    required this.purchase,
    required this.current,
    required this.up,
  });

  final String symbol;
  final String name;
  final String purchase;
  final String current;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = up ? ObsidianPalette.tertiary : ObsidianPalette.error;
    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              symbol,
              style: text.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700, color: tone),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  purchase,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.stackSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Current',
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                current,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

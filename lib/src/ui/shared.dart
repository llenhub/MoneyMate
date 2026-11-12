import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../core/models.dart';

const ink = Color(0xff123d33);
const mint = Color(0xffd8f1e5);
const icons = <String, IconData>{
  'wallet': Icons.account_balance_wallet_outlined,
  'cash': Icons.payments_outlined,
  'card': Icons.credit_card_outlined,
  'bank': Icons.account_balance_outlined,
  'phone': Icons.phone_android,
  'category': Icons.sell_outlined,
  'income': Icons.south_west,
  'food': Icons.restaurant_outlined,
  'home': Icons.home_outlined,
  'travel': Icons.flight_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'gift': Icons.card_giftcard,
};

IconData namedIcon(String name) => icons[name] ?? Icons.circle_outlined;

String money(int value, String currency) {
  final parts = decimalMoney(value.abs(), currency).split('.');
  final whole = NumberFormat.decimalPattern('en').format(int.parse(parts[0]));
  final fraction = parts.length == 2 ? '.${parts[1]}' : '';
  return '${value < 0 ? '−' : ''}$currency $whole$fraction';
}

String dateLabel(DateTime date, String format) =>
    DateFormat(format).format(date.toLocal());
String titleCase(String value) => value[0].toUpperCase() + value.substring(1);

void showProblem(BuildContext context, Object error) {
  final message = error is FormatException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) showProblem(context, error);
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<T?> editDialog<T>(BuildContext context, String title, Widget child) =>
    showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
  });

  final String title, subtitle;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 100),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1230),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(18),
  });
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(
    this.icon,
    this.title,
    this.detail, {
    super.key,
    this.action,
  });
  final IconData icon;
  final String title, detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({super.key, required this.children, this.minWidth = 250});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maximum = children.length.clamp(1, 4);
        final count = ((constraints.maxWidth + 14) / (minWidth + 14))
            .floor()
            .clamp(1, maximum);
        final width = (constraints.maxWidth - (count - 1) * 14) / count;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class Choice<T> extends StatelessWidget {
  const Choice(this.label, this.value, this.items, this.onChanged, {super.key});
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: items.containsKey(value) ? value : null,
        isExpanded: true,
        isDense: true,
        items: [
          for (final item in items.entries)
            DropdownMenuItem(
              value: item.key,
              child: Text(item.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (selected) {
                if (selected != null) onChanged!(selected);
              },
      ),
    ),
  );
}

Widget formFields(List<Widget> fields) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final (i, field) in fields.indexed) ...[
      if (i > 0) const SizedBox(height: 14),
      field,
    ],
  ],
);

class AppearanceFields extends StatelessWidget {
  const AppearanceFields(
    this.color,
    this.icon,
    this.onColor,
    this.onIcon, {
    super.key,
  });
  final int color;
  final String icon;
  final ValueChanged<int> onColor;
  final ValueChanged<String> onIcon;

  @override
  Widget build(BuildContext context) => formFields([
    Choice('Icon', icon, {
      for (final name in icons.keys) name: titleCase(name),
    }, onIcon),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (index, shade) in palette.indexed)
          Semantics(
            selected: shade == color,
            child: IconButton.filled(
              tooltip: [
                'Forest',
                'Blue',
                'Plum',
                'Terracotta',
                'Teal',
                'Ochre',
              ][index],
              onPressed: () => onColor(shade),
              style: IconButton.styleFrom(
                backgroundColor: Color(shade),
                foregroundColor: Colors.white,
              ),
              icon: Icon(shade == color ? Icons.check : Icons.circle, size: 15),
            ),
          ),
      ],
    ),
  ]);
}

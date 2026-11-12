import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider).requireValue;
    final ledger = state.ledger;
    final balances = Analytics(ledger).balances();
    void edit([Wallet? wallet]) => editDialog<void>(
      context,
      wallet == null ? 'New wallet' : 'Edit wallet',
      _WalletForm(state, wallet: wallet),
    );
    return PageBody(
      title: 'Wallets',
      subtitle: 'Manage the places you keep and spend money.',
      action: FilledButton.icon(
        onPressed: edit,
        icon: const Icon(Icons.add),
        label: const Text('New wallet'),
      ),
      children: [
        if (ledger.wallets.isEmpty)
          Panel(
            child: EmptyPanel(
              Icons.account_balance_wallet_outlined,
              'No wallets yet',
              'Create a wallet to start tracking income, spending, and transfers.',
              action: TextButton(
                onPressed: edit,
                child: const Text('Create a wallet'),
              ),
            ),
          ),
        AdaptiveGrid(
          children: [
            for (final wallet in ledger.wallets)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(wallet.color),
                          foregroundColor: Colors.white,
                          child: Icon(namedIcon(wallet.icon)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            wallet.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            final controller = ref.read(
                              financeProvider.notifier,
                            );
                            if (action == 'edit') {
                              edit(wallet);
                              return;
                            }
                            if (action == 'delete' &&
                                !await confirm(
                                  context,
                                  'Delete wallet?',
                                  'Wallets with transaction history must be archived.',
                                  'Delete',
                                )) {
                              return;
                            }
                            if (!context.mounted) return;
                            await runAction(
                              context,
                              () => controller.change((data) {
                                if (action == 'delete') {
                                  return data.copy(
                                    wallets: data.wallets.where(
                                      (w) => w.id != wallet.id,
                                    ),
                                  );
                                }
                                return data.copy(
                                  wallets: [
                                    for (final w in data.wallets)
                                      if (w.id != wallet.id)
                                        w
                                      else
                                        Wallet(
                                          w.id,
                                          w.name,
                                          w.type,
                                          w.currency,
                                          w.opening,
                                          w.color,
                                          w.icon,
                                          w.created,
                                          archived: !w.archived,
                                          limit: w.limit,
                                        ),
                                  ],
                                );
                              }, expectedDemo: state.preferences.demo),
                            );
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(
                                wallet.archived ? 'Unarchive' : 'Archive',
                              ),
                            ),
                            if (!ledger.entries.any(
                              (e) =>
                                  e.walletId == wallet.id ||
                                  e.destinationId == wallet.id,
                            ))
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${wallet.type.label}${wallet.archived ? ' · Archived' : ''}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(
                        wallet.type == WalletType.credit
                            ? -(balances[wallet.id]!)
                            : balances[wallet.id]!,
                        wallet.currency,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (wallet.type == WalletType.credit)
                      Text(
                        '${balances[wallet.id]! > 0 ? 'Credit on account shown as negative debt' : 'Outstanding debt'}'
                        '${wallet.limit == null ? '' : ' · Limit ${money(wallet.limit!, wallet.currency)}'}',
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WalletForm extends ConsumerStatefulWidget {
  const _WalletForm(this.state, {this.wallet});
  final FinanceState state;
  final Wallet? wallet;

  @override
  ConsumerState<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends ConsumerState<_WalletForm> {
  late final _name = TextEditingController(text: widget.wallet?.name);
  late final _opening = TextEditingController(
    text: widget.wallet == null
        ? '0'
        : decimalMoney(widget.wallet!.opening.abs(), widget.wallet!.currency),
  );
  late final _limit = TextEditingController(
    text: widget.wallet?.limit == null
        ? ''
        : decimalMoney(widget.wallet!.limit!, widget.wallet!.currency),
  );
  late var _negativeOpening =
      widget.wallet != null &&
      (widget.wallet!.type == WalletType.credit
          ? widget.wallet!.opening > 0
          : widget.wallet!.opening < 0);
  late var _currency =
      widget.wallet?.currency ?? widget.state.preferences.currency;
  late var _type = widget.wallet?.type ?? WalletType.cash;
  late var _icon = widget.wallet?.icon ?? 'wallet';
  late var _color = widget.wallet?.color ?? palette.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final opening = parseMoney(_opening.text, _currency);
    final limit = _type == WalletType.credit && _limit.text.trim().isNotEmpty
        ? parseMoney(_limit.text, _currency)
        : null;
    if (_name.text.trim().isEmpty ||
        opening == null ||
        opening < 0 ||
        (_type == WalletType.credit &&
            _limit.text.trim().isNotEmpty &&
            (limit == null || limit <= 0))) {
      setState(() => _error = 'Enter a name and valid amounts for $_currency.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final previous = widget.wallet;
    final sign =
        (_type == WalletType.credit ? -1 : 1) * (_negativeOpening ? -1 : 1);
    final wallet = Wallet(
      previous?.id ?? newId(),
      _name.text.trim(),
      _type,
      _currency,
      sign * opening,
      _color,
      _icon,
      previous?.created ?? DateTime.now().toUtc(),
      archived: previous?.archived ?? false,
      limit: limit,
    );
    try {
      await ref
          .read(financeProvider.notifier)
          .change(
            (data) => data.copy(
              wallets: [
                for (final item in data.wallets)
                  if (item.id == wallet.id) wallet else item,
                if (previous == null) wallet,
              ],
            ),
            expectedDemo: widget.state.preferences.demo,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.state.ledger.entries.any(
      (e) =>
          widget.wallet != null &&
          (e.walletId == widget.wallet!.id ||
              e.destinationId == widget.wallet!.id),
    );
    return formFields([
      TextField(
        controller: _name,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      Choice<WalletType>('Wallet type', _type, {
        for (final type in WalletType.values) type: type.label,
      }, history ? null : (value) => setState(() => _type = value)),
      Choice<String>('Currency', _currency, {
        for (final currency in currencies) currency: currency,
      }, history ? null : (value) => setState(() => _currency = value)),
      TextField(
        controller: _opening,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: _type == WalletType.credit
              ? 'Opening debt or credit'
              : 'Opening balance',
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          _type == WalletType.credit
              ? 'Opening amount is a credit'
              : 'Negative opening balance',
        ),
        value: _negativeOpening,
        onChanged: (value) => setState(() => _negativeOpening = value),
      ),
      if (_type == WalletType.credit)
        TextField(
          controller: _limit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Credit limit (optional)',
          ),
        ),
      AppearanceFields(
        _color,
        _icon,
        (color) => setState(() => _color = color),
        (icon) => setState(() => _icon = icon),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save wallet'),
      ),
    ]);
  }
}

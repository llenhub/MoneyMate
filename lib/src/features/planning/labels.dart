import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';

Future<String?> editLabel(
  BuildContext context,
  bool demo, {
  LedgerLabel? label,
}) => editDialog<String>(
  context,
  label == null ? 'Create label' : 'Edit label',
  _LabelEditor(demo, label),
);

Future<Set<String>?> pickLabels(
  BuildContext context,
  Set<String> initial, {
  bool single = false,
}) => editDialog<Set<String>>(context, 'Labels', _LabelPicker(initial, single));

class _LabelPicker extends ConsumerStatefulWidget {
  const _LabelPicker(this.initial, this.single);
  final Set<String> initial;
  final bool single;
  @override
  ConsumerState<_LabelPicker> createState() => _LabelPickerState();
}

class _LabelPickerState extends ConsumerState<_LabelPicker> {
  late final _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider).requireValue;
    final labels = finance.ledger.labels;
    return formFields([
      if (labels.isEmpty)
        const Text('Create a label to organize your records.'),
      Wrap(
        spacing: 7,
        runSpacing: 4,
        children: [
          for (final label in labels)
            FilterChip(
              avatar: Icon(
                namedIcon(label.icon),
                size: 16,
                color: Color(label.color),
              ),
              label: Text(label.name),
              selected: _selected.contains(label.id),
              onSelected: (selected) => setState(() {
                if (widget.single) _selected.clear();
                if (selected) {
                  _selected.add(label.id);
                } else {
                  _selected.remove(label.id);
                }
              }),
            ),
        ],
      ),
      TextButton.icon(
        onPressed: () async {
          final id = await editLabel(context, finance.preferences.demo);
          if (id != null && mounted) {
            setState(() {
              if (widget.single) _selected.clear();
              _selected.add(id);
            });
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create label'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _selected.intersection(labels.map((item) => item.id).toSet()),
        ),
        child: const Text('Apply labels'),
      ),
    ]);
  }
}

class _LabelEditor extends ConsumerStatefulWidget {
  const _LabelEditor(this.demo, this.label);
  final bool demo;
  final LedgerLabel? label;
  @override
  ConsumerState<_LabelEditor> createState() => _LabelEditorState();
}

class _LabelEditorState extends ConsumerState<_LabelEditor> {
  late final _name = TextEditingController(text: widget.label?.name);
  late var _color = widget.label?.color ?? palette.first;
  late var _icon = widget.label?.icon ?? 'category';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => formFields([
    TextField(
      controller: _name,
      maxLength: 50,
      decoration: const InputDecoration(labelText: 'Label name'),
    ),
    AppearanceFields(
      _color,
      _icon,
      (value) => setState(() => _color = value),
      (value) => setState(() => _icon = value),
    ),
    if (_error != null)
      Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    FilledButton(
      onPressed: _busy ? null : _save,
      child: const Text('Save label'),
    ),
  ]);

  Future<void> _save() async {
    final original = widget.label;
    final label = LedgerLabel(
      original?.id ?? newId(),
      _name.text.trim(),
      _color,
      _icon,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(financeProvider.notifier)
          .change(
            (ledger) => ledger.copy(
              labels: [
                for (final item in ledger.labels)
                  item.id == label.id ? label : item,
                if (original == null) label,
              ],
            ),
            expectedDemo: widget.demo,
          );
      if (mounted) Navigator.pop(context, label.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is FormatException ? error.message : error.toString();
        });
      }
    }
  }
}

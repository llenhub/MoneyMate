import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/editor_page.dart';
import '../../ui/shared.dart';

Future<void> createGoal(BuildContext context, Preferences preferences) =>
    openEditorPage<void>(context, _GoalSelection(preferences));

Future<void> editGoal(
  BuildContext context,
  Preferences preferences,
  SavingsGoal goal,
) => openEditorPage<bool>(
  context,
  _GoalEditor(preferences, goal.name, goal.color, goal.icon, original: goal),
);

const _ideas = [
  ('New Vehicle', 'car'),
  ('New Home', 'home'),
  ('Holiday Trip', 'travel'),
  ('Education', 'school'),
  ('Emergency Fund', 'shield'),
  ('Health Care', 'health'),
  ('Party', 'party'),
  ('Kids', 'gift'),
  ('Other', 'flag'),
];

class _GoalSelection extends StatefulWidget {
  const _GoalSelection(this.preferences);
  final Preferences preferences;
  @override
  State<_GoalSelection> createState() => _GoalSelectionState();
}

class _GoalSelectionState extends State<_GoalSelection> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue(String name, String icon, int color) async {
    final done = await openEditorPage<bool>(
      context,
      _GoalEditor(widget.preferences, name, color, icon),
    );
    if (done == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => EditorPage(
    title: 'New Goal',
    children: [
      Text(
        'What are you saving for?',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      TextField(
        controller: _name,
        maxLength: 60,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Your goal’s name',
        ),
        onChanged: (_) => setState(() {}),
      ),
      FilledButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => _continue(_name.text.trim(), 'flag', palette.first),
        child: const Text('Create Goal'),
      ),
      const SizedBox(height: 10),
      Text(
        'Some things people save for',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.65,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (index, (title, icon)) in _ideas.indexed)
            OutlinedButton(
              onPressed: () =>
                  _continue(title, icon, palette[index % palette.length]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Color(palette[index % palette.length]),
                    foregroundColor: Colors.white,
                    child: Icon(namedIcon(icon)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor(
    this.preferences,
    this.name,
    this.color,
    this.icon, {
    this.original,
  });
  final Preferences preferences;
  final String name, icon;
  final int color;
  final SavingsGoal? original;
  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  late var _currency = widget.original?.currency ?? widget.preferences.currency;
  late var _icon = widget.icon;
  late var _color = widget.color;
  late var _date = widget.original?.due;
  late final _name = TextEditingController(text: widget.name);
  late final _target = TextEditingController(
    text: widget.original == null
        ? ''
        : decimalMoney(widget.original!.target, widget.original!.currency),
  );
  late final _saved = TextEditingController(
    text: widget.original == null
        ? ''
        : decimalMoney(widget.original!.saved, widget.original!.currency),
  );
  late final _note = TextEditingController(text: widget.original?.note);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditorPage(
    title: widget.original == null ? 'New Goal' : 'Edit Goal',
    onSave: _save,
    busy: _busy,
    error: _error,
    children: [
      TextField(
        controller: _name,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      Choice('Currency', _currency, {
        for (final code in currencies) code: code,
      }, (value) => setState(() => _currency = value)),
      TextField(
        controller: _target,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Target amount'),
      ),
      TextField(
        controller: _saved,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Saved already'),
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _date == null
                  ? 'Desired date'
                  : dateLabel(_date!, widget.preferences.dateFormat),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (date != null && mounted) setState(() => _date = date);
            },
          ),
          if (_date != null)
            TextButton(
              onPressed: () => setState(() => _date = null),
              child: const Text('Clear date'),
            ),
        ],
      ),
      AppearanceFields(
        _color,
        _icon,
        (value) => setState(() => _color = value),
        (value) => setState(() => _icon = value),
      ),
      TextField(
        controller: _note,
        maxLength: 800,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note (optional)'),
      ),
    ],
  );

  Future<void> _save() async {
    final target = parseMoney(_target.text, _currency);
    final saved = _saved.text.trim().isEmpty
        ? 0
        : parseMoney(_saved.text, _currency);
    if (_name.text.trim().isEmpty ||
        target == null ||
        target <= 0 ||
        saved == null ||
        saved < 0) {
      setState(
        () => _error = 'Enter a name, positive target, and valid saved amount.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final previous = widget.original;
    final goal = SavingsGoal(
      previous?.id ?? newId(),
      _name.text.trim(),
      _currency,
      target,
      saved,
      _color,
      _icon,
      due: _date,
      note: _note.text.trim(),
    );
    try {
      await ref
          .read(financeProvider.notifier)
          .change(
            (data) => data.copy(
              goals: [
                for (final item in data.goals) item.id == goal.id ? goal : item,
                if (previous == null) goal,
              ],
            ),
            expectedDemo: widget.preferences.demo,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }
}

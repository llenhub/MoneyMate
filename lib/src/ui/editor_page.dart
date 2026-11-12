import 'package:material_ui/material_ui.dart';

Future<T?> openEditorPage<T>(BuildContext context, Widget page) => Navigator.of(
  context,
).push(MaterialPageRoute<T>(fullscreenDialog: true, builder: (_) => page));

class EditorPage extends StatelessWidget {
  const EditorPage({
    required this.title,
    required this.children,
    this.onSave,
    this.busy = false,
    this.error,
    this.floatingActionButton,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool busy;
  final String? error;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: floatingActionButton,
    appBar: AppBar(
      centerTitle: true,
      title: Text(title),
      leading: IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close),
        onPressed: busy ? null : () => Navigator.pop(context),
      ),
      actions: [
        if (busy)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (onSave != null)
          IconButton(
            tooltip: 'Save',
            onPressed: onSave,
            icon: const Icon(Icons.check),
          ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: child,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

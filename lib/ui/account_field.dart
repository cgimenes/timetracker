import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/derived.dart';

/// Text field that suggests accounts, best (by frecency) first.
class AccountField extends ConsumerWidget {
  const AccountField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          final all = ref.read(accountSuggestionsProvider);
          final matches = query.isEmpty
              ? all
              : all.where((a) => a.toLowerCase().contains(query));
          // Hide the list once the text is exactly one suggestion.
          return matches.where((a) => a != value.text).take(8);
        },
        onSelected: (account) => onChanged(account),
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
            TextField(
              key: const Key('account'),
              controller: controller,
              focusNode: focusNode,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Account',
                hintText: 'work:project:task',
                border: const OutlineInputBorder(),
                errorText: errorText,
              ),
              onChanged: onChanged,
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: constraints.maxWidth,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

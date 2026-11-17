import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation.dart';
import '../../state/clock.dart';
import '../../state/derived.dart';
import '../account_field.dart';
import '../date_time_fields.dart';
import '../ui_actions.dart';

/// Form to start an entry.
class AddEntryCard extends ConsumerStatefulWidget {
  const AddEntryCard({super.key});

  @override
  ConsumerState<AddEntryCard> createState() => _AddEntryCardState();
}

class _AddEntryCardState extends ConsumerState<AddEntryCard> {
  final _account = TextEditingController();
  final _accountFocus = FocusNode();

  /// The date and time are open: the play button starts at that moment.
  var _expanded = false;
  DateTime? _moment;
  String? _momentError;

  @override
  void initState() {
    super.initState();
    // Follow the last closed entry, unless the user is editing the field.
    ref.listenManual(lastAccountProvider, (_, last) {
      if (last != null && !_accountFocus.hasFocus && _account.text != last) {
        _account.text = last;
        if (mounted) setState(() {});
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _account.dispose();
    _accountFocus.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider)();

  /// Problem with the account, if any.
  String? _error() =>
      validateEntry(account: _account.text.trim(), start: _now, now: _now);

  /// Account valid and, when the date and time are open, a valid moment.
  bool get _canStart =>
      _error() == null && (!_expanded || _momentError == null);

  /// Starts now, or at the date and time when they are open.
  Future<void> _start() async {
    if (!_canStart) return;
    // Close the keyboard (and the suggestions) right away.
    FocusManager.instance.primaryFocus?.unfocus();
    final account = _account.text.trim();
    final start = _expanded ? _moment : null;
    final started = await startEntry(context, ref, account, start ?? _now);
    if (started && mounted) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error();
    final accountText = _account.text.trim();
    final showError = error != null && accountText.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AccountField(
                    controller: _account,
                    focusNode: _accountFocus,
                    errorText: showError ? error : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Level with the 56 dp field, whatever the error line does.
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(
                    key: const Key('start'),
                    tooltip: 'Start now',
                    iconSize: 28,
                    onPressed: _canStart ? _start : null,
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
              ],
            ),
            // Just a chevron, centered under the field: it opens the date and
            // time options.
            Center(
              child: IconButton(
                key: const Key('start-at'),
                tooltip: 'Start at...',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 28),
                  fixedSize: const Size(40, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() {
                  _expanded = !_expanded;
                  _moment = null;
                  _momentError = null;
                }),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: DateTimeFields(
                        key: const Key('start-at-fields'),
                        initial: _now,
                        first: DateTime(_now.year - 2),
                        last: DateTime(_now.year, _now.month, _now.day),
                        notAfter: _now,
                        onChanged: (moment, error) => setState(() {
                          _moment = moment;
                          _momentError = error;
                        }),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

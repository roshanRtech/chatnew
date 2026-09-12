import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HiddenIdFormatter extends TextInputFormatter {

  final mentionPattern = RegExp(r'@\w+\s*----userId>.*?<userId----');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (oldValue.text.length > newValue.text.length) {
      final cursorPos = oldValue.selection.baseOffset;

      for (final match in mentionPattern.allMatches(oldValue.text)) {
        if (cursorPos > match.start && cursorPos <= match.end) {
          final newText = oldValue.text.replaceRange(match.start, match.end, '');
          return TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: match.start),
          );
        }
      }
    }

    return newValue;
  }
}


class HiddenTextController extends TextEditingController {
  HiddenTextController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final hiddenPattern = RegExp(r'----userId>.*?<userId----');
    final text = this.text;

    final spans = <TextSpan>[];
    int start = 0;

    for (final match in hiddenPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: style,
        ));
      }

      // Skip rendering hidden id (empty span)
      spans.add(const TextSpan(text: ''));

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    return TextSpan(style: style, children: spans);
  }
}
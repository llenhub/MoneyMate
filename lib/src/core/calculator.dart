import 'models.dart';

/// Evaluates decimal literals using exact fractions, rounding once to minor units.
int evaluateAmount(String input, String currency) {
  if (input.isEmpty || input.length > 80) {
    throw const FormatException('Enter a valid amount.');
  }
  final negativeStart = input.startsWith('-') || input.startsWith('−');
  final expression = negativeStart ? input.substring(1) : input;
  final tokens = RegExp(
    r'(?:\d+(?:\.\d*)?|\.\d+)|[+−×÷-]',
  ).allMatches(expression).map((match) => match.group(0)!).toList();
  if (tokens.join() != expression || tokens.length.isEven) {
    throw const FormatException('Complete the calculation first.');
  }
  var sum = (BigInt.zero, BigInt.one);
  var term = (BigInt.zero, BigInt.one);
  var op = negativeStart ? '-' : '+';
  for (var index = 0; index < tokens.length; index += 2) {
    final token = tokens[index];
    if (!token.contains(RegExp(r'\d'))) {
      throw const FormatException('Invalid calculation.');
    }
    final parts = token.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final value = (
      BigInt.parse(parts.join()),
      BigInt.from(10).pow(fraction.length),
    );
    switch (op) {
      case '×':
        term = (term.$1 * value.$1, term.$2 * value.$2);
      case '÷':
        if (value.$1 == BigInt.zero) {
          throw const FormatException('Cannot divide by zero.');
        }
        term = (term.$1 * value.$2, term.$2 * value.$1);
      default:
        sum = _add(sum, term);
        term = (op == '+' ? value.$1 : -value.$1, value.$2);
    }
    if (index + 1 < tokens.length) {
      op = tokens[index + 1];
      if (!'+−×÷-'.contains(op) || op.length != 1) {
        throw const FormatException('Invalid calculation.');
      }
    }
  }
  final result = _add(sum, term);
  final scaled =
      result.$1.abs() * BigInt.from(10).pow(fractionDigits(currency));
  final rounded = (scaled * BigInt.two + result.$2) ~/ (result.$2 * BigInt.two);
  if (rounded > BigInt.from(maxMinor)) {
    throw const FormatException('Amount is too large.');
  }
  return result.$1.isNegative ? -rounded.toInt() : rounded.toInt();
}

(BigInt, BigInt) _add((BigInt, BigInt) a, (BigInt, BigInt) b) =>
    (a.$1 * b.$2 + b.$1 * a.$2, a.$2 * b.$2);

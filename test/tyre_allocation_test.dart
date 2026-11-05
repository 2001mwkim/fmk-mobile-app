import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/services/tyre_allocation_service.dart';

void main() {
  test('parses /tyres.json and drops malformed entries', () {
    final parsed = parseTyreAllocations({
      'races': {
        'brazil-2026': {'hard': 'C3', 'medium': 'C4', 'soft': 'C5'},
        'qatar-2026': {'hard': 'C1', 'medium': 'C2'},
        'bad-2026': {'hard': 'hard', 'medium': 'C2', 'soft': 'C3'},
      },
    });
    expect(parsed.keys, ['brazil-2026']);
    expect(parsed['brazil-2026']!.soft, 'C5');
    expect(parseTyreAllocations('nope'), isEmpty);
    expect(parseTyreAllocations({'races': []}), isEmpty);
  });
}

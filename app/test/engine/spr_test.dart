import 'package:flutter_test/flutter_test.dart';
import 'package:moduleup/engine/spr.dart';

void main() {
  test('official examples for 2/3', () {
    for (final ok in ['2/3', '.6666', '.6667', '0.666', '0.667']) {
      expect(gradeSpr(ok, ['2/3']), isTrue, reason: ok);
    }
    for (final bad in ['0.66', '.66', '0.67', '.67']) {
      expect(gradeSpr(bad, ['2/3']), isFalse, reason: bad);
    }
  });

  test('official examples for -1/3', () {
    for (final ok in ['-1/3', '-.3333', '-0.333']) {
      expect(gradeSpr(ok, ['-1/3']), isTrue, reason: ok);
    }
    for (final bad in ['-.33', '-0.33']) {
      expect(gradeSpr(bad, ['-1/3']), isFalse, reason: bad);
    }
  });

  test('equivalent forms and multiple accepted answers', () {
    expect(gradeSpr('3.50', ['7/2']), isTrue);
    expect(gradeSpr('7/2', ['3.5']), isTrue);
    expect(gradeSpr('14/4', ['7/2']), isTrue);
    expect(gradeSpr('5', ['-3', '5']), isTrue);
    expect(gradeSpr('-3', ['-3', '5']), isTrue);
    expect(gradeSpr('4', ['-3', '5']), isFalse);
  });

  test('format rules', () {
    expect(sprWellFormed('3 1/2'), isFalse);
    expect(sprWellFormed('12%'), isFalse);
    expect(sprWellFormed('1,000'), isFalse);
    expect(sprWellFormed('123456'), isFalse);
    expect(sprWellFormed('-12345'), isTrue);
    expect(gradeSpr('', ['1']), isFalse);
    expect(gradeSpr(null, ['1']), isFalse);
  });
}

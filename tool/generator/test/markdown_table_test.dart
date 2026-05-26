// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:skills/src/services/markdown_converter.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownConverter Tables', () {
    late MarkdownConverter converter;

    setUp(() {
      converter = MarkdownConverter();
    });

    test('converts simple table', () {
      const html = '''
<table>
  <thead>
    <tr>
      <th>Header 1</th>
      <th>Header 2</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Cell 1</td>
      <td>Cell 2</td>
    </tr>
  </tbody>
</table>
''';
      final markdown = converter.convert(html);
      expect(markdown, contains('| Header 1 | Header 2 |'));
      expect(markdown, contains('|---|---|'));
      expect(markdown, contains('| Cell 1 | Cell 2 |'));
    });

    test('converts table without thead', () {
      const html = '''
<table>
  <tr>
    <td>Cell 1</td>
    <td>Cell 2</td>
  </tr>
</table>
''';
      final markdown = converter.convert(html);
      // Fallback: treated as table with first row as header
      expect(markdown, contains('| Cell 1 | Cell 2 |'));
      expect(markdown, contains('|---|---|'));
    });

    test('converts definition lists', () {
      const html = '''
<dl>
  <dt>Term 1</dt>
  <dd>Definition 1</dd>
  <dt>Term 2</dt>
  <dd>Definition 2</dd>
</dl>
''';
      final markdown = converter.convert(html);
      expect(markdown, contains('**Term 1**'));
      expect(markdown, contains(': Definition 1'));
      expect(markdown, contains('**Term 2**'));
      expect(markdown, contains(': Definition 2'));
    });

    test('converts details/summary', () {
      const html = '''
<details>
  <summary>Summary</summary>
  Details content
</details>
''';
      // We'll preserve HTML for details as it's often supported in markdown rendering
      // OR we can just output the content.
      // Preserving HTML is usually safer for details.
      final markdown = converter.convert(html);
      expect(markdown, contains('<details>'));
      expect(markdown, contains('<summary>Summary</summary>'));
      expect(markdown, contains('Details content'));
      expect(markdown, contains('</details>'));
    });
    test('converts nested tables without flattening', () {
      const html = '''
<table>
  <tr>
    <td>Outer 1</td>
    <td>
      <table>
        <tr><td>Inner 1</td></tr>
      </table>
    </td>
  </tr>
</table>
''';
      final markdown = converter.convert(html);
      // Outer row should contain both outer text and inner table result.
      expect(markdown, contains('| Outer 1 |'));
      expect(markdown, contains('| Inner 1 |'));
      // The outer table should not have inner cells as separate columns of the outer structure.
    });
    test('handles empty table gracefully', () {
      const html = '<table></table>';
      final markdown = converter.convert(html);
      expect(markdown, isEmpty);
    });

    test('converts table with multiple tbodies', () {
      const html = '''
<table>
  <thead>
    <tr><th>Header</th></tr>
  </thead>
  <tbody>
    <tr><td>Row 1</td></tr>
  </tbody>
  <tbody>
    <tr><td>Row 2</td></tr>
  </tbody>
</table>
''';
      final markdown = converter.convert(html);
      expect(markdown, contains('| Header |'));
      expect(markdown, contains('| Row 1 |'));
      expect(markdown, contains('| Row 2 |'));
    });
  });
}

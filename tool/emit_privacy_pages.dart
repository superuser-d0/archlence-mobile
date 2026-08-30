/// Generates the published privacy pages from the app's own copy of the text.
///
/// Google Play wants the policy reachable from the store listing AND from
/// inside the app, and treats a policy that says something untrue as a policy
/// violation. Two hand-maintained copies is the arrangement that produces
/// exactly that, so there is one source — `lib/legal/privacy_policy.dart` —
/// the app renders it, and this writes the web copies.
///
///     dart run tool/emit_privacy_pages.dart
///
/// `test/privacy_pages_test.dart` runs the same generation in memory and
/// fails if what is committed differs, so a change to the text that is not
/// regenerated cannot be merged.
library;

import 'dart:io';

import 'package:archlence_mobile/legal/privacy_policy.dart';

void main(List<String> args) {
  final root = Directory.current.path;
  for (final (policy, filename) in [
    (privacyPolicyEn, 'privacy.html'),
    (privacyPolicyTr, 'gizlilik.html'),
  ]) {
    final file = File('$root/docs/$filename');
    file.writeAsStringSync(renderPolicyPage(policy));
    stdout.writeln('wrote docs/$filename (${file.lengthSync()} bytes)');
  }
}

/// `**bold**` and nothing else, with everything else HTML-escaped first.
///
/// One markup rule, because two renderers have to agree on it and every rule
/// added is a rule they can disagree about.
String inline(String source) {
  final escaped = source
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return escaped.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*', dotAll: true),
    (m) => '<strong>${m[1]}</strong>',
  );
}

String _blocks(List<PolicyBlock> blocks) {
  final out = StringBuffer();
  for (final block in blocks) {
    switch (block) {
      case PolicyParagraph(:final text):
        out.writeln('<p>${inline(text)}</p>');
      case PolicyBullets(:final items):
        out.writeln('<ul>');
        for (final item in items) {
          out.writeln('  <li>${inline(item)}</li>');
        }
        out.writeln('</ul>');
      case PolicyTable(:final headers, :final rows):
        out.writeln('<div class="table-wrap">');
        out.writeln('<table>');
        out.writeln('  <thead><tr>');
        for (final header in headers) {
          out.writeln('    <th>${inline(header)}</th>');
        }
        out.writeln('  </tr></thead>');
        out.writeln('  <tbody>');
        for (final row in rows) {
          out.writeln('    <tr>');
          for (final cell in row) {
            out.writeln('      <td>${inline(cell)}</td>');
          }
          out.writeln('    </tr>');
        }
        out.writeln('  </tbody>');
        out.writeln('</table>');
        out.writeln('</div>');
    }
  }
  return out.toString().trimRight();
}

/// The whole page, self-contained: no external stylesheet, no font host, no
/// script. A privacy policy that phones somewhere to render itself would be
/// making the reader's point for them.
String renderPolicyPage(PrivacyPolicy policy) {
  final other = policy.languageCode == 'en'
      ? '<a href="gizlilik.html" hreflang="tr">Türkçe</a>'
      : '<a href="privacy.html" hreflang="en">English</a>';
  final footer = policy.languageCode == 'en'
      ? 'Archlence for Android · Apache License 2.0 · Generated from '
            'lib/legal/privacy_policy.dart, which is also what the app itself '
            'displays.'
      : 'Android için Archlence · Apache License 2.0 · '
            'lib/legal/privacy_policy.dart dosyasından üretilmiştir; '
            'uygulamanın kendi içinde gösterdiği metin de aynı dosyadan '
            'gelir.';

  final sections = StringBuffer();
  for (final section in policy.sections) {
    sections.writeln('<h2>${inline(section.title)}</h2>');
    sections.writeln(_blocks(section.blocks));
  }

  return '''
<!DOCTYPE html>
<html lang="${policy.languageCode}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${inline(policy.title)}</title>
<meta name="description" content="${inline(policy.summary).replaceAll(RegExp(r'<[^>]+>'), '').split('.').first}.">
<style>
  :root {
    --ground: #F3F3F8;
    --raised: #FFFFFF;
    --hairline: #DCDCE6;
    --ink: #17171F;
    --ink-muted: #55545F;
    --ink-faint: #7C7B88;
    --accent: #494BD6;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --ground: #131313;
      --raised: #1C1B1B;
      --hairline: #2A2A2A;
      --ink: #E5E2E1;
      --ink-muted: #C7C4D7;
      --ink-faint: #908FA0;
      --accent: #C0C1FF;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--ground);
    color: var(--ink);
    font: 16px/1.65 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    -webkit-text-size-adjust: 100%;
  }
  main { max-width: 44rem; margin: 0 auto; padding: 3rem 1.25rem 5rem; }
  h1 { font-size: clamp(1.9rem, 5vw, 2.5rem); line-height: 1.15; margin: 0 0 .5rem; letter-spacing: -.02em; }
  .subtitle { color: var(--ink-faint); font-size: .9rem; margin: 0 0 .4rem; }
  .langs { font-size: .9rem; margin: 0 0 2rem; }
  h2 { font-size: 1.25rem; margin: 2.6rem 0 .6rem; letter-spacing: -.01em; padding-top: 1.4rem; border-top: 1px solid var(--hairline); }
  p, li { color: var(--ink-muted); }
  strong { color: var(--ink); }
  a { color: var(--accent); }
  ul { padding-left: 1.2rem; }
  li { margin: .4rem 0; }
  .lede {
    background: var(--raised);
    border: 1px solid var(--hairline);
    border-left: 4px solid var(--accent);
    border-radius: 10px;
    padding: 1.1rem 1.2rem;
    margin: 0 0 1rem;
  }
  .lede p { margin: 0; }
  .table-wrap { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; min-width: 30rem; font-size: .94rem; margin: 1rem 0; }
  th, td { text-align: left; padding: .55rem .8rem .55rem 0; border-bottom: 1px solid var(--hairline); vertical-align: top; color: var(--ink-muted); }
  th { color: var(--ink); font-size: .8rem; text-transform: uppercase; letter-spacing: .06em; }
  footer { margin-top: 3rem; padding-top: 1.2rem; border-top: 1px solid var(--hairline); color: var(--ink-faint); font-size: .88rem; }
</style>
</head>
<body>
<main>

<h1>${inline(policy.title)}</h1>
<p class="subtitle">${inline(policy.subtitle)}</p>
<p class="langs">$other</p>

<div class="lede">
  <p>${inline(policy.summary)}</p>
</div>

${sections.toString().trimRight()}

<footer>
  ${inline(footer)}
</footer>

</main>
</body>
</html>
''';
}

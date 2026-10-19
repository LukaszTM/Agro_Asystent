"""Składa stronę pakietu testera (jeden plik HTML) z docs/dla-testerow/*.md.

Użycie: python3 tools/dla_testerow/zbuduj_strone.py — wynik w dane/wynik/
pakiet-testera.html, do opublikowania jako strona dla testerów."""
import html, json, re, sys
from pathlib import Path

ZRODLO = Path(__file__).resolve().parents[2] / 'docs' / 'dla-testerow'
WYJSCIE = Path(__file__).resolve().parents[2] / 'dane' / 'wynik' / 'pakiet-testera.html'

def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'(https?://[^\s<)]+)', r'<a href="\1">\1</a>', t)
    return t

def md_do_html(tekst, od_naglowka=2):
    """Minimalny Markdown: nagłówki, akapity, listy, cytaty, kod, tabele."""
    out, i = [], 0
    linie = tekst.split('\n')
    para = []
    def flush():
        nonlocal para
        if para:
            out.append('<p>' + inline(' '.join(s.strip() for s in para)) + '</p>')
            para = []
    while i < len(linie):
        l = linie[i]
        if l.startswith('```'):
            flush(); blok = []; i += 1
            while i < len(linie) and not linie[i].startswith('```'):
                blok.append(linie[i]); i += 1
            out.append('<pre class="kod">' + html.escape('\n'.join(blok)) + '</pre>'); i += 1; continue
        m = re.match(r'^(#{1,4})\s+(.*)', l)
        if m:
            flush(); poziom = len(m.group(1)) + od_naglowka - 1
            out.append(f'<h{poziom}>{inline(m.group(2))}</h{poziom}>'); i += 1; continue
        if l.startswith('|'):
            flush(); wiersze = []
            while i < len(linie) and linie[i].startswith('|'):
                wiersze.append([c.strip() for c in linie[i].strip().strip('|').split('|')]); i += 1
            wiersze = [w for w in wiersze if not all(re.fullmatch(r'-+', c or '-') for c in w)]
            if wiersze:
                out.append('<div class="tabela-wrap"><table><thead><tr>' + ''.join(f'<th>{inline(c)}</th>' for c in wiersze[0]) + '</tr></thead><tbody>'
                           + ''.join('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in w) + '</tr>' for w in wiersze[1:]) + '</tbody></table></div>')
            continue
        if l.startswith('>'):
            flush(); cyt = []
            while i < len(linie) and linie[i].startswith('>'):
                cyt.append(linie[i][1:].strip()); i += 1
            out.append('<blockquote>' + md_do_html('\n'.join(cyt), od_naglowka) + '</blockquote>'); continue
        m = re.match(r'^(\s*)([-*]|\d+\.)\s+(.*)', l)
        if m:
            flush(); typ = 'ol' if m.group(2)[0].isdigit() else 'ul'; elementy = []
            while i < len(linie):
                m2 = re.match(r'^(\s*)([-*]|\d+\.)\s+(.*)', linie[i])
                if m2 and len(m2.group(1)) == len(m.group(1)):
                    elementy.append(m2.group(3)); i += 1
                elif linie[i].startswith('  ') and elementy and linie[i].strip():
                    elementy[-1] += ' ' + linie[i].strip(); i += 1
                else:
                    break
            out.append(f'<{typ}>' + ''.join(f'<li>{inline(e)}</li>' for e in elementy) + f'</{typ}>'); continue
        if not l.strip():
            flush(); i += 1; continue
        para.append(l); i += 1
    flush()
    return '\n'.join(out)

def plan(nazwa_pliku, klucz):
    """Plan testów: nagłówek z polami, grupy z wierszami TAK/NIE."""
    tekst = (ZRODLO / nazwa_pliku).read_text(encoding='utf-8')
    tytul = re.search(r'^# (.*)', tekst, re.M).group(1)
    grupy, pola, koncowe = [], [], []
    biezaca = None
    for l in tekst.split('\n'):
        m = re.match(r'^## (.*)', l)
        if m:
            biezaca = {'tytul': m.group(1), 'wiersze': []}; grupy.append(biezaca); continue
        if l.startswith('|') and biezaca is not None:
            kom = [c.strip() for c in l.strip().strip('|').split('|')]
            if kom[0] in ('Nr', '---') or all(re.fullmatch(r'-+', c or '-') for c in kom):
                continue
            if len(kom) >= 3:
                nr = kom[0].replace('★', '').strip()
                biezaca['wiersze'].append({'nr': nr, 'wazny': '★' in kom[0], 'co': kom[1], 'oczekiwane': kom[2],
                                           'uwaga': kom[4] if len(kom) > 4 and kom[4] else ''})
        m = re.match(r'^\d+\. (.*)', l)
        if m and biezaca and biezaca['tytul'].startswith('Na koniec'):
            koncowe.append(re.sub(r'\s*…+.*$', '', m.group(1)))
    grupy = [g for g in grupy if g['wiersze']]
    if klucz == 'telefon':
        pola = [('tester', 'Imię (albo pseudonim)'), ('model', 'Model telefonu'), ('system', 'Wersja Androida'),
                ('wersja', 'Wersja aplikacji (z Ustawień)'), ('wyglad', 'Wygląd: Prosty / Nowoczesny'), ('data', 'Data')]
    else:
        pola = [('tester', 'Imię (albo pseudonim)'), ('system', 'Windows 10 / 11'),
                ('wersja', 'Wersja programu (Ustawienia → O programie)'), ('data', 'Data')]
    razem = sum(len(g['wiersze']) for g in grupy)
    h = [f'<h2>{inline(tytul)}</h2>',
         '<p class="prowadzenie">Zakreśl <b>TAK</b>, gdy stało się to, co w „Co powinno się stać"; <b>NIE</b>, gdy coś innego — wtedy dopisz jednym zdaniem co; <b>–</b>, gdy punkt pominąłeś. Punkty z gwiazdką są najważniejsze. Wyniki zapisują się w tej przeglądarce; na końcu naciśnij <b>Skopiuj wyniki</b> i wklej tekst w wiadomości.</p>',
         f'<div class="postep" id="postep-{klucz}" aria-live="polite"></div>',
         '<div class="pola-testera">']
    for k, etyk in pola:
        h.append(f'<label>{etyk}<input type="text" id="pole-{klucz}-{k}" data-plan="{klucz}" data-pole="{k}" autocomplete="off"></label>')
    h.append('</div>')
    for g in grupy:
        h.append(f'<h3>{inline(g["tytul"])}</h3>')
        for w in g['wiersze']:
            rid = f'{klucz}-{w["nr"]}'
            gw = ' wazny' if w['wazny'] else ''
            h.append(f'''<article class="przypadek{gw}" id="p-{rid}" data-plan="{klucz}" data-nr="{w['nr']}">
  <div class="p-naglowek"><span class="nr">{inline(w['nr'])}</span>{'<span class="gwiazdka" title="najważniejszy">★</span>' if w['wazny'] else ''}
    <div class="p-tresc"><p class="co"><span class="etykieta">Co zrobić</span>{inline(w['co'])}</p>
    <p class="oczekiwane"><span class="etykieta">Co powinno się stać</span>{inline(w['oczekiwane'])}</p></div></div>
  <div class="p-wynik" role="group" aria-label="Wynik {w['nr']}">
    <button type="button" class="w tak" data-w="TAK">TAK</button>
    <button type="button" class="w nie" data-w="NIE">NIE</button>
    <button type="button" class="w pom" data-w="–">pominąłem</button>
  </div>
  <textarea class="uwagi" id="u-{rid}" rows="1" placeholder="Uwagi{(': ' + w['uwaga']) if w['uwaga'] else ' (co się stało, co było niejasne)'}"></textarea>
</article>''')
    if koncowe:
        h.append('<h3>Na koniec</h3>')
        for n, pyt in enumerate(koncowe, 1):
            h.append(f'<label class="pyt">{inline(pyt)}<textarea id="k-{klucz}-{n}" data-plan="{klucz}" data-koncowe="{n}" rows="2"></textarea></label>')
    h.append(f'''<div class="dzialania">
  <button type="button" class="glowny" data-kopiuj="{klucz}">Skopiuj wyniki</button>
  <button type="button" class="drugi" data-wyczysc="{klucz}">Wyczyść wszystko</button>
  <span class="potwierdz" id="potwierdz-{klucz}" hidden>Na pewno? <button type="button" data-wyczysc-tak="{klucz}">Tak, wyczyść</button> <button type="button" data-wyczysc-nie="{klucz}">Zostaw</button></span>
</div>
<p class="info" id="info-{klucz}" aria-live="polite"></p>
<textarea class="zapas" id="zapas-{klucz}" rows="8" hidden aria-label="Wyniki do skopiowania"></textarea>''')
    dane = {'tytul': tytul, 'razem': razem, 'pola': [k for k, _ in pola], 'koncowe': koncowe}
    return '\n'.join(h), dane

sekcje = {}
sekcje['start'] = md_do_html((ZRODLO / '00-czytaj-najpierw.md').read_text(encoding='utf-8'), 1)
sekcje['telefon'] = md_do_html((ZRODLO / '01-telefon-instalacja-i-obsluga.md').read_text(encoding='utf-8'), 1)
sekcje['komputer'] = md_do_html((ZRODLO / '02-komputer-instalacja-i-obsluga.md').read_text(encoding='utf-8'), 1)
sekcje['zgloszenie'] = md_do_html((ZRODLO / '05-zgloszenie-bledu.md').read_text(encoding='utf-8'), 1)
plan_t, dane_t = plan('03-plan-testow-telefon.md', 'telefon')
plan_k, dane_k = plan('04-plan-testow-komputer.md', 'komputer')
# W sekcji „start" tabela plików odsyła do zakładek strony.
sekcje['start'] = sekcje['start'].replace('<h1>Mój Łan — pakiet dla testera (beta 1)</h1>', '<h1>Czytaj najpierw</h1>')
for nazwa, kotw in [('01-telefon-instalacja-i-obsluga.md', 'telefon'), ('02-komputer-instalacja-i-obsluga.md', 'komputer'),
                    ('03-plan-testow-telefon.md', 'testy-telefon'), ('04-plan-testow-komputer.md', 'testy-komputer'),
                    ('05-zgloszenie-bledu.md', 'zgloszenie')]:
    sekcje['start'] = sekcje['start'].replace(f'<code>{nazwa}</code>', f'<a href="#{kotw}" data-zakladka="{kotw}">{nazwa.split("-", 1)[1].rsplit(".", 1)[0].replace("-", " ")}</a>')
for k in ('telefon', 'komputer', 'zgloszenie'):
    sekcje[k] = re.sub(r'<h1>(.*?)</h1>', r'<h1>\1</h1>', sekcje[k])

szablon = Path(__file__).with_name('szablon.html').read_text(encoding='utf-8')
strona = (szablon.replace('{{START}}', sekcje['start']).replace('{{TELEFON}}', sekcje['telefon'])
          .replace('{{KOMPUTER}}', sekcje['komputer']).replace('{{ZGLOSZENIE}}', sekcje['zgloszenie'])
          .replace('{{PLAN_TELEFON}}', plan_t).replace('{{PLAN_KOMPUTER}}', plan_k)
          .replace('{{DANE}}', json.dumps({'telefon': dane_t, 'komputer': dane_k}, ensure_ascii=False)))
WYJSCIE.write_text(strona, encoding='utf-8')
print(f'{WYJSCIE} {len(strona)//1024} KB, przypadków: {dane_t["razem"]} + {dane_k["razem"]}')

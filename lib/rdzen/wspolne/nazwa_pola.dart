import 'package:flutter/material.dart';

/// Zmiana własnej nazwy pola — to samo okno we wszystkich trzech wyglądach.
///
/// Pola wczytane z wniosku nazywają się „Pole A", „Pole B1". Rolnik mówi
/// o nich inaczej („Za stodołą", „Pod lasem") i nie każdy pamięta
/// oznaczenia z wniosku. Oznaczenie zostaje w danych — pokazujemy je tu
/// pomocniczo, żeby było widać, które pole z wniosku rolnik właśnie
/// nazywa po swojemu.
///
/// Zwraca nową nazwę albo `null`, gdy rolnik się rozmyślił.
class OknoNazwyPola extends StatefulWidget {
  const OknoNazwyPola({
    super.key,
    required this.nazwa,
    this.oznaczenieZWniosku,
  });

  final String nazwa;

  /// Oznaczenie z wniosku o dopłaty — `null`, gdy pole dodano ręcznie.
  final String? oznaczenieZWniosku;

  @override
  State<OknoNazwyPola> createState() => _OknoNazwyPolaState();
}

class _OknoNazwyPolaState extends State<OknoNazwyPola> {
  late final TextEditingController _nazwa = TextEditingController(
    text: widget.nazwa,
  );

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

  void _zapisz() {
    final nowa = _nazwa.text.trim();
    if (nowa.isEmpty) {
      return;
    }
    Navigator.of(context).pop(nowa);
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Nazwa pola'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nazwij pole tak, jak o nim mówisz. Oznaczenie z wniosku '
            'zostanie w danych — na wydruku dla ARiMR wyjdzie jedno '
            'i drugie.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nazwa,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: teksty.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Własna nazwa',
              hintText: 'np. Za stodołą',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _zapisz(),
          ),
          if (widget.oznaczenieZWniosku case final String oznaczenie) ...[
            const SizedBox(height: 8),
            Text('We wniosku: $oznaczenie', style: teksty.bodyMedium),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zostaw'),
        ),
        FilledButton(
          onPressed: _nazwa.text.trim().isEmpty ? null : _zapisz,
          child: const Text('Zapisz nazwę'),
        ),
      ],
    );
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as baza_stref;
import 'package:timezone/timezone.dart' as strefy;

import '../funkcje/terminy/przypomnienia.dart';

/// Przypomnienia przez powiadomienia systemowe.
///
/// Planujemy je w trybie niedokładnym: system może je pokazać kwadrans
/// później, za to nie musimy prosić o pozwolenie na dokładne budziki,
/// którego sklepy pilnują (a terminy rolnicze liczy się w dniach).
class PrzypomnieniaUrzadzenia implements UslugaPrzypomnien {
  PrzypomnieniaUrzadzenia({FlutterLocalNotificationsPlugin? wtyczka})
    : _wtyczka = wtyczka ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _wtyczka;
  bool _gotowe = false;

  static const String _kanal = 'terminy';
  static const String _nazwaKanalu = 'Terminy i przypomnienia';
  static const String _opisKanalu =
      'Przypomnienia o terminach z przepisów i o końcu karencji.';

  Future<void> _przygotuj() async {
    if (_gotowe) {
      return;
    }
    baza_stref.initializeTimeZones();
    // Bez strefy urządzenia przypomnienie o 7:00 odezwałoby się o innej
    // godzinie — `timezone` domyślnie stoi na czasie uniwersalnym.
    try {
      final strefa = await FlutterTimezone.getLocalTimezone();
      strefy.setLocalLocation(strefy.getLocation(strefa.identifier));
    } on Exception {
      // Zostaje czas uniwersalny; przypomnienie odezwie się z przesunięciem,
      // ale odezwie się — to lepsze niż brak przypomnienia.
    }

    await _wtyczka.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _gotowe = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _wtyczka
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> czyWolno() async {
    await _przygotuj();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> popros() async {
    await _przygotuj();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> zaplanuj(List<Przypomnienie> przypomnienia) async {
    await _przygotuj();
    await _wtyczka.cancelAll();

    for (final przypomnienie in przypomnienia) {
      await _wtyczka.zonedSchedule(
        id: przypomnienie.id,
        title: przypomnienie.tytul,
        body: przypomnienie.tresc,
        scheduledDate: strefy.TZDateTime.from(
          przypomnienie.kiedy,
          strefy.local,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _kanal,
            _nazwaKanalu,
            channelDescription: _opisKanalu,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> wylacz() async {
    await _przygotuj();
    await _wtyczka.cancelAll();
  }
}

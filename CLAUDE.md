# Instrukcije za Claude Code
- **Stack:** Flutter (Dart), Riverpod, sqflite.
- **Pravilo 1:** PRE svake izmene obavezno pročitaj `ARCHITECTURE.md` i `DATA_MODEL.md`. Posle većih izmena ažuriraj `ARCHITECTURE.md`.
- **Pravilo 2:** Novac se uvek računa u celim brojevima (int). Vreme u UTC milisekundama.
- **Pravilo 3:** NE izmišljaj zakone, cene ni tarife. Sve tarife korisnik unosi sam.
- **Pravilo 4:** `FareCalculator` ne sme imati zavisnosti od UI-a ili Flutter frameworka.
- **Komande:** Za testiranje koristi `flutter test`. Za proveru koda `flutter analyze`.
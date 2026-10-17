# Arhitektura Projekta

## Principi
- **Clean Architecture (pragmatična):** Slojevi `data`, `domain`, `presentation`.
- **State Management:** Riverpod (za reaktivno osvežavanje UI-a bez seckanja).
- **Core Logika:** `FareCalculator` je čista Dart klasa u `domain` sloju. Ne zna za UI ni za bazu. Pokrivena 100% unit testovima.

## Glavni Moduli
1. **GPS Engine (Foreground Service):** Sluša lokaciju i drži Android WakeLock. Odbacuje tačke sa lošom tačnošću (>15m).
2. **Obračun Cene (FareCalculator):** Ako je brzina < 8 km/h, računa vreme čekanja umesto distance.
3. **Lokalna Baza (sqflite):** Offline-first pristup. Vožnja se periodično upisuje u `ride_snapshots` tabelu.

## Tok Podataka
GPS Senzor -> Foreground Service -> Odbacivanje šuma -> FareCalculator -> Ažuriranje Riverpod State-a -> UI Prikaz & sqflite backup.

## Rizici i Tehnički Dug
- **Rizik 1 (Baterija):** Android agresivno gasi servise (Xiaomi, Huawei). Moramo obezbediti ekran koji vodi vozača da isključi Battery Optimization.
- **Rizik 2 (GPS Šum):** Stajanje u mestu može generisati mikropomake. Neophodan je brzinski prag ("pametno čekanje").
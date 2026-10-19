# Arhitektura Projekta

## Principi
- **Clean Architecture (pragmatična):** Slojevi `data`, `domain`, `presentation`.
- **State Management:** Riverpod (za reaktivno osvežavanje UI-a bez seckanja).
- **Core Logika:** `FareCalculator` je čista Dart klasa u `domain` sloju. Ne zna za UI ni za bazu. Pokrivena testovima za sve scenarije iz plana.

## Glavni Moduli
1. **GPS Engine (Foreground Service):** Sluša lokaciju i drži Android WakeLock. Odbacuje tačke sa lošom tačnošću (prag je podesiv iz baze, podrazumevano >15m).
2. **Obračun Cene (FareCalculator):** Pametno čekanje se aktivira kada je brzina ispod podesivog praga (podrazumevano < 8 km/h), tada računa vreme čekanja umesto distance.
3. **Lokalna Baza (sqflite):** Offline-first pristup. Vožnja se periodično upisuje u `ride_snapshots` tabelu.

## Tok Podataka
GPS Senzor -> Foreground Service -> Odbacivanje šuma -> FareCalculator -> Ažuriranje Riverpod State-a -> UI Prikaz & sqflite backup.

## Životni ciklus servisa
- **Vlasnik servisa je `RideServiceController` (UI isolate).** On pali i gasi foreground servis; handler (`RideTaskHandler`) nikad ne zove `stopService()`.
- **Servis radi samo dok postoji vožnja.** `connect()` pri otvaranju aplikacije kratko podiže servis radi oporavka; ako `ready{active:false}` / `status{active:false}`, odmah ga gasi. `startRide()` podiže servis ako ne radi. Događaj `stopped` → kontroler gasi servis.
- **GPS stream i snapshot timer** postoje samo dok traje vožnja (`_startTracking()` posle starta/oporavka, `_stopTracking()` posle uspešnog stopa).
- **Redosled komandi:** handler izvršava `start`/`stop`/`status` strogo redom (`_queue`); kontroler serijalizuje `connect`/`startRide`/`stopRide` (`_serialized`).
- **Plugin iza `ForegroundBridge`** da bi se kontroler testirao bez uređaja.
- **`RideEngine` (`lib/data/services/ride_engine.dart`)** drži svu logiku servisa: red komandi, upis vožnje, snapshot, oporavak. Prima `Database`, `send`, sat (`nowMs`) i kuke `onTrackingStart`/`onTrackingStop`; nema zavisnost od plugin-a, testira se preko sqflite_ffi (`test/data/ride_engine_test.dart`). `RideTaskHandler` je samo lepak: prosleđuje komande i GPS tačke i drži GPS stream/snapshot timer.
- **Baza u testovima:** `DatabaseHelper.openAt(path)` otvara produkcijsku šemu i migracije na proizvoljnoj putanji.

## Protokol događaja (servis → UI)
- `ready{active}`, `status{active, distance, waitingMs, price}`, `started{ride_id}`, `recovered{...}`, `update{...}`, `already_active`, `snapshot_failing`, `warning{message}`.
- `stopped{ride_id, distance_m, waiting_sec, start_price, km_price, waiting_price, min_price_adjustment, total_price}`; `ride_id: null` znači da vožnje nije bilo.
- `error{message, cmd?}`: `cmd:'start'` → UI se vraća u `idle`, kontroler gasi servis; `cmd:'stop'` → upis nije uspeo, vožnja ostaje aktivna, Stop se može ponoviti.
- UI faze (`RidePhase`): `idle → starting → running → stopping → finished` (`newRide()` → `idle`).

## Rizici i Tehnički Dug
- **Rizik 1 (Baterija):** Android agresivno gasi servise (Xiaomi, Huawei). Moramo obezbediti ekran koji vodi vozača da isključi Battery Optimization.
- **Rizik 2 (GPS Šum):** Stajanje u mestu može generisati mikropomake.
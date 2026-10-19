# Model Podataka (sqflite)

**Pravila:** Novac se čuva kao `INTEGER` (najmanja jedinica valute; za RSD dinar, za EUR cent — vidi N17 u `docs/AUDIT_2026-10-19.md`). Vreme se čuva kao `INTEGER` (UTC milisekunde). Logičke vrednosti (boolean) kao 0 ili 1.

**Verzija šeme: 5** (`DatabaseHelper.openAt`). `onConfigure`: WAL, `busy_timeout=5000`, `foreign_keys=ON`.
Servis (`RideEngine`) je jedini pisac u `rides` i `ride_snapshots`.

## Tabele
- `app_settings`: id, key (UNIQUE), value. Podrazumevano: `waiting_speed_threshold`, `gps_accuracy_threshold`, `calibration_multiplier` (za sada se ne čitaju). Koriste se: `eur_rate_milli` (kurs RSD po 1 EUR × 1000) i `waiting_speed_kmh` (prag brzine za čekanje, ceo broj 1–50; bez unosa važi 8).
- `tariffs`: id, name, start_price, price_per_km, waiting_para_per_min, min_price, rules_json.
- `holidays`: id, name, date_string, multiplier, recurring_yearly.
- `rides`: id, start_time, end_time, distance_m, waiting_time_sec, start_price, km_price, waiting_price, total_price, tariff_id, applied_calibration, status, **tariff_start_price, tariff_price_per_km, tariff_waiting_para_per_min, tariff_min_price** (kopija tarife važeća za vožnju), **min_price_adjustment**, **client_uuid** (v3, unique indeks; još se ne popunjava), **waiting_speed_kmh** (v5; prag brzine za čekanje koji je važio za vožnju, NULL = 8).
  - *Vrednosti za status:* `active` (u toku), `completed` (završena), `interrupted` (prekinuta; iznosi su iz poslednjeg snapshot-a, `end_time` = vreme snapshot-a ili `start_time`), `cancelled` (rezervisano).
  - `total_price = start_price + km_price + waiting_price + min_price_adjustment`.
- `ride_snapshots`: id, ride_id, current_distance (REAL, metri), current_waiting_ms, current_price, last_lat, last_lon, timestamp (GPS vreme poslednje tačke), **saved_at** (v3, vreme upisa; starost se meri njime). Najviše jedan red po vožnji; briše se pri stop-u i pri prekidu. Indeks `idx_snapshots_ride`.
- `fixed_routes`: id, name, from_label, to_label, conditions, fixed_price.

## Migracije
- v1→v2: kolone `tariff_*` i `min_price_adjustment`; snapshot tabela se pravi iznova; aktivne vožnje iz v1 postaju `interrupted`.
- v2→v3: `saved_at`, `client_uuid`, indeksi.
- v3→v4: cena čekanja po minutu se čuva u **para** (1/100 dinara; 13,4 din = 1340): `tariffs.waiting_para_per_min` i `rides.tariff_waiting_para_per_min` preimenovane i pomnožene sa 100.
- v4→v5: `rides.waiting_speed_kmh`.

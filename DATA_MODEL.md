# Model Podataka (sqflite)

**Pravila:** Novac se čuva kao `INTEGER` (najmanja jedinica valute; za RSD dinar, za EUR cent — vidi N17 u `docs/AUDIT_2026-10-19.md`). Vreme se čuva kao `INTEGER` (UTC milisekunde). Logičke vrednosti (boolean) kao 0 ili 1.

**Verzija šeme: 11** (`DatabaseHelper.openAt`). `onConfigure`: WAL, `busy_timeout=5000`, `foreign_keys=ON`.
Servis (`RideEngine`) je jedini pisac u `rides` i `ride_snapshots`.

## Tabele
- `app_settings`: id, key (UNIQUE), value. Tipizirano u `AppSettings` (domain): `eur_rate_milli` (kurs × 1000, opciono), `waiting_speed_kmh` (1–50, pod. 8), `calibration_permille` (500–1500, pod. 1000), `gps_accuracy_m` (5–50, pod. 15), `language` (sr|en), `currency` (RSD|EUR), `selected_tariff_id`, `auto_tariff` (1/0), `show_map`, `background_logo`, `printer_mac`, `printer_name`, `print_mode`, `print_codepage`, `receipt_header`, `receipt_logo`, `voice_announce`, `disclaimer_accepted` (1 = napomena prihvaćena), `battery_guide_shown` (1 = uputstvo za bateriju već prikazano), `button_feedback` (1/0, vibracija i zvuk na start/pauzu/kraj, pod. 1), `auto_print` (1/0, račun se sam štampa na kraju vožnje, pod. 0). Neispravna vrednost se čita kao podrazumevana. Stari ključevi iz v1 (`waiting_speed_threshold`, `gps_accuracy_threshold`, `calibration_multiplier`) se ne koriste.
- `tariffs`: id, name, start_price, price_per_km, waiting_para_per_min, min_price, rules_json (ne koristi se), **schedule_days** (v8; bitovi pon=0 … ned=6, 0 = bez rasporeda), **schedule_start_min**, **schedule_end_min** (lokalni minuti od ponoći; kraj < početak = preko ponoći; jednaki = ceo dan). Redosled (id) je prioritet kad se rasporedi poklapaju.
- `holidays`: id, name, date_string (`MM-DD` svake godine ili `YYYY-MM-DD`), multiplier (iz v1, ne koristi se), recurring_yearly, **tariff_id** (v8; tarifa koja važi ceo taj dan). Redovi bez `tariff_id` se ignorišu. Brisanje tarife briše njene praznike.
- `rides`: id, start_time, end_time, distance_m, waiting_time_sec, start_price, km_price, waiting_price, total_price, tariff_id, applied_calibration (REAL = promili / 1000, npr. 1.025), status, **tariff_start_price, tariff_price_per_km, tariff_waiting_para_per_min, tariff_min_price** (kopija tarife važeća za vožnju), **min_price_adjustment**, **client_uuid** (v3, unique indeks; još se ne popunjava), **waiting_speed_kmh** (v5; prag brzine za čekanje koji je važio za vožnju, NULL = 8), **gps_accuracy_m** (v7; prag GPS tačnosti vožnje, NULL = 15), **fixed_price**, **fixed_route_name** (v10; fiksna relacija: naplaćena je fiksna cena, put i vreme su ipak izmereni; NULL = taksimetar).
  - *Vrednosti za status:* `active` (u toku), `completed` (završena), `interrupted` (prekinuta; iznosi su iz poslednjeg snapshot-a, `end_time` = vreme snapshot-a ili `start_time`), `cancelled` (rezervisano).
  - `total_price = start_price + km_price + waiting_price + min_price_adjustment`.
- `ride_snapshots`: id, ride_id, current_distance (REAL, metri), current_waiting_ms, current_price, last_lat, last_lon, timestamp (GPS vreme poslednje tačke), **saved_at** (v3, vreme upisa; starost se meri njime). Najviše jedan red po vožnji; briše se pri stop-u i pri prekidu. Indeks `idx_snapshots_ride`.
- `ride_gaps` (v6): id, ride_id, started_at (UTC ms, poslednja važeća tačka pre rupe), duration_ms, kind, added_distance_m, added_waiting_ms. Prekidi GPS signala duži od 10 s tokom vožnje. `kind`: `waiting` (rupa naplaćena kao čekanje), `distance` (dodata vazdušna linija), `skipped` (skok nemoguće brzine, ništa dodato), `service_restart` (servis je bio zaustavljen, nije mereno). Indeks `idx_gaps_ride`.
- `shifts` (v9): id, start_time, end_time (NULL = smena u toku). Vožnje pripadaju smeni po vremenu početka; nema stranog ključa.
- `fixed_routes`: id, name, from_label, to_label, conditions (ne koristi se), fixed_price (ceo dinar). Unosi korisnik.

## Migracije
- v1→v2: kolone `tariff_*` i `min_price_adjustment`; snapshot tabela se pravi iznova; aktivne vožnje iz v1 postaju `interrupted`.
- v2→v3: `saved_at`, `client_uuid`, indeksi.
- v3→v4: cena čekanja po minutu se čuva u **para** (1/100 dinara; 13,4 din = 1340): `tariffs.waiting_para_per_min` i `rides.tariff_waiting_para_per_min` preimenovane i pomnožene sa 100.
- v4→v5: `rides.waiting_speed_kmh`.
- v5→v6: tabela `ride_gaps`.
- v6→v7: `rides.gps_accuracy_m`.
- v7→v8: raspored tarife (`tariffs.schedule_*`) i `holidays.tariff_id`.
- v8→v9: tabela `shifts`.
- v9→v10: `rides.fixed_price`, `rides.fixed_route_name`.

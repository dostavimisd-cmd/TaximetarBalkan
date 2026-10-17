# Model Podataka (sqflite)

**Pravila:** Novac se čuva kao `INTEGER` (para/dinar). Vreme se čuva kao `INTEGER` (UTC milisekunde).

## Tabele
- `app_settings`: id, key, value. (npr. prag brzine za čekanje, kalibracioni koeficijent).
- `tariffs`: id, name, start_price, price_per_km, waiting_price_per_min, min_price, rules_json.
- `holidays`: id, name, date_string, multiplier.
- `rides`: id, start_time, end_time, distance_m, waiting_time_sec, start_price, total_price, tariff_id, status.
- `ride_snapshots`: id, ride_id, current_distance, current_waiting_sec, timestamp. (Za oporavak vožnje).
- `fixed_routes`: id, name, fixed_price.
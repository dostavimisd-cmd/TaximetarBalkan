# Model Podataka (sqflite)

**Pravila:** Novac se čuva kao `INTEGER` (para/dinar). Vreme se čuva kao `INTEGER` (UTC milisekunde). Logičke vrednosti (boolean) kao 0 ili 1.

## Tabele
- `app_settings`: id, key, value. (Podesivi pragovi: brzina čekanja, preciznost GPS-a, kalibracioni koeficijent).
- `tariffs`: id, name, start_price, price_per_km, waiting_price_per_min, min_price, rules_json.
- `holidays`: id, name, date_string, multiplier, recurring_yearly.
- `rides`: id, start_time, end_time, distance_m, waiting_time_sec, start_price, km_price, waiting_price, total_price, tariff_id, applied_calibration, status.
  - *Vrednosti za status:* `active` (u toku), `completed` (završena), `cancelled` (poništena).
- `ride_snapshots`: id, ride_id, current_distance, current_waiting_sec, current_price, last_lat, last_lon, timestamp. (Za oporavak vožnje).
- `fixed_routes`: id, name, from_label, to_label, conditions, fixed_price.
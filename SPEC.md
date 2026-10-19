# Specifikacija obračuna

Odluke korisnika (2026-10-19), vidi `docs/AUDIT_2026-10-19.md` (N17, U7).

## Novac
- Sve cene i iznosi su **celi dinari** (`int`). Nema decimala u bazi ni u obračunu.
- Tarife unosi korisnik; aplikacija nema ugrađene tarife, cene ni kurs (Pravilo 3).
- **EUR je samo prikaz.** Korisnik unosi kurs (dinara za 1 EUR, do 3 decimale); čuva se kao `int` hiljaditih delova (`app_settings.eur_rate_milli`, 117.2 → 117200). Prikaz = `dinari * 100000 / kurs`, zaokruženo na cent (.5 naviše), celobrojno (`CurrencyConverter`). Bez unetog kursa EUR prikaz nije dostupan.

## Zaokruživanje (FareCalculator)
- Kilometraža i čekanje se zaokružuju **svaki posebno** na ceo dinar (.5 naviše), pa se sabiraju: `total = start + km + čekanje`.
- Ako je `total < min_price`, razlika ide u `min_price_adjustment` i `total = min_price`.
- Posledica: razlika do ±1 din u odnosu na zaokruživanje jednom na kraju. Namerno ostavljeno.

## Tarifa
- Polja: naziv, start, cena po km, čekanje po minutu, minimalna cena. Čekanje po minutu se unosi sa najviše 2 decimale (npr. 13,4) i čuva u para kao `int`; ostalo su celi dinari.
- Čekanje: `cena = sekunde * para_po_minutu / 6000`, zaokruženo na ceo dinar (.5 naviše).
- Sve cene ≥ 0 i ≤ 1.000.000 din (čekanje ≤ 1.000.000 din/min); to je tehnička granica protiv prekoračenja, ne tarifa.
- Vožnja čuva sopstvenu kopiju tarife (`rides.tariff_*`), pa izmena ili brisanje tarife ne menja istoriju.

## Čekanje
- Čekanje se računa kad je brzina ispod praga (km/h); inače se računa kilometraža. Korak ide ili u distancu ili u čekanje, nikad u oba.
- Prag podešava korisnik (Podešavanja), ceo broj 1–50 km/h; bez unosa važi 8 km/h (dosadašnje ponašanje). Šalje se pri startu i upisuje u `rides.waiting_speed_kmh`, pa oporavljena vožnja koristi isti prag.

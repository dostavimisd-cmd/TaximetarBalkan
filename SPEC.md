# Specifikacija: Taksimetar Balkan

## Cilj
Pomoćna aplikacija za vozača (offline-first) koja računa cenu vožnje. Pomaže taksistima da koriguju tarife u odnosu na državni taksimetar.
**Važno:** Ovo NIJE zvanični taksimetar ni fiskalni uređaj (jasna oznaka na UI i računu).

## Analiza Konkurencije (TAXImet, Taximeter)
- **Šta rade dobro:** Imaju osnovno merenje, istoriju i unos tarifa.
- **Problemi (Žalbe korisnika):** Pretpostavke, nisu proverene sa pravim recenzijama - aplikacije se gase u pozadini (baterija), GPS šum dodaje metre na semaforu, Bluetooth štampači izbacuju hijeroglife umesto č,ć,ž,š,đ, tarife ne prate automatski domaće praznike.
- **Naša prednost:** Pametno čekanje, stroga kalibracija, podrška za naša slova na kineskim štampačima, stabilan foreground servis.

## Faze razvoja
1. **Faza 1 (Jezgro):** GPS merenje, FareCalculator, sqflite čuvanje stanja vožnje, Foreground Service, glavni UI ekran.
2. **Faza 2 (Tarife):** Model tarifa, automatski/ručni režim, korisnički definisani praznici.
3. **Faza 3 (Izveštaji):** Istorija vožnji, mesečni izveštaji, fiksne relacije.
4. **Faza 4 (Hardver - ostavljeno za Claude Code):** Kalibracija, ESC/POS štampač, glasovna najava cene.

### Status (2026-10-19)
| Faza | Stavka | Status |
|---|---|---|
| 1 | GPS, FareCalculator, sqflite, Foreground Service, glavni ekran | urađeno (revizija koraci 1–9) |
| 2 | Model tarifa (unos korisnika) | urađeno |
| 2 | Automatski/ručni režim tarifa | urađeno |
| 2 | Korisnički definisani praznici | urađeno |
| 3 | Istorija vožnji | urađeno (brisanje odloženo) |
| 3 | Izveštaji (dan / nedelja / mesec) | urađeno |
| 3 | Fiksne relacije (cena za jednu vožnju, put se meri) | urađeno |
| 3 | Smene (izveštaj po smeni) | urađeno |
| 3 | Brisanje vožnje iz istorije | urađeno |
| 4 | Kalibracija | urađeno |
| 4 | ESC/POS štampač (č,ć,ž,š,đ), PT-210 58 mm | urađeno u kodu, čeka test na štampaču |
| 4 | Glasovna najava cene (kraj vožnje, uključuje se u Podešavanjima) | urađeno |
| UI | Besplatna open-source mapa (OpenStreetMap), tamna, linija vožnje | urađeno |
| UI | Pretraga adrese i predlog rute (Nominatim + OSRM) | urađeno |
| UI | Pozadina: crna ili logo slika | urađeno |
| UI | Ikonica aplikacije i splash | urađeno |
| — | Podešavanja (ekran, GPS prag tačnosti, pamćenje jezika/valute/tarife) | urađeno |

---

# Pravila obračuna (odluke korisnika)

Odluke korisnika (2026-10-19), vidi `docs/AUDIT_2026-10-19.md` (N17, U7).

## Novac
- Sve cene i iznosi su **celi dinari** (`int`), osim cene čekanja po minutu koja se čuva u para (1/100 dinara, takođe `int`). Nema `double` u obračunu.
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

## Kalibracija distance
- Korisnik unosi procenat korekcije (npr. 2,5 ili -1, jedna decimala, -50 do 50); čuva se kao ceo broj promila (1000 = bez korekcije).
- Obračun: `kalibrisani_metri = round_half_up(metri * promili / 1000)`, celobrojno. U `rides.distance_m` ostaje izmerena distanca, a iznos km se računa iz kalibrisane.
- Promili važe od starta vožnje (`rides.applied_calibration`), pa se oporavljena vožnja obračunava istom kalibracijom.

## Automatski izbor tarife (Faza 2, odluke korisnika)
- Tarifa se bira **samo pri startu** i važi do kraja vožnje.
  - **Potvrđeno (vlasnik, 19.10.2026):** pravilo u Srbiji je da vožnja koja počne u jednoj tarifi (npr. pre 22:00) ostaje u toj tarifi do kraja, pa prelaza tarife usred vožnje nema. Vozač tarifu menja ručno pre sledeće vožnje.
- Uključuje se u Podešavanjima. Redosled: **praznik** (ceo dan, lokalni datum) → **raspored** (prva tarifa na listi čiji raspored važi) → ručno izabrana tarifa → prva tarifa.
- Raspored po tarifi: dani u nedelji + lokalno vreme od–do; period preko ponoći pripada danu u kome počinje; isto vreme od i do = ceo dan. Kraj nije uključen (22:00 je već sledeći period).
- Praznike unosi korisnik (jednokratno ili svake godine) i uz svaki bira tarifu. Nema ugrađenih praznika.

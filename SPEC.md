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
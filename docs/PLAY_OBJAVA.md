# Play Console — materijal za objavu (nacrt)

Nalog: organizacija „DostaviMi+ Team” (bez obaveze 12 testera / 14 dana).
Paket: `rs.taksimetar.balkan`. Potpisan AAB: `build/app/outputs/bundle/release/app-release.aab`
(`flutter build appbundle --release`). Ključ: `D:\kljucevi\taksimetar-upload.jks` (kopiraj na bezbedno mesto; bez njega nema ažuriranja).
Pre prvog slanja `versionCode` je 1 (`pubspec.yaml` `version: 1.0.0+1`); svaki novi upload traži veći broj posle `+`.

## 1. Podešavanje aplikacije
- Kategorija: Auto i vozila (ili Alati). Cena: **besplatna** (prvo izdanje).
- Politika privatnosti: **https://taximetarbalkan.web.app/privacy** (već objavljena; izvor je `site/privacy.html`, a već je upisana u `privacyPolicyUrl` u `about_screen.dart`).
- Kontakt e-mail: dostavimisd@gmail.com
- Reklame: ne. Pristup aplikaciji: bez prijave (sve funkcije dostupne).
- Ciljna grupa: odrasli (18+). Nije za decu.

## 2. Data safety (predlog odgovora)
Odluku o tome da li navesti „prikuplja se” za lokaciju donosi vlasnik. Konzervativan odgovor:

| Pitanje | Odgovor |
|---|---|
| Da li prikupljate ili delite korisničke podatke? | Da |
| Precizna lokacija | Obrađuje se na uređaju; koordinate rute se šalju OSRM servisu (treće lice) radi predloga rute. Svrha: funkcionalnost aplikacije. Nije obavezno (samo uz mapu). Nije za reklame. |
| Ostali podaci (tekst pretrage adrese) | Šalje se Nominatim servisu radi pretrage. Svrha: funkcionalnost aplikacije. |
| Lični podaci, finansijski, kontakti, fotografije, audio | Ne prikupljaju se |
| Šifrovanje u prenosu | Da (HTTPS) |
| Zahtev za brisanje podataka | Podaci su samo na telefonu; brišu se brisanjem vožnji, podataka ili aplikacije |

## 3. Deklaracija foreground servisa (tip: location)
**Opis (za polje u konzoli):**
„Aplikacija je pomoćni taksimetar. Kad vozač pokrene vožnju, servis u prvom planu (sa trajnim obaveštenjem) meri pređeni put pomoću GPS-a i dok je ekran zaključan ili je aplikacija u pozadini. Bez toga merenje puta stane čim se ekran ugasi. Servis radi samo dok traje vožnja i gasi se kad vozač završi vožnju. Aplikacija ne traži lokaciju u pozadini kad vožnja nije pokrenuta.”

**Video (30–60 s), redosled:**
1. Otvori aplikaciju, pokaži ekran prvog pokretanja i dozvolu za lokaciju.
2. Pritisni START (vidi se obaveštenje „Taksimetar / Taximeter”).
3. Zaključaj ekran 10–15 s, pa ga otključaj: cena i distanca su se promenile.
4. Pritisni ZAVRŠI: obaveštenje nestaje, otvara se rezime vožnje.

## 4. Tekstovi prodavnice

### Srpski
**Naziv:** Taksimetar Balkan
**Kratak opis (≤80 znakova):** Pomoćni taksimetar za vozače i kurire: cena, tarife, relacije, štampa.

**Pun opis:**
Taksimetar Balkan je pomoćni program za vozače taksija i kurire koji žele tačnu evidenciju svake vožnje.

• Cena se računa preko GPS-a: start, kilometraža, čekanje i minimalna cena. Radi i bez interneta.
• Tarife unosite sami; automatski izbor po danu i satu, praznicima, ili ručno.
• Fiksne relacije sa brzom pretragom i uvozom celog cenovnika.
• Pauza tokom vožnje, rezime vožnje sa mapom rute.
• Izveštaji po danu, nedelji, mesecu i smeni: zarada ukupno, po vožnji, po satu i po km.
• Štampa računa na Bluetooth termalni štampač od 58 mm (naša slova ispravno).
• Besplatna mapa (OpenStreetMap), pretraga adrese i procena cene pre vožnje.
• Podesiva boja i veličina cene, ekran ostaje uključen, srpski i engleski.
• Vožnja se ne gubi ni kad telefon ugasi aplikaciju.

Važna napomena: aplikacija je pomoćni alat za evidenciju i procenu. Nije overeni taksimetar niti fiskalni uređaj. Tarife unosi korisnik; aplikacija ne sadrži zvanične cene.

Za rad sa zaključanim ekranom isključite ograničenja baterije za aplikaciju (uputstvo je u aplikaciji).

### English
**Title:** Taksimetar Balkan
**Short description (≤80 chars):** Auxiliary taximeter for drivers and couriers: fare, tariffs, routes, printing.

**Full description:**
Taksimetar Balkan is an auxiliary program for taxi drivers and couriers who want an accurate record of every ride.

• The fare is calculated from GPS: base fare, distance, waiting time and minimum fare. Works without internet.
• You enter your own tariffs; automatic choice by day and time, holidays, or manual.
• Fixed routes with quick search and bulk import of a whole price list.
• Pause during a ride and a ride summary with a route map.
• Reports by day, week, month and shift: total earnings, per ride, per hour and per km.
• Receipt printing on a 58 mm Bluetooth thermal printer.
• Free map (OpenStreetMap), address search and a fare estimate before the ride.
• Adjustable fare colour and size, screen stays on, Serbian and English.
• A ride is not lost even if the phone closes the app.

Important: this app is an auxiliary tool for recording and estimating. It is not a certified taximeter or a fiscal device. Tariffs are entered by the user; the app contains no official prices.

To keep it running with a locked screen, turn off battery restrictions for the app (instructions are in the app).

## 5. Grafika (u `docs/play/`)
- `ikona_512.png` — ikona 512×512 (spremna).
- `feature_graphic_1024x500.png` — feature graphic (spremna).
- `telefon_1_glavni_ekran.png`, `telefon_2_rezime_voznje.png`, `telefon_3_izvestaji.png` — snimci ekrana sa Honora, isečeni na odnos 2:1 (Play dozvoljava najviše 2:1). Snimci 2 i 3 prikazuju stvarne probne vožnje i zaradu; zameni ih ako ne želiš da se to vidi.
- Još treba: snimci na engleskom (prebaci jezik na EN i snimi isti redosled), po želji tamna/svetla varijanta. Play traži najmanje 2 snimka telefona, preporučeno 4–8.

## 6. Preostalo za vlasnika
- Napraviti rezervnu kopiju `D:\kljucevi\taksimetar-upload.jks` (i zapisati lozinku na sigurno mesto, ne u projekat).
- Snimiti video za deklaraciju foreground servisa.
- Snimiti slike ekrana.

## 7. Napomena verzije (za Play, „Šta je novo”)

**Srpski (sr):**
```
Prva verzija.
• Taksimetar: start, kilometraža, čekanje i minimalna cena, uz pauzu tokom vožnje.
• Tarife unosite sami, uz automatski izbor po danu, satu i praznicima.
• Fiksne relacije sa brzom pretragom i uvozom cenovnika.
• Mapa sa pretragom adrese i procenom cene pre vožnje.
• Izveštaji po danu, nedelji, mesecu i smeni.
• Štampa računa na Bluetooth štampač od 58 mm.
Napomena: aplikacija je pomoćni alat za evidenciju i procenu, nije overeni taksimetar niti fiskalni uređaj.
```

**English (en-US):**
```
First version.
• Taximeter: base fare, distance, waiting and minimum fare, with pause during rides.
• Your own tariffs, chosen automatically by day, time and holidays.
• Fixed routes with quick search and bulk price list import.
• Map with address search and a fare estimate before the ride.
• Reports by day, week, month and shift.
• Receipts on a 58 mm Bluetooth printer.
Note: an auxiliary tool for recording and estimating, not a certified taximeter or fiscal device.
```

Dužina: SR 480, EN 471 znakova (limit 500).

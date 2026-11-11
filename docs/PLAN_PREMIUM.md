# Plan izrade — premium osećaj (posle v1.0.0)

Stanje na dan 04.11.2026. Polazna tačka: v1.0.0 na Google Play, baza v11, 241 test.
Pravila iz `CLAUDE.md` važe za svaki korak: novac je `int`, vreme UTC ms, cene i tarife unosi korisnik (ne izmišljamo ih), `FareCalculator` bez Fluttera; pre izmene čitati `ARCHITECTURE.md` i `DATA_MODEL.md`, posle veće izmene ažurirati `ARCHITECTURE.md`.

## Redosled ukratko
| Faza | Izdanje | Šta | Zašto prvo |
|---|---|---|---|
| A | v1.1.0 | Vibracija i zvuk, dugmad u obaveštenju, automatska štampa | Brzo, vidi se odmah, malo rizika |
| B | v1.2.0 | Rezervna kopija, izveštaj u CSV i PDF | Podaci ne smeju da nestanu; knjigovođa |
| C | v1.3.0 | „Prvi km”, doplate, pomoćnik za kalibraciju | Poverenje u cenu; traži tvoje odluke |
| D | v1.4.0 | Čarobnjak prvog pokretanja, raspored za držač | Prvi utisak novih korisnika |
| E | paralelno | Više jezika, snimci ekrana na engleskom | Tržište „Balkan” |
| F | v2.0.0 | Premium (Play Billing), sopstveni server mape | Prodaje se kad A–D postoje |

Pre faze C sačekaj 2 nedelje povratnih informacija od kolega; mogu da promene redosled.

## Alati

**Modeli**
- **Opus:** obračun, migracije baze, životni ciklus servisa, uvoz podataka, plaćanje.
- **Sonnet:** ekrani, izveštaji, tekstovi, testovi, snimci ekrana.
- **Haiku:** prevodi na nove jezike i sitne izmene teksta.

**Paketi**
- Već postoje: `file_picker` (izbor fajla), `share_plus` (slanje fajla), `path_provider`, `flutter_foreground_task` (obaveštenje), `print_bluetooth_thermal`.
- Novi, dodaju se tek kad korak počne: `pdf` (izveštaj u PDF; uz ugrađen TTF font da bi č ć ž š đ bila ispravna), `in_app_purchase` (Premium).
- Bez paketa: vibracija (`HapticFeedback`), zvuk (`SystemSound`), CSV i JSON (`dart:convert`).

**Provera svakog koraka**
- `flutter analyze` i `flutter test` (svi testovi moraju da prođu).
- Telefon: Samsung preko USB-a, Honor bežično (`adb tcpip 5555`); uputstvo u `docs/GDE_SMO_STALI.md`.
- Objava: `pubspec.yaml` verzija +1, `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`, prvo interno testiranje u Play Console, pa produkcija. Simbole sačuvati u `docs/play/symbols-<verzija>/`.

---

## Faza A — v1.1.0 (brzo i vidljivo)

### A1. Vibracija i zvuk na START, PAUZA, ZAVRŠI
- Kratka vibracija i zvuk, da vozač ne mora da gleda u ekran. Prekidač u Podešavanjima (podrazumevano uključeno).
- Fajlovi: `taximeter_screen.dart`, `app_settings.dart` (+ ključ), `settings_screen.dart`, `en.dart`.
- Veličina S, rizik nizak. **Sonnet.**

### A2. Dugmad PAUZA/NASTAVI i ZAVRŠI u obaveštenju (Android)
- Vožnja se kontroliše iz obaveštenja dok je otvorena druga aplikacija (navigacija, Viber).
- `RideTaskHandler.onNotificationButtonPressed` šalje iste komande engine-u (`pause`, `resume`, `stop`); dugmad se menjaju preko `updateService`. UI već reaguje na događaje `paused`, `resumed`, `stopped`.
- iOS se ne dira (nema obaveštenja servisa).
- Testovi: komande iz obaveštenja kroz `RideEngine` (pauza, nastavak, stop), kontroler kad stop ne dolazi iz UI-ja.
- Veličina M, rizik srednji (životni ciklus servisa). **Opus.**

### A3. Automatska štampa računa na kraju vožnje
- Opcija u Podešavanjima; posle ZAVRŠI račun ide na izabrani štampač bez dodatnog dodira. Greška štampe ne sme da blokira kraj vožnje.
- Veličina S, rizik nizak. **Sonnet.**

**Gotovo kad:** na Samsungu i Honoru vibracija i zvuk rade, dugmad iz obaveštenja pauziraju i završavaju vožnju sa zaključanim ekranom, račun izlazi sam.

---

## Faza B — v1.2.0 (podaci)

### B1. Rezervna kopija (izvoz i uvoz)
- Izvoz u jedan JSON fajl: tarife, praznici, fiksne relacije, podešavanja, istorija vožnji (sa rutom i prekidima signala). Fajl se šalje preko `share_plus` (Viber, Drive, e-mail).
- Uvoz preko `file_picker`: proverava verziju šeme, sve u jednoj transakciji, **ništa se ne briše dok uvoz ne uspe**; pre uvoza pitanje „zameni” ili „dodaj”. Aktivna vožnja blokira uvoz.
- Testovi: izvoz → uvoz vraća iste podatke; oštećen fajl i stara verzija šeme ne menjaju bazu.
- Veličina M, rizik srednji (uvoz u bazu). **Opus** za format i uvoz, **Sonnet** za ekran.

### B2. Izveštaj u CSV i PDF
- Iz ekrana Izveštaji: period (dan, nedelja, mesec, smena) → CSV (Excel) ili PDF (logo, zaglavlje, zbir, spisak vožnji), slanje preko `share_plus`.
- PDF ne prevodi korisničke podatke; naslovi prate jezik aplikacije.
- Veličina M, rizik nizak. **Sonnet.**

**Gotovo kad:** izvezeš na Samsungu, uvezeš na Honoru i dobiješ iste tarife, relacije i istoriju; PDF se otvara sa ispravnim slovima.

---

## Faza C — v1.3.0 (poverenje u cenu) — traži tvoje odluke

### C1. „Prvi km” i doplate (jedna migracija v12)
- Tarifa dobija nova polja za prvi km (oblik zavisi od odluke 1 ispod), vožnja dobija doplate (tabela `ride_extras`: naziv, iznos u dinarima).
- Tokom vožnje: dugmad za doplate koje je vozač uneo (npr. „Prtljag +100”). Doplate se vide u rezimeu, na računu i u izveštajima.
- `FareCalculator` računa novu stavku; tarifa i doplate se snimaju uz vožnju (kao i do sada), pa stare vožnje ostaju iste.
- Testovi: svi postojeći scenariji obračuna + novi (prvi km kraći/duži od vožnje, doplate i minimalna cena, migracija v11 → v12 čuva istoriju).
- Veličina L, rizik visok (obračun i baza). **Opus.**

### C2. Pomoćnik za kalibraciju
- U rezimeu vožnje: „Zvanični taksimetar je pokazao ___ km”. Aplikacija izračuna kalibraciju u promilima (`zvanično / izmereno × 1000`, celobrojno) i ponudi da je sačuva.
- Čista funkcija u `domain/calibration.dart` + test.
- Veličina S, rizik nizak. **Sonnet.**

**Gotovo kad:** probna vožnja daje istu cenu kao zvanični taksimetar na tvom cenovniku.

---

## Faza D — v1.4.0 (prvi utisak)

### D1. Čarobnjak prvog pokretanja
- Posle napomene: 1) unesi tarifu, 2) uvezi fiksne relacije (opciono), 3) izaberi štampač (opciono), 4) uputstvo za bateriju. Svaki korak se može preskočiti; cene se ne predlažu.
- Veličina M, rizik nizak. **Sonnet.**

### D2. Raspored za držač u kolima
- Provera i dorada horizontalnog rasporeda glavnog ekrana (velika cena, dugmad dostupna jednim palcem).
- Automatski svetli/tamni režim **samo ako ga traže kolege** (taksimetri su obično tamni).
- Veličina S–M, rizik nizak. **Sonnet.**

**Urađeno 11.11.2026** (telefon i iPad 9. gen. potvrdio vlasnik; IPA 1.2.4).

**Odluke vlasnika (11.11.2026), predlog: https://claude.ai/artifact/NbLwLA9HCwvnBBL6C2Xd4Y**
- Varijanta **A**: dorada postojećeg položenog izgleda (sa mapom). Levo oko 42%: tarifa i GPS, velika cena, distanca, čekanje i brzina, cilj, dugmad (+, PAUZA, ZAVRŠI) na dnu. Desno oko 58%: mapa preko cele visine, pretraga adrese ostaje na mapi.
- Glavni uređaj: **iPad 9. generacije** (10,2", 4:3, 1080×810 tačaka), položen, držač na sredini table iznad ventilacije. Vozač je levo, pa dugmad ostaju **levo**.
- Dugmad +, PAUZA i ZAVRŠI: visina **1,5 cm** (iPad 9. gen. ima oko 132 tačke po inču, pa oko 78 tačaka).
- Telefon **uspravno ostaje kao sada**.
- Predlozi uz to: zaključavanje položenog ekrana i pun ekran tokom vožnje, strana dugmadi u Podešavanjima (levo podrazumevano); svaki je opcija.

### D3. Grafikon zarade (odluka 11.11.2026)
**Urađeno 11.11.2026**: sve pločice iz predloga (po satu rada, poređenje, vožnje i km, prosek po vožnji, linija cilja).
- Novi ekran u Izveštajima: Nedelja, Mesec, Godina; stubovi zarada i troškovi po danu (godina: po mesecu), linija proseka; pločice Zarada, Troškovi, Ostaje, Najbolji dan; „Najbolji sati” (broj vožnji po satu). Dodir na stub otvara izveštaj tog dana.
- Podaci iz postojećih tabela (`rides`, `shift_expenses`), bez nove šeme; novac int.
- Otvoreno (vlasnik oseća da nešto fali): zarada po satu rada, poređenje sa prethodnim periodom, broj vožnji i km, prosek po vožnji, linija dnevnog cilja (G3).
- Veličina M, rizik nizak. **Sonnet.**

---

## Faza E — paralelno (tržište)

### E1. Prevod na više jezika
- `Tr` danas zna samo srpski i engleski (`english: bool`). Prepravka na kod jezika (`Tr('hr')`) i rečnik po jeziku; test-čuvar proverava svaki jezik.
- Prepravka: **Sonnet** (S–M). Prevodi (hrvatski, bosanski, crnogorski, makedonski, slovenački, srpska ćirilica): **Haiku**, uz tvoju proveru ili proveru kolege iz te zemlje.

### E2. Prodavnica po jeziku
- Snimci ekrana na engleskom (i ostalim jezicima), opis prodavnice po zemlji. **Sonnet.**

---

## Faza F — v2.0.0

### F1. Premium (Play Billing)
- Jednokratna kupovina (oko 1 €), `in_app_purchase`, otključavanje radi i bez interneta (keš), dugme „Vrati kupovinu”, jedan `premiumProvider` koji zaključava funkcije.
- Data safety i politika privatnosti se ažuriraju.
- Veličina L, rizik visok (novac). **Opus.**

### F2. Sopstveni ili plaćeni server mape (ruta, pretraga)
- Tek kad broj korisnika naraste; obračun ostaje nezavisan od mape. **Opus**, košta mesečno.

---

## Faza G — vozačev dan (odluke vlasnika 05.11.2026)

Za sada besplatno (premium je odložen); kasnije se može zaključati u premium.

### G1. Automatska smena (A3)
- Smena počinje sama sa **prvom vožnjom** ako je vozač nije ručno pokrenuo; **završava je samo vozač** (ručno).
- Postojeća tabela `shifts` ostaje; dodaje se pravilo pri startu vožnje.
- Veličina S, rizik nizak. **Sonnet.**

### G2. Troškovi i „ostaje za pazar” (A2)
- Na kraju smene vozač unosi troškove: gorivo, pranje, parking, ostalo (celi dinari; spisak vrsta kao kod doplata).
- Rezime smene i izveštaj pokazuju **zaradu i troškove jedno pored drugog** i **koliko ostaje** (zarada − troškovi). Troškovi ulaze i u PDF/CSV i u rezervnu kopiju.
- Nova tabela `shift_expenses` (migracija v13).
- Veličina M, rizik srednji (baza, izveštaji). **Opus** za bazu i obračun, **Sonnet** za ekrane.

### G3. Dnevni cilj (A1)
- Vozač podesi cilj zarade (iznos po želji), uključuje/isključuje ga prekidačem; pri početku smene može da ga promeni.
- Na glavnom ekranu: „Danas 4.350 / 6.000 din” sa trakom napretka (samo kad je uključeno), kao motivacija.
- Veličina S, rizik nizak. **Sonnet.**

### G4. Glasovne komande (A4)
- „Start”, „pauza”, „kraj” glasom, **uvek uz potvrdu** (npr. „Potvrdi: kraj vožnje?” pa „da” ili dodir), da razgovor sa putnikom ne pokrene komandu.
- Prekidač u podešavanjima, podrazumevano isključeno. Traži dozvolu za mikrofon (izmena Data safety na Play-u).
- Veličina M, rizik srednji (prepoznavanje govora, srpski, dozvole). **Opus** za tok i bezbednost komandi.

### A5 (doplata jednim dodirom): ne radi se, postojeće dugme „+” je dovoljno.

### G5. Ekran za putnika (B1)
- Položen telefon u držaču: velika cena, logo i naziv firme, distanca, čekanje, doplata, tarifa; na kraju vožnje „Za naplatu” sa razradom, EUR i QR za račun.
- Izgled (predlog): Artifact „Ekran za putnika” (https://claude.ai/artifact/4QhzdVd54vqWapRrijpCpT).
- Ostalo iz B i C (QR/slanje računa, firmin paket) se preskače za sada.
- Veličina M, rizik nizak. **Sonnet.**

### G6. Navigacija i adrese (D12, D13)
- **D12:** unos adrese glasom preko glasovnog unosa koji je vozač već podesio na telefonu (npr. Google tastatura, mikrofon na tastaturi), bez sopstvenog prepoznavanja govora; dugme mikrofona otvara sistemski glasovni unos.
- **D13:** omiljene adrese u padajućem meniju pretrage (aerodrom, stanica, bolnica…), dodavanje iz rezultata pretrage.
- Veličina S–M, rizik nizak. **Sonnet.**

### G7. Toplotna mapa (D14) — verzija 1.2.0
- Gde i kada je bilo najviše vožnji, iz sopstvene istorije (`ride_points`), po danu u nedelji i satu.
- Veličina M, rizik nizak. **Sonnet** (prikaz), **Opus** ako treba agregacija u bazi.

### G8. Podaci u oblaku (E15, E16)
- **E15:** automatska rezervna kopija na Google Drive, svake večeri (postojeći JSON iz B1).
- **E16:** prelazak na novi telefon u jednom koraku (vraćanje poslednje kopije sa Drive-a).
- Traži Google prijavu (Drive API, OAuth) i izmenu politike privatnosti i Data safety. Veličina L, rizik srednji. **Opus.**

**Redosled:** G1 → G2 → G3 → G4 (G1 i G2 zajedno daju „zarada / troškovi / ostaje” po smeni).

---

## Odluke vlasnika (04.11.2026)
- **Redosled:** A → B (oba Opus) → C → popravka mape i pretraga adrese → F na kraju. Faza E (jezici) se odlaže: za sada SR i EN.
- **Prvi kilometar (C1):** opciono polje u tarifi. Prazno = kao do sada (sve po ceni km); 0 = prvi km uključen u start; iznos > 0 = prvi km po toj ceni, ostatak po ceni km. Vrednost unosi vozač ili firma.
- **Doplata / Extra (C1):** programibilna lista (naziv + iznos u dinarima) u Podešavanjima; vozač je dodaje tokom vožnje. SR naziv „Doplata”, EN „Extra”. Dodaje se **posle** minimalne cene (pretpostavka; vlasnik nije rekao drugačije).
- **„Van teritorije” (80/70 din/km):** nije potvrđeno, ne pravi se.
- **Mapa (novo, pre F):** popraviti povremeno loše iscrtavanje i zum koji ne približava; pretraga adrese daje predloge dok se kuca, poređane po blizini (prvo ulice u mestu, pa okolina, pa drugi gradovi). Javni Nominatim zabranjuje predloge dok se kuca, pa se za to koristi Photon (komoot, OSM, besplatno, pretraga po blizini).
- **Premium (F1):** šta je besplatno, a šta se plaća, određuje se na kraju.
- **Premium odložen (04.11.2026):** aplikacija ostaje potpuno besplatna dok ne naraste broj korisnika; F1 i F2 se ne rade do tada.

## Prvobitna pitanja
1. **„Prvi km” (C1):** šta znači u tvom cenovniku? Start uključuje prvih X km, prvi km ima posebnu cenu, ili nešto treće?
2. **Doplate (C1):** stalna lista koju vozač unese (naziv + iznos) ili slobodan iznos? Da li ulaze u minimalnu cenu?
3. **„Van teritorije” (C1):** 80 din/km do 100 km i 70 preko — važi za ceo put ili samo za deo preko granice?
4. **Premium (F1):** šta ostaje besplatno, a šta se plaća.
5. **Jezici (E1):** kojim redom.

Faze A i B ne zavise od ovih odluka i mogu odmah.

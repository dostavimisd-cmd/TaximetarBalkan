# Taksimetar Balkan — stanje projekta

Stanje na dan 19.10.2026. (poslednji commit `5846f96`).
Aplikacija radi na telefonu, računa vožnje, štampa račune i prevedena je na engleski. Sledeći cilj je objava na Google Play.

---

## Šta aplikacija sada radi

### Taksimetar (glavni ekran)
- Meri vožnju preko GPS-a u pozadini, i kad je ekran zaključan (foreground servis).
- Računa start + kilometražu + čekanje (ispod podesive brzine) + dopunu do minimalne cene. Sve u celim dinarima, bez decimalnih grešaka.
- **Pauza / Nastavi** tokom vožnje: u pauzi ne teku ni km ni čekanje, cena stoji.
- Prikazuje da li se trenutno vozi ili čeka, prekide GPS signala i upozorenja.
- Ako se aplikacija ugasi usred vožnje, posle ponovnog otvaranja vožnja se nastavlja (do 5 min), a kasnije se zatvara sa iznosom do prekida.
- Boja i veličina cene po izboru, osvežavanje cene na 1/4/6/10 s, ekran uvek uključen dok je aplikacija otvorena.
- Glasovna najava cene na kraju vožnje.

### Tarife
- Tarife unosi vozač (nema ugrađenih cena). Čekanje po minutu može sa decimalom (npr. 13,33).
- Automatski izbor tarife pri startu: praznici, pa raspored (dani + vreme od–do, i preko ponoći).
- Kalibracija distance u procentima, prag GPS tačnosti.

### Fiksne relacije
- 91 relacija iz cenovnika (važi od 06.05.2026.) — spisak je u `docs/fiksne_relacije.txt`.
  Gde postoje dve cene (npr. 450/480): prva je do centra, druga malo dalje.
- Uvoz celog spiska odjednom (iz .txt fajla ili nalepljenog teksta), pretraga bez kvačica, dodavanje, izmena, brisanje.
- Dugme **RELACIJE** na glavnom ekranu: izabrana relacija važi za sledeću vožnju (meri se put, naplaćuje se fiksna cena).

### Mapa
- Besplatna OpenStreetMap mapa (tamna), živa pozicija, linija pređene rute.
- Pretraga adrese → iscrtana ruta, km, procena vremena i **približna cena** po tarifi.

### Posle vožnje
- **Rezime vožnje**: cena, mapa pređene rute, distanca, trajanje, čekanje, prosečna brzina, pauza, razrada obračuna, prekidi signala. Dugmad ŠTAMPAJ i PODELI.
- Istorija vožnji (otvara isti rezime, može i brisanje).
- Izveštaji po danu, nedelji, mesecu i **smeni** (zarada ukupno, po vožnji, po satu, po km).

### Štampa računa
- Bluetooth termalni štampač 58 mm (testirano sa **PT-210**) — naša slova se štampaju ispravno.
- Logo firme i zaglavlje na računu, na dnu uvek "Ovo nije fiskalni račun".

### Ostalo
- Prevod na engleski (prekidač SR/EN). Štampa i podaci koje vozač unosi se ne prevode.
- Ikonica i početni ekran (logo Taximetar Balkan), naziv paketa `rs.taksimetar.balkan`.
- Pozadina: crna ili logo slika.

---

## Kvalitet
- 238 automatskih testova (obračun, oporavak vožnje, baza i migracije, štampa, prevod, uvoz relacija…).
- Baza ima migracije do verzije 11, podaci se čuvaju pri svakoj nadogradnji aplikacije.
- Testirano na dva telefona (Samsung S23 Ultra i drugi uređaj): vožnje, štampa, mapa, pretraga, uvoz relacija.

---

## Šta je ostalo (redom)

### 1. Za objavu na Google Play
- [ ] **Ključ za potpisivanje** aplikacije (potrebna lozinka; ključ se čuva na sigurnom, bez njega nema ažuriranja).
- [ ] **Politika privatnosti** (srpski i engleski) objavljena na nekoj adresi — aplikacija koristi lokaciju.
- [ ] **Deklaracija lokacije u pozadini** za Play (objašnjenje + kratak video).
- [ ] Bluetooth dozvola za skeniranje sa oznakom "ne za lokaciju" (izmena manifesta).
- [ ] Opis za prodavnicu i slike ekrana (srpski i engleski).
- [ ] Mapa za veći broj vozača: sopstveni ili plaćeni server (javni OSM serveri su za malu upotrebu).

### 2. Provera u pravoj vožnji (lista u `docs/TEST_VOZNJA.md`)
- [ ] Poređenje sa zvaničnim taksimetrom (km, čekanje, cena).
- [ ] Pauza, rezime sa mapom rute, zaključan ekran duže od 15 min, prekid aplikacije usred vožnje.

### 3. Mogući dodaci
- [ ] Rezervna kopija (izvoz/uvoz tarifa, relacija i istorije) — za prelazak na novi telefon.
- [ ] Doplate iz cenovnika (+50, +100… za određene ulice) i pravilo "van teritorije: 80 din/km do 100 km, 70 preko".
- [ ] Obaveštenje u statusnoj traci na engleskom.

---

## Gde je šta (za programera)
- Pravila obračuna: `SPEC.md` · Arhitektura: `ARCHITECTURE.md` · Baza: `DATA_MODEL.md`
- Poznati problemi: `KNOWN_ISSUES.md` · Revizija i plan testiranja: `docs/AUDIT_2026-10-19.md`
- Instalacija na drugi telefon: `adb install -r build\app\outputs\flutter-apk\app-release.apk`
  (ili pošalji APK na telefon i otvori ga).

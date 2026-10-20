# Play Console — korak po korak (da prođe iz prve)

Nalog: organizacija „DostaviMi+ Team" (bez obaveze 12 testera / 14 dana).
Paket: `rs.taksimetar.balkan`. Verzija: 1.0.0 (versionCode 1). targetSdk 36.

**Datoteka za otpremanje:** `build/app/outputs/bundle/release/app-release.aab` (48,6 MB).
**NE otpremaj APK** na Play — APK (`TaksimetarBalkan-1.0.0.apk`) je samo za deljenje kolegama van prodavnice.

---

## 0. Pre svega: verifikacija naloga i ključ

- **Verifikacija organizacije.** Google za nove naloge traži proveru identiteta organizacije (naziv, adresa, ponekad D-U-N-S broj i kontakt). Ako to nije završeno, uradi prvo — bez verifikacije se ne može objaviti. Podaci: Branislav Simulj pr DOSTAVI MI PLUS SMEDEREVO, Cara Lazara 7, Seone 231215, RS.
- **Rezervna kopija ključa.** `D:\kljucevi\taksimetar-upload.jks` (lozinka na sigurno, van projekta). Bez njega nema ažuriranja. **Napravi kopiju pre objave.**
- **Play App Signing.** Pri prvom otpremanju AAB-a Google ponudi „Play App Signing" — prihvati. Ti potpisuješ upload ključem (taj .jks), Google čuva ključ za distribuciju.
  - Posledica: APK koji kolege testiraju (potpisan tvojim upload ključem) ima drugačiji potpis od verzije sa Play-a. Testeri koji pređu na Play verziju prvo deinstaliraju test APK.

---

## 1. Kreiraj aplikaciju
Play Console → **Create app**.
- Naziv: **Taksimetar Balkan**
- Jezik podrazumevani: srpski (dodaćeš i engleski)
- App or game: **App**
- Free or paid: **Free**
- Potvrdi deklaracije (Developer Program Policies, US export laws).

---

## 2. Store listing (glavni unos u prodavnici)
Play Console → **Main store listing**. Tekstovi su u `docs/PLAY_OBJAVA.md` (SR i EN).
- Kratak opis (≤80): „Pomoćni taksimetar za vozače i kurire: cena, tarife, relacije, štampa."
- Pun opis: iz `docs/PLAY_OBJAVA.md`.
- **Grafika** (u `docs/play/`):
  - Ikona 512×512: `ikona_512.png`
  - Feature graphic 1024×500: `feature_graphic_1024x500.png`
  - Snimci telefona na srpskom (4, odnos 2:1): `store_sr_1_glavni_ekran.png`, `store_sr_2_izvestaji.png`, `store_sr_3_fiksne_relacije.png`, `store_sr_4_rezime_voznje.png`
    - *Napomena:* snimci 2 i 3 prikazuju stvarne vožnje i zaradu. Ako ne želiš to javno, zameni ih (javi mi, snimim nove na praznoj bazi ili na engleskom).
- Dodaj i engleski jezik (Store listing → Manage translations) i prenesi EN tekstove.

---

## 3. Politika privatnosti
Play Console → **App content → Privacy policy**.
- URL: **https://taximetarbalkan.web.app/privacy** (već objavljeno, SR i EN).

---

## 4. Dozvole i deklaracija foreground servisa (NAJVAŽNIJE — ovde se najčešće pada)
Play Console → **App content → App access** i **Advertising ID** i **Foreground service**.

- **App access:** sve funkcije su dostupne bez prijave → izaberi „All functionality is available without special access".
- **Ads:** nema reklama → „No".
- **Foreground Service (location):** aplikacija koristi servis u prvom planu tipa lokacija. Deklariši ga:
  - **Opis** (zalepi): „Aplikacija je pomoćni taksimetar. Kad vozač pokrene vožnju, servis u prvom planu sa trajnim obaveštenjem meri pređeni put GPS-om i dok je ekran zaključan ili je aplikacija u pozadini. Servis radi samo tokom vožnje i gasi se kad vozač završi. Aplikacija ne traži lokaciju u pozadini kad vožnja nije pokrenuta."
  - **Video (obavezan):** snimak ekrana 30–60 s, javno dostupan (npr. neobjavljen YouTube link). Redosled:
    1. Otvori aplikaciju, dozvoli lokaciju.
    2. Pritisni POKRENI (START) — vidi se obaveštenje „Taksimetar / Taximeter".
    3. Zaključaj ekran 10–15 s, pa otključaj — cena i distanca su se promenile.
    4. Pritisni ZAVRŠI — obaveštenje nestaje, otvara se rezime.

- **Deklaracija lokacije:** aplikacija koristi preciznu lokaciju samo u prvom planu tokom vožnje; **nema** `ACCESS_BACKGROUND_LOCATION` (i ne treba ga tražiti).

---

## 5. Data safety (bezbednost podataka)
Play Console → **App content → Data safety**. Odgovori moraju da odgovaraju stvarnom ponašanju:
- Prikuplja li aplikacija podatke? **Da.**
- **Lokacija → Precizna lokacija:**
  - Prikuplja se: **Da.** Deli se sa trećim licem: **Da** (koordinate rute idu OSRM servisu, tekst pretrage Nominatim servisu — radi predloga rute/pretrage adrese).
  - Svrha: **Funkcionalnost aplikacije.** Nije za reklame ni analitiku.
  - Obavezno za korišćenje: **Ne** (lokacija je potrebna samo za merenje/mapu).
- Ostali tipovi (lični podaci, kontakti, fotografije, finansije, audio): **ne prikupljaju se.**
- Šifrovano u prenosu: **Da** (HTTPS).
- Brisanje: podaci su samo na telefonu; brišu se brisanjem vožnji/podataka/aplikacije.

---

## 6. Ocena sadržaja (content rating)
Play Console → **App content → Content rating** → popuni upitnik.
- Kategorija: uslužna/alat. Bez nasilja, seksualnog sadržaja, kockanja.
- Rezultat: verovatno „Everyone / PEGI 3".

## 7. Ciljna publika i sadržaj
Play Console → **App content → Target audience and content**.
- Ciljna grupa: **odrasli (18+)** ili 16+ — aplikacija je za vozače/kurire, **nije za decu**.
- Potvrdi da aplikacija nije usmerena na decu.

---

## 8. Kategorija i kontakt
Play Console → **Store settings**.
- Kategorija aplikacije: **Auto i vozila** (ili Alati).
- Kontakt e-mail: **dostavimisd@gmail.com**
- Veb-sajt (opciono): **https://taximetarbalkan.web.app**

---

## 9. Otpremanje i testiranje
1. **Prvo interno testiranje** (Internal testing track):
   - Play Console → **Testing → Internal testing → Create new release**.
   - Otpremi `app-release.aab`. Prihvati **Play App Signing**.
   - Dodaj sebe (i kolege) kao testere (e-mail lista). Instaliraj sa linka i proveri da sve radi sa Play verzije.
2. Kad je interno OK → **Production → Create new release** → isti AAB (ili novi sa većim versionCode).
   - Popuni „Release notes" (šta je novo) SR i EN.
3. Pošalji na pregled (**Send for review**). Pregled traje obično par dana.

---

## 10. Najčešći razlozi odbijanja — i kako smo ih izbegli
- **Foreground location bez deklaracije/videa** → deklaracija + video iz koraka 4. (Najčešći uzrok.)
- **Data safety se ne poklapa sa stvarnim ponašanjem** → odgovori iz koraka 5 (lokacija se deli sa OSRM/Nominatim).
- **Nema politike privatnosti ili ne pominje lokaciju** → objavljena, pominje lokaciju (korak 3).
- **Obmanjujuće tvrdnje** (da je „zvanični/overeni taksimetar") → svuda stoji napomena „nije overeni taksimetar ni fiskalni uređaj" (prvo pokretanje, O aplikaciji, račun, opis).
- **BLUETOOTH_SCAN kao lokacija** → označen `neverForLocation`; stare BT dozvole samo do API 30.
- **Nizak targetSdk** → targetSdk 36, iznad minimuma.
- **Podaci u prodavničkim snimcima** → ako ne želiš svoje cene/zaradu na snimcima, zameni ih pre objave.

---

## 11. Posle objave
- Sačuvaj `app-release.aab` i mapu simbola `build/debug-info/` (za čitanje izveštaja o padovima — obfuskovani stek se bez nje ne može dešifrovati).
- Za svako sledeće izdanje: povećaj `versionCode` u `pubspec.yaml` (`1.0.0+2`, `+3`…), pa `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`.
- Sledeći razvoj (posle objave): „prvi km" i doplate (jedna migracija), pa Premium (Play Billing), pa firmin paket.

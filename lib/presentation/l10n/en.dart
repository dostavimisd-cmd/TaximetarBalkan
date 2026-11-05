/// Engleski prevodi (ključ = srpski tekst iz aplikacije).
/// Test test/presentation/translations_test.dart pada ako neki tekst nema prevod.
const Map<String, String> enStrings = {
  // ---- prvo pokretanje, O aplikaciji, uputstvo za bateriju
  'Pre nego što počneš':
      'Before you start',
  'Pomoćni program za evidenciju vožnji. Nije overeni taksimetar niti fiskalni uređaj.':
      'Auxiliary program for recording rides. It is not a certified taximeter or a fiscal device.',
  'PRIHVATAM':
      'I ACCEPT',
  'O aplikaciji':
      'About',
  'Verzija {0} ({1})':
      'Version {0} ({1})',
  'Politika privatnosti':
      'Privacy policy',
  'Adresa će biti objavljena pre izlaska u prodavnicu.':
      'The address will be published before the store release.',
  'Podaci mape':
      'Map data',
  'Veb-sajt':
      'Website',
  'Kontakt':
      'Contact',
  'Telefon (WhatsApp i Viber):':
      'Phone (WhatsApp and Viber):',
  'Ne mogu da otvorim vezu.':
      'Cannot open the link.',
  'Štampaj račun na kraju vožnje':
      'Print the receipt when the ride ends',
  'Račun se sam šalje na štampač kad završiš vožnju.':
      'The receipt is sent to the printer automatically when you end the ride.',
  'REZERVNA KOPIJA':
      'BACKUP',
  'Tarife, relacije, vožnje, podešavanja i logo u jednom fajlu. Sačuvaj ga na Drive ili pošalji sebi, pa ga vrati na novom telefonu.':
      'Tariffs, routes, rides, settings and logo in one file. Save it to Drive or send it to yourself, then restore it on a new phone.',
  'Sačuvaj kopiju':
      'Save backup',
  'Vrati iz kopije':
      'Restore backup',
  'Poništi poslednje vraćanje':
      'Undo last restore',
  'Vrati podatke iz kopije?':
      'Restore data from backup?',
  'Sve tarife, relacije, vožnje i podešavanja na ovom telefonu biće zamenjeni podacima iz kopije. Trenutni podaci se čuvaju, pa vraćanje možeš da poništiš.':
      'All tariffs, routes, rides and settings on this phone will be replaced with the backup. Current data is kept, so you can undo the restore.',
  'Otkaži':
      'Cancel',
  'IZABERI FAJL':
      'CHOOSE FILE',
  'Podaci su vraćeni iz kopije.':
      'Data restored from backup.',
  'Kopija nije napravljena: {0}':
      'Backup was not created: {0}',
  'Vožnja je u toku. Završi je pa vrati kopiju.':
      'A ride is in progress. End it, then restore the backup.',
  'Fajl nije rezervna kopija ove aplikacije.':
      'This file is not a backup of this app.',
  'Kopija je napravljena novijom verzijom aplikacije. Prvo ažuriraj aplikaciju.':
      'The backup was made with a newer app version. Update the app first.',
  'Rezervna kopija je oštećena.':
      'The backup is damaged.',
  'Broj':
      'No.',
  'CSV (Excel, za knjigovođu)':
      'CSV (Excel, for the accountant)',
  'Datum':
      'Date',
  'Izvezi izveštaj':
      'Export report',
  'Izveštaj':
      'Report',
  'Izvoz nije uspeo: {0}':
      'Export failed: {0}',
  'Km':
      'Km',
  'Kraj':
      'End',
  'Napomena':
      'Note',
  'Nema vožnji u ovom periodu.':
      'No rides in this period.',
  'PDF (za štampu i slanje)':
      'PDF (to print and send)',
  'Početak':
      'Start',
  'Smena':
      'Shift',
  'Taksimetar Balkan — pomoćni alat za evidenciju, nije fiskalni dokument.':
      'Taksimetar Balkan — auxiliary record-keeping tool, not a fiscal document.',
  'Trajanje':
      'Duration',
  'Ukupno (din)':
      'Total (RSD)',
  'prekinuta':
      'interrupted',
  'Čekanje (din)':
      'Waiting (RSD)',
  '+{0} din':
      '+{0} RSD',
  'DOPLATA':
      'EXTRA',
  'DOPLATE':
      'EXTRAS',
  'Dodaj doplatu':
      'Add extra',
  'Dodato u ovoj vožnji':
      'Added in this ride',
  'Doplata':
      'Extra',
  'Drugi iznos':
      'Other amount',
  'Dugme „+” tokom vožnje dodaje doplatu na cenu (posle minimalne).':
      'The "+" button during a ride adds an extra to the price (after the minimum).',
  'Iznos (din)':
      'Amount (RSD)',
  'Prvi km (din/km)':
      'First km (RSD/km)',
  'Prazno = kao ostali km. 0 = prvi km je uračunat u start.':
      'Empty = same as other km. 0 = the first km is included in the start.',
  'Stalne doplate (npr. prtljag) unosiš u Podešavanjima.':
      'Set up regular extras (e.g. luggage) in Settings.',
  'Ukloni':
      'Remove',
  'Naziv doplate je obavezan.':
      'Extra name is required.',
  'Čekam GPS lokaciju…':
      'Waiting for GPS location…',
  'Uskladi km sa zvaničnim taksimetrom':
      'Match km with the official taximeter',
  'Uskladi sa zvaničnim taksimetrom':
      'Match with the official taximeter',
  'Upiši km sa zvaničnog taksimetra (npr. 12,35). Razlika može biti najviše ±50%.':
      'Enter the km shown by the official taximeter (e.g. 12.35). The difference can be at most ±50%.',
  'Aplikacija je izmerila {0} km (bez kalibracije). Koliko km je pokazao zvanični taksimetar za ovu vožnju?':
      'The app measured {0} km (without calibration). How many km did the official taximeter show for this ride?',
  'Zvanični taksimetar (km)':
      'Official taximeter (km)',
  'IZRAČUNAJ':
      'CALCULATE',
  'Nova kalibracija: {0} %':
      'New calibration: {0} %',
  'Trenutno: {0} %. Važi od sledeće vožnje; završene vožnje se ne menjaju. Za tačniji rezultat uporedi dužu vožnju (5 km i više).':
      'Current: {0} %. Applies from the next ride; finished rides do not change. For a more accurate result compare a longer ride (5 km or more).',
  'Kalibracija sačuvana: {0} %':
      'Calibration saved: {0} %',
  'Prvi km: uračunat u start (ne naplaćuje se posebno)':
      'First km: included in the base fare (not charged separately)',
  'Prvi km: {0} din/km':
      'First km: {0} RSD/km',
  'CILJ ZARADE':
      'EARNINGS GOAL',
  'Cilj ostvaren: {0} / {1} din':
      'Goal reached: {0} / {1} RSD',
  'Cilj za ovu smenu':
      'Goal for this shift',
  'Cilj zarade (din)':
      'Earnings goal (RSD)',
  'Cilj: {0} / {1} din':
      'Goal: {0} / {1} RSD',
  'Dodaj trošak':
      'Add expense',
  'Iznos po želji; može se promeniti i pri početku smene.':
      'Any amount; can also be changed when a shift starts.',
  'OSTAJE':
      'REMAINING',
  'Počni smenu':
      'Start shift',
  'Prikaži cilj na glavnom ekranu':
      'Show goal on the main screen',
  'TROŠKOVI':
      'EXPENSES',
  'Traka napretka: zarada otvorene smene (ili današnja) prema cilju.':
      'Progress bar: earnings of the open shift (or today) towards the goal.',
  'Trošak':
      'Expense',
  'U toku od {0}':
      'Running since {0}',
  'Unesi cilj zarade (ceo broj dinara) ili isključi cilj.':
      'Enter an earnings goal (whole RSD) or turn the goal off.',
  'ZARADA':
      'EARNINGS',
  'Završi smenu':
      'End shift',
  'Neispravan cilj zarade.':
      'Invalid earnings goal.',
  'Naziv troška je obavezan.':
      'Expense name is required.',
  'Gorivo':
      'Fuel',
  'Pranje':
      'Car wash',
  'Parking':
      'Parking',
  'Ostalo':
      'Other',
  'Ekran za putnika':
      'Passenger screen',
  'Kilometraža ({0} km)':
      'Distance ({0} km)',
  'Pomoćni taksimetar · nije overeni taksimetar ni fiskalni uređaj':
      'Auxiliary taximeter · not a certified taximeter or fiscal device',
  'RELACIJA':
      'ROUTE',
  'TARIFA':
      'TARIFF',
  'VOŽNJA U TOKU':
      'RIDE IN PROGRESS',
  'ZA NAPLATU':
      'AMOUNT DUE',
  'Zatvori':
      'Close',
  'Čekanje ({0})':
      'Waiting ({0})',
  'Glasovni unos nije dostupan; koristi mikrofon na tastaturi.':
      'Voice input is not available; use the microphone on the keyboard.',
  'Ukloni iz omiljenih':
      'Remove from favourites',
  'Dodaj u omiljene':
      'Add to favourites',
  'Glasovni unos':
      'Voice input',
  'Traži':
      'Search',
  'Omiljene adrese':
      'Favourite addresses',
  'Vibracija i zvuk':
      'Vibration and sound',
  'Kratak signal kad vožnja počne, stane na pauzu, nastavi se ili završi.':
      'A short signal when a ride starts, pauses, resumes or ends.',
  'Telefon može da ugasi taksimetar kad je ekran zaključan. Da se to ne desi, isključi ograničenja baterije za ovu aplikaciju.':
      'The phone may shut the taximeter down while the screen is locked. To prevent that, turn off battery restrictions for this app.',
  'OTVORI PODEŠAVANJA BATERIJE':
      'OPEN BATTERY SETTINGS',
  'Samsung':
      'Samsung',
  'Xiaomi / Redmi / POCO':
      'Xiaomi / Redmi / POCO',
  'Honor / Huawei':
      'Honor / Huawei',
  'Motorola':
      'Motorola',
  'Lenovo':
      'Lenovo',
  'Ostali telefoni':
      'Other phones',
  'Podešavanja → Aplikacije → Taksimetar Balkan → Baterija → izaberi "Neograničeno".':
      'Settings → Apps → Taksimetar Balkan → Battery → choose "Unrestricted".',
  'Podešavanja → Baterija → Ograničenja pozadinske upotrebe → "Aplikacije koje nikad ne spavaju" → dodaj Taksimetar Balkan.':
      'Settings → Battery → Background usage limits → "Never sleeping apps" → add Taksimetar Balkan.',
  'Zaključaj aplikaciju u listi nedavnih aplikacija.':
      'Lock the app in the recent apps list.',
  'Podešavanja → Aplikacije → Upravljanje aplikacijama → Taksimetar Balkan → uključi "Autostart".':
      'Settings → Apps → Manage apps → Taksimetar Balkan → turn on "Autostart".',
  'Isto mesto → Ušteda baterije → izaberi "Bez ograničenja".':
      'Same place → Battery saver → choose "No restrictions".',
  'Podešavanja → Baterija → Pokretanje aplikacija → Taksimetar Balkan → isključi "Upravljaj automatski".':
      'Settings → Battery → App launch → Taksimetar Balkan → turn off "Manage automatically".',
  'Uključi sva tri prekidača: automatsko pokretanje, pokretanje iz druge aplikacije i rad u pozadini.':
      'Turn on all three switches: auto-launch, secondary launch and run in background.',
  'Podešavanja → Baterija → Optimizacija baterije → Sve aplikacije → Taksimetar Balkan → "Ne optimizuj".':
      'Settings → Battery → Battery optimization → All apps → Taksimetar Balkan → "Don’t optimize".',
  'Ako postoji "Upravljanje energijom" ili "Rad u pozadini", dozvoli radu aplikacije u pozadini.':
      'If there is "Power management" or "Background activity", allow the app to run in the background.',
  'Podešavanja → Aplikacije → Taksimetar Balkan → Baterija → izaberi "Bez ograničenja" (ili "Ne optimizuj").':
      'Settings → Apps → Taksimetar Balkan → Battery → choose "Unrestricted" (or "Don’t optimize").',
  'Ako telefon ima "Autostart" ili "Rad u pozadini", uključi ga za ovu aplikaciju.':
      'If the phone has "Autostart" or "Background activity", turn it on for this app.',

  // ---- glavni ekran
  'POMOĆNI TAKSIMETAR': 'AUXILIARY METER',
  'PAUZIRANO': 'PAUSED',
  'ČEKANJE (< {0} km/h)': 'WAITING (< {0} km/h)',
  'VOŽNJA': 'DRIVING',
  'DISTANCA': 'DISTANCE',
  'ČEKANJE': 'WAITING',
  'START': 'BASE',
  'Fiksno: {0}': 'Fixed: {0}',
  'Start': 'Base fare',
  'Kilometraža': 'Distance',
  'Čekanje': 'Waiting',
  'Dopuna do minimalne': 'Minimum fare top-up',
  'ŠTAMPAJ RAČUN': 'PRINT RECEIPT',
  'GPS signal prekidan {0}× (ukupno {1})': 'GPS signal lost {0}× (total {1})',
  'NOVA VOŽNJA': 'NEW RIDE',
  'NASTAVI': 'RESUME',
  'PAUZA': 'PAUSE',
  'ZAVRŠI': 'END',
  'POVEŽI SE PONOVO': 'RECONNECT',
  'DODAJ TARIFU': 'ADD TARIFF',
  'POKRENI (START)': 'START RIDE',
  'AUTO': 'AUTO',
  'PRAZNIK': 'HOLIDAY',
  'FIKSNO': 'FIXED',
  'RELACIJE': 'ROUTES',
  'Ukupno': 'Total',
  'UKUPNO': 'TOTAL',

  // ---- meni
  'TAKSIMETAR': 'TAXIMETER',
  'Balkan Pro Edition': 'Balkan Pro Edition',
  'Istorija vožnji': 'Ride history',
  'Izveštaji': 'Reports',
  'Tarife': 'Tariffs',
  'Podešavanja': 'Settings',
  'Optimizacija baterije': 'Battery optimization',
  'Uputstvo za rad u pozadini': 'How to keep it running in the background',
  'Pravna napomena:': 'Legal notice:',
  'Ova aplikacija je pomoćni alat za internu evidenciju i procenu troškova, a ne overeni službeni taksimetar.':
      'This app is an auxiliary tool for internal records and fare estimates, not a certified official taximeter.',
  'Rad u pozadini bez prekida': 'Uninterrupted background operation',
  'Za neprekidan rad kada je ekran zaključan:\n\n1. Isključite "Battery Optimization" za ovu aplikaciju.\n2. Dozvolite "Autostart" / rad u pozadini (posebno za Xiaomi, Huawei i Samsung uređaje).\n3. Zaključajte aplikaciju u listi nedavnih aplikacija.':
      'For uninterrupted operation while the screen is locked:\n\n1. Turn off "Battery Optimization" for this app.\n2. Allow "Autostart" / background activity (especially on Xiaomi, Huawei and Samsung devices).\n3. Lock the app in the recent apps list.',
  'RAZUMEM': 'GOT IT',

  // ---- zajednička dugmad i poruke
  'SAČUVAJ': 'SAVE',
  'ODUSTANI': 'CANCEL',
  'OBRIŠI': 'DELETE',
  'OBRIŠI SVE': 'DELETE ALL',
  'IZABERI': 'CHOOSE',
  'Greška: {0}': 'Error: {0}',
  'Nema rezultata.': 'No results.',
  'Naziv': 'Name',
  '{0} din': '{0} RSD',
  '{0} km': '{0} km',
  '{0} EUR': '{0} EUR',
  'RSD  ·  {0} EUR': 'RSD  ·  {0} EUR',
  'u toku': 'in progress',
  '© OpenStreetMap contributors': '© OpenStreetMap contributors',
  'Podaci © OpenStreetMap contributors': 'Data © OpenStreetMap contributors',

  // ---- istorija i rezime vožnje
  'Greška pri čitanju istorije: {0}': 'Could not read the history: {0}',
  'Još nema završenih vožnji.': 'No finished rides yet.',
  'PREKINUTA': 'INTERRUPTED',
  'Vožnja': 'Ride',
  'Obriši vožnju': 'Delete ride',
  'Obrisati vožnju?': 'Delete this ride?',
  '{0} · {1} din\nBrisanje se ne može poništiti.':
      '{0} · {1} RSD\nThis cannot be undone.',
  'VOŽNJA PREKINUTA · iznos do poslednjeg snimka':
      'RIDE INTERRUPTED · amount up to the last save',
  'TRAJANJE': 'DURATION',
  'PROSEČNA BRZINA': 'AVERAGE SPEED',
  'POČETAK': 'START',
  'KRAJ': 'END',
  'Fiksna cena': 'Fixed fare',
  'Ruta nije zabeležena (vožnja je kratka ili je počela pre ove verzije).':
      'Route not recorded (the ride was short or started before this version).',
  'Prekidi GPS signala: {0} (ukupno {1})': 'GPS signal gaps: {0} (total {1})',
  'naplaćeno kao čekanje': 'charged as waiting time',
  'dodata vazdušna linija {0} m': 'straight-line distance added: {0} m',
  'servis zaustavljen, nije mereno': 'service stopped, not measured',
  'nije obračunato': 'not charged',
  'Pomoćni alat za evidenciju i procenu, nije overeni službeni taksimetar ni fiskalni uređaj.':
      'Auxiliary tool for records and estimates; not a certified official taximeter or fiscal device.',

  // ---- izveštaji i smene
  'MESEC': 'MONTH',
  'SMENA': 'SHIFT',
  'POČNI SMENU': 'START SHIFT',
  'ZAVRŠI SMENU': 'END SHIFT',
  'Još nema smena.': 'No shifts yet.',
  'Vožnji': 'Rides',
  '{0} (prekinuto {1})': '{0} ({1} interrupted)',
  'Prosek po vožnji': 'Average per ride',
  'Po satu vožnje': 'Per hour of driving',
  'Po satu smene': 'Per shift hour',
  'Po kilometru': 'Per kilometre',
  'Trajanje smene': 'Shift duration',
  'Vreme u vožnji': 'Time driving',
  'Od toga čekanje': 'Of which waiting',
  'Pređeno (GPS)': 'Distance (GPS)',

  // ---- tarife
  'TARIFE': 'TARIFFS',
  'NOVA TARIFA': 'NEW TARIFF',
  'Još nema tarifa. Unesi tarifu koju primenjuješ.':
      'No tariffs yet. Enter the tariff you use.',
  'Start: {0} | Km: {1} | Čekanje/min: {2} | Min: {3}':
      'Base: {0} | Km: {1} | Waiting/min: {2} | Min: {3}',
  'Raspored': 'Schedule',
  'Automatski izbor je uključen: pri startu važe praznici pa raspored. Ručno izabrana tarifa važi kad nijedno pravilo ne važi.':
      'Automatic selection is on: at start, holidays apply first, then the schedule. The manually chosen tariff applies when no rule matches.',
  'FIKSNA RELACIJA (sledeća vožnja)': 'FIXED ROUTE (next ride)',
  'Bez fiksne relacije (taksimetar)': 'No fixed route (meter)',
  'Izmena tarife': 'Edit tariff',
  'Start (din)': 'Base fare (RSD)',
  'Cena po km (din)': 'Price per km (RSD)',
  'Čekanje po minutu (din, npr. 13,4)': 'Waiting per minute (RSD, e.g. 13.4)',
  'Minimalna cena (din)': 'Minimum fare (RSD)',
  'Popuni sva polja. Čekanje može sa zarezom (npr. 13,4), ostalo celim brojevima.':
      'Fill in all fields. Waiting may have decimals (e.g. 13.4); the rest must be whole numbers.',
  'Izaberi bar jedan dan rasporeda ili isključi raspored.':
      'Choose at least one schedule day or turn the schedule off.',
  'Raspored (automatski izbor)': 'Schedule (automatic selection)',
  'Važi kad je u podešavanjima uključen automatski izbor tarife.':
      'Applies when automatic tariff selection is on in Settings.',
  ' (preko ponoći)': ' (over midnight)',

  // ---- praznici
  'Praznici': 'Holidays',
  '(obrisana tarifa)': '(deleted tariff)',
  'Prvo unesi bar jednu tarifu.': 'Enter at least one tariff first.',
  'Nema praznika. Dodaj datume kada primenjuješ posebnu tarifu (npr. praznična).':
      'No holidays. Add the dates when you use a special tariff (e.g. holiday tariff).',
  'Novi praznik': 'New holiday',
  'Izmena praznika': 'Edit holiday',
  'Svake godine': 'Every year',
  '{0}.{1}. svake godine': '{0}.{1}. every year',

  // ---- fiksne relacije
  'Fiksne relacije': 'Fixed routes',
  'FIKSNE RELACIJE': 'FIXED ROUTES',
  'Uvezi spisak': 'Import list',
  'Obriši sve': 'Delete all',
  'Obrisati sve relacije?': 'Delete all routes?',
  'Biće obrisano {0} relacija. Istorija vožnji ostaje.':
      '{0} routes will be deleted. Ride history stays.',
  'Nema relacija. Dodaj ih ručno (+) ili uvezi ceo spisak odjednom (gore).':
      'No routes. Add them by hand (+) or import a whole list at once (top).',
  'Nema relacija (Podešavanja → Fiksne relacije)':
      'No routes (Settings → Fixed routes)',
  'Pretraga ({0} relacija)': 'Search ({0} routes)',
  'Pretraga ({0})': 'Search ({0})',
  'Nova relacija': 'New route',
  'Izmena relacije': 'Edit route',
  'Naziv (npr. Aerodrom)': 'Name (e.g. Airport)',
  'Od (opciono)': 'From (optional)',
  'Do (opciono)': 'To (optional)',
  'Fiksna cena (din)': 'Fixed fare (RSD)',
  'Unesi cenu celim brojem.': 'Enter the price as a whole number.',
  'Uvoz fiksnih relacija': 'Import fixed routes',
  'Jedan red = jedna relacija:\nNaziv ; Od ; Do ; Cena\nNaziv ; Cena\nNaziv - Cena':
      'One line = one route:\nName ; From ; To ; Price\nName ; Price\nName - Price',
  'Nalepi spisak ovde': 'Paste the list here',
  'Izaberi fajl (.txt)': 'Choose file (.txt)',
  'Nalepi iz klipborda': 'Paste from clipboard',
  'Fajl nije mogao da se pročita: {0}': 'The file could not be read: {0}',
  'Prepoznato relacija: {0}': 'Routes recognized: {0}',
  '… i još {0}': '… and {0} more',
  'Preskočeno redova: {0}': 'Lines skipped: {0}',
  'red {0}: {1}': 'line {0}: {1}',
  'UVEZI ({0})': 'IMPORT ({0})',
  'Uvezeno: {0} novih, {1} izmenjenih (cena).':
      'Imported: {0} new, {1} updated (price).',
  'Uvoz nije uspeo: {0}': 'Import failed: {0}',

  // ---- podešavanja
  'OBRAČUN': 'FARE',
  'Čekanje se računa ispod (km/h)': 'Waiting is charged below (km/h)',
  'Ceo broj {0}–{1}. Ispod ove brzine taksimetar računa čekanje umesto kilometara.':
      'Whole number {0}–{1}. Below this speed the meter charges waiting time instead of distance.',
  'Kalibracija distance (%)': 'Distance calibration (%)',
  '0 = bez korekcije; 2,5 = distanca +2,5%. Uskladi sa zvaničnim taksimetrom.':
      '0 = no correction; 2.5 = distance +2.5%. Match it to the official taximeter.',
  'GPS': 'GPS',
  'Najveća dozvoljena nepreciznost (m)': 'Maximum allowed inaccuracy (m)',
  'Ceo broj {0}–{1}. Tačke sa lošijom procenom tačnosti se odbacuju. Manje = strože.':
      'Whole number {0}–{1}. Points with worse estimated accuracy are discarded. Lower = stricter.',
  'Automatski izbor tarife pri startu': 'Automatic tariff selection at start',
  'Prvo praznici, pa raspored tarife (dani i vreme). Tarifa se ne menja tokom vožnje.':
      'Holidays first, then the tariff schedule (days and times). The tariff does not change during a ride.',
  'PRIKAZ': 'DISPLAY',
  'Jezik': 'Language',
  'Valuta prikaza': 'Display currency',
  'Kurs: dinara za 1 EUR': 'Exchange rate: RSD per 1 EUR',
  'Samo za prikaz u EUR. Obračun je uvek u dinarima.':
      'Only for showing EUR. Fares are always calculated in RSD.',
  'EKRAN': 'SCREEN',
  'Osvežavanje cene (s)': 'Price refresh (s)',
  '1 = odmah. Duže osvežavanje samo usporava prikaz; obračun i konačna cena su isti.':
      '1 = instant. A longer refresh only slows the display; the fare and final price are the same.',
  'Ekran uvek uključen': 'Keep screen on',
  'Dok je aplikacija otvorena ekran se ne gasi, cena se stalno vidi (troši više baterije).':
      'While the app is open the screen stays on and the fare is always visible (uses more battery).',
  'Boja cene': 'Fare colour',
  'Veličina cene: {0} %': 'Fare size: {0} %',
  'GLAS': 'VOICE',
  'Najavi cenu na kraju vožnje': 'Announce the fare at the end of the ride',
  'Telefon izgovori ukupan iznos. Koristi sintetizator govora telefona.':
      'The phone speaks the total. Uses the phone’s text-to-speech.',
  'IZGLED': 'APPEARANCE',
  'Prikaži mapu': 'Show map',
  'OpenStreetMap (besplatno). Podloge traže internet; obračun radi i bez mape.':
      'OpenStreetMap (free). Map tiles need internet; fares work without the map.',
  'Pozadina': 'Background',
  'Promeni sliku': 'Change image',
  'ŠTAMPAČ RAČUNA': 'RECEIPT PRINTER',
  'Štampač nije izabran': 'No printer selected',
  'Bluetooth, 58 mm (npr. PT-210)': 'Bluetooth, 58 mm (e.g. PT-210)',
  'Upareni uređaji': 'Paired devices',
  'Nema uparenih uređaja. Upari štampač u Bluetooth podešavanjima telefona (PIN je obično 0000 ili 1234).':
      'No paired devices. Pair the printer in the phone’s Bluetooth settings (PIN is usually 0000 or 1234).',
  'Štampač: {0}': 'Printer: {0}',
  'Naša slova (č ć ž š đ): "Kao slika" uvek radi. Za brži tekst odštampaj probnu stranicu i izaberi slovo reda koji je ispravan.':
      'Serbian letters (č ć ž š đ): "As image" always works. For faster text, print a test page and choose the letter of the line that looks right.',
  'Probna štampa': 'Test print',
  'Prvo izaberi štampač.': 'Choose a printer first.',
  'Probna štampa nije uspela: {0}': 'Test print failed: {0}',
  'Logo firme na računu': 'Company logo on receipt',
  'Promeni logo': 'Change logo',
  'Bez logoa': 'No logo',
  'Zaglavlje računa (naziv, telefon…)': 'Receipt header (name, phone…)',
  'Svaki red posebno. Na dnu računa uvek piše da nije fiskalni.':
      'One item per line. The bottom of the receipt always says it is not a fiscal receipt.',
  'RAD U POZADINI': 'BACKGROUND OPERATION',
  'Da taksimetar ne bi bio ugašen na zaključanom ekranu, isključi optimizaciju baterije za aplikaciju i dozvoli rad u pozadini.':
      'To keep the meter running while the screen is locked, turn off battery optimization for the app and allow background activity.',
  'Otvori podešavanja aplikacije': 'Open app settings',
  'Unesi brzinu za čekanje (ceo broj km/h).':
      'Enter the waiting speed (whole number, km/h).',
  'Kalibracija: procenat od -50 do 50, npr. 2,5 ili -1.':
      'Calibration: a percentage from -50 to 50, e.g. 2.5 or -1.',
  'Unesi GPS tačnost (ceo broj metara).':
      'Enter the GPS accuracy (whole number of metres).',
  'Kurs: npr. 117,2 (najviše 3 decimale).':
      'Exchange rate: e.g. 117.2 (up to 3 decimals).',
  'Za prikaz u EUR unesi kurs.': 'Enter an exchange rate to show EUR.',

  // ---- boje cene
  'Bela': 'White',
  'Crvena': 'Red',
  'Zelena': 'Green',
  'Plava': 'Blue',
  'Žuta': 'Yellow',
  'Narandžasta': 'Orange',

  // ---- mapa i pretraga adrese
  'Kuda se vozi?': 'Where to?',
  'Ulica i broj, grad': 'Street and number, city',
  'Unesi bar 3 slova adrese.': 'Enter at least 3 letters of the address.',
  'Ništa nije pronađeno. Probaj sa nazivom grada.':
      'Nothing found. Try adding the city name.',
  'Pretraga nije uspela (internet?): {0}': 'Search failed (internet?): {0}',
  'ZATVORI': 'CLOSE',
  'Trenutna lokacija nije poznata; prikazujem samo odredište.':
      'Current location unknown; showing the destination only.',
  'Ruta nije dostupna (internet?): {0}': 'Route unavailable (internet?): {0}',
  '\nFiksna cena: {0} din': '\nFixed fare: {0} RSD',
  '\n≈ {0} din (bez čekanja)': '\n≈ {0} RSD (without waiting)',

  // ---- dopuna (naslovi i dugmad)
  'Nije moguće menjati tarifu tokom aktivne vožnje!':
      'The tariff cannot be changed during a ride!',
  'Nova tarifa': 'New tariff',
  'PODELI': 'SHARE',
  'ŠTAMPAJ': 'PRINT',
  'Vožnja završena': 'Ride finished',
  'Štampam…': 'Printing…',

  // vrednosti izbora pozadine (prikazuju se velikim slovima)
  'crna': 'black',
  'logo': 'logo',

  // ---- izveštaji (segmenti)
  'DAN': 'DAY',
  'NED.': 'WEEK',

  // ---- poruke servisa i kontrolera (cele)
  'Servis ne odgovara.': 'The meter service is not responding.',
  'Servis nije radio; vožnja nije nastavljena.':
      'The service was not running; the ride was not resumed.',
  'Servis nije radio; vožnja nije zatvorena u bazi.':
      'The service was not running; the ride was not closed in the database.',
  'GPS je isključen. Uključi lokaciju na telefonu.':
      'GPS is off. Turn on location on the phone.',
  'Dozvola za lokaciju je trajno odbijena. Uključi je u podešavanjima telefona.':
      'Location permission is permanently denied. Enable it in the phone settings.',
  'Za rad taksimetra potrebna je dozvola za lokaciju.':
      'The taximeter needs location permission.',
  'Uključi "Preciznu lokaciju" za ovu aplikaciju u podešavanjima telefona.':
      'Turn on "Precise location" for this app in the phone settings.',
  'Notifikacije su isključene; obaveštenje o aktivnom taksimetru neće biti prikazano.':
      'Notifications are off; the "meter running" notification will not be shown.',
  'Vožnja je nastavljena posle prekida servisa.':
      'The ride was resumed after the service was interrupted.',
  'Vožnja je već bila aktivna u pozadini.':
      'A ride was already running in the background.',
  'Upozorenje: Problem sa periodičnim čuvanjem u bazu.':
      'Warning: problem with periodic saving to the database.',
  'Neispravna fiksna cena.': 'Invalid fixed fare.',

  // ---- provera unosa (domen)
  'Cene ne smeju biti negativne.': 'Prices cannot be negative.',
  'Naziv tarife je obavezan.': 'Tariff name is required.',
  'Cena relacije mora biti veća od 0.': 'Route price must be greater than 0.',
  'Naziv relacije je obavezan.': 'Route name is required.',
  'Naziv praznika je obavezan.': 'Holiday name is required.',
  'Izaberi tarifu za praznik.': 'Choose a tariff for the holiday.',
  'Neispravan datum.': 'Invalid date.',
  'Neispravan mesec.': 'Invalid month.',
  'Neispravni dani rasporeda.': 'Invalid schedule days.',
  'Vreme rasporeda mora biti od 00:00 do 23:59.':
      'Schedule time must be between 00:00 and 23:59.',
  'Kurs mora biti veći od 0.': 'The exchange rate must be greater than 0.',
  'Kalibracija: od -50 do 50 %.': 'Calibration: from -50 to 50 %.',
  'Nepoznat jezik.': 'Unknown language.',
  'Nepoznata valuta.': 'Unknown currency.',
  'Nepoznata boja cene.': 'Unknown fare colour.',
  'Osvežavanje cene: 1, 4, 6 ili 10 s.': 'Price refresh: 1, 4, 6 or 10 s.',
  'Neispravna kodna strana.': 'Invalid code page.',
  'Zaglavlje računa je predugačko.': 'The receipt header is too long.',
};

/// Poruke sa promenljivim krajem: prevodi se početak, ostatak (tehnički opis
/// greške ili vrednosti) ostaje kakav jeste.
const Map<String, String> enMessagePrefixes = {
  'Vraćanje kopije nije uspelo, podaci nisu menjani: ':
      'Restore failed, data was not changed: ',
  'Greška pri povezivanju sa servisom: ': 'Could not connect to the service: ',
  'Greška pri pokretanju servisa: ': 'Could not start the service: ',
  'Neuspelo pokretanje servisa: ': 'Failed to start the service: ',
  'Greška pri kreiranju vožnje: ': 'Could not create the ride: ',
  'Greška pri obradi GPS tačke: ': 'Error processing a GPS point: ',
  'Greška pri obradi komande: ': 'Error processing a command: ',
  'Greška pri oporavku vožnje: ': 'Error recovering the ride: ',
  'Greška pri zatvaranju vožnje: ': 'Error closing the ride: ',
  'Vožnja se ne snima u bazu: ': 'The ride is not being saved: ',
  'Nedostaje obavezno polje tarife: ': 'Missing required tariff field: ',
  'Brzina za čekanje mora biti od ': 'Waiting speed must be from ',
  'GPS tačnost mora biti od ': 'GPS accuracy must be from ',
  'Kalibracija mora biti od ': 'Calibration must be from ',
  'Geolocator greška: ': 'Location error: ',
  'Cena ne sme biti veća od ': 'Price cannot be higher than ',
  'Brzina za čekanje: od ': 'Waiting speed: from ',
  'GPS tačnost: od ': 'GPS accuracy: from ',
  'Veličina cene: od ': 'Fare size: from ',
};

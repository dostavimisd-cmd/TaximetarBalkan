# Poznati problemi i tehnički dug

1. **Android Battery Optimization:** Nismo testirali Background Service na kineskim telefonima (Xiaomi, Honor, Huawei) na terenu. Očekuje se ubijanje procesa na zaključanom ekranu bez whitelist-ovanja aplikacije.
2. **Google Play Zahtevi:** Potrebna je posebna prijava i video objašnjenje za Google Play Store za odobrenje Background Location permisija, kao i striktna deklaracija Foreground Service dozvola u Manifestu.
3. **Kineski štampači (CP1250, ESC/POS):** Translacija karaktera (č,ć,ž,š,đ u c,c,z,s,d) i upravljanje termalnim štampačima treba proveriti u Fazi 4. Pravi modeli hardvera nisu još testirani.
4. **Kalibracija GPS-a:** Nije još ubačen kalibracioni klizač (množilac) koji uparuje pređeni put sa hardverskim taksimetrom.
# Poznati problemi i tehnički dug

1. **Android Battery Optimization:** Nismo testirali Background Service na kineskim telefonima (Xiaomi, Honor, Huawei) na terenu. Očekuje se ubijanje procesa na zakljucanom ekranu bez whitelist-ovanja aplikacije.
2. **Kineski štampači (CP1250):** Translacija karaktera (č,ć,ž,š,đ u c,c,z,s,d) za jeftine Bluetooth štampače zahteva implementaciju ESC/POS protokola, što je ostavljeno za Fazu 4.
3. **Kalibracija GPS-a:** Nije još ubačen kalibracioni klizač (množilac) koji uparuje pređeni put sa hardverskim taksimetrom.
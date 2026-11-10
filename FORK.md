# Ein-Nutzer-Build (Fork mdornseif/iPanoramax)

Schlanke Aufnahme-App auf den Paketen von
[pascalpvk/iPanoramax](https://github.com/pascalpvk/iPanoramax). Die Pakete
(`PanoramaxKit`, `ImageMetadataKit`, `GeoKit`) bleiben unverändert, damit
Verbesserungen von upstream leicht übernommen werden können. Alles Eigene
liegt in `App/iPanoramax/`.

## Was die App macht

- **GPS-Sperre:** GPS und Kompass laufen dauerhaft, solange die App offen ist.
  Der Auslöser ist gesperrt, bis die Position genauer als das eingestellte
  Limit (Standard 10 m) und höchstens 3 s alt ist. Ein per Bluetooth
  gekoppelter MFi-GNSS-Empfänger wirkt automatisch.
- **Einzelfoto:** landet in einer Tages-Serie „Einzelfotos <Datum>“.
- **Serie:** automatisches Auslösen alle N Meter (3/5/10/20 m), Bildschirm
  bleibt an.
- **Metadaten:** GPS, Zeit, Genauigkeit und Kurs (GPS-Kurs ab 7 km/h, sonst
  Kompass) werden ohne Neukompression ins JPEG geschrieben.
- **Upload:** im Vordergrund, pro Serie ein Upload-Set. Bricht er ab, wird
  dasselbe Set weiterverwendet und nur der Rest geschickt.
- **Anmeldung:** „generate & claim“ im Browser, Token im Keychain.
- **Ablage:** `Documents/Serien/<uuid>/` mit `series.json` und JPEGs, über die
  Dateien-App sichtbar.

## Bauen

```bash
brew install xcodegen
xcodegen generate --spec App/project.yml
open App/iPanoramax.xcodeproj
```

In Xcode unter *Signing & Capabilities* das eigene Team wählen. Falls die
Bundle-ID `de.dornseif.ipanoramax` schon vergeben ist, in `App/project.yml`
anpassen.

## Bewusst weggelassen

Mehrere Konten, Karte, Hintergrund-Upload, 360°-Panoramen, Lokalisierung,
App-Store-Vorbereitung, XMP-Lage (Yaw/Pitch/Roll).

## Offene Punkte

- Ausrichtung: Das Foto wird über `videoRotationAngle` gedreht; prüfen, ob
  Panoramax Querformat-Serien korrekt anzeigt.
- Kompass bei aufrecht gehaltenem Gerät gegen echte Blickrichtung prüfen.
- Fokus in Serien ggf. auf unendlich fixieren.

# Koha-translations
Koha-Suomi translation files are kept here under lock and key. 

## Käännöstiedostojen päivitys ilman Node.js

### Yleiskuvaus

Skripti `update_koha_po_without_node.sh` (tässä repositoriossa) mahdollistaa Koha-käännöstiedostojen (PO) päivittämisen ilman Node.js:n asennusta palvelimelle. Se korvaa normaalin `gulp po:update` -työkulun täysin Bash- ja gettext-pohjaisella ratkaisulla.

**Mitä skripti tekee:**
1. Luo POT-tiedostot (käännöspohjat) Kohan lähteistä
2. Päivittää PO-tiedostot (käännökset) käännösrepossa POT-tiedostoilla
3. Käyttää samoja Perl-skriptejä kuin gulp (xgettext.pl, xgettext-pref, xgettext-installer)
4. Toimii täysin ilman Node.js:ää, npm:ää tai yarnia

### Esitiedot ja asennus

#### Tarvittavat työkalut

Skripti vaatii vain GNU gettext -työkalut, jotka ovat yleensä jo asennettu:

```bash
# Debian/Ubuntu
sudo apt-get install gettext

# Tarkista että työkalut löytyvät
which msgmerge xgettext msgcat
```

#### Tarvittavat tietovarannot

1. **Koha-repo** - Kohan päärepositorio, josta poimitaan käännettävät merkkijonot
2. **Koha-translations** - Käännösrepo, jossa PO-tiedostot sijaitsevat

```bash
# Tyypillinen hakemistorakenne
/home/koha/
├── Koha/                    # Kohan päärepo
└── Koha-translations/       # Käännösrepo (tämä repo)
    ├── po/                  # PO-tiedostot täällä
    ├── pot/                 # POT-tiedostot (käännöspohjat) täällä
    └── update_koha_po_without_node.sh  # Päivitysskripti
```

### POT- ja PO-tiedostot

#### Mitä ovat POT-tiedostot?

POT (Portable Object Template) -tiedostot ovat **käännöspohjia**:
- Sisältävät kaikki käännettävät merkkijonot Kohan lähdekoodista
- Luodaan automaattisesti Kohan .tt, .pl, .pm, .js, .vue ja .yml -tiedostoista
- Tallennetaan tämän repon `pot/` -hakemistoon
- Nimeltään esim. `Koha-pref.pot`, `Koha-staff-prog.pot`, `Koha-messages-js.pot`

**POT-tiedostotyypit:**
- `marc-MARC21` - MARC21-kentät ja -arvot
- `marc-UNIMARC` - UNIMARC-kentät ja -arvot  
- `marc-NORMARC` - NORMARC-kentät ja -arvot (legacy)
- `staff-prog` - Virkailijaliittymän templatet
- `opac-bootstrap` - Asiakasliittymän templatet
- `opac-prog` - Vanha asiakasliittymä (legacy)
- `pref` - Järjestelmäasetukset
- `messages` - Perl- ja Template Toolkit -viestit
- `messages-js` - JavaScript- ja Vue-viestit
- `installer` - Asennustiedostot
- `installer-MARC21` - MARC21-asennustiedostot
- `installer-UNIMARC` - UNIMARC-asennustiedostot
- `staff-help` - Ohjetekstit (legacy, ei tuettu)

#### Mitä ovat PO-tiedostot?

PO (Portable Object) -tiedostot sisältävät **varsinaiset käännökset**:
- Luodaan POT-tiedostoista tietylle kielelle (esim. fi-FI)
- Nimeltään `<kieli>-<tyyppi>.po`, esim. `fi-FI-pref.po`, `sv-SE-staff-prog.po`
- Tallennetaan `Koha-translations/po/` -hakemistoon
- Päivitetään msgmerge-työkalulla kun POT muuttuu

### Käyttö

#### Peruskäyttö

Yksinkertaisin tapa - päivitä kaikki käännökset:

```bash
cd /home/koha/Koha-translations
./update_koha_po_without_node.sh --koha-path /home/koha/Koha
```

Tämä:
1. Havaitsee automaattisesti että skripti on käännösrepossa
2. Käyttää `./po/` -hakemistoa PO-tiedostoille
3. Käyttää `./pot/` -hakemistoa POT-tiedostoille
4. Luo puuttuvat POT-tiedostot automaattisesti Koha-reposta
5. Päivittää kaikki löytyvät PO-tiedostot

#### Parametrit

```bash
Parametrit:
  -k, --koha-path PATH         Polku Koha-repoon (pakollinen jos ei löydy automaattisesti)
  -r, --translations-path PATH Polku käännösrepoon (oletus: skriptin hakemisto)
  -o, --po-dir PATH           Polku PO-hakemistoon (oletus: ./po)
  -p, --pot-dir PATH          Polku POT-hakemistoon (oletus: ./pot)
  -g, --generate-pot MODE     POT-generointi: auto (oletus), always, never
  -l, --lang LANGS            Kielet pilkulla erotettuna (esim. fi-FI,sv-SE)
  -t, --type TYPES            Tyypit pilkulla erotettuna (esim. pref,messages)
  -c, --copy-to-koha          Kopioi päivitetyt PO-tiedostot Koha-repoon (misc/translator/po/)
  -P, --push-to-github        Commitoi ja pushaa päivitetyt PO/POT-tiedostot GitHubiin (testimpäristöille)
  -n, --dry-run               Testaa ilman muutoksia
  -h, --help                  Näytä ohje
```

#### Esimerkkejä

**Päivitä vain tietyt kielet:**
```bash
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --lang fi-FI,sv-SE
```

**Päivitä vain tietyt tyypit:**
```bash
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --type pref,messages,messages-js
```

**Pakota POT-tiedostojen uudelleengenerointi:**
```bash
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --generate-pot always
```

**Käytä olemassa olevia POT-tiedostoja, älä luo uusia:**
```bash
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --generate-pot never
```

**Tarkista mitä tapahtuisi (ei tee muutoksia):**
```bash
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --dry-run
```

**Ympäristömuuttujilla (jos Koha ei ole viereisessä hakemistossa):**
```bash
export KOHA_PATH=/home/koha/Koha
./update_koha_po_without_node.sh --lang fi-FI
```

**Kopioi PO-tiedostot Koha-repoon päivityksen jälkeen:**
```bash
./update_koha_po_without_node.sh \
  --koha-path /home/koha/Koha \
  --lang fi-FI,sv-SE \
  --copy-to-koha
```

Tämä on hyödyllinen esim. build-skripteissä tai kun halutaan testata käännöksiä Koha-instanssissa.

**Automaattinen päivitys ja GitHub-pushaus (testimpäristöissä):**
```bash
./update_koha_po_without_node.sh \
  --koha-path /home/koha/Koha \
  --generate-pot always \
  --push-to-github
```

Tämä päivittää POT- ja PO-tiedostot, commitoi muutokset ja pushaa GitHubiin automaattisesti. 
**Huom:** Käytä vain testimpäristöissä, ei tuotannossa!

### Tyypilliset työnkulut

#### 1. Viikoittainen käännöspäivitys

```bash
# 1. Päivitä Koha-repo uusimpaan
cd /home/koha/Koha
git pull origin main

# 2. Päivitä käännösrepo uusimpaan
cd /home/koha/Koha-translations
git pull origin main

# 3. Generoi uudet POT-tiedostot ja päivitä PO-tiedostot
cd /home/koha/Koha-translations
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --generate-pot always

# 4. Tarkista muutokset
git status
git diff po/fi-FI-pref.po  # Esimerkki PO-tiedosto
ls -lh pot/                # Tarkista POT-tiedostot

# 5. Commitoi ja pushaa (sekä PO että POT)
git add po/ pot/
git commit -m "Update PO and POT files from latest Koha sources"
git push origin main
```

#### 2. Uuden kielen lisääminen

```bash
# 1. Luo POT-tiedostot ja PO-tiedostot uudelle kielelle (esim. en-GB)
cd /home/koha/Koha-translations

# Luo POT-tiedostot ensin
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --generate-pot always --po-dir /tmp/skippo

# Luo PO-tiedostot POT-tiedostoista
for pot in pot/*.pot; do
  type=$(basename "$pot" .pot | sed 's/^Koha-//')
  msginit -i "$pot" -o "po/en-GB-$type.po" -l en_GB --no-translator
done

# 2. Päivitä juuri luodut PO-tiedostot
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --lang en-GB --generate-pot always
```

#### 3. Vain tiettyjen tyyppien päivitys (nopea)

```bash
# Päivitä vain ne tyypit jotka muuttuvat usein
./update_koha_po_without_node.sh \
  --koha-path /home/koha/Koha \
  --lang fi-FI,sv-SE \
  --type pref,messages-js \
  --generate-pot always
```

#### 4. Integrointi build-release.sh:hon

Voit lisätä automaattisen päivityksen release-buildiin:

```bash
# Lisää build-release.sh:hon ennen käännösten linkitystä:
if test $KOHA_UPDATE_TRANSLATIONS -eq 1 2> /dev/null; then
    echo "\n$self: Pulling latest translations"
    cd $HOME/Koha-translations
    git pull origin "$KOHA_MASTER_BRANCH"
    
    echo "\n$self: Updating PO files from Koha sources and copying to build"
    ./update_koha_po_without_node.sh \
        --koha-path "$BUILD_DIR" \
        --generate-pot always \
        --copy-to-koha || die "Failed to update PO files"
fi
```

**Huom:** `--copy-to-koha` -lippu korvaa aiemman `cp -s --force` -komennon, joka linkitti PO-tiedostot manuaalisesti.

#### 5. Automaattinen päivitys testimpäristössä (cron-ajo)

Testimpäristössä voit ajaa automaattisen päivityksen, joka päivittää POT-tiedostot ja pushaa ne GitHubiin käännettäviksi:

```bash
# Lisää crontab-ajastin (esim. päivittäin klo 02:00)
# crontab -e
0 2 * * * cd /home/koha/Koha-translations && ./update_koha_po_without_node.sh --koha-path /home/koha/Koha --generate-pot always --push-to-github >> /var/log/koha-translations-update.log 2>&1
```

**Tai yksinkertaisempi manuaalinen ajo:**

```bash
cd /home/koha/Koha-translations

# 1. Päivitä Koha-repo
cd /home/koha/Koha && git pull origin main

# 2. Päivitä käännösrepo ja pushaa GitHubiin automaattisesti
cd /home/koha/Koha-translations
./update_koha_po_without_node.sh \
  --koha-path /home/koha/Koha \
  --generate-pot always \
  --push-to-github
```

Tämä:
- Luo/päivittää POT-tiedostot Kohan lähdekoodista
- Päivittää PO-tiedostot
- Commitoi muutokset aikaleimalla ja suodattimilla
- Pushaa GitHubiin automaattisesti

**Commit-viestin muoto:**
- `Update PO and POT files from Koha sources (2026-05-04 14:30)`
- `Update PO and POT files from Koha sources (2026-05-04 14:30) [langs: fi-FI,sv-SE]`
- `Update PO and POT files from Koha sources (2026-05-04 14:30) [langs: fi-FI] [types: pref,messages-js]`

**VAROITUS:** Älä käytä `--push-to-github` -lippua tuotantoympäristössä! Se on tarkoitettu vain testimp\u00e4rist\u00f6ihin, joissa k\u00e4\u00e4nn\u00f6kset p\u00e4ivitet\u00e4\u00e4n automaattisesti.


### Vianmääritys

#### "msgmerge not found"
```bash
# Asenna gettext-työkalut
sudo apt-get install gettext
```

#### "Cannot cd to /path/to/Koha"
```bash
# Tarkista polut
echo $KOHA_PATH
ls -la /home/koha/Koha

# Tai anna polku eksplisiittisesti
./update_koha_po_without_node.sh --koha-path /oikea/polku/Koha
```

#### "No files found for type X"
- Jotkut tyypit (esim. staff-help, opac-prog) ovat vanhoja eivätkä välttämättä ole käytössä
- Tämä on normaalia, skripti jatkaa muiden tyyppien kanssa

#### "Skipping XX-YY-type.po: missing POT"
```bash
# Varmista että POT:it generoidaan
./update_koha_po_without_node.sh --koha-path /home/koha/Koha --generate-pot always

# Tai tarkista että POT-tiedostot löytyvät
ls -la pot/*.pot
```

#### Xgettext-varoitukset Vue-tiedostoista
```
warning: unterminated string
```
- Nämä ovat normaaleja, xgettext ei täysin ymmärrä Vue-syntaksia
- POT-tiedostot luodaan silti oikein

### POT-tiedostojen käyttö muissa skripteissä

Jos haluat käyttää POT-tiedostoja muissa työkaluissa:

```bash
# Generoi vain POT:it, älä päivitä PO-tiedostoja
./update_koha_po_without_node.sh \
  --koha-path /home/koha/Koha \
  --generate-pot always \
  --po-dir /tmp/ei-olemassa  # Ohittaa PO-päivityksen

# POT:it löytyvät nyt täältä
ls -la pot/*.pot

# Voit kopioida ne muualle tarvittaessa
cp pot/*.pot /muu/sijainti/
```

### Vertailu gulp-työnkulkuun

**Perinteinen gulp-työnkulku (vaatii Node.js):**
```bash
cd /home/koha/Koha
yarn install              # Asentaa riippuvuudet
gulp po:update --lang fi-FI  # Päivittää PO:t
```

**Uusi työnkulku (ei vaadi Node.js):**
```bash
cd /home/koha/Koha-translations
./update_koha_po_without_node.sh \
  --koha-path /home/koha/Koha \
  --lang fi-FI
```

**Edut ilman Node.js:ää:**
- Ei tarvitse asentaa Node.js:ää, npm:ää tai yarnia palvelimelle
- Nopeampi (ei node_modules-asennusta)
- Kevyempi (säästää levytilaa)
- Helpompi automatisoida (vähemmän riippuvuuksia)
- Toimii vanhemmilla järjestelmillä ilman Node-päivityksiä

## Nopea PO-kopiointi ja asennus Kohalle

Jos haluat vain kopioida valmiit PO-tiedostot Koha-repoon ja asentaa ne (ilman POT/PO-päivitystä), käytä skriptiä `copy_and_install_translations.sh`.

Skripti tekee kaksi asiaa:
1. Kopioi `po/*.po` -> `Koha/misc/translator/po/`
2. Ajaa Koha-asennuksen: `misc/translator/translate install`

### Esimerkit

**Asenna kaikki kielet:**
```bash
cd /home/koha/Koha-translations
./copy_and_install_translations.sh --koha-path /home/koha/Koha
```

**Asenna vain tietyt kielet:**
```bash
./copy_and_install_translations.sh \
  --koha-path /home/koha/Koha \
  --lang fi-FI,sv-SE
```

**Dry-run (näytä mitä tapahtuisi):**
```bash
./copy_and_install_translations.sh --koha-path /home/koha/Koha --dry-run
```

### Parametrit

```bash
  -k, --koha-path PATH          Polku Koha-repoon
  -r, --translations-path PATH  Polku Koha-translations-repoon
  -l, --lang LANGS              Kielet pilkulla erotettuna (esim. fi-FI,sv-SE)
  -n, --dry-run                 Testaa ilman muutoksia
  -h, --help                    Näytä ohje
```

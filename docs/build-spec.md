# Build-spec: It's 404, yo!

En simpel macOS drag-drop-app der gør vilkårlige sample-packs SP-404 MkII-kompatible
og fjerner den kryptiske "Unsupported File"-fejl. Engangskøb, ingen backend.

> Navnet blev **"It's 404, yo!"** — søster til "It's mono, yo!". (Denne fil er det oprindelige
> planlægnings-/kildebelæg-dokument; format-specen i §4 er fortsat sandhedskilden, jf. `CLAUDE.md`.)

---

## 1. Positionering (one-liner)
"Træk din sample-pack ind → få den tilbage klar til SP-404 MkII. Ingen DAW, ingen terminal,
ingen 'Unsupported File'."

## 2. Målgruppe & job-to-be-done
- **Hvem:** SP-404 MkII-beatmakere (bevidst hands-on, ikke-tekniske brugere). Samme publikum
  som "It's mono, yo!" allerede nævner og sælger til.
- **Jobbet:** "Jeg har downloadet en pro/Splice-pack, smidt den på SD-kortet, og SP'en siger
  'Unsupported File' uden at forklare hvorfor. Fix det for hele mappen på én gang."

## 3. Kerneproblemet (verificeret mod Roland primær-kilder)
- SP-404 MkII kører internt **16-bit lineær PCM / 48 kHz**; alt importeret konformeres hertil.
- **To importveje med forskellige regler:**
  - **SD-kort/direkte:** accepterer KUN **16-bit lineær WAV/AIFF/MP3**. Alt andet risikerer fejl.
  - **Officiel SP-404MK2-app:** accepterer bredere (WAV/AIFF/MP3/FLAC/M4A), down-konverterer selv.
- **Hyppigste konkrete årsag til "Unsupported File":** **32-bit float** WAV (allestedsnærværende i
  pro/Splice-packs). Enheden afviser uden at forklare hvorfor.
- **Hullet vi udfylder:** Den gratis Roland-app auto-konverterer kun *legacy-projekter*, ikke
  vilkårlige løse packs. DigiChain (gratis) har **ingen SP-404-preset**. Folk konverterer i dag
  fil-for-fil i en DAW eller via CLI (FFmpeg/SOX) — klodset for "hundreder/tusinder af samples".

## 4. Konverterings-target-spec (det app'en SKAL ramme)
Disse regler maksimerer SD-kort-kompatibilitet:

| Aspekt | Regel |
|---|---|
| **Container/codec** | Lineær PCM WAV (RIFF). Transcode float-PCM/ADPCM/komprimeret. Konvér AIFF/FLAC/MP3/M4A → WAV. |
| **Bit-depth** | **Force 16-bit integer.** Aldrig pass-through af 24-bit eller 32-bit (især ikke 32-bit float). |
| **Sample rate** | **Force 48 kHz** (= nul on-device resampling) som default. Option for 44.1 kHz. Resample alt andet (96k/88.2k/22.05k…). |
| **Kanaler** | **Bevar mono/stereo som kilden.** Ingen dokumenteret kanal-afvisning. |
| **Metadata** | Skriv en ren, kanonisk WAV → dropper automatisk BWF/broadcast-wav, ekstra RIFF-chunks, cue points. |
| **Længde/størrelse** | Advar (eller tilbyd split) hvis fil > ~16 min eller > ~185 MB pr. sample. |
| **Min. længde** | Advar ved < ~100 ms (kan fejle ved import; rest-edge-case). |

**Ærlig vurdering:** "force 16-bit/48k(eller 44.1) PCM + behold kanaler" fikser ~alle reelle
tilfælde. Rest-cases (>16 min/185 MB, <100 ms, evt. problematiske filnavne) håndteres defensivt
med advarsler — de er sjældne ift. format-problemet.

## 5. UX-flow
1. **Drop** en mappe eller filer (genbrug mono yo's mappe-import med bevaret struktur).
2. **Analyse:** app'en scanner og viser en liste: ✅ allerede kompatibel / ⚠️ vil blive konverteret
   (med menneskelig grund: "32-bit float → 16-bit", "96 kHz → 48 kHz", "FLAC → WAV").
   Dette "forklar hvorfor"-trin er en stor del af value-proppen (SP'en selv forklarer intet).
3. **Indstillinger (minimal):** målrate 48 kHz (default) / 44.1 kHz. Output: ny mappe ved siden af,
   eller "i en _SP404-mappe". Bevar mappestruktur (default til).
4. **"Make SP-404 Ready"** → batch-konvertering med progress (genbrug mono yo's progress-UI).
5. **Færdig-rapport:** X filer konverteret, Y allerede ok, Z advarsler (for lange/korte).
   Knap: "Reveal in Finder".

## 6. Teknisk stak (native — ingen FFmpeg, ingen backend)
- **Sprog/UI:** Swift + SwiftUI (eller AppKit, match mono yo). macOS, Apple Silicon native.
- **Lyd:** **AVFoundation / Core Audio** — præcis din eksisterende mono-yo-stak.
  - Læsning: `AVAudioFile` (WAV/AIFF/MP3/M4A/AAC/ALAC; FLAC understøttet på moderne macOS via Core Audio).
  - Konvertering: `AVAudioConverter` til sample-rate + format; eller `ExtAudioFile` med client/output
    `AudioStreamBasicDescription` sat til 16-bit integer PCM ved 48/44.1 kHz.
  - Skrivning: `AVAudioFile`/`ExtAudioFile` → ren kanonisk `WAVE`/`pcm_s16le`-fil (stripper chunks gratis).
- **Hvorfor ikke FFmpeg:** GPL-licens + bundling-besvær passer dårligt til App Store og din native stil.
  AVFoundation dækker alt det nødvendige.
- **Ingen netværk, ingen konto, ingen IAP-server** → ren offline utility.

## 7. Edge cases at håndtere defensivt
- 32-bit **integer** vs **float**: Roland dokumenterer ikke forskellen. **Down-konvér alt ikke-16-bit**
  (stol ikke på at integer slipper igennem).
- Filer > 16 min / 185 MB: advar; v1 behøver ikke auto-split.
- Filer < ~100 ms: advar (kan fejle ved import).
- Skæve filnavne (double-byte/meget lange): overvej valgfri sanitering i v2.
- Allerede-kompatible filer: spring over eller kopiér uændret (ikke gen-encode unødigt).

## 8. Monetisering & ASO
- **Pris:** **$4.99 engangskøb, betalt up-front (hard paywall).** Højere end mono yo ($0.99) fordi
  den løser et større, mere irriterende problem. Præcedens i nichen: Easy Wav Converter $3.99,
  DigiChain native-binaries $3-8.
- **Ingen abonnement** (nichen er for lille; engangskøb matcher dit mønster og tidligere research).
- **Mac App Store** (evt. også direkte salg via din side, som mono yo).
- **ASO-keywords:** "SP-404", "SP404 MK2", "SP-404 sample converter", "unsupported file",
  "16 bit wav converter", "sample pack converter", "roland sampler". Long-tail + lav konkurrence.
- **Apple 4.3(b)-differentiering** (vigtigt i 2026): device-specifik (SP-404 MkII) + batch +
  bevaret mappestruktur + "forklar hvorfor den fejlede"-rapport = meningsfuldt mere end en generisk
  konverter. Det passerer review.

## 9. Krydssalg
- "It's mono, yo!" nævner allerede SP-404 og kan importere en hel pack med bevaret struktur —
  **samme UX, samme kunder, samme kodearkitektur.** Cross-promote begge veje (in-app + din side).
- Mulig fremtidig produktlinje: "sampler-prep" til devices **uden** gratis transfer-tooling
  (Akai MPC standalone, 1010music Blackbox/Bitbox) — se v2.

## 10. Scope & tidslinje
- **MVP (1-3 uger):** drop → analyse-liste → batch-konvér til 16-bit/48k(eller 44.1) WAV, bevar
  struktur, færdig-rapport. Det er hele appen.
- Stor genbrug fra mono yo (drag-drop, mappe-import, progress, light/dark) → lav byggerisiko.

## 11. Risici (vær ærlig)
- **Primær risiko:** Værdien er en **ikke-teknisk GUI** over funktionalitet der findes gratis i CLI +
  to GitHub-konvertere. Hvis SP-404-folk er FFmpeg-komfortable, smuldrer betalingsviljen.
  *Modargument:* SP-404 MkII er bevidst en hands-on groovebox for beatmakere, ikke programmører —
  præcis et publikum der betaler $5 for at undgå terminalen.
- **Lille marked:** forvent hundreder, ikke tusinder, af salg. Behandl som portefølje-tilføjelse +
  ASO der compounder, ikke en jackpot.
- **Firmware-drift:** accepterede formater kan ændre sig med firmware-opdateringer.

## 12. Åbne spørgsmål at teste på hardware før/under build
1. Accepterer SD-kort-import reelt 32-bit **integer**, eller kun 16-bit? (Down-konvér uanset.)
2. Præcis min-længde-tærskel der fejler (~100 ms?) — og gælder den SD-kort eller kun app'en?
3. Filnavn/sti-begrænsninger (double-byte, længde, mappedybde) på SD-kort-import?
4. Down-konverterer den officielle app stille 24/32-bit (inkl. float) korrekt? (Så kunne app'en
   alternativt anbefale "brug Roland-app'en" for de filer — men vores pre-konvertering er mere robust.)

---

### Kildebelæg (verificeret)
- Roland reference-manual v4 (specs: 16-bit lineær / 48 kHz)
- Roland support 4408189989147 ("converted to 48 kHz/16-bit on import")
- Roland app-manual v4 (SD-import = 16-bit lineær WAV/AIFF/MP3; app = + FLAC/M4A)
- Roland support 4408196941851 (16 min / ~185 MB pr. sample)
- sebpatron.com + GitHub (pkMinhas, seb-patron, ConorCorp, haoranzhang929): 32-bit float = dominant
  "Unsupported File"-årsag; 16-bit PCM-target virker

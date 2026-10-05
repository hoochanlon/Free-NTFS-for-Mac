## Über Nigate

**Nigate** ist ein kostenloses macOS-Werkzeug zum Lesen und Schreiben von NTFS-Speichergeräten auf Basis von ntfs-3g.

- <img src="../imgs/svg/social/github.svg" alt="" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> Autorenseite: [https://github.com/hoochanlon](https://github.com/hoochanlon)
- <img src="../imgs/svg/social/github.svg" alt="" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> Softwareprojekt: [https://github.com/hoochanlon/Free-NTFS-for-Mac](https://github.com/hoochanlon/Free-NTFS-for-Mac)
- <img src="../imgs/svg/social/email.svg" alt="" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> Kontakt-E-Mail: [hoochanlon@outlook.com](mailto:hoochanlon@outlook.com)

> [!IMPORTANT]
> **Haftungsausschluss**
>
> Die Verwendung dieses Tools zum Einhängen und Ändern von NTFS-Geräten birgt das Risiko von Datenverlust. Es wird empfohlen, wichtige Daten vor der Verwendung zu sichern. Dieses Tool wird "wie besehen" ohne jegliche ausdrückliche oder stillschweigende Garantien bereitgestellt. Der Entwickler übernimmt keine Verantwortung für Datenverluste, die durch die Verwendung dieses Tools verursacht werden.

Der stabile Betrieb und die Datenintegrität dieser Software hängen von der Leistung der Speichergeräte ab. Um Datenlese-/schreibfehler, Übertragungsunterbrechungen oder Geräteerkennungsfehler zu vermeiden, wird empfohlen, USB-Laufwerke zu verwenden, die aus hochwertigen Flash-Speicherchips hergestellt sind und eine zuverlässige Lese-/Schreibleistung aufweisen.

## Systemanforderungen

Dieses Tool erfordert die folgenden Systemabhängigkeiten:

1. **Xcode Command Line Tools** - Apple-Entwicklungstools
2. **Homebrew** - Paketmanager für macOS
3. **MacFUSE** - Dateisystem-Benutzerraum-Framework
4. **ntfs-3g** - NTFS-Dateisystemtreiber

### Systemabhängigkeiten installieren

Vor der ersten Verwendung sollten Sie prüfen, ob die Systemabhängigkeiten installiert sind. Klicken Sie im Tab "Systemabhängigkeiten" auf die Schaltfläche "Abhängigkeiten prüfen", und das System erkennt automatisch den Installationsstatus der erforderlichen Abhängigkeiten.

Wenn fehlende Abhängigkeiten erkannt werden, befolgen Sie bitte diese Schritte zur manuellen Installation:

#### 1. Xcode Command Line Tools installieren

Führen Sie den folgenden Befehl im Terminal aus:

```bash
xcode-select --install
```

Nach dem Ausführen wird ein Installationsfenster angezeigt. Folgen Sie den Anweisungen, um die Installation abzuschließen. Der Installationsvorgang kann einige Minuten bis mehrere zehn Minuten dauern, bitte haben Sie Geduld.

#### 2. Homebrew installieren

Führen Sie den folgenden Befehl im Terminal aus:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Folgen Sie den Anweisungen, um die Installation abzuschließen. Wenn das Netzwerk langsam ist, können Sie eine inländische Spiegelquelle verwenden:

```bash
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

#### 3. MacFUSE installieren

> [!TIP]
> Apple-Silicon-Macs blockieren Kernel-Erweiterungen von Drittanbietern standardmäßig. Fahren Sie den Mac herunter und halten Sie die Ein-/Aus-Taste gedrückt, bis die Startoptionen erscheinen → Optionen → Fortfahren → Dienstprogramme → Startsicherheitsdienstprogramm. Wählen Sie das Systemvolume, öffnen Sie die Sicherheitsrichtlinie, wählen Sie „Reduzierte Sicherheit“ und aktivieren Sie „Verwaltung von Kernel-Erweiterungen von identifizierten Entwicklern durch Benutzer erlauben“.

Führen Sie den folgenden Befehl im Terminal aus:

```bash
brew install --cask macfuse
```

#### 4. ntfs-3g installieren

Führen Sie den folgenden Befehl im Terminal aus:

```bash
brew tap gromgit/homebrew-fuse
brew install ntfs-3g-mac
```

> [!TIP]
> Nach der Installation von macFUSE und ntfs-3g wählen Sie in den Systemeinstellungen unter „Allgemein“ nacheinander „Anmeldeobjekte & Erweiterungen“ > „Erweiterungen“ > „Nach Kategorie“ > „Dateisystemerweiterungen“. Klicken Sie anschließend auf das Infosymbol und aktivieren Sie ntfs-3g (falls vorhanden) sowie macFUSE.

**Hinweis**: Die Installationsreihenfolge ist wichtig. Bitte installieren Sie in der Reihenfolge: 1 → 2 → 3 → 4.

## Benutzeroberflächen-Symbole

Die Hauptoberfläche der Anwendung bietet mehrere Funktionssymbole, die Ihnen helfen, schnell auf häufig verwendete Funktionen zuzugreifen:

### Titelleisten-Symbole

- <img src="../imgs/svg/devices/flash-auto.svg" alt="Automatisches Lesen/Schreiben" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Automatisches Lese-Schreib-Symbol** - Wenn aktiviert, hängt der Hintergrund neu angeschlossene schreibgeschützte NTFS-Volumes mit Schreibzugriff ein, auch ohne geöffnetes Fenster. Ein manuell auf Schreibschutz zurückgesetztes Volume bleibt für die aktuelle Verbindung unverändert. Aktiv erscheint das Symbol blau.
- <img src="../imgs/svg/devices/tray.svg" alt="Systemleisten-Modus" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Systemleisten-Modus-Symbol** - Wenn aktiviert, wird die Anwendung beim Schließen des Fensters in die Systemleiste minimiert, anstatt beendet zu werden. Das Symbol erscheint rot, wenn es aktiv ist.
- <img src="../imgs/svg/system/caffe.svg" alt="Ruhezustand verhindern" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Ruhezustand verhindern-Symbol** - Wenn aktiviert, verhindert das System, dass es in den Ruhezustand wechselt, um sicherzustellen, dass Geräte kontinuierlich verfügbar bleiben. Das Symbol erscheint kaffeefarben, wenn es aktiv ist.
- <img src="../imgs/svg/system/protect.svg" alt="Status-Schutz" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Status-Schutz Symbol** - 3s lang drücken, um den Schutzstatus umzuschalten. Wenn geschützt, werden automatisches Lesen/Schreiben, Tray-Modus und Ruhezustand verhindern deaktiviert, um versehentliche Vorgänge zu verhindern. Das Symbol erscheint grün mit einer Pulsanimation, wenn es geschützt ist.
- <img src="../imgs/svg/ui/info.svg" alt="Info" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Info-Symbol** - Öffnet das Info-Fenster, um Anwendungsinformationen und Projektlinks anzuzeigen.
- <img src="../imgs/svg/actions/exit.svg" alt="Beenden" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Beenden-Symbol** - Beendet die Anwendung.

### Symbol im Einstellungsbereich

- 🤫 **Easter-Egg-Symbol** - Neben der Überschrift „Anwendungseinstellungen“. 3 Sekunden gedrückt halten, um die Hover-Tooltips für Symbolschaltflächen in der gesamten App umzuschalten; die Auswahl wird gespeichert.

### Registerkarten-Symbole

- <img src="../imgs/svg/ui/log.svg" alt="Protokoll" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Protokoll-Symbol** - Wechselt zur Registerkarte "Betriebsprotokolle", um Aufzeichnungen aller Vorgänge anzuzeigen.

### Geräteverwaltungs-Symbole

- <img src="../imgs/svg/actions/refresh.svg" alt="Aktualisieren" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Aktualisieren-Symbol** - Aktualisiert die Geräteliste und erkennt angeschlossene NTFS-Geräte neu.
- <img src="../imgs/svg/actions/format.svg" alt="Formatieren" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Formatieren-Symbol** - Baut die gesamte externe Festplatte als GPT-NTFS neu auf. Alle Partitionen und Daten auf dieser Festplatte werden gelöscht und können nicht wiederhergestellt werden. Das Symbol erscheint nur bei eingehängten externen Datenträgern.
- <img src="../imgs/svg/actions/repair.svg" alt="Reparieren" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Reparatur-Symbol** - Klicken Sie beim gewünschten Gerät auf das Reparatur-Symbol und bestätigen Sie, um eine Reparatur des NTFS-Dateisystems zu versuchen. Dafür sind Administratorrechte und ein Passwort erforderlich. Fehler vom Typ "Resource busy" können automatisch behandelt werden.

> [!tip]
> <img src="../imgs/svg/actions/check-okey-done.svg" alt="Fertig" style="height: 20px; width: 20px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **Fertig-Symbol** - Nach erfolgreichem Formatieren oder Reparieren wechselt das entsprechende Symbol kurz zu diesem Abschlusszeichen und kehrt nach etwa 3 Sekunden zurück.

**Hinweis: `ntfsfix` bietet nur begrenzte Reparaturmöglichkeiten und kann Windows `chkdsk /f` nicht ersetzen.**

## Verwendungsschritte

### Systemabhängigkeiten prüfen

Klicken Sie im Tab "Systemabhängigkeiten" auf die Schaltfläche "Abhängigkeiten prüfen", und das System erkennt automatisch den Installationsstatus der erforderlichen Abhängigkeiten. Wenn fehlende Abhängigkeiten erkannt werden, werden detaillierte Installationsanweisungen angezeigt, einschließlich Installationsbefehlen und Beschreibungen.

### NTFS-Geräte verwalten

Nach dem Einstecken eines NTFS-formatierten Wechselspeichergeräts können Sie alle angeschlossenen Geräte im Tab "NTFS-Geräte" anzeigen.

#### Doppelklick zum Öffnen des Laufwerks (Finder)

Im Tab **"NTFS-Geräte"** oder im **Systemleisten-Menü** zunächst **den entsprechenden Geräteeintrag auswählen** und anschließend **das Gerät doppelklicken**, um das zugehörige Einhängeverzeichnis direkt im Finder zu öffnen.

Der Gerätestatus wird in zwei Typen unterteilt:

- **Schreibgeschützt** - Das Gerät kann nur gelesen, nicht geschrieben werden. Dies ist die Standardbehandlung von NTFS-Geräten durch macOS.
- **Lese-/Schreibzugriff** - Das Gerät ist im Lese-/Schreibzugriff-Modus eingehängt und kann Dateien normal lesen und schreiben.

**Kapazitätsbalken-Anleitung：**

In der Hauptoberfläche und im Systemleisten-Menü wird für jedes Gerät ein Kapazitätsbalken angezeigt, um die Speicherplatznutzung visuell darzustellen. Die Farbbedeutungen sind wie folgt:

- **Blau** (0-74%): Ausreichend Speicherplatz, mit mehr als 25% freiem Speicherplatz
- **Gelb** (75-89%): Speicherplatz ist knapp, mit 11%-25% freiem Speicherplatz. Es wird empfohlen, Dateien zeitnah zu bereinigen
- **Rot** (90-100%): Speicherplatz ist kritisch niedrig, mit weniger als 10% freiem Speicherplatz. Dateien sollten sofort bereinigt werden, um Speicherplatz freizugeben

### Automatisches Lesen/Schreiben

Automatisches Lesen/Schreiben läuft im Hintergrund. Es hängt nicht davon ab, ob das Hauptfenster oder das Menüleistendienstprogramm geöffnet ist. Ist es aktiv, werden bei einer Geräteänderung geeignete schreibgeschützte NTFS-Volumes mit Lese- und Schreibzugriff eingehängt.

**Aktivieren:**

- Klicken Sie in der Titelleiste auf das Symbol für automatisches Lesen/Schreiben (<img src="../imgs/svg/devices/flash-auto.svg" alt="Automatisches Lesen/Schreiben" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;">). Aktiviert wird es blau
- Aktivieren Sie „Automatisches Lesen/Schreiben“ im Menü der Menüleiste

**Wann eingehängt wird:**

- **Beim Einschalten**: verbundene Volumes, die noch schreibgeschützt und eingehängt sind, werden sofort geprüft
- **Beim späteren Anschließen**: die nächste Geräteänderung prüft neu angeschlossene schreibgeschützte Volumes
- Volumes mit bereits vorhandenem Schreibzugriff, nicht eingehängte Volumes und Volumes ohne nutzbares Volume werden übersprungen

**Wann nicht eingehängt wird:**

- **Manuell schreibgeschützt**: Beim Zurücksetzen auf Schreibschutz oder vor einem Reset wird diese Wahl gespeichert. Solange das Volume verbunden bleibt, stellt automatisches Lesen/Schreiben den Schreibzugriff nicht wieder her
- **Ein manuelles Einhängen mit Schreibzugriff löscht diese Wahl**
- **Kurze Pause nach dem Schreibschutz**: Etwa 8 Sekunden nach Wiederherstellung oder Reset wird nicht sofort zurückgeschaltet
- **Während einer Reparatur**: Automatisches Lesen/Schreiben pausiert für dieses Volume etwa 2 Minuten
- **Ein Versuch je Änderung**: Dasselbe Volume wird je Geräteänderung nur einmal versucht. Ein Fehlschlag wird in diesem Durchgang nicht wiederholt; der nächste Anschluss oder das erneute Einschalten startet einen neuen Versuch

**Nach dem Entfernen:**

Die gespeicherte Schreibschutz-Wahl gilt nur für die aktuelle Verbindung. Nach dem Auswerfen oder Trennen für mehr als etwa 9 Sekunden wird sie gelöscht; beim nächsten Anschließen ist das Volume wieder geeignet. Erscheint es innerhalb von 9 Sekunden erneut, bleibt die Wahl erhalten, damit das kurze Aushängen beim Wiederherstellen des Schreibschutzes nicht als Entfernen gilt.

### Gerät als Lese-/Schreibzugriff einhängen

Für Geräte im schreibgeschützten Status können Sie auf die Schaltfläche "Lese-/Schreibzugriff" klicken, um sie im Lese-/Schreibzugriff-Modus einzuhängen. Dieser Vorgang erfordert Administratorrechte, und das System zeigt einen Passworteingabedialog an.

**Hinweise:**

- Das Einhängen erfordert Administratorrechte, bitte haben Sie Ihr Systempasswort bereit
- Wenn das Einhängen fehlschlägt, mögliche Gründe sind:
  - Das Dateisystem des Geräts befindet sich in einem unsauberen Zustand (wenn dieses NTFS-Gerät zuvor auf einem Windows-Computer mit aktiviertem Schnellstart verwendet wurde, stecken Sie es bitte wieder in den Windows-Computer ein und fahren Sie vollständig herunter, bevor Sie es erneut versuchen)
  - Das Gerät wird von anderen Programmen verwendet
  - Systemberechtigungsprobleme
- Bitte werfen Sie das Gerät nach dem Einhängen sicher aus, um Datenverlust zu vermeiden

### Gerät aushängen

Für eingehängte Geräte können Sie auf die Schaltfläche "Aushängen" klicken, um sie auszuhängen. Das Aushängen erfordert Administratorrechte.

**Eigenschaften des Aushängens:**
- Entfernt das Gerät aus dem Dateisystem
- Das Gerät bleibt physisch mit dem Computer verbunden
- Das System kann das Gerät automatisch erneut einhängen (z. B. Wiedereinstecken oder automatisches Einhängen durch das System)
- Das Gerät bleibt in der Liste, markiert als "Ausgehängt"-Status
- Kann erneut eingehängt werden

**Anwendungsfälle:**
- Temporäres Trennen des Gerätezugriffs, während das Gerät mit dem Computer verbunden bleibt
- Geräteeinhängemethode neu konfigurieren müssen
- Wenn das Gerät Probleme hat, zuerst aushängen, dann erneut einhängen

### Gerät auswerfen

Für eingehängte Geräte können Sie auf die Schaltfläche "Auswerfen" klicken, um sie vollständig zu trennen. Das Auswerfen erfordert keine Administratorrechte.

**Eigenschaften des Auswerfens:**
- Trennt das Gerät vollständig und entfernt es aus dem System
- Das Gerät verschwindet aus der Liste
- Das System wird das Gerät nicht automatisch erneut einhängen
- Das Gerät muss erneut eingesteckt werden, um verwendet zu werden
- Zeigt an, dass das Gerät sicher entfernt werden kann

**Anwendungsfälle:**
- Vor dem Entfernen des Geräts sicherstellen, dass Daten vollständig geschrieben wurden
- Gerät vollständig trennen müssen
- Wenn das Gerät nicht mehr benötigt wird
- Ähnlich der Funktion "Auswerfen" im macOS Finder

**Aushängen vs. Auswerfen:**

| Funktion | Aushängen | Auswerfen |
|----------|-----------|-----------|
| Erfordert Admin-Rechte | ✅ Ja | ❌ Nein |
| Gerät physisch verbunden | ✅ Bleibt verbunden | ✅ Bleibt verbunden |
| System automatisches Wiedereinhängen | ⚠️ Möglicherweise | ❌ Nein |
| Gerät in Liste | ✅ Verbleibt (als ausgehängt markiert) | ❌ Entfernt |
| Kann erneut einhängen | ✅ Ja | ❌ Muss erneut eingesteckt werden |
| Anwendungsfälle | Temporäres Trennen, Neu konfigurieren | Vorbereitung zum Entfernen, vollständiges Trennen |

## Häufig gestellte Fragen

### Warum wird mein Gerät als schreibgeschützt angezeigt?

Dies ist das Standardverhalten von macOS. macOS hängt NTFS-Geräte standardmäßig im schreibgeschützten Modus ein. Dieses Tool kann Geräte im Lese-/Schreibzugriff-Modus einhängen.

### Was tun, wenn das Einhängen fehlschlägt?

Wenn der Einhängevorgang fehlschlägt oder ein Timeout auftritt, prüfen Sie bitte Folgendes:

- **Systemabhängigkeiten**: Stellen Sie sicher, dass alle Systemabhängigkeiten installiert sind (Xcode Command Line Tools, Homebrew, MacFUSE, ntfs-3g)
- **Administratorrechte**: Stellen Sie sicher, dass das eingegebene Administrator-Passwort korrekt ist
- **Dateisystemzustand**: Wenn dieses NTFS-Gerät zuvor auf einem Windows-Computer mit aktiviertem Schnellstart verwendet wurde, kann sich das Dateisystem in einem unsauberen Zustand befinden. Stecken Sie es bitte wieder in den Windows-Computer ein und fahren Sie vollständig herunter (nicht Ruhezustand/Energiesparmodus), und versuchen Sie dann erneut, es einzuhängen
- **Gerätenutzung**: Prüfen Sie, ob andere Programme das Gerät verwenden, schließen Sie verwandte Programme und versuchen Sie es erneut
- **Vorgangs-Timeout**: Wenn der Vorgang ein Timeout hat, bricht die Anwendung den Vorgang automatisch ab, um ein Hängen zu verhindern. Bitte prüfen Sie die oben genannten Gründe und versuchen Sie es erneut

#### "Resource busy" Fehler

Wenn Sie auf `Error opening '/dev/diskXsX': Resource busy` stoßen, liegt dies normalerweise daran, dass der Vorgang zwangsweise unterbrochen wurde und das Gerät noch belegt ist. Lösung:

1. **Gerätepfad bestätigen**: Verwenden Sie den Befehl `diskutil list`, um das entsprechende Festplattengerät zu bestätigen (z. B. `/dev/disk5s1`)

2. **Gerät aushängen**:
   ```bash
   sudo diskutil unmount /dev/disk5s1
   ```
   Hinweis: Ersetzen Sie `/dev/disk5s1` durch Ihren tatsächlichen Gerätepfad

3. **Dateisystem reparieren**: Führen Sie die Reparatur durch, während das Gerät ausgehängt ist
   ```bash
   sudo ntfsfix /dev/disk5s1
   ```

4. **Erneut einhängen**: Nach Abschluss der Reparatur versuchen Sie erneut, das Gerät einzuhängen

**Ursache**: Dieser Fehler tritt normalerweise auf, wenn ein Einhängvorgang zwangsweise unterbrochen wurde (z. B. durch erzwungenes Beenden der Anwendung, Systemabsturz usw.), wodurch das Gerät in einem belegten Zustand verbleibt. Sie müssen es zuerst aushängen und reparieren, bevor Sie es erneut einhängen können.

**Verwenden der Reset-Schaltfläche**: Bei einem "Resource busy"-Fehler können Sie direkt auf die Reset-Schaltfläche klicken. Die Reset-Funktion führt automatisch folgende Operationen aus:
- Gerät aushängen
- Dateisystem reparieren
- Gerätebelegungsstatus löschen

Die Reset-Operation erfordert Administratorrechte und eignet sich zur schnellen Lösung von Gerätebelegungsproblemen.

### Was tun, wenn die Installation von Abhängigkeiten fehlschlägt?

Wenn Sie während der Installation auf Probleme stoßen, prüfen Sie bitte Folgendes:

- **Netzwerkverbindung**: Stellen Sie sicher, dass die Netzwerkverbindung normal ist, die Installation erfordert das Herunterladen von Dateien
- **Festplattenspeicher**: Stellen Sie sicher, dass ausreichend Festplattenspeicher vorhanden ist (Xcode Command Line Tools benötigen mehrere GB Speicher)
- **Systemberechtigungen**: Stellen Sie sicher, dass Administratorrechte vorhanden sind, einige Installationen erfordern die Passworteingabe
- **Installationsreihenfolge**: Bitte installieren Sie Abhängigkeiten in der richtigen Reihenfolge (Xcode → Homebrew → MacFUSE → ntfs-3g)

**Häufige Probleme:**

1. **Xcode Command Line Tools Installation schlägt fehl**
   - Netzwerkverbindung prüfen
   - Versuchen Sie, das Installationsprogramm manuell von der Apple-Entwicklerwebsite herunterzuladen

2. **Homebrew Installation langsam oder schlägt fehl**
   - Verwenden Sie eine inländische Spiegelquelle (siehe Installationsschritte oben)
   - Netzwerk-Proxy-Einstellungen prüfen

3. **MacFUSE oder ntfs-3g Installation schlägt fehl**
   - Stellen Sie sicher, dass Homebrew zuerst installiert ist
   - Führen Sie `brew update` aus, um Homebrew zu aktualisieren
   - Prüfen Sie auf Berechtigungsprobleme

### MacFUSE ist nach einem großen macOS-Upgrade zu alt

Wenn diese Meldung erscheint, ist die installierte macFUSE-Version nicht mit der aktuell laufenden macOS-Version kompatibel:

> The installed version of macFUSE is too old for the operating system. Please upgrade your macFUSE installation to one that is compatible with the currently running version of macOS.

Gehen Sie wie folgt vor:

1. **Apps aus allen Quellen erlauben**

   Führen Sie im Terminal folgenden Befehl aus:

   ```bash
   sudo spctl --master-disable
   ```

   Wenn Terminal `Globally disabling the assessment system needs to be confirmed in System Settings.` meldet, öffnen Sie die Systemeinstellungen erneut und wählen Sie **Datenschutz & Sicherheit**. Suchen Sie unter **Sicherheit** nach **Apps aus folgenden Quellen erlauben** und wählen Sie **Überall**. Die Bezeichnungen können je nach macOS-Version abweichen.

   > [!WARN]
   > Dieser Befehl deaktiviert die Gatekeeper-Prüfung global und verringert die Systemsicherheit. Verwenden Sie ihn nur bei Bedarf. Nach dem Upgrade von macFUSE und der Freigabe der Systemerweiterung können Sie die Standardprüfung mit `sudo spctl --master-enable` wieder aktivieren.

2. **macFUSE aktualisieren**

   ```bash
   brew upgrade --cask --greedy macfuse
   ```

3. **Systemerweiterung freigeben und neu starten**

   Öffnen Sie **Systemeinstellungen → Datenschutz & Sicherheit**, geben Sie die macFUSE-Systemerweiterung frei und starten Sie den Mac wie aufgefordert neu.

Wenn das Problem weiterhin besteht, konsultieren Sie bitte die offizielle Dokumentation der einzelnen Abhängigkeiten oder suchen Sie technischen Support.
Wenn das Problem weiterhin besteht, konsultieren Sie bitte die offizielle Dokumentation der einzelnen Abhängigkeiten oder suchen Sie technischen Support.

### Kann nach dem Aushängen nicht auf das Gerät zugegriffen werden?

Nach dem Aushängen wird das Gerät aus dem System entfernt. Wenn Sie erneut darauf zugreifen müssen, stecken Sie das Gerät bitte erneut ein oder verwenden Sie die integrierte Einhängefunktion des Systems.

## Betriebsprotokolle

Im Tab "Betriebsprotokolle" können Sie Aufzeichnungen aller Vorgänge anzeigen, einschließlich:

- Abhängigkeitsprüfungsergebnisse
- Geräteerkennungsstatus
- Ein-, Aushänge- und Auswurfvorgänge
- Reparatur-, Umbenennungs- und Formatierungsvorgänge
- Fehlermeldungen und Warnungen

**Betriebsprotokolle aktivieren:**

Betriebsprotokolle sind standardmäßig deaktiviert und müssen manuell aktiviert werden. Aktivieren Sie das Kontrollkästchen "Betriebsprotokolle aktivieren" im Tab "Betriebsprotokolle", um die Protokollierung zu aktivieren. Wenn aktiviert, zeichnet die App alle Betriebsprotokolle auf. Wenn deaktiviert, werden keine neuen Protokolle aufgezeichnet, aber zuvor aufgezeichnete Protokolle bleiben erhalten.

**Protokollspeicherung:**

Protokolle werden im JSON-Format im Dateisystem an folgendem Speicherort gespeichert:

```
~/Library/Application Support/Nigate/logs.json
```

Die Protokolldatei verwendet formatiertes JSON-Format und kann direkt mit einem Texteditor geöffnet werden, um sie anzuzeigen. Wenn Sie die App deinstallieren, wird die Protokolldatei nicht automatisch gelöscht, sodass sie später leicht angezeigt oder gesichert werden kann.

**Protokollgrenzen:**

Um die Anwendungsleistung und Stabilität sicherzustellen, hat das Protokollierungssystem die folgenden Grenzen:

- **Aufbewahrungsdauer**: Protokolle werden standardmäßig maximal 30 Tage gespeichert. Protokolle, die älter als 30 Tage sind, werden automatisch bereinigt
- **Datensatzanzahlgrenze**: Es werden maximal 500 Protokolleinträge aufbewahrt. Wenn die Grenze überschritten wird, werden die ältesten Einträge automatisch gelöscht, sodass nur die neuesten 500 Einträge erhalten bleiben
- **Dateigrößenbegrenzung**: Die Protokolldatei hat eine maximale Größe von 500 KB. Wenn die Grenze überschritten wird, werden alte Einträge automatisch gelöscht, um die Dateigröße innerhalb der Grenze zu halten
- **Anzeigegrenze**: Die Benutzeroberfläche zeigt maximal 300 Protokolleinträge (die neuesten 300) an, um die Rendering-Leistung zu verbessern

**Protokollverwaltung:**

- **Protokolle löschen**: Klicken Sie auf die Schaltfläche "Löschen", um alle Protokolleinträge zu löschen
- **Protokolle exportieren**: Klicken Sie auf die Schaltfläche "Exportieren", um Protokolle als Textdatei zu exportieren, um sie zu sichern oder zu teilen

## Weitere Fehlerbehebung

Wenn Sie auf andere Probleme stoßen (wie "Datei beschädigt"-Warnungen, Gerät ausgelastet-Fehler, Treiberkonflikte usw.), konsultieren Sie bitte unser [Fehlerbehebungszentrum](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9), das detaillierte Fehlerbehebungsschritte und Lösungen enthält.

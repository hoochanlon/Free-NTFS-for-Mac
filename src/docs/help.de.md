## Haftungsausschluss

Die Verwendung dieses Tools zum Einhängen und Ändern von NTFS-Geräten birgt das Risiko von Datenverlust. Es wird empfohlen, wichtige Daten vor der Verwendung zu sichern. Dieses Tool wird "wie besehen" ohne jegliche ausdrückliche oder stillschweigende Garantien bereitgestellt. Der Entwickler übernimmt keine Verantwortung für Datenverluste, die durch die Verwendung dieses Tools verursacht werden.

## Systemanforderungen

Dieses Tool erfordert die folgenden Systemabhängigkeiten:

1. **Swift (Xcode Command Line Tools)** - Apple-Entwicklungstools
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

**Hinweis**: Die Installationsreihenfolge ist wichtig. Bitte installieren Sie in der Reihenfolge: 1 → 2 → 3 → 4.

## Verwendungsschritte

### Systemabhängigkeiten prüfen

Klicken Sie im Tab "Systemabhängigkeiten" auf die Schaltfläche "Abhängigkeiten prüfen", und das System erkennt automatisch den Installationsstatus der erforderlichen Abhängigkeiten. Wenn fehlende Abhängigkeiten erkannt werden, werden detaillierte Installationsanweisungen angezeigt, einschließlich Installationsbefehlen und Beschreibungen.

### NTFS-Geräte verwalten

Nach dem Einstecken eines NTFS-formatierten Wechselspeichergeräts können Sie alle angeschlossenen Geräte im Tab "NTFS-Geräte" anzeigen.

Der Gerätestatus wird in zwei Typen unterteilt:

- **Schreibgeschützt** - Das Gerät kann nur gelesen, nicht geschrieben werden. Dies ist die Standardbehandlung von NTFS-Geräten durch macOS.
- **Lese-/Schreibzugriff** - Das Gerät ist im Lese-/Schreibzugriff-Modus eingehängt und kann Dateien normal lesen und schreiben.

### Gerät als Lese-/Schreibzugriff einhängen

Für Geräte im schreibgeschützten Status können Sie auf die Schaltfläche "Als Lese-/Schreibzugriff konfigurieren" klicken, um sie im Lese-/Schreibzugriff-Modus einzuhängen. Dieser Vorgang erfordert Administratorrechte, und das System zeigt einen Passworteingabedialog an.

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

Wenn das Problem weiterhin besteht, konsultieren Sie bitte die offizielle Dokumentation der einzelnen Abhängigkeiten oder suchen Sie technischen Support.

### Kann nach dem Aushängen nicht auf das Gerät zugegriffen werden?

Nach dem Aushängen wird das Gerät aus dem System entfernt. Wenn Sie erneut darauf zugreifen müssen, stecken Sie das Gerät bitte erneut ein oder verwenden Sie die integrierte Einhängefunktion des Systems.

## Betriebsprotokolle

Im Tab "Betriebsprotokolle" können Sie Aufzeichnungen aller Vorgänge anzeigen, einschließlich:

- Abhängigkeitsprüfungsergebnisse
- Geräteerkennungsstatus
- Einhänge-/Aushängevorgangsergebnisse
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

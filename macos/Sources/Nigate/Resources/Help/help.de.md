# Nigate Anleitung

## Über die App und Sicherheit

Nigate ist eine native macOS-App auf Basis von Swift und SwiftUI und benötigt macOS 14 oder neuer. NTFS-Partitionen werden über die macOS-Datenträgerdienste erkannt; für den Lese-/Schreibzugriff verwendet die App MacFUSE und `ntfs-3g`.

Einhängen, Reparieren und Formatieren können die Daten auf dem Datenträger beeinflussen. Sichern Sie wichtige Dateien vorher. Trennen Sie das Gerät während einer Übertragung nicht und beenden Sie die App nicht zwangsweise. `ntfsfix` behebt nur bestimmte NTFS-Probleme und ersetzt Windows `chkdsk` nicht.

Die App deaktiviert Gatekeeper nicht und ändert keine globalen Sicherheitseinstellungen. Folgen Sie bei der Installation von MacFUSE oder einer Systemerweiterung den aktuellen macOS-Hinweisen und prüfen Sie, ob die Quelle vertrauenswürdig ist.

## Erste Schritte und Abhängigkeiten

1. Öffnen Sie **Abhängigkeiten** und wählen Sie **Abhängigkeiten prüfen**, um macOS, Xcode Command Line Tools, Homebrew, MacFUSE, `ntfs-3g` und das optionale `fswatch` zu überprüfen.
2. Für NTFS-Lese-/Schreibzugriff sind macOS 14 oder neuer, MacFUSE und `ntfs-3g` erforderlich. Zweck und Status der weiteren Komponenten werden in der Liste angezeigt.
3. Mit **Ein-Klick-Installation** starten Sie den Installationsablauf im Terminal. Alternativ können Sie einen Eintrag aufklappen, den Befehl anzeigen und kopieren und die Installation manuell ausführen. Bestätigen Sie Systemerweiterungen nur nach den macOS-Hinweisen.
4. Prüfen Sie die Abhängigkeiten nach Installation und Freigabe erneut. NTFS-Lese-/Schreibzugriff und zugehörige Aktionen sind erst möglich, wenn MacFUSE und `ntfs-3g` bereit sind. Wenn macOS die App als beschädigt blockiert oder Dateisystem- bzw. Kernel-Erweiterungen bestätigt werden müssen, lesen Sie die folgenden Abschnitte.

## Unverzichtbares Mac-Wissen

### Quarantäne nur für eine App entfernen vs Gatekeeper global deaktivieren

#### „Die Datei ist beschädigt, in den Papierkorb legen“

Weil [Apple übertragene Software hinter einem Installationsschutz hält](https://developer.apple.com/developer-id/), kann beim Start die Meldung erscheinen, die Software sei beschädigt und gehöre in den Papierkorb. Wählen Sie Abbrechen.

![](images/1.png)

Unter **App → Terminal** heben Sie die Quarantäne mit diesem Befehl auf:

```bash
xattr -cr /Applications/nigate.app
```

![](images/2.png)

Gehen Sie wie im Screenshot vor.

![](images/3.png)

#### Beliebige Quellen erlauben

Gatekeeper global deaktivieren:

```bash
sudo spctl --master-disable
```

Erscheint `Globally disabling the assessment system needs to be confirmed in System Settings.`, folgen Sie dem Screenshot.

![](images/4.png)

#### Kurzfassung

`xattr -cr`: gezielt freigeben, präzise und sicherer — behebt nur das aktuelle App-Problem. (⭐⭐⭐⭐⭐ bevorzugt)

`spctl --master-disable`: global aus, sehr hohes Risiko — das Sicherheitstor des Mac wird vollständig geöffnet. (⭐⭐⭐ nicht empfohlen, aber für IT-Fachleute nutzbar)

### Kernel-Erweiterungen von Drittanbietern zulassen

Wenn der Dialog **System Extension Blocked** erscheint, öffnen Sie in den Systemeinstellungen **Datenschutz & Sicherheit** und erlauben Sie die Systemerweiterung von „Benjamin Fleischer“.

![](images/bc-3.png)

Klicken Sie im Bereich Sicherheit unter Datenschutz & Sicherheit, um die Systemerweiterung zu aktivieren.

![](images/bc-1.png)

Anschließend werden Sie aufgefordert, den Mac auszuschalten und in den Wiederherstellungsmodus zu wechseln. Klicken Sie auf **Ausschalten** und fahren Sie mit dem Abschnitt **SIP deaktivieren** fort.

![](images/bc-2.png)

### SIP deaktivieren

SIP steht für System Integrity Protection (Systemintegritätsschutz). Damit soll selbst das Root-Konto das System nicht vollständig kontrollieren können; das Verfahren heißt auch Rootless. SIP ist standardmäßig eingeschaltet. Wie im Screenshot zu sehen, ist das hier eindeutig der Fall.

![](images/6.png)

Halten Sie nach dem Herunterfahren die Ein/Aus-Taste gedrückt, bis **Startoptionen werden geladen** erscheint.

![](images/7.gif)

Halten Sie die Ein/Aus-Taste weiter gedrückt.

![](images/8.png)

Jetzt können Sie die Taste loslassen.

![](images/9.png)

Wählen Sie das Konto, klicken Sie auf **Weiter** und geben Sie das Mac-Passwort ein.

![](images/10.png)

Klicken Sie auf **Optionen** und fahren Sie fort.

![](images/11.png)

Wählen Sie in der Menüleiste **Dienstprogramme → Startsicherheitsdienstprogramm**.

![](images/12.png)

Alternativ können Sie im Terminal `csrutil disable` eingeben, den Vorgang beenden und den Mac neu starten (Methode 2).

Wir bleiben bei Methode 1 und klicken auf **Sicherheitsrichtlinie**.

![](images/13.png)

Setzen Sie die Richtlinie auf **Reduzierte Sicherheit**, aktivieren Sie **Benutzerverwaltung von Kernel-Erweiterungen identifizierter Entwickler zulassen** und bestätigen Sie.

![](images/14.png)

Mit `csrutil status` im Terminal sehen Sie, ob SIP disable oder enable ist.

![](images/15.png)

### Dateisystemerweiterungen aktivieren

Öffnen Sie in den **Allgemein**-Einstellungen nacheinander **Anmeldeobjekte & Erweiterungen** > **Erweiterungen** > **Nach Kategorie** > **Dateisystemerweiterungen**. Klicken Sie anschließend auf das Informationssymbol des Eintrags, oder springen Sie mit dem folgenden Befehl zu **Dateisystemerweiterungen**, und aktivieren Sie ntfs-3g (falls vorhanden), macFUSE und verwandte Optionen.

```shell
open "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.fskit.fsmodule"
```

![](images/5.png)

## Geräte und Aktionen

Nach dem Anschließen eines NTFS-Laufwerks scannt Nigate die erkannten Volumes und zeigt sie unter **NTFS-Geräte** an. Jede Karte zeigt Volume-Name, Gerätekennung, Einhängepunkt sowie verfügbaren und gesamten Speicherplatz. Mit **Aktualisieren** können Sie erneut suchen. Über die Sammelaktionen lassen sich geeignete Geräte einhängen, schreibgeschützt wiederherstellen, aushängen oder auswerfen.

### Symbolübersicht

- **Navigation**: Das Puzzleteil öffnet **Abhängigkeiten**, das Laufwerk **NTFS-Geräte**, das Fragezeichen die **Hilfe** und das Zahnrad die **Einstellungen**.
- **Titelleiste**: Die Kaffeetasse wechselt den Ruhezustandsschutz. Halten Sie das Schild 3 Sekunden gedrückt, um den Statusschutz umzuschalten. Das Energiesymbol beendet die App, das Herz öffnet **Autor unterstützen**, das Informationssymbol öffnet **Über die App**, und Sonne/Mond wechseln das Erscheinungsbild.
- **Statuspunkt**: Grün bedeutet, dass Geräte erkannt wurden und keines schreibgeschützt ist; Orange bedeutet, dass eine Kernabhängigkeit fehlt oder mindestens ein Volume schreibgeschützt ist; Grau bedeutet, dass kein NTFS-Gerät erkannt wurde.
- **Geräteaktionen**: Der runde Pfeil aktualisiert; der Bleistift hängt mit Lese-/Schreibzugriff ein; das Auge stellt den Schreibschutz wieder her; das Auswurfsymbol hängt aus; das Laufwerk mit X wirft das Gerät aus; Schraubenschlüssel und Schraubendreher reparieren; der Textcursor benennt um; das interne Laufwerk formatiert; der gebogene Pfeil setzt zurück. Das Laufwerkssymbol auf einer Karte ist bei Lese-/Schreibzugriff grün und bei Schreibschutz orange. Neben den Aktionssymbolen stehen außerdem Textbezeichnungen.

- **Schreibgeschützt**: Dateien können gelesen, aber nicht geändert werden. Windows-Schnellstart oder Ruhezustand kann NTFS in einem unsicheren Zustand hinterlassen. Fahren Sie Windows vollständig herunter, bevor Sie das Laufwerk erneut am Mac anschließen.
- **Lese-/Schreibzugriff**: Wählen Sie **Lese-/Schreibzugriff** und bestätigen Sie den Administratoreingriff. Das vorhandene Mount wird entfernt und das Volume anschließend mit `ntfs-3g` eingehängt. Schließen Sie zuerst Apps, die auf das Volume zugreifen.
- **Schreibschutz wiederherstellen**: Entfernt das Lese-/Schreib-Mount und lässt macOS das Volume schreibgeschützt einhängen. Die manuelle Auswahl verhindert vorübergehend, dass Auto-Einhängen den Modus wieder ändert.
- **Aushängen**: Entfernt nur das Dateisystem-Mount; das Gerät bleibt angeschlossen. Aktualisieren Sie die Liste, um es erneut einzuhängen.
- **Auswerfen**: Bittet macOS, das Gerät auszuwerfen. Warten Sie auf den erfolgreichen Abschluss, bevor Sie es trennen. Schließen Sie vorher Apps, die das Laufwerk verwenden.
- **Zurücksetzen**: Für Fehler durch belegte Geräte. Nigate hängt die Partition aus, führt `ntfsfix` aus und versucht danach, sie schreibgeschützt einzuhängen. Administratorbestätigung ist erforderlich; eine Reparatur birgt Datenrisiken.
- **Reparieren**: Führt mit `ntfsfix` begrenzte Reparaturen aus und versucht, den vorherigen Mount-Modus wiederherzustellen. Notieren Sie bei einem Fehler die Meldung und wiederholen Sie Reparaturen nicht unnötig bei wichtigen Daten.
- **Umbenennen**: Geben Sie eine neue Volume-Bezeichnung ein. Nigate hängt das Gerät aus, aktualisiert NTFS-Bezeichnung und Partitionsnamen und stellt den vorherigen Schreibschutz- oder Lese-/Schreibmodus wieder her. Der Name muss 1 bis 32 Zeichen lang sein und darf `\\ / : * ? " < > |` nicht enthalten. Währenddessen keine Dateien übertragen.

### Aushängen oder auswerfen

| Aktion | Dateisystem-Mount | Geräteverbindung | Erneute Verwendung |
| --- | --- | --- | --- |
| Aushängen | Entfernt | Bleibt verbunden | Aktualisieren und erneut einhängen |
| Auswerfen | Zusammen mit dem Gerät entfernt | System wird um Trennung gebeten | Gerät erneut anschließen |

Aushängen ist nicht dasselbe wie sicheres Trennen. Verwenden Sie vor dem Abziehen **Auswerfen** und warten Sie auf die Bestätigung.

## Formatieren

Beim Formatieren werden alle Partitionen und Daten des gesamten Datenträgers unwiderruflich gelöscht. Nigate erstellt eine GPT-Partitionstabelle und ein NTFS-Dateisystem für den ganzen Datenträger; es wird nicht nur das ausgewählte Volume geleert. Sichern Sie vorher Ihre Daten und prüfen Sie Ziellaufwerk und Kapazität.

Aus Sicherheitsgründen ist das Formatieren nur erlaubt, wenn macOS das Ziel als externe physische Festplatte bestätigt, die weder Startvolume noch intern, virtuell, Abbild oder synthetisch ist. Geräte-, Partitions- und Protokollangaben müssen vorhanden und konsistent sein. Fehlende, unbekannte oder widersprüchliche Angaben führen zur Ablehnung. Trennen Sie das Laufwerk nicht und beenden Sie die App während des Vorgangs nicht.

## Automatischer Lese-/Schreibzugriff

Beim Scan verarbeitet Nigate NTFS-Volumes, die **bereits eingehängt und aktuell schreibgeschützt** sind, und hängt sie mit Schreibzugriff neu ein. Das Fenster muss nicht geöffnet sein. Nicht eingehängte, bereits beschreibbare oder nicht erkannte Geräte sind keine Kandidaten. Für automatische Einhängeaktionen kann eine Administratorbestätigung erforderlich sein.

Nach manuellem Wiederherstellen des Schreibschutzes oder **Zurücksetzen** wird das Gerät für die aktuelle Verbindung als manuell schreibgeschützt vorgemerkt und nicht sofort wieder auf Schreibzugriff umgestellt. Ein späteres manuelles Einhängen mit Schreibzugriff hebt diese Auswahl auf.

## Ruhezustandsschutz und Statusschutz

Klicken Sie auf das Kaffeetassen-Symbol in der Titelleiste, um zwischen **Aus → Ruhezustand verhindern → Intelligenter Ruhezustandsschutz → Aus** zu wechseln. Der intelligente Schutz ist die Voreinstellung. Bei aktivem Statusschutz ist diese Steuerung gesperrt.

- **Aus**: Nigate verhindert den Ruhezustand nicht.
- **Ruhezustand verhindern**: Verhindert den Ruhezustand dauerhaft, auch wenn das Laufwerk gerade nicht verwendet wird. Geeignet für lange Aufgaben.
- **Intelligenter Ruhezustandsschutz**: Überwacht nur eingehängte Datenträger. Bei Festplattenaktivität wird der Ruhezustand verhindert; etwa 20 Sekunden nach Ende der Aktivität wieder erlaubt. Ohne eingehängte Datenträger wird er nicht dauerhaft verhindert.

Beim Beenden der App wird der Ruhezustandsschutz beendet. Halten Sie das Schildsymbol in der Titelleiste 3 Sekunden gedrückt, um den Statusschutz ein- oder auszuschalten. Er verhindert versehentliche Änderungen, schützt aber nicht vor Defekten oder Datenverlust.

## Einstellungen

Unter **Einstellungen** können Sie festlegen, ob das Administratorkennwort im macOS-Schlüsselbund gespeichert wird, ob die App bei der Anmeldung startet, welche Seite beim Start geöffnet wird sowie Sprache, Darstellung und Schaltflächenhinweise. Hinweise sind standardmäßig aus. Das Kennwort wird nur bei aktivierter Speicherung im Schlüsselbund abgelegt. Sie können die Option jederzeit deaktivieren oder das gespeicherte Kennwort löschen.

Beim Schließen des Fensters bleibt Nigate in der Menüleiste und wird nicht beendet. Über das Menüleisten-Symbol können Sie das Fenster wieder öffnen oder NTFS-Geräte verwalten. Sprache und Darstellung werden automatisch gespeichert. Der Ruhezustandsschutz lässt sich auch in der Titelleiste steuern.

## Fehlerbehebung

### Warum ist das Volume schreibgeschützt?

macOS hängt NTFS standardmäßig schreibgeschützt ein. Prüfen Sie auf der Seite **Abhängigkeiten**, ob MacFUSE und `ntfs-3g` bereit sind, und wählen Sie dann **Lese-/Schreibzugriff**. Falls Windows-Schnellstart oder Ruhezustand verwendet wurde, schließen Sie das Laufwerk an Windows an und fahren Sie Windows vollständig herunter.

### Einhängen schlägt fehl oder läuft in ein Timeout

Prüfen Sie die Abhängigkeiten erneut, schließen Sie andere Apps mit Zugriff auf das Laufwerk und kontrollieren Sie die Administratorbestätigung. Ein nicht ordnungsgemäß beendetes Windows kann ebenfalls Inkonsistenzen verursachen. Aktualisieren Sie nach einem Timeout die Geräteliste, bevor Sie es erneut versuchen, und wiederholen Sie den Vorgang nicht während einer Übertragung.

### Fehler `Resource busy`

Schließen Sie Finder-Fenster und Apps, die das Volume verwenden, und wählen Sie **Zurücksetzen** auf der Gerätekarte. Nigate hängt die Partition aus, führt `ntfsfix` aus und versucht ein schreibgeschütztes erneutes Einhängen. Administratorbestätigung ist erforderlich. Sichern Sie wichtige Daten vorher. Falls der Fehler bestehen bleibt, notieren Sie ihn und wenden Sie sich an den Support, statt destruktive Terminalbefehle auf eine unsichere Gerätekennung anzuwenden.

### Nach der Reparatur ist kein Schreibzugriff möglich

`ntfsfix` hat nur begrenzte Fähigkeiten und kann möglicherweise nur einige Metadaten reparieren. Prüfen Sie das Laufwerk unter Windows mit Administratorrechten mit `chkdsk`. Sind wichtige Daten nicht erreichbar, schreiben Sie nichts mehr auf das Laufwerk und priorisieren Sie die Datenrettung.

### MacFUSE ist nach einem macOS-Upgrade veraltet oder die Erweiterung wird blockiert

Klappen Sie MacFUSE auf der Seite **Abhängigkeiten** auf und folgen Sie dort den Schritten zum Aktualisieren der offiziellen Version. Bestätigen Sie die verifizierte Erweiterung unter **Systemeinstellungen → Datenschutz & Sicherheit**. Die Bezeichnungen unterscheiden sich je nach macOS-Version. Lassen Sie Gatekeeper nicht dauerhaft deaktiviert. Falls die Anleitung eine vorübergehende Sicherheitsänderung verlangt, beachten Sie den Warnhinweis und stellen Sie die Einstellung sofort danach wieder her. Kann ein Mac mit Apple-Chip die Kernel-Erweiterung weiterhin nicht laden, siehe **SIP deaktivieren** oben.

### Wo finde ich das Gerät nach dem Aushängen?

Aushängen entfernt nur das Dateisystem-Mount; das Gerät bleibt angeschlossen. Aktualisieren Sie die Liste, um es wieder einzuhängen. Verwenden Sie **Auswerfen**, bevor Sie es trennen.

Weitere Hilfe finden Sie im [Fehlerbehebungszentrum](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9). Geben Sie bei einer Meldung macOS-Version, Gerätedetails, ausgeführte Aktion und die vollständige Fehlermeldung an. Veröffentlichen Sie keine Kennwörter oder privaten Dateiinhalte.

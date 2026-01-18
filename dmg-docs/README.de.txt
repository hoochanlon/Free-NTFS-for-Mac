═══════════════════════════════════════════════════════════
          Nigate - Installationsanleitung
═══════════════════════════════════════════════════════════

📦 Installationsschritte:

1. Ziehen Sie Nigate.app in den Ordner "Programme" rechts

2. Wenn beim ersten Start die Meldung "Nigate.app kann nicht
   geöffnet werden, da der Entwickler nicht verifiziert werden
   kann" erscheint, befolgen Sie diese Schritte, um die App
   zu entsperren:

   【Methode 1: Empfohlen】
   Öffnen Sie die App "Terminal" (in Programme > Dienstprogramme),
   kopieren und führen Sie den folgenden Befehl aus:

   xattr -cr /Applications/Nigate.app

   Versuchen Sie dann erneut, die App zu öffnen.

   【Methode 2: Falls Methode 1 nicht funktioniert】
   Führen Sie den folgenden Befehl im Terminal aus, um
   Gatekeeper zu deaktivieren:

   sudo spctl --master-disable

   Gehen Sie dann zu "Systemeinstellungen" > "Datenschutz &
   Sicherheit" und wählen Sie die Option "Überall" aus.

═══════════════════════════════════════════════════════════

💡 Wichtige Hinweise:

• Passen Sie den Pfad im Entsperrbefehl an Ihren tatsächlichen
  Installationsort an
• Wenn die App an einem anderen Ort installiert ist, ändern Sie
  den Pfad im Befehl entsprechend
• Beispiel: Wenn auf dem Desktop installiert, wäre der Befehl:
  xattr -cr ~/Desktop/Nigate.app

• Weitere Hilfe und Problemberichte:
  https://github.com/hoochanlon/Free-NTFS-for-Mac

═══════════════════════════════════════════════════════════

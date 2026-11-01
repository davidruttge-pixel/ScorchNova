# Android APK – Build über GitHub Actions

Dieses Projekt enthält einen **ungetesteten** GitHub-Actions-Buildworkflow. Er erstellt bei erfolgreicher Ausführung eine Debug-APK als herunterladbares Artefakt. Godot/Android-SDK und Export-Templates werden auf dem GitHub-Runner benötigt; die Build-Konfiguration kann weitere Anpassungen erfordern.

## Nur mit Android-Handy
1. Auf github.com ein neues privates Repository anlegen.
2. Die **Inhalte** dieses Projektordners (nicht den übergeordneten Ordner) hochladen. Versteckte `.github`-Dateien müssen ebenfalls hochgeladen werden. Bei GitHub im mobilen Browser kann dafür die Desktop-Ansicht nötig sein.
3. Unter **Actions** den Workflow **Android APK** auswählen und **Run workflow** drücken.
4. Nur wenn der Build grün erfolgreich ist, unter **Artifacts** die Datei **ScorchNova-Android-APK** herunterladen, entpacken und die APK installieren.
5. Wenn der Build fehlschlägt, das Actions-Protokoll zur Fehlerbehebung bereitstellen.

WICHTIG: Es wurde noch kein Godot-Laufzeit- oder Android-Gerätetest durchgeführt. Eine APK wird hier nicht mitgeliefert. Debug-APKs sind nicht für die Veröffentlichung im Play Store gedacht.

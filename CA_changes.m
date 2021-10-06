% this file should contain only a variable assignment
% Note: Changes are in English starting with version 0.8.3
% Note: The main program "ChronAlyzer" has its own version number stored. This number is looked for here.

greetingtext = [ ...
	'Last Changes:' CR ...
	'0.2.1' CR ...
	' - Direktes Einlesen der XLS-Dateien' CR ...
	' - Einlesen mehrere Datens�tze m�glich:' CR ...
	'   - Platten-Replikate (mehrere Dateien)' CR ...
	'   - Multi-Read-Daten (mehrere Messreihen in einer Datei)' CR ...
	'- Wellnamen anklicken erzeugt Grafik' CR ...
	'0.2.2' CR ...
	'- Fehler in Neustart beseitigt' CR ...
	'- Leere Zeilen im Excel-Export vermieden' CR ...
	'0.2.3' CR ...
	'- Fehler in Auswahl der korrekten Grafik-Anzeige beseitigt' CR ...
	'0.2.4' CR ...
	'- Fehler beim Einlesen unterschiedlich langer Datens�tze beseitigt' CR ...
	'- Lasso-Range angepasst' CR ...
	'- Fehler beim Schreiben in Excel-Tabelle (seit Einf�hrung der "Multi-Dateien"' CR ...
	'0.2.5' CR ...
	'- Fehler beim Kompilieren beseitigt' CR ...
	'- Neu: Men�-Icon im Resultat-Bild zum Aus-/Einblenden der Rohdaten' CR ...
	'- Neu: Men�-Icon im Resultat-Bild zum Aus-/Einblenden der ...' CR ...
	'  erweiterten (= abgew�hlten) Rohdaten' CR ...
	'- Neu: In Gruppen An- und Abwahl eines Wells durch Anklicken des Graphen' CR CR ...
	'0.3.0' CR ...
	'- Verbesserungen beim Einlesen mehrerer Excel-Dateien' CR ...
	'- Dateien mit Replikaten verarbeiten, selbst bei unterschiedlichen Plattenlayouts (->"kleinster Nenner")' ...
	'- Einf�hrung einer Annotation-Datei pro Experiment' CR ...
	'- Historie der letzten �nderungen wird nur angezeigt, wenn wirklich neu' CR  ...
	'- Grafiken bekommen aussagekr�ftigere Titel' CR ...
	'0.4.0' CR ...
	'- In Teilen komplett neue Programmlogik' CR ...
	'- Wahnsinnig viele �nderungen "unter der Haube"!' CR ...
	'- Programmcode in Hinblick auf Lesbarkeit / Weitergabe verbessert (ein Anfang ist getan)' CR ...
	'- Grafische Auswahl der zu ber�cksichtigenden Zeitspanne �berarbeitet' CR ...
	'- auch eine numerische Auswahl der zu ber�cksichtigenden Zeitspanne ist nun m�glich' CR ...
	'- Statistik-Werte am Ende der Analyse jetzt interaktiv! (Samples ausw�hlbar)' CR ...
	'- Button f�r Nature-Artikel ...' CR ...
	'- Anzahl der biol. Replikate auf GUI angezeigt (Spalte "Sample", z.B. "(x2)")' CR ...
	'- Default-Wert f�r zeitl. Auswerte-Intervallende auf 48 [h] festgesetzt' CR ...
	'- PreView- (oder Rohdaten-)Darstellung auch bei biol. Replikaten' CR ...
	'- txt-Files werden nicht mehr in vollen Umfang unterst�tzt!' CR ...
	'- (Vorerst) eingeschr�nkte Auswahl von Optionen bei Multi-Dateien: Techn. Replikate werden nicht mehr unterst�tzt' CR ...
	'0.4.1' CR ...
	'- Gemeinsame Auswerte-Grafiken f�r biol. Replikate (Mittelwerte und Einzelgraphen - schaltbar)' CR ...
	'0.4.2' CR ...
	'- Fehlerhafter Programmablauf bei Markierung von Ausrei�ern korrigiert (-> Startzeit-Abfrage)' CR ...
	'0.4.3' CR ...
	'- Beseitigt: Wenn Replikatgruppen nur ein Well enthielten ...' CR ...
	'- Ausger�umt: Textfiles werden ab dieser Version nicht mehr als Input-Option angeboten' CR ...
	'0.4.4' CR ...
	'- Beseitigt: Laufzeitfehler beseitigt ...' CR ...
	'- Fehlerhafte Anzeige bei grafischer Aus-/Abwahl von Wells in Replikatgruppe' CR ...
	'- Weitere Tooltips eingef�gt (Spalten�berschriften)' CR ...
	'- Buttons in nicht mehr aktiven Fenstern entfernt' CR ...
	'- bei Neustart wurden schon vorverarbeitete Messdaten nochmals vorverarbeitet' CR ...
	'- Bei Optimierung ist die logarithmierte Differenz als "Methode" ausw�hlbar' CR ...
	'- Bei Optimierung ist alternativ auch die "normierte Basislinie" ausw�hlbar' CR ...
	'0.4.5' CR ...
	'- Bug Fixes: Beim Einlesen von Tabellen mit Leerzeilen (Fehler Zeile 296)' CR ...
	'- Einige Fensterpositionen angepasst' CR ...
	'0.4.6' CR ...
	'- Einbau von Scrollbalken; mehr als 60 Wells werden damit pro Platte m�glich' CR ...
	'0.4.7' CR ...
	'- Einbau von Scrollbalken; noch nicht abgeschlossen' CR ...
	'- Beim �ffnen mehrerer Messdaten-Dateien wird immer der zuletzt ge�ffnete Pfad als Vorgabe ge�ffnet' CR ...
	'- �berpr�fung, ob Computer zur Soundausgabe f�hig' CR ...
	'- QuickView-Zuordnung optimiert' CR ...
	'- QuickView: Legende wird angezeigt' CR ...
	'- Messdaten-�bersicht: Beschriftung optimiert' CR ...
	'- Verbesserte Gruppenauswahl bei Replikatgruppen (mit Maus)' CR ...
	'- Neue (wichtige) Option: Periodendauer oder Phasenverschiebung bei Optimierung konstant halten' CR ...
	'0.4.8' CR ...
	'- Abruf der Phase und Periode von QuickView-Graphen (wenn vom Typ "Kontrolle")' CR ...
	'0.4.9' CR ...
	'- Normierung auf Medium/Kontrolle funktionierte nicht mehr' CR ...
	'- Ausgabe-Plots jetzt auch in X-Achse "verlinkt"' CR ...
	' ToDo: Scrollbalken (f�r MTP mit mehr als 60 Wells)' CR ...
	'0.4.10' CR ...
	'- Quote of the Day' CR ...
	'- Verlinkung der Ausgabe-Plot-Achsen war fehlerhaft' CR ...
	'- Ausgabe: Vergleich der Anpassungen f�r biolog. Replikate' CR ...
	'0.4.11' CR ...
	'- Fehler beim Neustart beseitigt' CR ...
	'- Eingabemasken f�r Y-Achsen Skalierung hinzugef�gt' CR ...
	'0.4.12' CR ...
	'- Schwer reproduzierbarer Fehler bei Normierung auf Kontrolle/Medium nach Stunden gefunden und beseitigt' CR ...
	'0.5.0' CR ...
	'- Scrollbalken eingebaut' CR ...
	'- Max. Zeitangabe (> t_end) bei Auswertung f�hrt nicht mehr zu Absturz' CR ...
	'- Tabelle bietet auch Option f�r Normierung auf Medium/Kontrolle-Amplitude' CR ...
	'- WICHTIG: Als Amplitude wird nun der erste Extremwert der angepassten Kurve innerhalb des gew�hlten Zeitfensters ausgegeben!' CR ...
	'- WICHTIG: Als D�mpfung wird nicht mehr der Faktor im Exponenten angegeben, sondern die prozentuale Abnahme zum n�chsten (gleichen) Extremwert' CR ...
	' ToDo: Excel-Ausgabe mit neuen Parametern testen' CR ...
	'0.5.1' CR ...
	'- Fehler in Option zur Anfangsgewichtung funktionierte genau falsch herum!' CR ...
	'- Texte angepasst' CR ...
	'- Import von BioTek-Dateien' CR ...
	'0.6.0' CR ...
	'- Import von BioTek-Dateien verbessert' CR ...
	'- Faktor in ausgegebenen Amplituden und Phasenwerten entfernt (war: x 60)' CR ...
	'0.6.1' CR ...
	'- Neustart-Knopf deaktiviert' CR ...
	'- Biologische Replikate (vor�bergehend) deaktiviert' CR ...
	'- Ausgabe in Excel-File erweitert (zB ChronAlyzer-Versionsnummer) und an neue Normierung angepasst (s. 1.5.0)' CR ...
	'- Fehler in Sortierung f�r BioTek-Daten' CR ...
	'- Fehler in Ergebnistabelle (Layout) behoben' CR ...
	'0.6.2' CR ...
	'- Opera-Phenix-Dateien (*.txt) k�nnen eingelesen werden' CR ...
	'- Eingabe-Dateien mit der Endung ".txt" werden nur noch als Opera-Phenix-Dateien erlaubt' CR ...
	'0.6.3' CR ...
	'- �nderung beim Einlesen der BioTek-Dateien: Datenpaket "Lum2" wird nun verwendet' CR ...
	'- BioTek gibt manchmal "OVRFLW" Fehler anstelle eines Messwerts; dieser wird ersetzt durch einen Mittelwert' CR ...
	'0.6.4' CR ...
	'- Neuer Button: "Save Tab+Fig", speichert alle (ge�ffneten!) Grafiken mit Kurvenanpassungen auf einmal' CR ...
	'- "Mithras-Style"-Ansicht der eingelesenen MTP: Statt farbiger Markierung wird der Zeitverlauf pro Well dargestellt' CR ...
	'- Biologische Replikate wieder aktiviert' CR ...
	'0.6.5' CR ...
	'- interne Programmverbesserungen' CR ...
	'- einige Meldungsfenster schlie�en sich nach kurzer Zeit automatisch' CR ...
	'- In Dialogen wurden sinnvolle Standardwerte voreingetragen' CR ...
	'0.6.6' CR ...
	'- BioTek-Daten: Die "Lum"-Werte werden nun ausgelesen (vormals: "Lum[2]")' CR ...
	'0.7.0' CR ...
	'- Fehler beim Speichern vieler Grafiken beseitigt' CR ...
	'- Kurioser Fehler beim Speichern der Ergebnistabelle (xlsx) beseitigt (aber da ist evtl. noch einer)' CR ...
	'- Fensterposition angepasst' CR ...
	'- "Save Tab+Fig" Button in "Save Figs" Button ge�ndert' CR ...
	'- Einlesen von Duplikat-BioTek-Datenfiles wurde ver�ndert; grafische Darstellung stimmt nun wieder' CR ...
	'- Erweitert von 12 auf 24 Replikatgruppen' CR ...
	'- ChronAlyzer Reports werden eingef�hrt (noch nicht verf�gbar)' CR ...
	'- Ergebnis-Grafiken zeigen nun auch die originalen Rohdaten unterhalb der Hauptgrafik an' CR ...
	'  (bei Replikaten stattdessen den Mittelwert)' CR ...
	'- Ausgabe-Fenster f�r die Mittelwerte der biolog. Replikate zeigen nun auch eine Legende an' CR ...
	'- Zeitgesteuerte Fensterschlie�ungen verursachen keine Fehlermeldungen mehr' CR ...
	'- Neuer Default-Wert f�r zeitl. Auswerte-Intervallende auf 60 [h] (vorher: 48) festgesetzt' CR ...
	'- Die Konfiguration von Replikatgruppen kann gespeichert und geladen werden' CR ...
	'- Neue DEBUG-Option: zus�tzliche Grafikausgaben. Achtung: Nicht f�r mehr als ca. 16 Wells verwenden' CR ...
	'- Verbesserte oder erg�nzte Titel, Legenden, Fehlermeldungen etc.' CR ...
	'- Der Dateiname von gespeicherten Bildern wird um Zeit&Datum erg�nzt' CR ...
	'- Grafiken der techn. Replikate werden automatisch gespeichert' CR ...
	'0.7.1' CR ...
	'- Platten�bersicht zeigt jedes Well im gleichen Ma�stab an' CR ...
	'0.7.2' CR ...
	'- �berpr�fung auf zulange Pfad-Datei-Namen (ToDo: work-around)' CR ...
	'0.7.3' CR ...
	'- Erweitert von 24 auf 30 Replikatgruppen (und durch Variable ersetzt)' CR ...
	'0.7.4' CR ...
	'- Anzahl der ge�ffneten Figures wird �berpr�ft und ggfs. wird der Benutzer gefragt, ob er alle ge�ffnet haben will (noch nicht fertig)' CR ...
	'0.7.5' CR ...
	'- Fehler in der QuickView-Datenzuordnung bei BioTek-Files beseitigt' CR ...
	'- Ein vorzeitiger Abbruch der Messung am Ger�t f�hrte zu unvollst�ndigen Zeitdaten, die wiederum zu Fehlern ... Dies wird nun erkannt' CR ...
	'0.8.0' CR ...
	'- Inhalt des Hauptfensters l�sst sich auch mit Mausrad scrollen' CR ...
	'- Import eines Layout-Files mit Beschreibung zu den Wells (obligatorisch!)' CR ...
	'  Das Plattenlayout muss im ersten Sheet einer Excel-Datei in den Zellen B3:M10 vorliegen.' CR ...
	'- Automatisches Gruppieren (techn. Replikate) durch Informationen im Layout-File' CR ...
	'  Damit werden auch viele Diagramm-Titel u.�. "informativer"' CR ...
	'  Aber die Funktion f�r die spezielle Bedeutung von "Kontrolle" und "Medium" muss anders gel�st werden:' CR ...
	'  Die Beschreibungen (im Layout-File) f�r solche speziellen Gruppen m�ssen nun entweder die Zeichenkette' CR ...
	'  "control" oder "medium" (case insensitive) enthalten, dann werden sie als diese speziellen Gruppen erkannt.' CR ...
	'- MouseWheel-Funktion f�r die Well-�bersichtr auf der Main-GUI eingebaut.' CR ...
	'- Optisch wurde die GUI ein wenig aufgefrischt' CR ...
	'- "Neustart"-Funktion wieder aktiviert' CR ...
	'- �berbleibsel aus alter Annotationsmethode im Code (und GUI) beseitigt' CR ...
	'- Ausgabe in Files ebenfalls an neue Annotation angepasst' CR ...
	'- Ein neuer Schriftzug (Logo) wurde eingebaut' CR ...
	'- Kleinere �nderungen f�r das Zusammenspiel mit KNIME (haupts�chlich Layout/Benennung der Ausgaben)' CR ...
	'0.8.1' CR ...
	'- Minimale Anpassungen f�r (bereits gemergte!) Daten vom Envision' CR ...
	'- Bessere Vorbereitung f�r weitere, neue Ger�te' CR ...
	'- Fix: Platten�bersicht (thumbnails) wurde versehentlich deaktiviert, wieder aktiviert!' CR ...
	'0.8.2' CR ...
	'- �berpr�fung f�r falsch orientiertes Platten-Layout hinzugef�gt.' CR ...
	'- Ber�cksichtung f�r nicht vollst�ndig ausgef�llt Platten-Layouts ("[NaN]")' CR ...
	'- Vereinfachtes Ausw�hlen von Daten von biolog. Replikaten (Mehrfachauswahl)' CR ...
	'0.8.3' CR ...
	'- translation of program into English started' CR ...
	'- added support for test data' CR ...
	'- simplification: when field for text input of analyzing horizon is left blank; it is set to start or end (no need to enter numbers)' CR ...
	'- re-introduced the base e-function search' CR ...
	'- improvements to e-function search' CR ...
	'- removed first smoothing of data (without effect)' CR ...
	'- fixed: pre-analysis steps respect user defined range' CR ...
	'0.8.4' CR ...
	'- overhauled some parts, generalized variables and work flow ...' CR ...
	'- ... preparing implementation of improved normalization and analysis function' CR ...
	'- introduced method for interactive access on Excel (selection of well annotations' CR ...
	'- changed (simplified) annotation input requirements: Just select layout in any Excel file' CR ...
	'- deactivated "Normalized" option for analysis function' CR ...
	'- mouse wheel control (to set user-defined time range for analysis) respects time limits of experiment' CR ...
	'- dropdown menu for manual selection of replication group was deactivated (actually a while ago).' CR ...
	'- right clicking on the replicate group name of a row (de)selects all wells belonging to this group' CR ...
	'- more text to provide user more operatings instructions' CR ...
	'- catching a missing cell range selection in XLS file (results now in a repeated question' CR ...
	'- several improvements for start values of optimization' CR ...
	'0.8.5' CR ...
	'- introduced "particle swarm optimization" method' CR ...
	'- option settings are now save and loaded into/from user setting (like version number)' CR ...
	'- interface to change option settings are now accessable via "Options" button only' CR ...
	'- introduced extreme point editor/validator' CR ...
	'- introduced a linear fade-in weighting factor (user defineable), to decrease influences of start of experimental' CR ...
	'- added this weighing factor to the general options dialog (and it''s saved to user settings that way' CR ...
	'- added a gray-color gradient background to show time-range of weighting factors fade-in for optimization' ...
	'- added more time-outs to dialog windows, to enhance "automatic" run of ChronAlyzer (not yet 100%)' CR ...
	'- LOTS of minor (and not so minor) improvements to code (e.g. readability) and output.' CR ...
	'0.8.6' CR ...
	'- MOVED TO GIT:  https://github.com/ChronAlyzer/ChronAlyzer.git' CR ...
	'0.8.7' CR ...
	'- started big re-work, because of this, the version number jumped to 0.9' CR ...
	'0.9' CR ...
	'- much re-work done in program flow in order to introduce the weighting matrix, e.g.:' CR ...
	'   o introduced user dialog to select between "gap" or calculation of an average if well information are missing' CR ...
	'   o time vector is based on equidistant time measurements, missing measurements are now "gaps"' CR ...
	'   o measurement matrix is now always 96 well sized (other plate sizes are currently un-supported now)' CR ...
	'   o individual well time-series can be incomplete (failed measurement) or whole measurements can miss on a plate' CR ...
	'   o weighting matrix can be used for outliers and missings and more' CR ...
	'- error fix when using outliers' CR ...
	'- changed wording "outliers" -> "remove noisy peaks"' CR ...
	'- temporarily removed support for other than 96-well-plates' CR ...
	'- added and translated more comments' CR ...
	'- introduced a "global messages" string, to save user choices (like "gap" or "averages") and write this string to output (perhaps also to GUI)' CR ...
	];
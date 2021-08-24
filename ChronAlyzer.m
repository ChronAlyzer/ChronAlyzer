function result = ChronAlyzer()

% This program analyzes time-series data from plate readers with 96-well
% plates, from experiments regarding the circadian rhythm.
% It tries to fit a simple mathematical model to the measurements
% ("curve-fitting") in order to obtain parameter values for:
% Amplitude, Period length, Phase-shift and Damping (caused by the
% experimental set-up in in vitro experiments).

% Copyright (c) 2017-2021 Norman Violet     == MIT License ==
%
% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the
% "Software"), to deal in the Software without restriction, including
% without limitation the rights to use, copy, modify, merge, publish,
% distribute, sublicense, and/or sell copies of the Software, and to permit
% persons to whom the Software is furnished to do so, subject to the
% following conditions:
%
% The above copyright notice and this permission notice shall be included
% in all copies or substantial portions of the Software.
%
% == DISCLAIMER ==
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
% OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
% ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
% WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
%
% THE SOFTWARE PACKAGE IS FREELY AVAILABLE AS A COURTESY OF THE DEVELOPER, 
% BUT HAS NOT BEEN NECESSARILY VALIDATED, REVIEWED OR APPROVED. OTHER SOFTWARE
% MAY BE EQUALLY USEFUL. THE MAINTENANCE OF THE SOFTWARE IS NOT GUARANTEED
% BY THE DEVELOPER. 
%
% The program was developed during my work at the BfR in 2019-2020
%
% Author: Norman Violet
% E-Mail: norman.violet@bfr.bund.de
% Bundesinstitut für Risikobewertung (BfR)
% German Federal Institute for Risk Assessment
% 10589 Berlin, Germany
%
%
% I used Matlab (Mathworks, 2017a) to script it. 
%
%
% PROGRAM DESCRIPTION
% see paper <...> and graphical guide.
%
%----------------------------------------------------------------------
% INPUT:
%
% OUTPUT:
% result:		Returns status from subfunction (not yet really useful)	
%
% --------------------------------------------------------------------
%
% ToDo: For publication:
%		1. Create and provide sample data file
%		2. Create and provide sample plate layout file
%		3. Provide sample quotes.txt
%		4. Turn jokes options off (automatically for unknown users, but
%			check again!)
%		5. Add publication address of paper.
%		6. Remove other user names (if not in paper)
%
% ToDo: Further ideas
%	- create heatmaps from deviations to average: Are the differences in cell at the border of the plate greater?
%	
%
% ToDo: Remove ToDos and Notes in the code
% ToDo: Check everything for plates other than 96-well plates
%

%% Variables initialization

	version_str		= 'v0.8.7'; % current version
	
	monitor			= get(0,'screensize');
	NoAudio         = false; 
	if audiodevinfo(0) < 1 || NoAudio
		% check if sound is possible at all
        NoSound = true;
    else
        NoSound = false;
	end
	
	CR				= newline;
	version_user	= 'v0.0.0'; % initialitation, it will be loaded which version the user already knows (saved in user settings)
	pfad			= ''; % path - saved in user settings

	annotations		= '';
	check_range		= 0;
	OK				= false;
	Stop			= false;
	Ende			= false;
	Neustart		= false;
	tab_pha_h		= []; % handles for entries in the main table (phase, amplification, ....)
	tab_amp_h		= [];	
	tab_dam_h		= [];	
	pha_button		= 1;
	mouseselectY_1	= [];
	mouseselectY_2	= [];
	kontroll_idx	= NaN;
	medium_idx		= NaN;
	well_annotation = false; % obsolete, was: only if TRUE well annotation were asked for
	s_idx			= [];
	nof_replgr		= 1; % at least one must be there for analyze 
	
	fname			= []; % File name (Data source)
	pathname		= []; 
	line_h_global	= []; % some more graphics handle
	file_anz		= 0; % number of data files
	replicate_mode	= ''; % This indicates if biological replicates (multiple plates) are used
	biolgr_name		= '';
	
	general_options	= struct('TimeWeight',false,'LogDiff',false,'ConstParameterPER',true, 'ConstParValue', 24, 'weight_threshhold_time',12); % options - saved in user settings	
    nof_wells       = 96; % ToDo: number of wells -  actually other plate format should work also, but not tested yet. 
	datum_str		= strrep(char(datetime('now')),':','_');  % Date, used for file export
	
	% User-Optionen (default values) - will be asked for in program
	time_weight		= false; % Forcing more weight on measurements in the beginning of the time-series?
	log_diff		= false; % Using the log difference in the calculation of the "error" difference in curve-fitting?
    const_PER       = true; % Period length OR phase-shift must be kept constant, which one?
    const_value		= 24; % default value for constant period length (should be modified below if "const_PER" is FALSE of course)
	
	% for annotation - obsolete
	config			= []; % obsolete too
	% Note: there are "Load_Replgr" and "Save_Replgr" which could be re-used
	% for modification of the replicate groups later on, but this
	% functionality is given also in the layout excel file.
	
	% (measurement) device-depending file format options (this is important
	% for the order of the information/wells within the files)
	device_biotek	= false; % data files are created by BioTek reader
	device_envision = false;
	device_mithras  = false;
	device_opera	= false;

	joke_done		= true; % jokes on/off (this will be turned off for unknown users)
	debug			= false; % mainly for programmer (but can be changed on main GUI)
	

	%allow_Annoation_edit = false; % flag, if TRUE: Open GUI for annotation
	%interface - obsolete now!
	
	% Import icon images for additional menu options
	try
		toolbar_icon1 = imread('delete_raw_icon.tif');
		toolbar_icon1 = double(toolbar_icon1(:,:,1:3))./255; % value range of 0-1 is needed for the icon
	catch
		% if file is missing: create a generic icon
		toolbar_icon1 = ones(16,16,3);
		for i = 1:16
			toolbar_icon1(i,i,:) = 0;
			toolbar_icon1(17-i,i,:) = 0;
		end
	end
	
	try
		image_data	= imread('ChronAlyzer_logo.png');
	catch
		image_data	= ones(566,1352,3);
	end
	
%% Initialisation

	% remove left-overs from last program loop
	idx	= findall(0, 'UserData','Output'); % Das sind alle Outputs von "findChronoParameter"
	idx = unique([idx findall(0, 'UserData','Annotation')]);
	for i = 1:numel(idx)
		close(idx(i));
	end
	% also in the main GUI
	idx	= findall(0, 'Tag','Table','Type','figure');
	close(idx);
	idx = [];
		
%% Greetings with version info and Quote of the Day
	
	% Get (windows) user name: for welcome greeting and for later file exports
	username = lower(getenv('username'));
	switch username
		case {'ndikung'}
			username = 'Dr. Jo';
		case {'ertych'}
			username = 'Newman';
		case {'violet'}
			% developer
			username = 'Master of the ChronAlyzer :-)';
			debug	= true;
			NoSound = true;
		case {'oelgeschlaeger'}
			username = 'Micha';
		case {'storm'}
			username = 'Doro';
		case {'mihelmel'}
			username = 'Melina';
		otherwise
			username	= [upper(username(1)) username(2:end)];
            joke_done	= true; % for not known user always off :-)
	end

	
%% Loading user settings	
	
	% Get information about user directory, this is the place to store the
	% recently used version
	get_user_settings(); % Fills global variables "version_user" and "pfad". They stay empty if no information was found in user directory

	
%% changes.text	
	
	greetingtext = '';
	
	if old_version || debug % user knows running version already? (Then don't show older version info)
		% Note: "Debug" will be set by ordinary user later in the main GUI,
		% so this works here only for pre-defined users (see above)

		% Note: Sorry, but I don't think that I need to translate all the
		% old changes. English starts from v0.8.3
		
		% ToDo: Outsource this file and functionality, so a user can always
		% have a look into a "changes.txt" file also, independent from the
		% greetings window at program start. But keep actual version in
		% this file here (see above in declaration section)
		
		greetingtext = [ ...
		'Last Changes:' CR ...
		'0.2.1' CR ...
		' - Direktes Einlesen der XLS-Dateien' CR ...
		' - Einlesen mehrere Datensätze möglich:' CR ...
		'   - Platten-Replikate (mehrere Dateien)' CR ...
		'   - Multi-Read-Daten (mehrere Messreihen in einer Datei)' CR ...
		'- Wellnamen anklicken erzeugt Grafik' CR ...	
		'0.2.2' CR ...	
		'- Fehler in Neustart beseitigt' CR ...		
		'- Leere Zeilen im Excel-Export vermieden' CR ...			
		'0.2.3' CR ...	
		'- Fehler in Auswahl der korrekten Grafik-Anzeige beseitigt' CR ...
		'0.2.4' CR ...	
		'- Fehler beim Einlesen unterschiedlich langer Datensätze beseitigt' CR ...	
		'- Lasso-Range angepasst' CR ...		
		'- Fehler beim Schreiben in Excel-Tabelle (seit Einführung der "Multi-Dateien"' CR ...		
		'0.2.5' CR ...	
		'- Fehler beim Kompilieren beseitigt' CR ...	
		'- Neu: Menü-Icon im Resultat-Bild zum Aus-/Einblenden der Rohdaten' CR ...		
		'- Neu: Menü-Icon im Resultat-Bild zum Aus-/Einblenden der ...' CR ...
		'  erweiterten (= abgewählten) Rohdaten' CR ...		
		'- Neu: In Gruppen An- und Abwahl eines Wells durch Anklicken des Graphen' CR CR ...
		'0.3.0' CR ...	
		'- Verbesserungen beim Einlesen mehrerer Excel-Dateien' CR ...	
		'- Dateien mit Replikaten verarbeiten, selbst bei unterschiedlichen Plattenlayouts (->"kleinster Nenner")' ...	
		'- Einführung einer Annotation-Datei pro Experiment' CR ...	
		'- Historie der letzten Änderungen wird nur angezeigt, wenn wirklich neu' CR  ...
		'- Grafiken bekommen aussagekräftigere Titel' CR ...
		'0.4.0' CR ...
		'- In Teilen komplett neue Programmlogik' CR ...
		'- Wahnsinnig viele Änderungen "unter der Haube"!' CR ...
		'- Programmcode in Hinblick auf Lesbarkeit / Weitergabe verbessert (ein Anfang ist getan)' CR ...
		'- Grafische Auswahl der zu berücksichtigenden Zeitspanne überarbeitet' CR ...
		'- auch eine numerische Auswahl der zu berücksichtigenden Zeitspanne ist nun möglich' CR ...
		'- Statistik-Werte am Ende der Analyse jetzt interaktiv! (Samples auswählbar)' CR ...
		'- Button für Nature-Artikel ...' CR ...				
		'- Anzahl der biol. Replikate auf GUI angezeigt (Spalte "Sample", z.B. "(x2)")' CR ...
		'- Default-Wert für zeitl. Auswerte-Intervallende auf 48 [h] festgesetzt' CR ...
		'- PreView- (oder Rohdaten-)Darstellung auch bei biol. Replikaten' CR ...
		'- txt-Files werden nicht mehr in vollen Umfang unterstützt!' CR ...
		'- (Vorerst) eingeschränkte Auswahl von Optionen bei Multi-Dateien: Techn. Replikate werden nicht mehr unterstützt' CR ...
		'0.4.1' CR ...
		'- Gemeinsame Auswerte-Grafiken für biol. Replikate (Mittelwerte und Einzelgraphen - schaltbar)' CR ...
		'0.4.2' CR ...
		'- Fehlerhafter Programmablauf bei Markierung von Ausreißern korrigiert (-> Startzeit-Abfrage)' CR ...
		'0.4.3' CR ...
		'- Beseitigt: Wenn Replikatgruppen nur ein Well enthielten ...' CR ...
		'- Ausgeräumt: Textfiles werden ab dieser Version nicht mehr als Input-Option angeboten' CR ...
		'0.4.4' CR ...
		'- Beseitigt: Laufzeitfehler beseitigt ...' CR ...
		'- Fehlerhafte Anzeige bei grafischer Aus-/Abwahl von Wells in Replikatgruppe' CR ...
		'- Weitere Tooltips eingefügt (Spaltenüberschriften)' CR ...
		'- Buttons in nicht mehr aktiven Fenstern entfernt' CR ...
		'- bei Neustart wurden schon vorverarbeitete Messdaten nochmals vorverarbeitet' CR ...
		'- Bei Optimierung ist die logarithmierte Differenz als "Methode" auswählbar' CR ...
		'- Bei Optimierung ist alternativ auch die "normierte Basislinie" auswählbar' CR ...
		'0.4.5' CR ...
		'- Bug Fixes: Beim Einlesen von Tabellen mit Leerzeilen (Fehler Zeile 296)' CR ...
		'- Einige Fensterpositionen angepasst' CR ...
		'0.4.6' CR ...		
		'- Einbau von Scrollbalken; mehr als 60 Wells werden damit pro Platte möglich' CR ...
		'0.4.7' CR ...		
		'- Einbau von Scrollbalken; noch nicht abgeschlossen' CR ...        
        '- Beim Öffnen mehrerer Messdaten-Dateien wird immer der zuletzt geöffnete Pfad als Vorgabe geöffnet' CR ...
        '- Überprüfung, ob Computer zur Soundausgabe fähig' CR ...
        '- QuickView-Zuordnung optimiert' CR ...
        '- QuickView: Legende wird angezeigt' CR ...
        '- Messdaten-Übersicht: Beschriftung optimiert' CR ...
        '- Verbesserte Gruppenauswahl bei Replikatgruppen (mit Maus)' CR ...
        '- Neue (wichtige) Option: Periodendauer oder Phasenverschiebung bei Optimierung konstant halten' CR ...
		'0.4.8' CR ...		
		'- Abruf der Phase und Periode von QuickView-Graphen (wenn vom Typ "Kontrolle")' CR ...                
		'0.4.9' CR ...		
		'- Normierung auf Medium/Kontrolle funktionierte nicht mehr' CR ...
        '- Ausgabe-Plots jetzt auch in X-Achse "verlinkt"' CR ...
        ' ToDo: Scrollbalken (für MTP mit mehr als 60 Wells)' CR ...
		'0.4.10' CR ...		
		'- Quote of the Day' CR ...
        '- Verlinkung der Ausgabe-Plot-Achsen war fehlerhaft' CR ...
        '- Ausgabe: Vergleich der Anpassungen für biolog. Replikate' CR ...
		'0.4.11' CR ...		        
        '- Fehler beim Neustart beseitigt' CR ...
        '- Eingabemasken für Y-Achsen Skalierung hinzugefügt' CR ...
		'0.4.12' CR ...		        
        '- Schwer reproduzierbarer Fehler bei Normierung auf Kontrolle/Medium nach Stunden gefunden und beseitigt' CR ...
		'0.5.0' CR ...
		'- Scrollbalken eingebaut' CR ...
		'- Max. Zeitangabe (> t_end) bei Auswertung führt nicht mehr zu Absturz' CR ...
		'- Tabelle bietet auch Option für Normierung auf Medium/Kontrolle-Amplitude' CR ...
		'- WICHTIG: Als Amplitude wird nun der erste Extremwert der angepassten Kurve innerhalb des gewählten Zeitfensters ausgegeben!' CR ...
		'- WICHTIG: Als Dämpfung wird nicht mehr der Faktor im Exponenten angegeben, sondern die prozentuale Abnahme zum nächsten (gleichen) Extremwert' CR ...
		' ToDo: Excel-Ausgabe mit neuen Parametern testen' CR ...
		'0.5.1' CR ...
		'- Fehler in Option zur Anfangsgewichtung funktionierte genau falsch herum!' CR ...
		'- Texte angepasst' CR ...
		'- Import von BioTec-Dateien' CR ...
		'0.6.0' CR ...
		'- Import von BioTec-Dateien verbessert' CR ...
		'- Faktor in ausgegebenen Amplituden und Phasenwerten entfernt (war: x 60)' CR ...
		'0.6.1' CR ...
		'- Neustart-Knopf deaktiviert' CR ...
		'- Biologische Replikate (vorübergehend) deaktiviert' CR ...
		'- Ausgabe in Excel-File erweitert (zB ChronAlyzer-Versionsnummer) und an neue Normierung angepasst (s. 1.5.0)' CR ...
		'- Fehler in Sortierung für BioTek-Daten' CR ...
		'- Fehler in Ergebnistabelle (Layout) behoben' CR ...
		'0.6.2' CR ...
		'- Opera-Phenix-Dateien (*.txt) können eingelesen werden' CR ...		
		'- Eingabe-Dateien mit der Endung ".txt" werden nur noch als Opera-Phenix-Dateien erlaubt' CR ...				
		'0.6.3' CR ...
		'- Änderung beim Einlesen der Biotec-Dateien: Datenpaket "Lum2" wird nun verwendet' CR ...
		'- BioTek gibt manchmal "OVRFLW" Fehler anstelle eines Messwerts; dieser wird ersetzt durch einen Mittelwert' CR ...
		'0.6.4' CR ...
		'- Neuer Button: "Save Tab+Fig", speichert alle (geöffneten!) Grafiken mit Kurvenanpassungen auf einmal' CR ...	
		'- "Mithras-Style"-Ansicht der eingelesenen MTP: Statt farbiger Markierung wird der Zeitverlauf pro Well dargestellt' CR ...
		'- Biologische Replikate wieder aktiviert' CR ...
		'0.6.5' CR ...
		'- interne Programmverbesserungen' CR ...	
		'- einige Meldungsfenster schließen sich nach kurzer Zeit automatisch' CR ...
		'- In Dialogen wurden sinnvolle Standardwerte voreingetragen' CR ...
		'0.6.6' CR ...
		'- BioTec-Daten: Die "Lum"-Werte werden nun ausgelesen (vormals: "Lum[2]")' CR ...	
		'0.7.0' CR ...
		'- Fehler beim Speichern vieler Grafiken beseitigt' CR ...
		'- Kurioser Fehler beim Speichern der Ergebnistabelle (xlsx) beseitigt (aber da ist evtl. noch einer)' CR ...
		'- Fensterposition angepasst' CR ...		
		'- "Save Tab+Fig" Button in "Save Figs" Button geändert' CR ...
		'- Einlesen von Duplikat-Biotec-Datenfiles wurde verändert; grafische Darstellung stimmt nun wieder' CR ...
		'- Erweitert von 12 auf 24 Replikatgruppen' CR ...
		'- ChronAlyzer Reports werden eingeführt (noch nicht verfügbar)' CR ...	
		'- Ergebnis-Grafiken zeigen nun auch die originalen Rohdaten unterhalb der Hauptgrafik an' CR ...
		'  (bei Replikaten stattdessen den Mittelwert)' CR ...
		'- Ausgabe-Fenster für die Mittelwerte der biolog. Replikate zeigen nun auch eine Legende an' CR ...
		'- Zeitgesteuerte Fensterschließungen verursachen keine Fehlermeldungen mehr' CR ...
		'- Neuer Default-Wert für zeitl. Auswerte-Intervallende auf 60 [h] (vorher: 48) festgesetzt' CR ...	
		'- Die Konfiguration von Replikatgruppen kann gespeichert und geladen werden' CR ...
		'- Neue DEBUG-Option: zusätzliche Grafikausgaben. Achtung: Nicht für mehr als ca. 16 Wells verwenden' CR ...
		'- Verbesserte oder ergänzte Titel, Legenden, Fehlermeldungen etc.' CR ...
		'- Der Dateiname von gespeicherten Bildern wird um Zeit&Datum ergänzt' CR ...
		'- Grafiken der techn. Replikate werden automatisch gespeichert' CR ...
		'0.7.1' CR ...
		'- Plattenübersicht zeigt jedes Well im gleichen Maßstab an' CR ...	
		'0.7.2' CR ...
		'- Überprüfung auf zulange Pfad-Datei-Namen (ToDo: work-around)' CR ...		
		'0.7.3' CR ...
		'- Erweitert von 24 auf 30 Replikatgruppen (und durch Variable ersetzt)' CR ...
		'0.7.4' CR ...
		'- Anzahl der geöffneten Figures wird überprüft und ggfs. wird der Benutzer gefragt, ob er alle geöffnet haben will (noch nicht fertig)' CR ...
		'0.7.5' CR ...
		'- Fehler in der QuickView-Datenzuordnung bei BioTek-Files beseitigt' CR ...
		'- Ein vorzeitiger Abbruch der Messung am Gerät führte zu unvollständigen Zeitdaten, die wiederum zu Fehlern ... Dies wird nun erkannt' CR ...
		'0.8.0' CR ...
		'- Inhalt des Hauptfensters lässt sich auch mit Mausrad scrollen' CR ...
		'- Import eines Layout-Files mit Beschreibung zu den Wells (obligatorisch!)' CR ...
		'  Das Plattenlayout muss im ersten Sheet einer Excel-Datei in den Zellen B3:M10 vorliegen.' CR ...		
		'- Automatisches Gruppieren (techn. Replikate) durch Informationen im Layout-File' CR ...
		'  Damit werden auch viele Diagramm-Titel u.ä. "informativer"' CR ...		
		'  Aber die Funktion für die spezielle Bedeutung von "Kontrolle" und "Medium" muss anders gelöst werden:' CR ...
		'  Die Beschreibungen (im Layout-File) für solche speziellen Gruppen müssen nun entweder die Zeichenkette' CR ...
		'  "control" oder "medium" (case insensitive) enthalten, dann werden sie als diese speziellen Gruppen erkannt.' CR ...
		'- MouseWheel-Funktion für die Well-Übersichtr auf der Main-GUI eingebaut.' CR ...
		'- Optisch wurde die GUI ein wenig aufgefrischt' CR ...
		'- "Neustart"-Funktion wieder aktiviert' CR ...
		'- Überbleibsel aus alter Annotationsmethode im Code (und GUI) beseitigt' CR ...
		'- Ausgabe in Files ebenfalls an neue Annotation angepasst' CR ...
		'- Ein neuer Schriftzug (Logo) wurde eingebaut' CR ...
		'- Kleinere Änderungen für das Zusammenspiel mit KNIME (hauptsächlich Layout/Benennung der Ausgaben)' CR ...
		'0.8.1' CR ...
		'- Minimale Anpassungen für (bereits gemergte!) Daten vom Envision' CR ...
		'- Bessere Vorbereitung für weitere, neue Geräte' CR ...
		'- Fix: Plattenübersicht (thumbnails) wurde versehentlich deaktiviert, wieder aktiviert!' CR ...
		'0.8.2' CR ...
		'- Überprüfung für falsch orientiertes Platten-Layout hinzugefügt.' CR ...
		'- Berücksichtung für nicht vollständig ausgefüllt Platten-Layouts ("[NaN]")' CR ...
		'- Vereinfachtes Auswählen von Daten von biolog. Replikaten (Mehrfachauswahl)' CR ...
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
		'- error fix when using outliers' CR ...
		'- changed wording "outliers" -> "remove noisy peaks"' CR ...
		'- added and translated more comments' ...
		];
	
	end

	% Shorten text cell in order to show only recent changes
	idx_txt		= strfind(greetingtext,version_user(2:end));
	important	= ['Note: The current version of this program needs identical time points in all data files' newline ...
		'if biological or technical replicates are to be processed!'];
	
%% Greetings (closes automatically after time)

	% quote of the day
	try
		quotes_str	= quotes;
	catch ME
		quotes_str = '';
	end
	quotes_str	= regexprep(quotes_str(1:end-1),'"(\s*- )','"\n\n');
	
	greetingtext	= ['Hello ' username '!' CR  CR 'You have started ChronAlyzer version ' version_str CR important CR repmat('-',1,85) ...
		CR CR CR  greetingtext(idx_txt:end) CR repmat('-',1,85) CR CR quotes_str ];
	
	% Output of complete greeting text
	
	dummy					= figure('dockcontrols','off','Resize','off','toolbar','none','menubar','none','nextplot','add','color',[1 1 1],'units','pixel');
	dummy.Position([2 3])	= [60 660];
	
	hbestaetigt			= uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, ...
		'String','OK','units','normalized','Position',[.4,.03,.2,.06],'Callback',{@(~,~)myclose(dummy)});
	
	image(image_data);
	logo_axes_h = gca;
	
	set(logo_axes_h,'units','pixel','position',[86.8 316 495 84],'visible','off');
	
	gruss_text_h	= uicontrol('Style','text','fontsize',9.5,'String',greetingtext, 'BackgroundColor',[1 1 1],'HorizontalAlignment','left');	
	figure_position = get(gcf,'pos');
	
	% check for quote size and adapt windows if too small
	if gruss_text_h.Extent(4) > gruss_text_h.Position(4)
		% calculate needed size change
		enlarge_diff = gruss_text_h.Extent(4) - gruss_text_h.Position(4) + gruss_text_h.Position(2);
		% move and resize
		set(gcf,'position',[figure_position(1) figure_position(2) figure_position(3) figure_position(4) + enlarge_diff])
		logo_axes_h.Position(2)		= logo_axes_h.Position(2) + enlarge_diff; % 50: space for button
		gruss_text_h.Position(2)	= 80; % 100: space for button
		gruss_text_h.Position(3)	= 620;
		gruss_text_h.Position(4)	= gruss_text_h.Position(4) + enlarge_diff + 100; % 100: space for button
		% ToDo: This re-sizing does not work if changes contain too many
		% lines --> re-write the whole section, use a fixed window height
		% and use scroll bars ...
	end
	drawnow
	
	% Starts timer and call closerequest of greetings window after 
	timed = timer('ExecutionMode','singleShot','StartDelay',10+ceil(numel(greetingtext)/20),'TimerFcn',@(~,~)myclose(dummy)); % creates timer object
	start(timed);
	pause(2) % That's a minimum time the user has to look at the greeting window
	

%% Select data sources (files)
	
	% Load all file names into "fname" and the respective paths to those files in
	% "pathname"

	% First, check last used file path (stored in user settings if one was saved before)
	if ~isempty(pfad)
		system_dependent('DirChangeHandleWarn','Never');  % If this command misses, Matlab issues a strange warning. Reset to default later on
		try
			cd(pfad) % try to switch to last used path
		catch ME
			msgbox(['Note: The last used path ("' pfad '") is not accessible.']);
			pfad = '';
		end
	end
	
	
	% List all files and let user select from these
	i = 1;
	
	while true % loop until user cancels selection of further files to import
        
        if i > 1
            cd(pathname{i-1})
		end
        
		if i == 1
			[fname{1}, pathname{1}] = uigetfile( {'*.xls*','Mithras / Biotec / Envision result files (xls xlsx)';'*.txt', 'Opera Phenix export file (txt)'}, ...
				[num2str(i) '. Select data file or cancel'],'Select first data file or cancel');
			i = i + 1;
		else
			[fname_, pathname{i}] = uigetfile( {'*.xls*','Mithras / Biotec / Envision result files (xls xlsx)';'*.txt', 'Opera Phenix export file (txt)'}, ...
				['Select ' num2str(i) '. and more data file or cancel'],['Select ' num2str(i) '. file or cancel'], 'MultiSelect', 'on');
			
			if ~iscell(fname_) % easy: only one file was selected at the same time
				
				fname{i}	= fname_;
				i			= i + 1;	

			else % user selected multiple files at once
				
				% ToDo: check if this branch still properly works further on (obviously it is not possible to select more files after)
				pathname_ = pathname{i};
				
				for j = 1:numel(fname_)
					
					if i > 1 && ~isempty(cellstrfind(fname(1:i-1),fname_{j}, 'exact'))
						uiwait(msgbox('File already selected, skipping selection, please select another or cancel','','modal'));
					else
						fname{i}	= fname_{j};
						pathname{i} = pathname_;
						i			= i + 1;
					end
					
				end
				
			end
			
		end
		
		if isempty(fname{i-1}) || isscalar(fname{i-1})
			% remove empty or invalid file selections
			fname		= fname(1:end-1);
			pathname	= pathname(1:end-1);
			break
		end

		clear fname_

		% Update user settings (last used (=actual running) version and file path for file selection)
		set_user_settings(pathname{end}); 
		
		cd(pathname{end})
		
		if numel(fname) == 1
		
			f_all	= findall(0,'Type','figure');
			timer_h = timer('TimerFcn',{@closeit f_all}, 'StartDelay', 4);
			start(timer_h)

			answer = questdlg('Loading another data file (as biological replicate)?',...
				'Loading replicate(s)?','Yes','No','No');

			if strcmp(timer_h.Running,'on') % timer still running?
				stop(timer_h);
			end
			delete(timer_h)

			if isempty(answer) 
				answer = 'No'; % default value
			end			
				
			if isempty(answer)
				answer = 'No';
			end

			switch answer
				
				case 'No'
					break

				case 'Yes'
					replicate_mode = 'biol';
					mbox_h = msgbox(['Note: For proper processing of biological replicates, all data files have to be in the same way structured as the first!'],'','modal');
					% auto time-out for dialog window:
					timed =  timer('ExecutionMode','singleShot','StartDelay',2,'TimerFcn',@(~,~)myclose(mbox_h));
					start(timed);
			end

		end
		
	end % loop is ended if "break" is called by user selection


	% -------------------
	if isempty(fname) % was file selection aborted by closing selection windows (clicking on the "red cross")? Then abort complete program 
		return
	end
	% -------------------

	system_dependent('DirChangeHandleWarn','Once'); % Reset to default; see comment above (search for "system_dependent")

	file_anz = numel(fname); % number of selected file
	
	
    if ~NoSound
        try
            [Y, FS]			= audioread('diagnosticcomplete_ep.mp3');
            sound_obj		= audioplayer(Y,FS);
            play(sound_obj);
			pause(1)
        catch
            clear sound_obj
            clear Y
            clear FS
        end
    end


	if numel(file_anz) > 1
		uiwait(msgbox(['Important notice! There is currently NO CHECK for consistent time point values in all selected data files!'],'','modal'))
	end
	
	
%% Now, import data from selected files

	% ===================================================================================
	% The following variables are created/filled here, they're important
	% (this info is hopefully useful for general understanding and developing new device adaptions)
	%
	% Outcome (after completing): 
	% "t"	:	contains a vector of measuring times (valid for all measurements!)
	% "mess":	this is a 3D-matrix; 1-dim well number (so length == 96); 2-dim: entries for all measurements (so length == length(t)); 
	%				3-dim: number of files loaded
	% "name":	cell matrix with strings, containing names of wells ("A01" ,...")	
	% ===================================================================================

	for file_idx = 1:file_anz
		
		[~,~,extension] = fileparts(fname{file_idx});
		
		
		% Data sources are not always formatted in this way, imported data
		% has to be re-formatted accordingly (or a new import filter must
		% be coded).
		
		switch extension
			
			case '.txt' % could be used for "*.csv" as well
				% Note: this case is not developed further and might be outdated.
				
				% modify text layout to your needs
				
				messdaten		= importdata(fullfile(pathname{file_idx},fname{file_idx}),'\t',9);
				result			= true;
				
				wrong_data_idx = find(isnan(messdaten.data(:,9))); % "wrong data" = incomplete data sets
				
				% try to "repair" incomplete data set (so that it can be used at least):
				% ToDo: add comments on text layout: i.e. what is in column 4 and 9 ..?
				for i = 1:numel(wrong_data_idx)
					% set entry for time
					if wrong_data_idx(i) > 1
						if messdaten.data(wrong_data_idx(i),4) == messdaten.data(wrong_data_idx(i)-1,4)
							messdaten.data(wrong_data_idx(i),9) = messdaten.data(wrong_data_idx(i)-1,9);
						else
							messdaten.data(wrong_data_idx(i),9) = messdaten.data(wrong_data_idx(i)+1,9);
						end
					end
				end
				% set measurement value to zero (because it was invalid somehow)
				messdaten.data(wrong_data_idx,5) = 0; % set measurement value to zero
				
				t								= messdaten.data(:,9)'./3600;
				t								= zeitrunden(t);
				mess							= messdaten.data(:,5);
				mess							= mess';
				
				first_measurement_idx			= find(messdaten.data(:,4) == 0); % MessInfo sometimes empty
				rows							= messdaten.data(first_measurement_idx,[1:2]);
				
				mess							= reshape(mess,numel(find(t==0)),[]);
				t								= unique(t);
				
				name							= {};
				
				for r_idx = 1:size(rows,1)
					r1			= rows(r_idx,1);
					r2			= ['0' num2str(rows(r_idx,2))];
					name{end+1} = [char(64+r1) extractAfter(r2,strlength(r2)-2)];
				end
				
				device_opera = true; % this "Opera" device can export measurement into TXT files (not used anymore)
				
			case {'.xls','.xlsx'}
				
				try
					[enum,txt,raw] = xlsread(fullfile(pathname{file_idx},fname{file_idx}));
				catch ME
					uiwait(msgbox('Note: If this notice occurs in connection with an Excel read error, the most possible reason for this are the access rights within Excel (security center)!','','modal'))
					rethrow(ME);
				end
				
				if strcmpi(raw{1,1},'lab book')
					% this error happened regulary, just by selecting the wrong file. Now, a helpful error message is given to the user
					uiwait(msgbox(['Error: The selected file "' fname{file_idx} '" does not appear to be a valid data file!'],'','modal'))
					error(['The selected file "' fname{file_idx} '" does not appear to be a valid data file!'])
				end
				
				if size(raw,2) > size(txt,2)
					% "error" in Excel file?  "raw" contains too many columns
					raw(:,size(txt,2)+1:end) = [];
					msgbox(['Warning: Possible inconsistence in ' fname{file_idx} ', maybe just caused by additional empty rows or columns (if so, this warning can be ignored)'])
				end
				
				
				anz_reads = numel(cellstrfind(txt(:,1),'^Time')); % How many data sets are found in the actual file (was only important for Mithras device)
				
				% We use now the Envision device, this does not use the keyword "Time", but instead this:
				if anz_reads == 0
					anz_reads = numel(cellstrfind(txt(:,1),'^t \[h\]')); % Für Envision-Files: Wieviele Datensätze sind in diesem File enthalten?
				end
				
				
				% Note:
				% -- Mithras and Envision devices use the word "Time" only once; in the column before the time-series data. Detect Envision by
				% finding the key word "Synergy Neo2". This should be modified for different devices.
				% -- BioTec uses "Times" twice; the first in the meta data header, the second in the second column before the measurement data
				
				
				if anz_reads > 1 && file_anz > 1
					error('The current version of this program cannot process biological replicates and data files containing multi-channel data at the same time!')
				end
				
				if anz_reads > 2
					error('Somehow this program encounters unexpected data structures, perhaps an update is needed (please contact author, code:"Channel anz_read > 2")');
				end
				
				% ------ Actual reading of file content starts here -------------------
				
				if size(txt,1) == 1 % Detect device-dependent text entries
					
					% Device: Envision
					
					device_envision	= true;
					data_starts		= 2;
					data_ends		= size(raw,1);
					
					if isempty(raw{data_ends,1})
						error('Error reading XLSX file, perhaps caused by empty rows at the end?')
					end
					if ~isnumeric(raw{data_starts,1})
						error('Error reading XLSX file, perhaps additional rows in front of expected data?')
					end
					
				else
					
					% Device: BioTec or Mithras
					
					if ~strcmpi(txt{8,2},'synergy neo2') % = Mithras
						
						device_mithras	= true;
						
						data_starts		= cellstrfind(txt(:,1),'^Time');
						data_ends		= cellstrfind(txt(:,1),'','exact');
						
						if isempty(data_ends)
							% This happens sometimes, in particular after manual editing of the data file.
							% work-around to prevent this "error": append a empty row in excel (with a space character) and save again
							data_ends = size(txt,1);
						end
						
						try
							if  numel(data_ends) == 0 || (numel(data_ends) > 0 && data_ends(1) < data_starts)
								uiwait(msgbox('Mithras data file has unexpected format!? Can''t process further! (Please contact author)','','modal'))
								error('Reading error: Mithras format')
							end
						catch ME
							uiwait(msgbox(['The selected file "' fname{file_idx} '" does not appear to be a valid data file!'],'','modal'))
						end
						
						if numel(data_ends) > 1
							data_ends = data_ends(1);
						end
						
						data_ends = data_ends-1;
						
					else % BioTec
						
						device_biotek	= true;
						data_starts		= cellstrfind(txt(:,2),'^Time');
						
						if numel(data_starts) > 1
							data_starts = data_starts(1); % The first entry is important (coded as "[Lum]"), the values in the second one ("[Lum2]") were amplified.
							% By using the first section there should be much less "OVERFLW" entries
						end
						
						dummy		= cellfun(@isnan,raw(:,2),'uniformoutput',false); % "NaN" == leere Excel-Zellen?
						data_ends	= find([cellfun(@any,dummy(data_starts+1:end,1))] == 1,1,'first') + data_starts -1;
						
						if numel(data_ends) > 1
							msgbox('Too many entries for time points found, perhaps multi-channel data file or manually edited file?! Please check result!')
						end
						
						data_ends = data_ends - numel(find(cell2mat(raw(data_starts+2:data_ends,2))==0));
						% Note: Boiotec data sheets sometimes contain rows with "00:00:00" times, but otherwise empty.
						% This happens when the measurement is interupted manually at the device.
						
					end
					
				end
				
				if isempty(data_ends)
					data_ends = size(txt,1);
				end
				
				% ------ Importing of file text content starts here ----------------------
				
				% Reading measurement time information
				if file_idx == 1
					
					if device_mithras
						t			= txt(data_starts(1)+1:data_ends(1),1);
						t			= convert_Time2DecHour(t); % Conversion of time from character string
					elseif device_biotek
						t			= cell2mat(raw(data_starts+1:data_ends,2)) * 24; % Conversion of decimal time into hours
						t			= t'; % Transponieren
					elseif device_envision
						t			= cell2mat(raw(data_starts:data_ends,1)); % No conversion nesessary
						t			= t'; % Transponieren
					end
					
				else
					
					if device_mithras
						t_			= txt(data_starts(1)+1:data_ends(1),1);
						t_			= convert_Time2DecHour(t_); % Conversion of time from character string
					elseif device_biotek
						t_			= cell2mat(raw(data_starts+1:data_ends,2)) * 24; % Conversion of decimal time into hours
						t_			= t_'; % Transponieren
					elseif device_envision
						t_			= cell2mat(raw(data_starts:data_ends,1)); % No conversion nesessary
						t_			= t_'; % Transponieren
					end
					
					if numel(t) ~= numel(t_)
						
						msgbox('Warning: Files contain different amounts of time points! Using only the shortest time series!')
						
						if numel(t) > numel(t_)
							% the last imported data set is shorter then the first imported! Action: Reduce longer files!
							mess = mess(:,1:end - abs(diff([numel(t),numel(t_)])),:);
							t = t_; % shortening
						else
							% the last imported data set is longerr then the first imported! Action: Reduce longer files!
							data_ends = data_ends - abs(diff([numel(t),numel(t_)])); % move data_ends value accordingly
						end
						
					end
					
					clear t_
				end
				
				if device_mithras
					name		= txt(data_starts(1),2:end); % Wellnamen
				elseif device_biotek
					name		= txt(data_starts(1),4:end); % Wellnamen
				elseif device_envision
					name		= txt(data_starts-1,3:end); % Wellnamen
				end
				
				biolgr_name = [biolgr_name name];
				
				% Read measurement values
				
				for daten_idx = 1:anz_reads
					
					if device_mithras
						
						disp('Mithras data file detected!')
						
						mess_{daten_idx}		= cell2mat(raw(data_starts(daten_idx)+1:data_ends(daten_idx),2:end));
						read_titel(daten_idx)	= raw(data_starts(daten_idx)-1,1); % only used for files containing multiple data sets
						
					else % = Biotek or Envision measurements
						
						disp('Biotek or Envision data file detected! (or special case: test data)')
						
						try
							if device_biotek
								mess_{daten_idx} 	= cell2mat(raw(data_starts(daten_idx)+1:data_ends(daten_idx),4:end));
							elseif device_envision
								mess_{daten_idx} 	= cell2mat(raw(data_starts(daten_idx):data_ends(daten_idx),3:end));
							end
							
						catch ME
							
							if device_envision
								error('Error while reading data')
							end
							
							uiwait(msgbox(['There are OVERFLW values within the imported data! Those will be replaced now by the average ' ...
								'of the adjacent values. Please chech the results!'],'','modal'))
							% This error should not occur any longer. This happened only, if the second measurement set
							% in the file was used ("[Lum2]") which was already modified (amplified) by the device software
							
							if strcmp(ME.identifier, 'MATLAB:cell2mat:MixedDataTypes')
								
								dummy	= raw(data_starts(daten_idx)+1:data_ends(daten_idx),4:end); %
								idx		= find(cellfun(@ischar, dummy));
								
								for i = 1:numel(idx)
									
									if idx(i) == 1 && idx(i+1) ~= 2
										% if only the first entry reads OVERFLW, and the second not, just take the next value
										dummy(1) = dummy(2);
									elseif idx(i) == numel(dummy) && idx(i-1) ~= (numel(dummy)-1)
										% ToDo: Same kind of problem if last entry is missing; use second-to-last
										
									elseif idx(i) > 1 && idx(i) < numel(dummy)
										% entry between start and end: Just calculate the mean (user was
										% informed about this work-around above)
										dummy(idx(i)) = {round(mean([dummy{idx(i)-1},dummy{idx(i)+1}]))};
									else
										uiwait(msgbox('There are OVEFLW values at the beginning or the end of the data. Please edit the file before using the ChronAlyzer again.','','modal'))
										error('There are OVERFLW entries in the data files which can''t be corrected automatically!');
									end
									
								end
								
								raw(data_starts(daten_idx)+1:data_ends(daten_idx),4:end) = dummy;
								mess_{daten_idx} = cell2mat(raw(data_starts(daten_idx)+1:data_ends(daten_idx),4:end));
								
							end
							
						end % try catch
						
						
						% BioTec device software always writes 96 wells into file: Delete unused wells.
						
						% Note: The developement for ChronAlyzer was for Mithras device only at the beginning.
						% It would have been better to use the BioTec layout from the beginning. ToDo: Rewrite software
						% (Always use a complete 96 matrix (8x12) ...)
						
						del_idx = [];
						
						if size(mess_{1},2) < 96
							disp('test data detected! (otherwise at least 96 well entries were expected)')
							for spalte_idx = 1:size(mess_{1},2)
								del_idx = [del_idx, all(isnan(mess_{1}(:,spalte_idx)))];
							end
							% data matrix doesn't have to be filled, because it will be shrinked anyway
							
						else
							
							for spalte_idx = 1:96
								del_idx = [del_idx, all(isnan(mess_{1}(:,spalte_idx)))];
							end
							
						end
						mess_{1}(:,logical(del_idx))	= []; % remove empty columns
						name(logical(del_idx))			= [];
						
						if ~device_envision
							read_titel(daten_idx)			= txt(6,2);
						else
							read_titel(daten_idx)			= fname(daten_idx);
						end
						
						% Important check: Are there measurement for all wells for all times? If not, there will be errors
						% (see below, text in messagebox).
						% --> work-around: Cut those entries ...
						
						% ToDo: Whole measurement data matrix system must be checked or better
						% be reworked (in particular if non-96 well plates are introduced)
						
						dummy	= any(cell2mat(cellfun(@isnan, mess_,'UniformOutput',false)),2);
						
						if any(dummy)
							
							mess_{1}(dummy,:)	= [];
							t(dummy)			= [];
							
							uiwait(msgbox(['There are empty rows (or at least some cells in those rows are empty) in the file "' fname{file_idx} ...
								'". Perhaps caused by a manually stop of the experiment. All data in these rows are about to be ignored. But this ' ...
								'can result in error when biological replicates are considered.' newline 'Proposed remedy: Manually edit all files ' ...
								'in question before starting the ChronAlyzer again.'],'','modal'))
							
						end
					end
					
				end % schleife über alle Dateien
				
				if anz_reads > 1 % this variable is > 1 only if there are multiple data sets within one file (only ever noticed with Mithras (I think))
					
					a = ['1. Datensatz = ' read_titel{1} ' - ' read_titel{2}];
					b = ['2. Datensatz = ' read_titel{2} ' - ' read_titel{1}];
					
					% ToDo: Documentation is needed for this question - I can't remember since we don't use the Mithras device
					% anymore (since several years)
					answer = questdlg('Which set of data do you want to modify?','Modification',a, b, a);
					
					switch answer
						case a
							mess_{1} = mess_{1} - mess_{2};
						case b
							mess_{2} = mess_{2} - mess_{1};
					end
					
					mess(:,:,1) = mess_{1}';
					mess(:,:,2) = mess_{2}';
					
				else
					
					mess_ = mess_{1}';
					
					if file_idx == 1
						
						mess = NaN(size(mess_,1),size(mess_,2),file_anz);
						
					end
					
					
					% ToDo: Maybe this IF-ELSE-THEN is obsolete, I have to check biological and technical replicates were handled
					% differently in early versions of ChronAlyzer
					
					if strcmp(replicate_mode, 'tech')
						
disp('This should not be called anymore!')
keyboard	
						
						if any(size(mess(:,:,1)) ~= size(mess_))
							
							msgbox(['Error: To make use of technical replicates, data files must be structured in the same way:' CR ...
								'Same used wells and same measurement times!'],'','modal')
							
							if size(mess_,2) ~= size(mess(:,:,1),2)
								
								msgbox(['Time range of experiment in file "' fname{file_idx} '" doesn''t fit; I am trying to shorten measurements! Please check results carefully!'],'','modal')
								
								if size(mess_,2) > size(mess(:,:,1),2)
									
									mess_	= mess_(:,1:size(mess(:,:,1),2),1);
									t		= t(1:size(mess,2));
									
								else
									
									mess	= mess(:,1:size(mess_(:,:),2),1);
									
								end
								
							else
								
								error('Proably user error (code: "No technical replicates were selected")')
								
							end
						end
						
						mess(:,:,file_idx) = mess_;
						
					elseif strcmp(replicate_mode, 'biol')
						
						if file_idx == 1
							
							mess = NaN(96,size(mess_,2),file_anz);
							
						elseif size(mess(:,:,1),2) ~= size(mess_,2) % different time-series lengths!
							
							uiwait(msgbox(['The selected data files contain data sets of different sizes (-> number of measurements)', CR ...
								'Only identical measurements can be merged! Please check your file selection!' CR ...
								'Now, without further checks, the data sets are constrained to the shortest common test duration!!'], '','modal'));
							
							if size(mess,2) > size(mess_,2) % New file's time-series is shorter, shorten previous files
								
								mess	= mess(:,1:size(mess_,2),:);
								% don't need to fill "t" again, because this is not the first file and "t" must be the same for all
								
							elseif size(mess,2) < size(mess_,2) % new file's time-series is longer, cut this one according to previous "t"
								
								mess_	= mess_(:,1:size(mess,2));
								t		= t(1:size(mess,2));
								
							end
							
						end
						
						mess(:,:,file_idx) = wellname_pos(mess_, name); % do it for all wells anyway
						
					else % case if no replicate group was used, neither biological nor technical
						
						if file_anz > 1
							error('I am sorry, this should have not occured (error code: "f_anz > 1"')
						end
						
						if size(mess_,1) == 96
							mess = wellname_pos(mess_, name); % respects the order of wells in file
						else
							mess = mess_;
						end
						
					end
					
					clear mess_;
					
				end
				
			otherwise
				
				warning(['unknown file type: "' fname{file_idx} '"']);
				continue
				
		end % switch (file) extension
		
		% checking data
		if numel(t) < 5 % and this
			uiwait(msgbox('The imported files do not contain time series or at least too few measurements!','','modal'))
			error('The imported files do not contain time series?!');
		end
		
		[~,filename,~] = fileparts(fname{1});
		
		% ToDo:
		% check for equidistant measurement times create a global weighting factor vector, and set the value to zero
		% when a measurement is missing (or is later declared as a 'noisy peak' by the user).
		
		
%% Import Layout (only once, when importing the first file) -- (still inside loop)
		
		if file_idx == 1
			
			OK = false;
			while ~OK
				
				mbox_h = msgbox(['Next: Please select a) a data file with the used wells layout (if not available press cancel), ' ...
					'b) then select the Excel cells containing the labels of each well AND the row and column with labels (A-H, 1-12)'],'Annotation file?' ,'modal');
				
				child					= get(findobj(mbox_h,'type','Axes'),'Children');
				child.FontSize			= 10;
				mbox_h.OuterPosition(3) = 350;
				
				timed = timer('ExecutionMode','singleShot','StartDelay',5,'TimerFcn',@(~,~)myclose(mbox_h));
				% auto time-out
				start(timed);
				
				% get layout file name from user
				[layoutname, layoutpath] = uigetfile( {'*.xls*','well-layout File (xls xlsx)'}, ...
					'Select well-layout file or cancel','select file or cancel');
				
				if layoutpath == 0
					
					uiwait(msgbox(['For future application, please place the well-layout whether in the same (in a different sheet) or a seperate Excel file:' newline ...
						'The content of the Excel cells will be used as label for the wells.'],'','modal'))
					
					% create a generic named well-layout
					
					for wi = 1:8
						for wj = 1:12
							layoutraw{wi,wj} = [char(64+wi) num2str(wj,'%02.0f')];
						end
					end
					
					OK = true;
					
					layouttxt			= cellfun(@num2str,layoutraw,'UniformOutput',false); % converts all into text, even NaN
					
				else
					
					try
						[layoutnum,layouttxt,layoutraw] = xlsread(fullfile(layoutpath,layoutname),-1); 
					catch ME
						layoutraw = [];
					end
					
					if size(layoutraw,1) < 2
						
						answer = questdlg('Apparently no range of cells were selected within the XLS file. Abort program or repeat file selection?','Abort or Repeat?','Abort','Repeat','Repeat');
						if strcmp(answer,'Abort')
							return
						end
						
						continue
						
					else
						
						% delete empty rows (perhaps used be combined Excel rows
						delete_rowidx = [];
						
						for wi = 1:size(layoutraw,1)
							if numel(cell2mat(cellfun(@isnan,layoutraw(wi,:),'UniformOutput',false))) == size(layoutraw,2) && ...
									all(cell2mat(cellfun(@isnan,layoutraw(wi,:),'UniformOutput',false)))
								delete_rowidx = [delete_rowidx;wi];
							end
						end
						if ~isempty(delete_rowidx)
							layoutraw(delete_rowidx,:)=[];
						end
						
						if ((size(layoutraw,1)-1) * (size(layoutraw,2)-1)) < numel(name)
							warning(['Layout data not complete? For each well on the plate should exist a corresponding Excel cell entry ' ...
								'AND additionally the labels of the rows and columns (e.g. "A-H" and "1-12")!'])
						end
						
						OK = true;
					end
					
					layouttxt			= cellfun(@num2str,layoutraw,'UniformOutput',false); % converts everything into text, even NaN
					layouttxt			= layouttxt(2:end,2:end); % cut labels (A-H, 1-12)
					
				end
				
			end % repeat file selection until data are good (or arbitrary)
			
			name_gruppen_layout = setxor(unique(layouttxt),'NaN');
			anz_gruppen_layout	= numel(name_gruppen_layout);
			
		end
		
	end


%% some clean-up after all data are imported (loop end)
	
	% this is a quick & dirty fix:
	if device_mithras
		num_sorted		= true; % Mithras data are order by numbers (A1, B1, ..., H1, A2, ...)
	else
		num_sorted		= false; % BioTek and Envision are order by letters (A1, A2, ..., A12, B1, B2, ...)
	end

	
	if strcmp(replicate_mode,'biol') && device_mithras
		
		name				= asort(unique(biolgr_name));
		name				= reshape(name.anr,1,[]);
		anz					= numel(name);
	
	else
		anz					= numel(name);
	end

	
	for i = 1:numel(name)
        if numel(name{i}) == 2 % nur "B2" anstatt von "B02"
            name{i} = [name{i}(1) '0' name{i}(2)];
        end
	end
	
	% check again
	if any(any(diff(reshape(cell2mat(cellfun(@size,name,'UniformOutput',false))',2,numel(name)),2,2)))
		uiwait(msgbox('Error: Imported well descriptions are not in the anticipated format (e.g. "B05")','','modal'));
		error('Imported well descriptions are not in the anticipated format (error code 1121)')
	end

	% ===================================================================================
	% Outcome of this section (as stated at the beginning of the big loop):
	% "t":		contains a vector of measuring times (valid for all measurements!)
	% "mess":	this is a 3D-matrix; 1-dim well number (so length == 96); 2-dim: entries for all measurements (so length == length(t));
	%				3-dim: number of files loaded
	% "name":	cell matrix with strings, containing names of wells ("A01" ,...")			
	% ===================================================================================
	
	
	
%% Show thumbnail ansd plate layout	

	% ===============================================
	
	show_Thumbnails;
	show_layout;
	% ToDo: Since plate layout is imported from xls file, there's no real need to display it. Perhaps just to enable the user to see if the
	% correct file was selected and loaded?
	
	% ===============================================

%% "Considering" of biological replicates

	% General idea of work-flow: If biological replicates are loaded, these are not averaged immediately (in contrast to technical replicates)
	% Still, it might be interesting to see the difference between several plates

	if file_anz > 1 % && strcmp(replikat_mode, 'tech'),

		stdabw	= std(mess,0,3,'omitnan'); % calculate standard deviation
		% Note: "omitnan" ignores single NaN entries - it can always happen that a well or a single measurement (time & well) failed
		% Single NaNs will be already replaced (above) by the average of adjacent values
		%
		% For the percentage calculation I set the minimum to 0.1 in order to prevent division by zero - and this is only for display of
		% course. The percentage value refers to the first selected plate.
		
		if strcmp(replicate_mode, 'biol')

			notnan_xidx = [];

			for d_idx = 1:size(mess,3)
				notnan_xidx = [notnan_xidx; find(~isnan(mess(:,1,d_idx)))]; % find all columns with NaNs (e.g.: empty/failed well)
			end
			
			% Addtional: Keep only those with at least two data sets are available (can't calculate "std" otherwise)

			not2nan_xidx = notnan_xidx; 
			for i = numel(not2nan_xidx):-1:1
				if numel(find(not2nan_xidx(i) == not2nan_xidx)) == 1 % found only a single entity ...
					not2nan_xidx(i) = []; % ... therefore: remove element
				end
			end
			
			not2nan_xidx	= unique(not2nan_xidx);
			notnan_xidx		= unique(notnan_xidx);			
			stdabw			= stdabw(not2nan_xidx,:);		% clear columns from std-matrix
			full_mess		= mess(notnan_xidx,:,:);		% save full matrix for later
			mess			= mess(not2nan_xidx,:,:);		% clear columns from meas-matrix
			
			% Explanation: Only for the graphical comparision wells with at least 2 replicates are valid. 
			% But of course those with only one entity are valid for analyze as well
			
		else
			
			% With technical replicates this is much easier :-)
			notnan_xidx = 1:size(mess,1);
			
		end
		
		
		if strcmp(replicate_mode, 'tech') 
			
disp('This shouldn''t be called here')			
keyboard
			% ================================================================
			% Here, the averaging of technical replicates is performed
			mess = mean(mess(not2nan_xidx,:,:),3);
			% ================================================================
		
		end
		
		f				= figure;
		f.Position		= [50   50  970  800];
		if strcmp(replicate_mode, 'biol')
			f.Name		= 'Comparison of biological replicates: Average value and standard deviations (+/-)';
		else
			f.Name		= 'Comparison of biological replicates';
		end
		f.NumberTitle	= 'off';

		%[subplot_x,subplot_y] = calc_subplot(size(mess,1));		-- kann
		%man vielleicht für variable Plattengrößen verwenden ..
		
		subplot_x	= 12;
		subplot_y	= 8; 
		k			= 0; % Indexzähler für die Images
		
		for i = 1:subplot_x
			for j = 1:subplot_y


				k = k + 1;
				if k > size(mess,1)
					break
				end
				subplot(subplot_y, subplot_x, k)

				plot(t,mean(mess(k,:,:),3,'omitnan'),'k:',t,mean(mess(k,:,:),3,'omitnan')+stdabw(k,:),'k-', ...
					t,mean(mess(k,:,:),3,'omitnan')-stdabw(k,:),'k-'); % "mean" ist für biol.-Repl.-Fall !

				k_to_name = k; % Matrix wurde geändert, so stimmt es jetzt für biotec
				title([name{k_to_name} ],'fontsize',8);
				if i == subplot_x % ToDo: Falls unterste Zeile nicht voll, müsste Unterschrift in vorletzte Zeile
					xlabel('t [h]')
				end
				
				if strcmp(replicate_mode, 'tech') 
					
disp('This shouldn''t be called here')			
keyboard					
					name{k} = ['MHA-' name{k}]; % damit in Zukunft klar wird, dass Mittelwert von t.Repl. dargestellt wird
				end
		 
				curax			= gca;
				curax.XLim(2)	= t(end);
				if any(stdabw(k,:)) > 0 && (max(mean(mess(k,:,:),3,'omitnan')+stdabw(k,:)) > min(mean(mess(k,:,:),3,'omitnan')-stdabw(k,:))),
					% ansonsten sind die Daten der Wells vermutlich einfach
					% leer
					curax.YLim(2)	= max(mean(mess(k,:,:),3,'omitnan')+stdabw(k,:));
					curax.YLim(1)	= min(mean(mess(k,:,:),3,'omitnan')-stdabw(k,:));
				end
				curax.FontSize	= 6;
				
			end
		end
		
		% Skalen normieren		
		idx = findobj(f,'Type','axes');
		for i = 1:numel(idx)
			idx(i).YLim = [max(0,min([idx.YLim])) max([idx.YLim])];
		end

		figure(f);
        
        help_text = uicontrol('Style','text','fontsize',11, ...
			'String','Averaged and standard deviation from all biological replicates are shown here, not individual time series!','units','normalized','Position',[.05,.935,.5,.05]);
        
		hbestaetigt = uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, ...
			'tooltip','From now on: Averaged value will be used instead of individual technical replicates.', ...
			'String','Using the averaged values (displayed as dashed line) from now on','units','normalized','Position',[.55,.95,.4,.04],'Callback',{@OK_Button_Cb});
	
		
		if strcmp(replicate_mode, 'biol')
			
			hbestaetigt.String	= 'User acknowledged standard deviations, continue ...';
			mess				= full_mess;	% Stelle vollständige Matrix wieder her
			
		end
		
		OK = false;
		while ~OK
			pause(0.2)
			drawnow
			if ~ishandle(f)
				answer = questdlg('Really abort?','','Yes','No','No');
				if strcmp(answer, 'Yes')
					error('User wanted abortion')
				else
					break % weiter machen
				end
			end
		end
		
		if OK % falls Schleife durch break verlassen wurde
			hbestaetigt.Visible = 'off';
		end
		
		OK	= false;
		
	end
	
	OK = false; % restore default value
	
%% Aufbau der GUI 

	mainfig_max		= min([1200 monitor(4)-50]); % 1280
	mainfig_max		= 1025;
	mainfig_min		= 10;

	old_fig = findobj(0,'tag','Table');

	if isempty(old_fig)

		tabelle_fig_h = figure;
		set(gcf,'dockcontrols','off','Resize','off','toolbar','none','menubar','none','tag','Table',...
		'Position',[10 mainfig_min 1200 mainfig_max], 'Color', [1 1 1], ...
		'numbertitle','off');
		set(gca,'visible','off','clipping','off','position',[0.0 0.0 1 1]);
		set(gcf,'WindowButtonDownFcn', @Mouse_Select_Down_Cb);
		set(gcf,'windowscrollWheelFcn',@MWheel);
		set(gcf,'CloseRequestFcn',@allclose_Cb);
		
		panel		= uipanel('position',[0 -1 0.985 1],'Tag','uipanel');	
		vscrollbar	= uicontrol('style','slider','units','normalized','position',[.985 0 .015 1],'value',1,'Tag','uiscroll','callback',@vscroll_Callback);
		% Alle Komponenten müssen an das "panel" angebunden werden, zB:
		% uicontrol('parent',panel,'style','text','string','test')
		%           ^^^^^^^^^^^^^^	
		
		xlim([0 1]);
		ylim([0 1]);
		
		if ~isempty(replicate_mode) % biological replicate
			tabelle_fig_h.Name	= strjoin(fname,' + ');	
		else
			tabelle_fig_h.Name	= filename;
		end

		drawnow

	else

		tabelle_fig_h = old_fig;
		figure(tabelle_fig_h);
		cla;
		panel		= findall(0,'Tag','uipanel');	
		vscrollbar	= findall(0,'Tag','uiscroll');
		
	end

	% Hinweis: Diese Tabelle ist wegen Benutzeranfragen immer weiter
	% gewachsen, ich hätte es anders machen sollenm, aber so ist der Code
	% eben mitgewachsen.
	uicontrol('parent',panel,'style','text','units','normalized','position',[.0225 .9650 .05, .008],'string','QuickView','fontsize',8,'tooltip','Click on well button for display');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.0205 .9575 .16   .008],'string','Well    -    Replicate group','fontsize',9,'tooltip','name of well or group');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.16   .9575 .075 .008],'string','Amplification','fontsize',9,'tooltip','Amplitude of first peak');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.2525 .9575 .08  .008],'string','Damping [%]','fontsize',9,'tooltip','Difference from peak to peak (in percent)');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.3375 .9575 .06  .008],'string','Period [h]','fontsize',9,'tooltip','Period length');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.4225 .9575 .06  .008],'string','Phase [min]','fontsize',9,'tooltip','Phase-shift at test start');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.58   .9575 .075 .008],'string','Basis_Amp','fontsize',9,'tooltip','experimentell');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.66   .9575 .075 .008],'string','Basis_Dam','fontsize',9,'tooltip','experimentell');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.74   .9575 .075 .008],'string','Basis_Off','fontsize',9,'tooltip','experimentell');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.82   .9575 .075 .008],'string','Error','fontsize',9,'tooltip','Fitting error between measurements and model (divided by number of measurement times)');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.90   .9575 .075 .008],'string','Outlier?','fontsize',9,'tooltip','Has the user marked noisy peaks?');
	uicontrol('parent',panel,'style','text','units','normalized','position',[.0256 .951  .045 .0055],'string','all/none','fontsize',8);
	
	% Sortierung der Wells
	buttongroup_h0	= uibuttongroup('parent',panel,'Position',[.01 0.975 .08 .02], 'clipping','on');
	s0				= uicontrol('Style','Radio','String','1','units','normalized', 'tooltip','Sorting by number', ...
		'pos',[.55 0.15 .3 .4],'parent',buttongroup_h0,'HandleVisibility','off','Callback',{@Sort_1_Cb});

	s1				= uicontrol('Style','Radio','String','A','units','normalized', 'tooltip','Sortierung by letter', ...
		'pos',[.2 0.15 .3 .4],'parent',buttongroup_h0,'HandleVisibility','off','Callback',{@Sort_A_Cb}, 'value',1);

	sort_text_h		= uicontrol('parent', panel,'style','text','String','Order of Wells','units','normalized','pos',[0.015 .9875 .07 .0065]);		
	
	% Normierung der Ausgaben 
	buttongroup_h1	= uibuttongroup('parent',panel,'Position',[0.43 0.975 .1675 .02], 'clipping','on');
	s2				= uicontrol('Style','Radio','String','N/A','units','normalized', 'tooltip','Show absolute values of phase', ...
		'pos',[.04 0.15 .25 .4],'parent',buttongroup_h1,'HandleVisibility','off','Callback',{@Phase_1_Cb}, 'value',1); 

	s3				= uicontrol('Style','Radio','String','control','units','normalized', 'tooltip','Show phase relative to "control" group', ...
		'pos',[.32 0.15 .45 .4],'parent',buttongroup_h1,'HandleVisibility','off','Callback',{@Phase_2_Cb}, 'value',0);

	s4				= uicontrol('Style','Radio','String','medium','units','normalized', 'tooltip','Show phase relativ to "medium" group', ...
		'pos',[.68 0.15 .45 4],'parent',buttongroup_h1,'HandleVisibility','off','Callback',{@Phase_3_Cb}, 'value',0);
	phasen_text_h = uicontrol('parent', panel,'style','text','String','Normalization to ...','units','normalized','pos',[0.475 0.9875 .08 .007]);		
	
	set(buttongroup_h1,'visible','off');
	set(phasen_text_h,'visible','off');

	ausreisser_h	= uicontrol('parent',panel,'Style','checkbox','value',0,'units','normalized','position',[0.23 0.985 0.015 0.01],'tooltip','Open window to select "noisy peaks"');
	debug_h			= uicontrol('parent',panel,'Style','checkbox','value',debug,'units','normalized','position',[0.23 0.975 0.015 0.01],'tooltip','Open additional output windows (beware: this is for debugging mainly, it can open too many windows to handle!)');
	text_ausreiss_h = uicontrol('parent',panel,'style','text','String','Remove noisy peaks ?','units','normalized','position',[.123 .9865 .095 .007],'fontsize',8);		
	text_debug_h	= uicontrol('parent',panel,'style','text','String','Debug outputs ?', 'units','normalized','position',[.13 .9765 .09 .007],'fontsize',8);		
	
	pos		= 968 + round((mainfig_max-mainfig_min) - 15.7*((1:anz+1)+2));


	% Aus Experimentlayout gelesene Daten verwenden
	dropdown_str =  unique([{' ','control','medium'},name_gruppen_layout(:)']);
	dropdown_str =  name_gruppen_layout; % ToDo;: Jetzt ist nicht mehr sichergestellt, wie die beiden Sondergruppen
	% Kontrolle und Medium zu erkennen sind.
	% Das erste Element muss aber noch ausgetauscht werden, damit es dem
	% Plattenlayout entspricht, das muss aber unten erfolgen.
	

	%##### hier wird wieder eine große Matrix erwartet, aber bei der Behandelung techn. Replikate ist die Matrix
	%##### verkürzt worden. Dort eventuell daher nur temp. Variablen verwenden, oder hier halt nicht die große Matrix
	%##### verlangen
	
	if strcmp(replicate_mode, 'biol')
			
			for wellidx = 1:size(mess,1) %96,
				anz_rep(wellidx) = sum(~isnan(mess(wellidx,1,:))); % Wieviele Replikate gibt es pro Well
			end
			
	else
		
		anz_rep = [];
		
	end
	
	panel.Position(4) = 2; % rücke Blickfeld der Figure richtig (ist vorher außerhalb des Sichtbereichs)
	
	for i = 1:anz
        
        % Hinweis: Die Maus-Events (auch der Callback "QuickView_Cb")
        % benötigen eine Variable, die erst mit dem Aufruf von
        % "Sort_A_Cb()" gefüllt wird! (Bei Debugging beachten!)
        
		if strcmp(replicate_mode, 'biol')
			
            t_h(i)	= uicontrol('parent',panel,'Style','pushbutton','units','pixel', 'position',[32 pos(i)-8 50 15],'String',[name{i} ' (x' num2str(anz_rep(i)) ')'], ...
                'Callback',{@QuickView_Cb,i});
		else
			
            t_h(i)	= uicontrol('parent',panel,'Style','pushbutton','units','pixel', 'tooltip', 'click to display raw data', 'position',[32 pos(i)-8 50 15],'String',name{i}, ...
                'Callback',{@QuickView_Cb,i});
			
        end
		
		check_h(i)	= uicontrol('parent',panel,'Style','checkbox','value',0,'units','pixel', 'tooltip','select well for analysis', ...
			'position',[0 pos(i)-8 15 15],'Tag',name{i},'Callback',{@Sample_Button_Cb}); % set UserData some more lines below
		
		% todo braucht es überhaupt noch ein dropdown menü wenn Bezeichnung durch layoutFile festgelegt ist?
		% Nein, aber komplettes umschreiben ist aufwändig, daher werden
		% einfach statische Texte hinzugefügt.

		% berechne aus name() die Position in layout-Matrix
		[col_, row_] = calc_pos(name{i});
		str_ = layouttxt{col_,row_}; 
		value = cellstrfind(name_gruppen_layout, str_,'exact');
 		drop_h(i)	= uicontrol('parent',panel,'Style','text','String',str_, 'tooltip','right click on replicate group name to select all wells belonging to this group', ...
 					'units','pixel','Position',[90 pos(i)-7 100 12],'Tag',['check' num2str(i)],'Callback',{@Select_dropbox_Cb},'fontsize',6, 'value',value);
		set(check_h(i),'UserData',str_);				

				
	end
	
	uica_h	= uicontrol('parent',panel,'Style','checkbox','value',0,'units','pixel', 'tooltip','all on/off', 'BackgroundColor', [1 0 0], ...
			'position',[0 pos(1)-8+18 15 15],'Tag',['check' num2str(i)],'Callback',{@On_Off_Cb}); % 
		
	if device_mithras
		Sort_A_Cb();
	else
		%Sort_1_Cb(); -- unnötig, Daten liegen schon so vor
	end

	Amp			= NaN(anz,1);
	Dam			= NaN(anz,1);
	Per			= NaN(anz,1);
	Pha			= NaN(anz,1);
	Basis_Amp	= NaN(anz,1);
	Basis_Dam	= NaN(anz,1);
	Basis_Off	= NaN(anz,1);
	Fehler		= NaN(anz,1);

	ausreisser_liste = cell(1,anz);


	hStart		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12,'Enable','off', 'tooltip','Start analysis', ...
		'String','Start','units','normalized','Position',[.6,.965,.1,.04],'Callback',{@Start_Button_Cb});

	hStop		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[1 0 0],'fontsize',12, 'tooltip','Abort program', ...
		'String','Abort','units','normalized','Position',[.7,.965,.1,.04],'Callback',{@Stop_Button_Cb});

	hNeustart	= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.2 1 .2],'fontsize',12,  'tooltip', 'Re-start programm', ...
		'String','Re-Start','units','normalized','Position',[.8, .965,.1,.04],'Callback',{@Neustart_Button_Cb},'Enable','off');

	hHilfe		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.9 .9 .9],'fontsize',9,  'tooltip', 'N/A', ...
		'String','Help / Annotation','units','normalized','Position',[.8, .98,.1,.02],'Callback',{@Hilfe_Button_Cb});
	
	hOptions		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.4 .4 1],'ForegroundColor',[1 1 1],'fontsize',12, 'tooltip','Options', ...
		'String','Options','units','normalized','Position',[.49,.965,.1,.04],'Callback',{@Options_Button_Cb});	
	
	hLoadR	= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.5 .5 .9],'fontsize',9,  'tooltip', 'N/A', ...
		'String','Load','units','normalized','Position',[.8, .965,.05,.015],'Callback',{@LoadRepl_Button_Cb});
	
	hSaveR	= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.5 .5 .9],'fontsize',9,  'tooltip', 'N/A', ...
		'String','Save','units','normalized','Position',[.85, .965,.05,.015],'Callback',{@SaveRepl_Button_Cb});
	
	hHilfe.Visible = 'off';
	hLoadR.Visible = 'off';
	hSaveR.Visible = 'off';
	
	
	hEnde		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[1 .2 .2],'fontsize',12, 'tooltip','Quits program after analysis',  ...
		'String','End','units','normalized','Position',[.9,.965,.1,.04],'Callback',{@Ende_Button_Cb},'Enable','off');

	hSaveTab		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.2 .2 1],'fontsize',12, 'tooltip','Save result table in *.xls file',  ...
		'String','Save Tab','units','normalized','Position',[.7,.965,.1,.04],'Callback',{@SaveTab_Button_Cb},'Enable','off');

	hSaveFigs	= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.3 .3 0.8],'fontsize',11, 'tooltip','Save all graphic figures and result table',  ...
		'String','Save Figs','units','normalized','Position',[.6,.965,.1,.04],'Callback',{@SaveFigs_Button_Cb},'Enable','off');

	
	messdaten_fuer_Neustart = mess;
	
%% Initialisierung alle GUI-Schaltfläche
	
	while ~Ende % Loop bis Abbruch durch User
		% Hinweis: Ursprünglich sollte der Benutzer den Anpassungsprozess
		% mit den gleichen Daten aber unterschiedlichen Optionen schnell
		% mehrfach hintereinander durchführen können, um die Resultate zu
		% vergleichen. Allerdings traten dabei Fehler auf (irgendwelche
		% Variablen waren falsch dimensioniert: Den gesamten
		% Initialisierungsteil von oben neu durchlaufen zu lassen, hätte
		% vermutlich geholfen), aber gleichzeitig wurde auch klar, dass es
		% kein Use-Case war, daher wurde auf das Debugging vorerst verzichtet

		hEnde.Enable		= 'off';
		hNeustart.Enable	= 'off';
		hNeustart.Visible	= 'off';
		hSaveTab.Visible	= 'off';
		hSaveFigs.Visible	= 'off';
		hSaveFigs.Enable	= 'off';

		if Neustart

			OK				= false;
			hStart.Enable	= 'on';
			hStop.Enable	= 'on';
			hStart.Visible	= 'on';
			hStop.Visible	= 'on';
			mess			= messdaten_fuer_Neustart;
			s0.Enable		= 'on';
			s1.Enable		= 'on';
			hOptions.Visible= 'on';
		
			Amp			= NaN(anz,1);
			Dam			= NaN(anz,1);
			Per			= NaN(anz,1);
			Pha			= NaN(anz,1);
			Basis_Amp	= NaN(anz,1);
			Basis_Dam	= NaN(anz,1);
			Basis_Off	= NaN(anz,1);
			Fehler		= NaN(anz,1);
			checkbox_platte = [];

% 			delete(stat_h);
			d_idx = findobj(tabelle_fig_h,'tag','table_entry');
			delete(d_idx);

			Neustart = false;

		end
		
		if debug
			set(gcf,'dockcontrols','on','Resize','on','toolbar','auto','menubar','figure')
		end

%% Warten, bis Auswahl getroffen und Start

		while ~(OK || Stop) % eines von beiden drücken
			try
				if sum(cell2mat(get(check_h,'value'))) == 0
					hStart.Enable = 'off';
				end
			catch
				% Fenster wurde evtl. geschlossen
				return
			end
			pause(0.2)
		end

		if Stop
			close(gcf)
			return
		end

		Options			= [];
		checkbox_replgr = NaN(1,anz);

%% GUI aufräumen, Optionen abfragen und einfrieren

		% Nachdem Start (oder Stop) gedrückt wurde, die Schaltflächen ausblenden
		ausreisser_h.Visible		= 'off';
		text_ausreiss_h.Visible		= 'off';
		text_debug_h.Visible		= 'off';		
		buttongroup_h2.Visible		= 'off';
		text_fittingmode_h.Visible	= 'off';
		hStart.Visible				= 'off';
		hStop.Visible				= 'off';
		s0.Enable					= 'off';
		s1.Enable					= 'off';
		buttongroup_h0.Visible		= 'off';
		sort_text_h.Visible			= 'off';
		debug_h.Visible				= 'off';
		hHilfe.Visible				= 'off';
		hSaveR.Visible				= 'off';
		hLoadR.Visible				= 'off';
		hOptions.Visible			= 'off';


		
		
		
		% Checkbox-Werte auslesen: Indizes der ausgewählten Samples (Beachten; es handelt sich um die
		% Indizes der Checkbox-_Handles_! Die Darstellung auf der GUI ist von der Sortierung abhängig!)
		% unchecked -> value = 0 -> "find" findet keine nullen
		checkbox_idx			= find(cell2mat(get(check_h,'value')));
		ausreisser				= ausreisser_h.Value;
		debug					= debug_h.Value;
		%e_funkt				= e_funkt_h.Value;
		%Options.e_funkt_flag	= e_funkt;
		%Basislinienoption		= 	100 * MWglaett + 10 * Normiert + 1 * e_funkt; % Basislinie = 100, wenn MWglaett (=default), = 10 wenn Normiert, sonst 1 (e-func nicht mehr unterstützt
		Basislinienoption		= 	100; % fixed to the only option that was developed further lately
		
		% ToDo: Currently "Options" and "general_options" are used, only
		% one of then is really needed!
		Options.Basislinienoption	= Basislinienoption;
		Options.ausreisser_flag	= ausreisser;
		Options.time_weight		= time_weight;
		Options.log_diff		= log_diff;
        Options.NoSound         = NoSound;
		Options.debug			= debug;
		Options.const_PER		= const_PER;
        Options.const_value		= const_value;
		Options.weight_threshhold_time = general_options.weight_threshhold_time;
		
		%if e_funkt,
		if Basislinienoption == 1 % = efunkt
			% msgbox('Dieser Programm-Zweig mit "Exp-Kurve" wird z.Z. nicht mehr weiter entwickelt');
		end

%% Defining of replicate groups
		
		% Die Idee war, dass beliebig positionierte Replikate sogar über
		% mehrere Platten verteilt sein konnten. Das war mit den
		% ursprünglichen Mithras-Datenfiles schwierig zu realisieren, da
		% ich keine Umrechnung auf komplette 96er Platte vornehmen wollte
		% (zu dem Entwicklungszeitpunkt, habe ich nur Platten bekommen, die
		% maximal zu einem Viertel gefüllt waren). Dies hat mir beim
		% Programmieren aber jede Menge Schwierigkeiten eingebrockt, in der
		% nächsten Version des ChronAlyzers (2.0) von Anfang an anders
		% programmieren!!!!

		% todo die bedeutung der gruppennamen und position entfällt ab der aktuellen version		
		
		for i = 1:anz   % Durchlaufe alle Wells

			set(drop_h(i),'Enable','off');
			if ~ismember(i,checkbox_idx)
				check_h(i).Enable   = 'off';
				t_h(i).Enable       = 'off';
				continue
			end

			% Zuordnung: Zu welcher Replikatgruppe gehört aktuelle Checkbox?
			% 1    = leer
			% 2    = Kontrollgruppe
			% 3    = Medium
			% 4-27 = Replikatgruppen
			% die bedeutung der gruppennamen und position entfiel mit
			% version 0.8

			checkbox_replgr(i)	= get(drop_h(i),'value');
			
			[col_, row_]	= calc_pos(name{i});
			str_			= layouttxt{col_,row_};
			titel_str{i}	= [name{i} ' - ' str_];
					
			if isnan(kontroll_idx) && ~isempty(strfind(lower(str_),'ontrol'))
				% englisch oder deutsch für Kontroll-Gruppe
				kontroll_idx = i;
			end
			if isnan(medium_idx) && ~isempty(strfind(lower(str_),'medium'))
				% englisch oder deutsch für Kontroll-Gruppe
				medium_idx = i;
			end

			
		end


%% Überprüfen der Replikatgruppen durch Benutzer & dynamisches Abwählen von Replikaten

		dummy = msgbox(['Please, check each time series for outliers first. After that, the average of each ' ...
			'individual replicate group will be calculated and used instead of the original values']);
		timed = timer('ExecutionMode','singleShot','StartDelay',5,'TimerFcn',@(~,~)myclose(dummy));
			% Schließt Fenster nach einer bestimmten Zeit automatisch
		start(timed);

		nof_replgr = numel(unique(checkbox_replgr));
		
		for file_idx = 1:file_anz

			for replgr_id = unique(checkbox_replgr) % Durchlaufe alle Replikatgruppen

				% Hinweis: Replikat_gruppen_ müssen nur mindestens _ein_ Element enthalten!

				anz_in_replgr = sum(checkbox_replgr == replgr_id); % Anzahl der Elemente in der aktuellen Gruppe		

				if  anz_in_replgr < 2 % if  replgr_id == 1 || anz_in_replgr < 2
					% Wenn nur ein Element ist keine weitere Abarbeitung dieser Schleife notwendig
					% Und Gruppe == 1 bedeutet: Keine Zuordnung zu einer Gruppe, also alle einzeln
					% abarbeiten
					if ~isnan(replgr_id)
						checkbox_idx_in_replgr{replgr_id} = find(checkbox_replgr == replgr_id); % Diese Checkbox (Samples) gehören zu der aktullen Replikatgruppe		
						checkbox_platte{file_idx, replgr_id} = checkbox_idx_in_replgr{replgr_id};
					end
					continue
				end		

				checkbox_idx_in_replgr{replgr_id} = find(checkbox_replgr == replgr_id); % Diese Checkbox (Samples) gehören zu der aktullen Replikatgruppe

				% Deaktivere alle Checkboxes, die nicht zur aktuellen Replikatgruppe gehören
				for j = 1:anz
					if ~ismember(j,checkbox_idx_in_replgr{replgr_id})				
						set(check_h(j),'Enable','off');
					else
						set(check_h(j),'Enable','on');
					end
				end

				% Berechne Werte für "vollständige" Replikatgruppe
				if strcmp(replicate_mode,'biol')
					% Überprüfe, ob auf aktueller Platte die ausgewählten Wells gefüllt sind
					
					checkbox_platte{file_idx, replgr_id} = checkbox_idx_in_replgr{replgr_id};
					for j = checkbox_platte{file_idx, replgr_id}(end:-1:1)
						if isnan(mess(j,1,file_idx))
							checkbox_platte{file_idx, replgr_id}(find(j == checkbox_platte{file_idx, replgr_id})) = []; % Dieses Well ist auf dieser Platte leer
						end
					end
					
					if isempty(checkbox_platte{file_idx, replgr_id})
						mittelwerte(replgr_id,:) = NaN;
					else
						anz_in_replgr_auf_Platte = numel(checkbox_platte{file_idx, replgr_id});
						mittelwerte_ = sum(mess(checkbox_platte{file_idx, replgr_id} ,:,file_idx),3,'omitnan') / anz_in_replgr_auf_Platte; % "omitnan" wichtig!
						mittelwerte(replgr_id,:) = sum(mittelwerte_,1);
					end
					
				else
					
					mittelwerte(replgr_id,:)				= sum(mess(checkbox_idx_in_replgr{replgr_id} ,:),1) / anz_in_replgr;	
					checkbox_platte{file_idx, replgr_id}	= checkbox_idx_in_replgr{replgr_id};
					
				end

				replf_h					= figure;
				set(gcf,'Tag','TechnRg');
				replf_h.DeleteFcn		= '@my_closereq;';
				replf_h.NumberTitle		= 'off';		
				replf_h.Name			= ['Replicate group: "' name_gruppen_layout{replgr_id} '"'];				
				
				% end
				replf_h.Name		= [replf_h.Name ' - ' num2str(file_idx) '. plate ("' fname{file_idx} '")'];
				replf_h.Position	= [50 70 950 900];


				hbestaetigt			= uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, 'tooltip','Show next replicate group', ...
				'String','Next group','units','normalized','Position',[.43,.95,.25,.04],'Callback',{@OK_Button_Cb});

				hhelp1				= uicontrol('Style','text','String',['Click on a curve to de-select well' newline '(re-select well on main window list)'],'units','normalized','Position',[.165,.95,.2,.04]);
				OK						= false;
				OK_Close				= false;
				
				sub1_h					= subplot(2,1,1);
				if ~isempty(mittelwerte(replgr_id,:))
					plot_MW_h				= plot(t,mittelwerte(replgr_id,:),'linewidth',2,'color',[0 0 0],'UserData','RawData');
					plot_MW_h.ButtonDownFcn = '@Mouse_Select_CB;';
				else
					text(0.275, 0.5,'No data on this plate found!','FontSize',14)
				end
				mw_axis					= gca;				
				mw_axis.Title.String	= [replf_h.Name  ': Single and averaged measurement values'];
				mw_axis.Title.Interpreter='none';
				mw_axis.XLabel.String	= 'time [h]';

				hold on;
				grid

				sub2_h					= subplot(2,1,2);
				if ~isempty(mittelwerte(replgr_id,:))				
					error_plot_h			= plot(t,zeros(size(mittelwerte(replgr_id,:))));
				end
				e_axis					= gca;
				e_axis.Title.String		= 'Squared error: Difference to average';
				e_axis.XLabel.String	= 'time [h]';

				grid

				sub2_h.Position(2)		= 0.05;
				sub2_h.Position(4)		= 0.15;
				sub1_h.Position(2)		= 0.3;
				sub1_h.Position(4)		= 0.6;

				if ~isempty(mittelwerte(replgr_id,:))
					
					while ishandle(replf_h) && ~OK
						
						figure(replf_h);
						
						plot_MW_h.YData	= mittelwerte(replgr_id,:); % aktuelle Daten reinschreiben
						
						err					= [];
						multiplot_Samples_h	= [];
						
						if strcmp(replicate_mode,'biol')
							checkbox_temp			= checkbox_platte{file_idx, replgr_id};
						else
							checkbox_temp			= checkbox_idx_in_replgr{replgr_id};
						end
						
						for ii = checkbox_temp
							err						= [err; (mess(ii,:, file_idx) - mittelwerte(replgr_id,:)).^2 ];
							multiplot_Samples_h(ii) = plot(mw_axis, t,mess(ii,:, file_idx));
							hold on
							set(multiplot_Samples_h(ii),'ButtonDownFcn',{@Mouse_Select_CB});
						end
						
						% Plot-Einstellungen aktuell halten:
						legend(mw_axis,['Averaged' name(checkbox_temp)]);
						
						if mean(err) == 0 % Fall: ein Well ist nur als unique-Replikat vorhanden oder so
							break
						end
						
						if  ~isempty(checkbox_temp)
							
							if isnan(std(mittelwerte(replgr_id,:))) || isnan(mean(mittelwerte(replgr_id,:)))
								uiwait(msgbox('Calculation of average was not successful! Are there gaps in the imported data?'));
								error
							end
							
							ylim(mw_axis,[0 round(2 * std(mittelwerte(replgr_id,:)) + mean(mittelwerte(replgr_id,:)))]);
							t_lim = get(mw_axis,'xlim');
							set(mw_axis,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
							
							err = sum(err,1); % Fehler über Samples aufaddieren
							
							error_plot_h.YData			= err;
							error_plot_h.Parent.YLim	= [0 round(2*std(err) + mean(err))];
							
							t_lim = get(e_axis,'xlim');
							set(e_axis,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
							
						end
						
						drawnow
						pause(0.3)
						
						OK = false;
						
						while ~OK && ishandle(replf_h)
							
							plot_on =  logical(cell2mat(get(check_h(checkbox_temp),'value')));
							
							if ~exist('plot_on_old','var')
								plot_on_old = plot_on;
							else
								if ~all(plot_on == plot_on_old)
									% plot aktiviert oder deaktiviert
									
									aktivieren		= plot_on > plot_on_old;
									deaktivieren	= plot_on < plot_on_old;
									
									if any(deaktivieren)
										set(multiplot_Samples_h(checkbox_temp(deaktivieren)),'visible','off');
									end
									
									if any(aktivieren)
										set(multiplot_Samples_h(checkbox_temp(aktivieren)),'visible','on');
									end
									
									if sum(plot_on) > 0
										mittelwerte(replgr_id,:) = sum(mess(checkbox_temp(plot_on),:, file_idx),1) / numel(checkbox_temp(plot_on));
									else
										mittelwerte(replgr_id,:) = NaN(size(t));
									end
									
									set(plot_MW_h,'ydata',mittelwerte(replgr_id,:));
									
									if sum(plot_on) > 1
										
										err = [];
										
										for ii = checkbox_temp(plot_on)
											err = [err; (mess(ii,:, file_idx) - mittelwerte(replgr_id,:)).^2 ];
										end
										
										err = sum(err,1);
										
										error_plot_h.Parent.YLim = [0 round(2*std(err) + mean(err))];
										
									else
										
										err = zeros(size(error_plot_h.XData));
										
									end
									
									error_plot_h.YData	= err;
									plot_on_old			= plot_on;
									drawnow
									
								end
							end
							
							pause(0.2)
							drawnow
							
							if ~isnan(kontroll_idx) && any(ismember(checkbox_temp,kontroll_idx)) && ~any(ismember(checkbox_temp(plot_on),kontroll_idx))
								% if kontroll_idx is member of the current
								% replicate group but is not member of the
								% current activated (plot_on) members,
								% change kontroll_idx to first active
								% member
								kontroll_idx = (checkbox_temp(plot_on));
								kontroll_idx = kontroll_idx(1);
							end

							if ~isnan(medium_idx) && any(ismember(checkbox_temp,medium_idx)) && ~any(ismember(checkbox_temp(plot_on),medium_idx))
								% if medium_idx is member of the current
								% replicate group but is not member of the
								% current activated (plot_on) members
								% change kontroll_idx to first active
								% member
								medium_idx = (checkbox_temp(plot_on));
								medium_idx = medium_idx(1);
							end

							
						end
						
						if ishandle(hbestaetigt)
							% Abfrage, weil Fenster vielleicht schon zu
							hbestaetigt.Enable = 'off';
						end
						
						% Technisches Replikat wird nun als der Mittelwert der gewählten Samples verwendet;
						% die anderen Mitglieder dieser Replikatgruppe können (müssen) nun "unchecked" werden:						
						if ~isempty(checkbox_temp)
							tmp												= checkbox_temp(plot_on);
							if isempty(tmp)
								error('Please do not de-select all wells! (error code 2095)')
							end
							selected_checkbox_in_replgr						= tmp(1);
							mess(selected_checkbox_in_replgr,:, file_idx)	= mittelwerte(replgr_id,:);
							checkbox_idx									= [];
							if iscell(checkbox_platte)
								checkbox_platte{file_idx, replgr_id}	= tmp(1); 
							else
								checkbox_platte{1,1}					= tmp(1);
							end
						else
							checkbox_platte{file_idx, replgr_id} = setdiff(checkbox_idx, setdiff(tmp,tmp(1)));
						end
						
						pause(0.6)
						drawnow
						
					end
						
					checkbox_replgr(checkbox_temp(~plot_on)) = NaN;
				
				else
					
					while ishandle(replf_h) && ~OK
						pause(0.2)
					end
					
				end

				clear plot_on_old

				for j = 1:anz
					set(check_h(j),'Enable','off');
				end
				
				if OK_Close
					delete(replf_h)
				end

			end

		end
			
		tmp = findall(0,'UserData','RawData');
		if ~isempty(tmp)
			tmp = [tmp.Parent]; % axes-Object holen
		
			for j = 1:numel(tmp)
				tmp(j).YLim = [min([tmp.YLim]) max([tmp.YLim])];
			end
		end
		
%--------------------------------------------------------------------------------------------------------		

		if numel(tmp) > 0
			hhelp2						= uicontrol('Style','text','String',['Edit numbers' newline 'in boxes' newline ' to zoom' newline '(enter blank' newline ...
				' to reset)'],'units','normalized','Position',[.01,.6,.068,.1]);
			hbestaetigt.String			= 'Save figures and continue';
			hbestaetigt.TooltipString	= 'Save figures and continue';
			hablehnen					= uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, 'tooltip','Continue without saving', ...
					'String','Continue','units','normalized','Position',[.8,.95,.15,.04],'Callback',{@OK_Button_Cb});


			% für die obere Grafik in diesen Figures

			maxy_fig	= 0;
			miny_fig   = Inf;

			for i = 1:numel(tmp)
				try
					% Children(3) ist die erste, obere Grafik -> Anpassung
					% Children(2) ist die Legende (in der oberen Grafik)
					% Children(1) ist die zweite, untere Grafik -> RawData (oder Mittelwert)

					if tmp(i).YLim(2) > maxy_fig
						maxy_fig = tmp(i).YLim(2);
					end
					if tmp(i).YLim(1) < miny_fig
						miny_fig = tmp(i).YLim(1);
					end

				catch ME
					rethrow 
				end
			end

			idx_fig		= [];

			for i = 1:numel(tmp)
				try
					idx_fig				= [idx_fig, tmp(i)];
					idx_fig(end).YLim(2)	= maxy_fig;
					idx_fig(end).YLim(1)	= miny_fig;				

				catch ME
					rethrow 
				end
			end

			for i = 1:numel(tmp)
				try
					% kann leider nicht in der Schleife davor stehen, da sonst
					% zuviele Children gefunden werden.

					uicontrol(tmp(i).Parent,'Style','edit','max',1,'units','pixel', 'position',[5 800 35 15],'String',num2str(maxy_fig), 'Tag','max','Callback',{@Update_Scale_Cb,idx_fig(i)});
					uicontrol(tmp(i).Parent,'Style','edit','max',1,'units','pixel', 'position',[5 260 35 15],'String',num2str(miny_fig), 'Tag','min','Callback',{@Update_Scale_Cb,idx_fig(i)});
				catch ME
					rethrow ME
				end
			end

			if ~isempty(tmp)
				linkaxes(idx_fig,'xy');		
			end
			
			if ishandle(hbestaetigt)
				% Abfrage, weil Fenster vielleicht schon zu
				hbestaetigt.Enable = 'on';
			end
			
		
		%--------------------------------------------------------------------------------------------------------		

			OK			= false;
			OK_Close	= false;
			
			while ~OK
				pause(0.1);
				% warten auf callback von Taste
			end

			if ishandle(hbestaetigt)
				% Abfrage, weil Fenster vielleicht schon zu
				hbestaetigt.Enable	= 'off';
				hablehnen.Enable	= 'off';
			end

			if ~OK_Close % OK_Close wird gesetzt bei Druck auf Knopf "Weiter"
				% Bilder speichern
				% vorher Buttons unsichtbar machen (könnte auch
				% gleich entfernt werden?)
								

				for j = 1:numel(tmp)			

					if ishandle(tmp(j))
						
						dummy = tmp(j).Parent;
						dummy = findobj(dummy.Children,'type','uicontrol');
						for u = 1:numel(dummy)
							dummy(u).Visible = 'off';
						end
						
						figure_savename = get(tmp(j).Parent,'Name');
						figure_savename = strrep(figure_savename,'"','_');
						figure_savename = [figure_savename '_' datum_str];
						figure_savename = strrep(figure_savename,' ','');
						figure_savename = strrep(figure_savename,':','');				

						if numel(figure_savename) > 240
							uiwait(msgbox('Length of file+path name is too long! The program will probably quit very soon to protect the Windows file system :-( ','modal'));
						end
						
						hbestaetigt.Visible = 'off';
						hablehnen.Visible	= 'off';
						
						if ~exist([figure_savename '.eps'],'file')
							saveas(tmp(j),[pathname{1} figure_savename '.eps'],'eps');
							%saveas(tmp(j),[pathname{1} figure_savename '.png'],'png');
							print(tmp(j).Parent,[pathname{1} figure_savename '.png'],'-dpng','-r0');
						else
							msgbox(['File name "' figure_savename '" already exists, please rename or delete old file first löschen!']);
						end
						
						hbestaetigt.Visible = 'on';
						hablehnen.Visible	= 'on';
						
						clear figure_savename
						
						for u = 1:numel(dummy)
							dummy(u).Visible = 'on';
						end	
			
						delete dummy
						
					else
						disp('Figure does not exists anymore! It was probably already manually closed?');
					end
					
				end
			end
					
		end
		
		
%% Aufruf des Unterprogramms zur Anpassung (Optimierung)
        
		% Löschen; im Falle eines Neustarts existiert Tabelle schon
		i = findall(0,'tag','table_entry');
		delete(i);
		medium_pha		= [];
		kontroll_pha	= [];
		medium_amp		= [];
		kontroll_amp	= [];
		kontroll_dam	= [];		
		medium_dam		= [];
	
		tab_amp_h		= [];
		tab_dam_h		= [];
		tab_per_h		= [];
		tab_pha_h		= [];
		tab_err_h		= [];
		
		if strcmp(replicate_mode,'biol')
			dummy = msgbox(['For each imported plate there will be an invidual fitting for each well (or replicate group if defined) performed. Results will be merged at the end.']);
			timed = timer('ExecutionMode','singleShot','StartDelay',15,'TimerFcn',@(~,~)myclose(dummy));
			% Schließt Fenster nach einer bestimmten Zeit automatisch
			start(timed);
			pause(3)
		end
		
		% for i = checkbox_idx',
		
		
		% some Matlab magic here, the idea is from several Mathworks community and
		% file exchange entries: First, make a list of all open figures,
		% then start a timer object. Open dialog as usually (this opens another figure, but one that
		% we can't get the figure handle for). At the end of the timer, compare
		% current list of figures with the stored list of figure. The
		% difference must be the dialog window. Close that. Finally, deal with empty
		% returns and so on.
		
		f_all = findall(0,'Type','figure');
		timer_h = timer('TimerFcn',{@closeit f_all}, 'StartDelay', 4);
		start(timer_h)
		
		answer = questdlg('Close current graphics?','Saving memory?','Yes','No','Yes');

		if strcmp(timer_h.Running,'on') % timer still running?
			stop(timer_h);
		end
		delete(timer_h)
		
		if isempty(answer) 
			answer = 'Yes'; % default value
		end

		if strcmp(answer,'Yes')
			fig_index = findall(0,'Type','figure','Tag','TechnRg');
			close(fig_index)
			fig_index = findall(0,'userdata','Well-Layout');
			close(fig_index)
			fig_index = findall(0,'userdata','Thumbnail');
			close(fig_index)
			fig_index = findall(0,'Tag','QuickView');
			close(fig_index)			
		end
		
		for file_idx = 1:file_anz
			
			for replgr_id = unique(checkbox_replgr)
				
				if isnan(replgr_id)
					continue
				end
				
				%if replgr_id > 1
					idx_upper = checkbox_platte{file_idx, replgr_id};
				%else
				%	idx_upper = checkbox_idx';
				%end
				
				for i = idx_upper
					
					[col_, row_] = calc_pos(name{i});
					akt_gruppe_str = layouttxt{col_,row_};
					
					sample_name = ['Well: ' name{i} ' - group: "' akt_gruppe_str '"'];
					
					disp([CR 'Adaption for: ' char(171) sample_name char(187) ' - biological replicate No.: ' num2str(file_idx)])
					
					
					% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    % +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
					% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    
					if strcmp(replicate_mode,'biol')
						
						%vorhanden = reshape(find(~isnan(mess(i,1,:))),1,[],1); % In diesen Dateien sind Daten zu dem aktuell Well ("i")
						
						if exist('mittelwerte','var') && size(mittelwerte,1) >= checkbox_replgr(i)
							% [fit_param_, Abbruch, Options] = findChronoParameter(t,mess(i,:,file_idx), ...
							% 	[sample_name ' - Replikat ' num2str(file_idx)], mittelwerte(checkbox_replgr(i),:), Options);
							
							[fit_param_, Abbruch, Options] = findChronoParameter(t,mess(i,:,file_idx), ...
								[sample_name ' - plate (replicate) No.: ' num2str(file_idx)], mess(checkbox_platte{file_idx, replgr_id} ,:,file_idx), Options);
							
							
						else
							
							[fit_param_, Abbruch, Options] = findChronoParameter(t,mess(i,:,file_idx), ...
								[sample_name ' - plate (replicate) No: ' num2str(file_idx)], NaN, Options);

						end
						
						Options.results{i}	= fit_param_;
						fit_param_.Pha		= fit_param_.Pha * 60; % Umrechnung von [h] in [min]
						
						%fit_param{file_idx} = fit_param_;
						fit_param = fit_param_;
						
					else
						
						[fit_param, Abbruch, Options] = findChronoParameter(t,mess(i,:), sample_name, ...
							NaN, Options);
						
						% fit_param.Pha	= fit_param.Pha * 60; % Umrechnung von [h] in [min]
						
					 end
                    
					% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    % +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    % +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
					
					
					if Abbruch
						break
					end
					
                    if ~NoSound
                        try
    						play(sound_obj,FS); % play diagnostic complete sound
							pause(1)
                        catch
                        end
                    end
					
					if ~strcmp(replicate_mode,'biol')
						Options.results{i} = fit_param;
					end

					
						Amp(i,file_idx)		= fit_param.Amp;
						Dam(i,file_idx)		= fit_param.Dam;
						Per(i,file_idx)		= fit_param.Per;
						Pha(i,file_idx)		= fit_param.Pha;
						
						%DeltaPer(i,file_idx)	= fit_param.DeltaPer;
						Fehler(i,file_idx)		= fit_param.Fehler;
					

					% There is somewhere an error above; upper_idx contains a
					% different number of the well of the same group as
					% medium_idx oder kontrol_idx. ... here's the
					% work-around with "checkbox_replgr"
					
					if ~isnan(medium_idx) && checkbox_replgr(medium_idx) == checkbox_replgr(i)
						medium_pha = Pha(i,1);
						medium_amp = Amp(i,1);
						medium_dam = Dam(i,1);
					end
					
					if ~isnan(kontroll_idx) && checkbox_replgr(kontroll_idx) == checkbox_replgr(i)
						kontroll_pha = Pha(i,1);
						kontroll_amp = Amp(i,1);						
						kontroll_dam = Dam(i,1);
					end
					
					
					%if e_funkt,
					if Basislinienoption == 1 % 1 = e_funktion
						
						if ~iscell(fit_param)
							
							Basis_Amp(i,1)	= fit_param.Basis_Amp;
							Basis_Dam(i,1)	= fit_param.Basis_Dam;
							Basis_Off(i,1)	= fit_param.Basis_Off;
							Basis_P1(i,1)	= fit_param.Basis_P1;
							
						else
							
							Basis_Amp(i,1)		= mean(cell2mat([cellfun(@(c) c.Basis_Amp,		fit_param, 'UniformOutput', 0)]));
							Basis_Dam(i,1)		= mean(cell2mat([cellfun(@(c) c.Basis_Dam,		fit_param, 'UniformOutput', 0)]));
							Basis_Off(i,1)		= mean(cell2mat([cellfun(@(c) c.Basis_Off,		fit_param, 'UniformOutput', 0)]));
							Basis_P1(i,1)		= mean(cell2mat([cellfun(@(c) c.Basis_P1,		fit_param, 'UniformOutput', 0)]));
							
						end
						
					end
				
				
%% --- Ausgabe der Ergebnisse

					if device_biotek || device_envision % quick but dirty ...
						Sort_A_Cb(); % sonst ist Reihenfolge in Tabelle bei Ausgabe falsch
					end
						
                    spalten_pos = [200,300,400,500,620,700,780,860,1000,1070];
                    
					if isempty(s_idx)
						% passiert, wenn Biotek_device und nie umsortiert
						% wurde
						s_idx = 1:anz;
					end
					
					if ~num_sorted
						for j = 1:anz
							s_pos(s_idx(j)) = pos(j);
						end
					else
						s_pos = pos;
					end
					
                   
                    figure(tabelle_fig_h);

					% ---------------------------------------------------------------------	

					% Amplitude 
					if exist('tab_amp_h','var') && numel(tab_amp_h) >= i && (~isempty(tab_amp_h(i)) && tab_amp_h(i) ~= 0)
						% Eintrag existiert schon, Tabelleneintrag
						% aktualisieren (bei biolog. Replikaten notwendig)

						std_str	= [char(963) '=' num2str(std(Amp(i,:)), '%05.0f')];
						set(tab_amp_h(i,1), 'String',[num2str(mean(Amp(i,:),'omitnan'),'%05.0f') '  ' std_str]); % num2str(nof_wells * fit_param.Amp,'%+05.0f')

					else

						tab_amp_h(i,1) = uicontrol('parent', panel,'Style','text','units','pixel', 'position',[spalten_pos(1) s_pos(i)-8 85 15],'String',num2str(fit_param.Amp,'%05.0f'), ...
							'HorizontalAlignment', 'left', 'tag','table_entry');

					end


					% Dämpfung 
					if exist('tab_dam_h','var') && numel(tab_dam_h) >= i && (~isempty(tab_dam_h(i)) && tab_dam_h(i) ~= 0)
						% Eintrag existiert schon, Tabelleneintrag
						% aktualisieren (bei biolog. Replikaten notwendig)

						std_str	= [char(963) '=' num2str(std(Dam(i,:)), '%05.0f')];
						set(tab_dam_h(i,1), 'String',[num2str(mean(Dam(i,:),'omitnan'),'%05.0f') '  ' std_str]); % num2str(nof_wells * fit_param.Amp,'%+05.0f')

					else

						tab_dam_h(i,1) = uicontrol('parent', panel,'Style','text','units','pixel', 'position',[spalten_pos(2) s_pos(i)-8 85 15],'String',num2str(fit_param.Dam,'%05.0f'), ...
							'HorizontalAlignment', 'left', 'tag','table_entry');

					end

					% Periode 
					if exist('tab_per_h','var') && numel(tab_per_h) >= i && (~isempty(tab_per_h(i)) && tab_per_h(i) ~= 0)
						% Eintrag existiert schon, Tabelleneintrag
						% aktualisieren (bei biolog. Replikaten notwendig)

						std_str	= [char(963) '=' num2str(std(Per(i,:)), '%05.0f')];
						set(tab_per_h(i,1), 'String',[num2str(mean(Per(i,:),'omitnan'),'%05.0f') '  ' std_str]); % num2str(nof_wells * fit_param.Amp,'%+05.0f')

					else

						tab_per_h(i,1) = uicontrol('parent', panel,'Style','text','units','pixel', 'position',[spalten_pos(3) s_pos(i)-8 85 15],'String',num2str(fit_param.Per,'%05.2f'), ...
							'HorizontalAlignment', 'left', 'tag','table_entry');

					end

					% Phase 
					if exist('tab_pha_h','var') && numel(tab_pha_h) >= i && (~isempty(tab_pha_h(i)) && tab_pha_h(i) ~= 0)
						% Eintrag existiert schon, Tabelleneintrag
						% aktualisieren (bei biolog. Replikaten notwendig)

						std_str	= [char(963) '=' num2str(std(Pha(i,:)), '%05.0f')];
						set(tab_pha_h(i,1), 'String',[num2str(mean(Pha(i,:),'omitnan'),'%05.0f') '  ' std_str]); % num2str(nof_wells * fit_param.Amp,'%+05.0f')

					else

						tab_pha_h(i,1) = uicontrol('parent', panel,'Style','text','units','pixel', 'position',[spalten_pos(4) s_pos(i)-8 85 15],'String',num2str(fit_param.Pha,'%05.1f'), ...
							'HorizontalAlignment', 'left', 'tag','table_entry');

					end

						
					% ---------------------------------------------------------------------	

					
					% ---------------------------------------------------------------------					
					
					
					% Fehler
					if exist('tab_err_h','var') && numel(tab_err_h) >= i && (~isempty(tab_err_h(i)) && tab_err_h(i) ~= 0)
						% Eintrag existiert schon, Tabelleneintrag
						% aktualisieren (bei biolog. Replikaten notwendig)

						set(tab_err_h(i,1), 'String',num2str(sum(Fehler(i,:),'omitnan'),'%5.1f')); % num2str(nof_wells * fit_param.Amp,'%+05.0f')

					else

						tab_err_h(i,1) = uicontrol('parent', panel,'Style','text','units','pixel', 'position',[spalten_pos(9) s_pos(i)-8 30 15],'String',num2str(fit_param.Fehler,'%5.1f'), ...
							'HorizontalAlignment', 'left', 'tag','table_entry');

					end

					tmp = str2double(get(tab_err_h(i,1),'String'));
					
					if tmp > 2
						set(tab_err_h(i,1),'foregroundcolor',[1 0 0]);
					elseif tmp > 1
						set(tab_err_h(i,1),'foregroundcolor',[1 0.6 0.1]);
					elseif tmp > 0.8
						set(tab_err_h(i,1),'foregroundcolor',[0 0 1]);
					else
						set(tab_err_h(i,1),'foregroundcolor',[0 0.8 0]);
					end
					

% ---------------------------------------------------------------------					

					ausreisser_liste(i) = {Options.ausreisser_liste};

					if ~isempty(Options.ausreisser_liste)
                        uicontrol('parent', panel,'Style','text','units','pixel', 'position',[spalten_pos(10) s_pos(i)-8 30 15],'String','Yes', 'tag','table_entry');
					else
						uicontrol('parent', panel,'Style','text','units','pixel', 'position',[spalten_pos(10) s_pos(i)-8 30 15],'String','No', 'tag','table_entry');
					end

				end
			end
		end
		

		% to scale all outputs in the same way: find global YLIM min/max
		idx	= findall(0, 'UserData','Output'); % Das sind alle Outputs von "findChronoParameter"
		
		% für die obere Grafik in diesen Figures - old
		
		maxy_upperfig	= 0;
        miny_upperfig   = Inf;
		maxy_lowerfig	= 0;
        miny_lowerfig   = Inf;
		
		for i = 1:numel(idx)
            try
				% Children(3) ist die erste, obere Grafik -> Anpassung
				% Children(2) ist die Legende (in der oberen Grafik)
				% Children(1) ist die zweite, untere Grafik -> RawData (oder Mittelwert)
				
				% output reduces; children(2) is single axis object now
                if idx(i).Children(2).YLim(2) > maxy_upperfig
    				maxy_upperfig = idx(i).Children(2).YLim(2);
                end
                if idx(i).Children(2).YLim(1) < miny_upperfig
    				miny_upperfig = idx(i).Children(2).YLim(1);
                end


			catch ME
				rethrow(ME)
            end
		end
	
		idx_upper = [];
		idx_lower = [];
		
		for i = 1:numel(idx)
            try
                idx_upper				= [idx_upper, idx(i).Children(2)];
                idx_upper(end).YLim(2)	= maxy_upperfig;
                idx_upper(end).YLim(1)	= miny_upperfig;				
	
				
			catch ME
				rethrow 
			end
		end
		
		% Erstelle Eingabefelder für die figure-übergreifenden (linkaxes)
		% ymin und ymax Limits
		for i = 1:numel(idx)
            try
				% kann leider nicht in der Schleife davor stehen, da sonst
				% zuviele Children gefunden werden.

                uicontrol(idx(i),'Style','edit','max',1,'units','pixel', 'position',[5 400 35 15],'String',num2str(maxy_upperfig), 'Tag','max','Callback',{@Update_Scale_Cb,idx_upper(i)});
                uicontrol(idx(i),'Style','edit','max',1,'units','pixel', 'position',[5 180 35 15],'String',num2str(miny_upperfig), 'Tag','min','Callback',{@Update_Scale_Cb,idx_upper(i)});                
            catch ME
				rethrow ME
            end
        end
		
        hlink = [];
		
        linkaxes(idx_upper,'xy');
		% linkaxes(idx_lower,'xy'); zweites linkaxes geht laut doku nicht

		
		if ~isnan(kontroll_idx) || ~isnan(medium_idx)
			set(buttongroup_h1,'visible','on');
			set(phasen_text_h,'visible','on');
		end

		
		if strcmp(replicate_mode,'biol')
			% Suche im Folgenden Ausgabe-Grafiken, in deren Titel Anführungszeichen stehen; diese sind einzelne
			% Replikatgruppen-Ergebnisse. Es werden dann jeweils die Grafiken, die zu einem Replikatgruppennamen
			% passen, zusammen gesucht und die angepassten Kurven aus den Grafiken in eine gemeinsame, neue Figure kopiert.
			
            tmp = [];
			
            for i = 1:numel({idx.Name})
				
                dummy = regexp(idx(i).Name,'"(.*)"','tokens','once'); % Finde den Teil in Anführungszeichen (den Replikatgruppennamen)
				if numel(dummy) > 0
					tmp{end+1} = dummy{1};
				else
					tmp{end+1} = 'singleton';
				end
				
            end
            
			[tmp, ia, ~] = unique(tmp);
			
			for i = 1:numel(tmp)

				if ischar(tmp{i})
					k		= findobj('-regexp','Name',['^.*[gG]ruppe "' tmp{i} '" -'], 'UserData','Output'); % Für "Medium" und "Kontrolle" und andere Namen
				else
					k		= findobj('-regexp','Name',['[gG]ruppe "' num2str(tmp{i}) '"'], 'UserData','Output');
				end
				
				if isempty(k)
					continue
				end
				
				legend_txt		= [];
				f				= figure;
				ax				= axes;
				anz				= 0;
				mw_y			= 0;
				ax.Tag			= 'CombinedResult';
				ax.Title.String = ['Average of the biological replicate group ' regexp(idx(ia(i)).Name,'"(\w+)"','match','once')]; % idx(ia(i)).Name(1:strfind(idx(ia(i)).Name,' /'))];
				hold on
				
				for j = 1:numel(k)
					
					linie		= findobj(k(j),'Tag','sim','LineStyle', '-'); % finde Graphen in anderer Figure
					strichel	= findobj(k(j),'Tag','sim','LineStyle', '--'); % finde Graphen in anderer Figure 
					c			= copyobj(linie, ax); % kopiere Graph in neue Figure ...
					set(c, 'LineWidth',10,'Color',[.7+(j*0.075) .8-(j*0.15) 1]); % ... und verbreitere sie. ToDo?: Breite Linie suggeriert fälschlicherweise eine Varianz!
					copyobj(strichel, ax); % kopiere Graph
					mw_y		= mw_y + [strichel.YData, linie.YData]; % addiere Werte ...
					anz			= anz + 1; % ... und zähle mit
					leg_temp	= regexp(k(j).Name,'replicate(\d+)','match');
					legend_txt	= [legend_txt {['Biological ' leg_temp{1}]}]; 
					
				end
				
				mw_y = mw_y ./ anz; % bilde Mittelwert und ...
				
				plot([strichel.XData linie.XData],mw_y,'k', 'LineWidth',2); % ... plotte ihn
				
				child_h = get(gca,'Children');
				child_num = numel(child_h);
				set(gca,'Children',child_h([2:2:child_num-1 1 child_num:-2:3])); % sortiert die "Lines", damit nur zwei Legend-Einträge notwendig sind
				clear child_h child_num leg_temp; % todo: Prüfen, ob richtige Legende
				
				grid;
				legend([legend_txt {'Mittelwert'}])
				xlabel('t [h]');
				toolbar_h	= findall(f,'type','uitoolbar');
				th1			= uitoggletool(toolbar_h, 'CData', toolbar_icon1, 'HandleVisibility','off','TooltipString', ...
								'Single data on/off','ClickedCallback',@Raw_anaus_CB);
			end
			
			axs = findall(0,'Tag','CombinedResult');
		
			if ~isempty(axs)
		
				for j = 1:numel(axs)
					axs(j).YLim = [min([axs.YLim]) max([axs.YLim])];
				end

			end			
			
		end
			
		figure(tabelle_fig_h);	
		
		if Abbruch
			return
		end

		samples				= name(~isnan(Amp(:,1))); %name(1:numel(Amp))';
		
		for i = 1:numel(samples)
			if ~isempty(cellstrfind(titel_str,['^' samples{i} ' ']))
				samples{i} = extractAfter(titel_str{cellstrfind(titel_str,['^' samples{i} ' '])},'- ');
			end
		end

		ausreisser_liste	= reshape(ausreisser_liste, numel(ausreisser_liste),1);


%% Kurze statistische Auswertung

		hSaveTab.Visible		= 'on';
		hSaveTab.Enable			= 'on';	
		hEnde.Enable			= 'on';
		hNeustart.Enable		= 'on';
		hNeustart.Visible		= 'on';
		hSaveFigs.Visible		= 'on';
		hSaveFigs.Enable		= 'on';
		debug_h.Visible			= 'on';
		text_debug_h.Visible	= 'on';
		ausreisser_h.Visible	= 'on';
		text_ausreiss_h.Visible	= 'on';
		
		if ~joke_done
			if rand > 0.9
				joke_str = 'Sensationell !! Gleich Nature Paper erzeugen und als pre-submission einsenden?';
			else
				joke_str = 'Toll, Paper dazu erstellen und ausdrucken (Draft!)?';
			end
			
			joke_h = uicontrol('parent', panel,'Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, ...
				'String',joke_str,'units','normalized','Position',[.2,.5,.6,.05],'Callback',@joke_Cb);
		end
	
		old_checkbox_idx = checkbox_idx;
		figure(tabelle_fig_h); % call GUI to front view

		while ~(Ende || Neustart)
			
			pause(0.1)
			
			if ~ishandle(tabelle_fig_h) % Hauptfenster wurde geschlossen
				Ende = true;
				return
			end

		end
		
		if exist('joke_h') && ishandle(joke_h)
            delete(joke_h)
		end

		if Ende
			% User hat auf "Ende" Button gedrückt
			break
		end

		
	end
	
	result = Options.result; % Does subfunctions work as intended?
	
	
%% clean up GUI before regular program termination
	
	hSaveFigs.Visible	= 'off';
	hSaveTab.Visible	= 'off';
	hNeustart.Visible	= 'off';
	hEnde.Visible		= 'off';
	hOptions.Visible	= 'off';

	
	
%% nested functions

	function Basisl_option_cb(source, eventdata)
	
		MWglaett = false;
		Normiert = false;
		e_funkt  = false;
		
		switch source.String
			case 'MHA'
				MWglaett = true;
			case 'Normalized'
				Normiert = true;
			case 'Exp.func'
				e_funkt = true;
		end
	end

	function result = get_user_settings()
		
		[~, user_settings_pfad] = dos('echo %userprofile%');
		
		user_settings_pfad		= regexprep(fullfile(user_settings_pfad,'ChronAlyzer'),'\n','');
		
		user_settings			= fullfile(user_settings_pfad,'ChronAlyzer.cfg');
		
		user_settings_exists	= exist(user_settings,'file');
		
		if user_settings_exists
			
			result = load(user_settings,'-mat'); % lädt String mit zuletzt benutztem Pfad
			
			if isfield(result,'saved_cfg')
				
				pfad			= result.saved_cfg.Pfad;
				version_user	= result.saved_cfg.Version;
				try
					general_options	= result.saved_cfg.Options;
				catch ME
					general_options.TimeWeight				= false;
					general_options.LogDiff					= false;
					general_options.ConstParameterPER		= true;
					general_options.ConstParValue			= 24;
					general_options.weight_threshhold_time	= 12;
				end
			else
				
				pfad	= result.pfad;
				
			end
			
			if ~isfield(general_options, 'TimeWeight') || isempty(general_options.TimeWeight)
				general_options.TimeWeight				= false;
			end
			if ~isfield(general_options, 'LogDiff') || isempty(general_options.LogDiff)
				general_options.LogDiff					= false;
			end
			if ~isfield(general_options, 'ConstParameterPER') || isempty(general_options.ConstParameterPER)
				general_options.ConstParameterPER		= true;
			end
			if ~isfield(general_options, 'ConstParValue') || isempty(general_options.ConstParValue)		
				general_options.ConstParValue			= 24;
			end
			if ~isfield(general_options, 'weight_threshhold_time') || isempty(general_options.weight_threshhold_time)
				general_options.weight_threshhold_time	= 12;
			end					

			
		else
			
			pfad			= '';
			version_user	= 'v0.0.0';
			
		end
		
		result = true;
		
	end

	function set_user_settings(pfad, varargin)
		
		[~, user_settings_pfad] = dos('echo %userprofile%');
		
		user_settings_pfad		= regexprep(fullfile(user_settings_pfad,'ChronAlyzer'),'\n','');
		
		if ~exist(user_settings_pfad,'dir')
			mkdir(user_settings_pfad);
		end
		
		user_settings	= fullfile(user_settings_pfad,'ChronAlyzer.cfg');
		
				
		saved_cfg		= struct('Pfad',pfad,'Version',version_str, 'Options',general_options);
		
		
		save(user_settings, 'saved_cfg','-mat');
		
		success = true;
		
	end

	function Update_Scale_Cb(source, eventdata, myaxes)
		
		if strcmp(source.Tag,'max')
			%obj				= findobj(get(source,'Parent'),'type','axes');
			%obj(2).YLim(2) = str2num(source.String);
			if isempty(source.String)
				myaxes.YLimMode = 'auto';
				myaxes.YLim(2)	= 'manual';
				source.String	= num2str(myaxes.YLim(2));
			else
				myaxes.YLim(2) = str2num(source.String);
			end
		else % = min-Eintrag
			%obj				= findobj(get(source,'Parent'),'type','axes');
			%obj(2).YLim(1) = str2num(source.String);
			if isempty(source.String)
				myaxes.YLimMode = 'auto';
				myaxes.YLim(1)	= 'manual';
				source.String	= num2str(myaxes.YLim(1));
			else
				myaxes.YLim(1) = str2num(source.String);
			end
		end
	end

	function On_Off_Cb(source,eventdata)
		% An- bzw. Ausschalten aller Checkboxes
		set(check_h,'Value',get(source,'value'));
		Sample_Button_Cb(true,true); % Argumente sollten egal sein
		
		
		if ~isempty(check_range) && ~ismember(0,check_range)
			
			wert = get(source,'Value');
			
			if ismember(source.Tag,{drop_h(check_range).Tag})
				for ik = check_range
					set(check_h(ik),'Value',1);
					%set(drop_h(ik),'Value',wert);
				end	
			end
			
			check_range = [];
			
		end
		
	end

	function Start_Button_Cb(source,eventdata)
		if sum(cell2mat(get(check_h,'value'))) == 0
			return
		end
		OK = true;
	end

	function my_closereq(source,eventdata)
		OK = true;
		delete(gcf);
	end

	function OK_Button_Cb(source,eventdata)
		OK = true;
		if strcmp(source.String,'Continue') % Es wurde auf "Schließen und weiter" geklickt
			OK_Close = true;
		end
	end

	function Stop_Button_Cb(source,eventdata)
		Stop = true;
	end

	function Ende_Button_Cb(source,eventdata)
		Ende = true;
	end


	function SaveTab_Button_Cb(source,eventdata)

		% Ergebnisse schreiben

		source.String = 'Wait ...';
		
		if ~isempty(fit_param)
			
			start_at	= Options.start_at;
			end_at		= Options.end_at;

			ForceFocusStart		= Options.time_weight;
			LogDifference		= Options.log_diff;
			Fade_In				= general_options.weight_threshhold_time;
			
			switch Basislinienoption
				case 1
					FittingMethod = {'exp. function'};
				case 10
					FittingMethod = {'normalized'};
				case 100
					FittingMethod = {'moving horizon average'};

				otherwise
					error('unknown option')
			end
			
			switch Options.const_PER
				case 0
					constantPAR			= {'phase-shift'};
				case 1
					constantPAR			= {'periodlength'};
				otherwise
					error('unknown option')
			end
			
			ConstParValue		= const_value;
			save_version = strrep(version_str,'.','_');
			T1			= table({save_version}, start_at, end_at,ForceFocusStart,LogDifference, FittingMethod, constantPAR, ConstParValue, Fade_In);
			
			tab_pha		= NaN(size(Pha,1),1);
			tab_amp		= NaN(size(Amp,1),1);
			tab_dam		= NaN(size(Dam,1),1);			
			
			for kk = 1:length(Pha)
				if ~isnan(Pha(kk))
					% falls kein Leerzeichen vorhanden ist, gibt es bei
					% extractBefore ein Fehler, daher einfach noch ein
					% Leerzeichen dranhängen
					tab_pha(kk) = str2num(extractBefore([get(tab_pha_h(kk),'String') ' '],' '));
				end
			end
			for kk = 1:length(Amp)
				if ~isnan(Amp(kk))
					%if pha_button ~= 1,
						tab_amp(kk) = str2num(extractBefore([get(tab_amp_h(kk),'String') ' '],' '));
					%else
					%	tab_amp(kk) = str2num(get(tab_amp_h(kk),'String'));
					%end
				end
			end
			for kk = 1:length(Dam)
				if ~isnan(Dam(kk))
					tab_dam(kk) = str2num(extractBefore([get(tab_dam_h(kk),'String') ' '],' '));
				end
			end
			
			tab_amp = tab_amp(~isnan(tab_amp));
			tab_dam = tab_dam(~isnan(tab_dam));
			tab_pha = tab_pha(~isnan(tab_pha));
			Per		= Per(~isnan(mean(Per,2)));
			Fehler	= Fehler(~isnan(mean(Fehler,2)));
			
			
% 			T2		= table(samples, tab_amp, tab_dam, Per, tab_pha,  Basis_Amp, Basis_Dam, Fehler, ausreisser_liste, ...
% 				'VariableNames',{'Sample','Amplitude','Daempfungsprozent','Periodenlaenge_h','Phasenverschiebung_min', ...
% 				'Basis_Amp', 'Basis_Dam', 'Fehler', 'ausreisser_liste'});
			T2		= table(samples', tab_amp, tab_dam, Per, tab_pha, Fehler, ausreisser_liste(~isnan(tab_amp)), ...
				'VariableNames',{'sample','amplitude','damping','period_length','phase_shift', ...
				'error', 'outliers'});


% 			T2(isnan(Amp),:) = []; % löscht leere Zeilen

			
			for kk = 1:numel(checkbox_idx_in_replgr)
				
				if isempty(checkbox_idx_in_replgr{kk})
					continue
				end
				
				wells				= checkbox_idx_in_replgr{kk};
				idx					= 0;
				used_wells			= [];
				for jj = 1:numel(wells)
					if get(findall(0,'Tag',name{wells(jj)}),'value') == 0
						continue
					end
					idx = idx + 1;
					used_wells = [used_wells wells(jj)];
				end		
					
				wellname{kk}		= [];
				header_wellname{kk} = [];

				for jj = 1:numel(used_wells)
					if jj == 1
						%header_wellname{kk} = name{used_wells(jj)};
						[col_, row_]		= calc_pos(name{used_wells(jj)});
						header_wellname{kk}	= layouttxt{col_,row_};
					end
					wellname{kk} = [wellname{kk} name(used_wells(jj))];
				end
						
			end
			
			
			[PATHSTR,NAME,EXT]	= fileparts(fname{1});
			NAME_				= ['(Analysis from ' strrep(char(datetime('now')),':','_') ') ' NAME '.xlsx'];
			savefname			= fullfile(pathname{1},NAME_); % in fname ist path nicht mehr enthalten

			try

				writetable(T1,savefname,'Sheet',1,'Range','A1');
				
				writetable(T2,savefname,'Sheet',1,'Range','A8');
				i = 1;
				for kk = 1:numel(wellname)
					if isempty(wellname{kk})
						continue
					end
					
					header		= [];
					tab			= [];
					header{1,1} = 'Group';
					tab{1}		= ['"' header_wellname{kk} '"'];
					
					for jj = 1:numel(wellname{kk})
						header{1,1+jj} = ['Well_' num2str(jj)];
						tab{1,1+jj} = wellname{kk}{jj};
					end
					
					T3							= cell2table(tab);
					T3.Properties.VariableNames = header;
					
					%if numel(wellname{kk}) > 1,
						%writetable(T3,savefname,'Sheet',2,'Range',['A' num2str(8+size(T2,1)+kk*3+5)]);
						writetable(T3,savefname,'Sheet',2,'Range',['A' num2str(i)]);
					%end
					i = i+3;
				end
				
				source.String = 'Save Tab';
				
				[PATHSTR,NAME,EXT]	= fileparts(savefname);
				hmess				= msgbox(['Results saved at' CR CR PATHSTR CR CR 'in file' CR CR NAME EXT] );
				hmess_a				= get(hmess,'CurrentAxes');
				hmess_c				= get(hmess_a,'Children');
				hmess_e_alt			= hmess_c.Extent([3 4]);
				set(hmess_c,'FontSize',11);
				hmess_e_neu			= hmess_c.Extent([3 4]);
				hmess.Position(3)	= hmess.Position(3) * hmess_e_neu(1)/hmess_e_alt(1);
				hmess.Position(4)	= hmess.Position(4) * hmess_e_neu(2)/hmess_e_alt(2);

			catch ME

				msgbox(['Error: Writing into Excel not possible. Perhaps missing file access permits, no space left, configuration of Excel(!) ?' ...
					CR ME.message])

			end
		end
	end

	function SaveFigs_Button_Cb(source,eventdata)
		
		source.String = 'Wait ...';
		
		figs_h = findall(0,'type','figure','UserData','Output');
		
		% global variable datum_str = strrep(char(datetime('now')),':','_');
		
		for i = 1:numel(figs_h)
			
			figure_savename = strrep(strrep(figs_h(i).Tag,'findfit_','fit_for_'),'"','_');
			figure_savename = strrep(figure_savename,' ','_');
			figure_savename = strrep(figure_savename,'/','_');
			figure_savename = strcat(figure_savename, '_', datum_str);
			figure_savename = strrep(figure_savename,'.','_');
			figure_savename = regexprep(figure_savename,'(_)+','_');
			figure_savename = [pathname{1} strrep([filename '_' figure_savename],':','_')];
						
			if ~exist([figure_savename '.eps'],'file')
				saveas(figs_h(i),[figure_savename '.eps'],'eps');
				%saveas(figs_h(i),[figure_savename '.png'],'png');
				print(figs_h(i),[figure_savename '.png'],'-dpng','-r0');
			else
				msgbox(['File "' figure_savename '" already exists, please re-name or delete old file first!']);
			end
			
		end
		
		% v1.7.0 "ChronAlyzerReport" ToDo: Speichere alle Bilder auch als (ein?) PDF und dazu die Ergebnis-Tabelle
		source.String = 'Save Figs ...';
		
	end


	function Neustart_Button_Cb(~,~)

		Neustart						= true;
		%e_text_h.Visible				= 'on';
		%e_funkt_h.Visible				= 'on';
		buttongroup_h2.Visible			= 'on';
		text_fittingmode_h.Visible		= 'on';
		
		% if ~isnan(kontroll_idx) || ~isnan(medium_idx)
		% 	buttongroup_h1.Visible	= 'on';
		% end
		
		phasen_text_h.Visible			= 'on';
		sort_text_h.Visible				= 'on';
		buttongroup_h0.Visible			= 'on';
		s0.Enable						= 'on';
		s1.Enable						= 'on';
		buttongroup_h1.Visible			= 'on';
		
		for j = 1:anz
			check_h(j).Enable			= 'on';
			drop_h(j).Enable			= 'on';
			t_h(j).Enable				= 'on';		
		end
		
		% Neustart vorbereiten
		hSaveTab.Visible				= 'off';
		hSaveTab.Enable					= 'off';	
		hEnde.Enable					= 'off';
		hStart.Visible					= 'on';
		hNeustart.Enable				= 'off';
		hNeustart.Visible				= 'off';
		buttongroup_h1.Visible			= 'off';
		phasen_text_h.Visible			= 'off';
		hSaveFigs.Visible				= 'off';
		
		didx = findobj('-regexp','Tag','findfit*');
		close(didx)
		didx = findobj('-regexp','Tag','TechnRg');
		close(didx)
		didx = findobj('-regexp','tag','table_entry');
		delete(didx)
% 		if exist('stat_h')
% 			for didx = 1:numel(stat_h)
% 				delete(stat_h(didx))
% 			end
% 		end
	end

	function Hilfe_Button_Cb(~,~)
		
		hmess				= msgbox(['This program imports measurement data from a *.xls or *.xlsx' CR ...
			'file and fits the foloowing function to it:' CR CR 'y(t) = A * exp(-D * t) * cos(2 * pi/T * (t-ps))' ...
			CR CR 'A   = amplitude' CR 'D   = damping' CR 'T   = period [h]' CR 'ps = phase-shift' ...
			CR 't    = time [h]' CR 'y   = measurement data' CR CR 'More detailed information will follow in a "readme.txt"'], ...
			['Help - ChronAlyzer ' version_str]);
		hmess_a				= get(hmess,'CurrentAxes');
		hmess_c				= get(hmess_a,'Children');
		hmess_e_alt			= hmess_c.Extent([3 4]);
		set(hmess_c,'FontSize',12);
		hmess_e_neu			= hmess_c.Extent([3 4]);
		hmess.Position(3)	= hmess.Position(3) * hmess_e_neu(1)/hmess_e_alt(1);
		hmess.Position(4)	= hmess.Position(4) * hmess_e_neu(2)/hmess_e_alt(2);
		
		answer				= questdlg('Enter Annotation again?','Enter Annotation again?','Yes','No','No');
		
		if strcmp(answer,'Yes')
			update_Annotations();
		end
		
	end

	function Options_Button_Cb(~,~)
		
		quest_fig_h		= figure;
		questgroup_h1	= uibuttongroup('parent',quest_fig_h,'Position',[0.075 0.8 .85 .1], 'clipping','on');
		questgroup_h2	= uibuttongroup('parent',quest_fig_h,'Position',[0.075 0.6 .85 .1], 'clipping','on');
		questgroup_h3	= uibuttongroup('parent',quest_fig_h,'Position',[0.075 0.4 .85 .1], 'clipping','on');
		questgroup_h4	= uibuttongroup('parent',quest_fig_h,'Position',[0.075 0.2 .85 .1], 'clipping','on');
		
		uicontrol('parent',questgroup_h1,'style','text','String','Force fitting focus on earlier measurements?', ...
						'units','normalized','position',[-.3 .2 1.3 .5],'fontsize',10);		
		answ1_1			= uicontrol('Style','Radio','String','No','units','normalized', 'tooltip',['All measurements will be weighted equally in the objective function. ' ...
							'Since higher values do have more influence in the objective function, it is typical that the beginning of a measurement is more important.'], ...
							'pos',[.725 0.35 .12 .35],'parent',questgroup_h1,'HandleVisibility','off');
		answ1_2			= uicontrol('Style','Radio','String','Yes','units','normalized', 'tooltip',['Earlier measurements will be weighted (slightly) even more in the objective function.' ...
							'This option typically results into a better fitting to the beginning of the experiment. [Note: weighting factor = 1/exp(-0.015.*(t-t_0)), approx. -15%/10h]'], ...
							'pos',[.85 0.35 .1 .35],'parent',questgroup_h1,'HandleVisibility','off');
		
		if general_options.TimeWeight
			set(answ1_2,'value',1);
		else
			set(answ1_1,'value',1);
		end
		
		uicontrol('parent',questgroup_h2,'style','text','String','Use log difference in the objective function for fitting?', ...
						'units','normalized','position',[-.3 .2 1.3 .5],'fontsize',10);		
		answ2_1			= uicontrol('Style','Radio','String','No','units','normalized', 'tooltip','Default', 'pos',[.725 0.35 .12 .35],'parent',questgroup_h2,'HandleVisibility','off');
		answ2_2			= uicontrol('Style','Radio','String','Yes','units','normalized', 'tooltip','This option can be used to lower the importance of high peaks in measurements. Check outcome!', 'pos',[.85 0.35 .1 .35],'parent',questgroup_h2,'HandleVisibility','off');

		if general_options.LogDiff
			set(answ2_2,'value',1);
		else
			set(answ2_1,'value',1);
		end

	
		uicontrol('parent',questgroup_h3,'style','text','String','One of the following two parameters must be kept constant: Period length or phase-shift?', ...
						'units','normalized','position',[0.025  0.025  0.64 0.85],'fontsize',10);		
		answ3_1			= uicontrol('Style','Radio','String','Period','units','normalized', 'tooltip','Use this option, if you want to detect a change in the phase-shift', 'pos',[.725 0.5 .12 .35],'parent',questgroup_h3,'HandleVisibility','off');
		answ3_2			= uicontrol('Style','Radio','String','Phase','units','normalized', 'tooltip','Use this option, if you want to detect a change in the period length', 'pos',[.85 0.5 .15 .35],'parent',questgroup_h3,'HandleVisibility','off');
		answ3_3			= uicontrol('Style','edit','String','24','units','normalized', 'tooltip','Enter the value for the constant parameter', 'pos',[.81 0.044 .1 .35],'parent',questgroup_h3,'HandleVisibility','off');						
		uicontrol('parent',questgroup_h3,'style','text','String','[h]','units','normalized','position',[.91 -0.0255 0.04 .45],'fontsize',8);		

		if general_options.ConstParameterPER
			set(answ3_1,'value',1);
		else
			set(answ3_2,'value',1);
		end
		set(answ3_3,'String',num2str(general_options.ConstParValue));
			

		uicontrol('parent',questgroup_h4,'style','text','String','Fade-in endtime for the weighting factors (after selected start time)?', ...
						'units','normalized','position',[0.025  0.025  0.64 0.85],'fontsize',10);
		answ4_1			= uicontrol('Style','edit','String','12','units','normalized', 'tooltip','Enter the value for the constant parameter', 'pos',[.81 0.044 .1 .35],'parent',questgroup_h4,'HandleVisibility','off');											
		uicontrol('parent',questgroup_h4,'style','text','String','[h]','units','normalized','position',[.91 -0.0255 0.04 .45],'fontsize',8);		

		if ~isempty(general_options.weight_threshhold_time)
			set(answ4_1,'String',general_options.weight_threshhold_time);
		end

		
		hbestaetigt = uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, ...
			'String','Continue','units','normalized','Position',[.4,.07,.2,.06],'Callback',{@OK_Button_Cb});

		OK = false;
		
		while ~OK
			pause(0.1)
		end
	
		% Auswertung des Fensters
		
		if strcmp(questgroup_h1.SelectedObject.String,'No')
			time_weight = false;
		else
			time_weight = true;
		end
		
			
		if strcmp(questgroup_h2.SelectedObject.String,'No')			
			log_diff = false;
		else
			log_diff = true;
		end
			
		if strcmp(questgroup_h3.SelectedObject.String,'Period')
			const_PER = true;
			%Options.const = 1;
		else
			const_PER = false;
			%Options.const = 2;
		end
		

		const_value = str2num(strrep(answ3_3.String,',','.')); % Strrep: Ersetze Dezimalkomma durch -punkt, Str2Num: konvertiere zu Zahl

		general_options.TimeWeight				= questgroup_h1.SelectedObject.String;
		general_options.LogDiff					= questgroup_h2.SelectedObject.String;
		general_options.ConstParameterPER		= questgroup_h3.SelectedObject.String;
		general_options.ConstParValue			= answ3_3.String;
		general_options.weight_threshhold_time	= str2num(answ4_1.String); % ToDo: Maybe this should be rounded?
		
		set_user_settings(pfad, general_options)
		
		close(quest_fig_h)
		
		OK = false;
			
		
	end

	function Sample_Button_Cb(source,data)

		% ToDo: "all/none" functions as intended but throws an error now
		
		if sum(cell2mat(get(check_h,'value'))) > 0
			set(hStart,'Enable','on');
		else
			set(hStart,'Enable','off');
		end
		
		if ~isempty(check_range) && ~ismember(0,check_range)
			
			wert = get(source,'Value');
			
			for ik = check_range
				set(check_h(ik),'Value',wert);
			end	
		end
			
		check_range = [];
				
	end

	function Sort_A_Cb(~,~)

		if num_sorted
		
			[sorted, s_idx] = sort(name); 
			for k = 1:anz
				set(check_h(s_idx(k)), 'Position',[0 pos(k)-8 15 15]);
				set(drop_h(s_idx(k)),  'Position',[90 pos(k)-7 100 12]);
				set(t_h(s_idx(k)),     'Position',[32 pos(k)-8 50 15]);
			end
		end
		
		num_sorted = false;
		
	end

	function Sort_1_Cb(~,~)

		if ~num_sorted
			
			if device_biotek || device_envision
				s_idx = asort(name);
				s_idx = s_idx.aix;
				
				for k = 1:anz
					set(check_h(s_idx(k)), 'Position',[0 pos(k)-8 15 15]);
					set(drop_h(s_idx(k)),  'Position',[90 pos(k)-7 100 12]);
					set(t_h(s_idx(k)),     'Position',[32 pos(k)-8 50 15]);
				end
				
			elseif device_mithras
				
				for k = 1:anz
					set(check_h(k), 'Position',[0 pos(k)-8 15 15]);
					set(drop_h(k),  'Position',[90 pos(k)-7 100 12]);
					set(t_h(k),     'Position',[32 pos(k)-8 50 15]);
				end
				s_idx = 1:anz;
			end
		end
		
		num_sorted = true;
		
	end
	
	function Select_dropbox_Cb(source,~)
		
		% this was the old functionality
		if source.Value > 0
			% es wurde eine Replikationsgruppe gewählt
			% Usability: Dann gleich auch anwählen
			set(check_h(str2num(cell2mat(regexp(source.Tag,'\d*','match')))),'Value',1);
			set(hStart,'Enable','on');
		end
		
	end

	function Phase_1_Cb(~,~)
		
		% Umschalten auf absolute Werte
		
		if pha_button ~= 1
			
			switch pha_button
				case 2
					offset_p = -kontroll_pha;
					offset_a =  kontroll_amp / 100;
					offset_d = -kontroll_dam;
				case 3
					offset_p = -medium_pha;
					offset_a =  medium_amp / 100;
					offset_d = -medium_dam;
			end
			
            for i = cell2mat(checkbox_platte)
					% Hinweis: falls kein Leerzeichen vorhanden ist, gibt es bei
					% extractBefore ein Fehler, daher einfach noch ein
					% Leerzeichen dranhängen
				set(tab_pha_h(i),'String',num2str(str2double(get(tab_pha_h(i),'String')) - (offset_p),'%+06.1f')); % (offset_p * nof_wells)
				set(tab_amp_h(i),'String',num2str(str2double(extractBefore([get(tab_amp_h(i),'String') ' '],' ')) .* offset_a,'%05.0f'));
				set(tab_dam_h(i),'String',num2str(str2double(extractBefore([get(tab_dam_h(i),'String') ' '],' ')) -  offset_d,'%03.1f'));
			end
			
			pha_button = 1;

		else
			
			switch pha_button
				case 2
					s3.Value	= 1;
					pha_button	= 2;
				case 3
					s4.Value	= 1;
					pha_button	= 3;
			end

			
		end
			
	end

	function Phase_2_Cb(~,~)
		
		% Umschalten auf Kontrollgruppen-Normierung
		
		if ~isnan(kontroll_idx)

			% nur wenn entsprechende Gruppe definiert ist
			
			if pha_button ~= 2

				switch pha_button
			
					case 1
						offset_p = kontroll_pha;
						offset_a = kontroll_amp / 100;
						offset_d = kontroll_dam;
					case 3
						offset_p = kontroll_pha - medium_pha;
						offset_a = kontroll_amp / medium_amp;
						offset_d = kontroll_dam - medium_dam;
				end

				for i = cell2mat(checkbox_platte)
					% Hinweis: falls kein Leerzeichen vorhanden ist, gibt es bei
					% extractBefore ein Fehler, daher einfach noch ein
					% Leerzeichen dranhängen
					set(tab_pha_h(i),'String',num2str(str2double(get(tab_pha_h(i),'String')) - offset_p,'%+06.1f')); % (offset_p * nof_wells)
					if pha_button == 1
						set(tab_amp_h(i),'String',num2str(str2double(get(tab_amp_h(i),'String')) ./ offset_a,'%03.1f %%'));
					else
						set(tab_amp_h(i),'String',num2str(str2double(extractBefore([get(tab_amp_h(i),'String') ' '],' ')) ./ offset_a,'%03.1f %%'));
					end
					set(tab_dam_h(i),'String',num2str(str2double(extractBefore([get(tab_dam_h(i),'String') ' '],' ')) - offset_d,'%03.1f %%'));
				end

				pha_button = 2;

			end

		else
			
			switch pha_button
				case 1
					s2.Value	= 1;
					pha_button	= 1;
				case 3
					s4.Value	= 1;
					pha_button	= 3;
			end

			
		end		
			
	end

	function Phase_3_Cb(~,~)
		
		% Umschalten auf Medium-Kontrollgruppen-Normierung		

		if ~isnan(medium_idx)

			% nur wenn entsprechende Gruppe definiert ist
				
			if pha_button ~= 3

				switch pha_button
					
					case 1
						offset_p = medium_pha;
						offset_a = medium_amp / 100;
						offset_d = medium_dam;						
					case 2
						offset_p = medium_pha - kontroll_pha;
						offset_a = medium_amp / kontroll_amp;
						offset_d = medium_dam - kontroll_dam;
				end

                for i = cell2mat(checkbox_platte)
					
					set(tab_pha_h(i),'String',num2str(str2double(get(tab_pha_h(i),'String')) - offset_p,'%+06.1f')); % (offset_p * nof_wells)
					
					if pha_button == 1
						set(tab_amp_h(i),'String',num2str(str2double(get(tab_amp_h(i),'String')) ./ offset_a,'%03.1f %%'));
					else
						set(tab_amp_h(i),'String',num2str(str2double(extractBefore([get(tab_amp_h(i),'String') ' '],' ')) ./ offset_a,'%03.1f %%'));
					end
					% Hinweis: falls kein Leerzeichen vorhanden ist, gibt es bei
					% extractBefore ein Fehler, daher einfach noch ein
					% Leerzeichen dranhängen
					set(tab_dam_h(i),'String',num2str(str2double(extractBefore([get(tab_dam_h(i),'String') ' '],' ')) - offset_d,'%03.1f %%'));
				end

				pha_button = 3;

            end
			
		else
			switch pha_button
				case 1
					s2.Value	= 1;
					pha_button	= 1;
				case 2
					s3.Value	= 1;
					pha_button	= 2;					
			end
		end

	end

	function Mouse_Select_CB(~,~)
		
		line_h_global = gcbo;
		line_idx = findall(check_h,'tag',get(line_h_global,'DisplayName'));
		set(line_idx,'value',0);
	
	end

	function Mouse_Select_Down_Cb(source,event)
		% function for ...
		% a) drawing a rectangle while holding the left mouse key in order
		% to select adjacent wells (followed by a click in a check box
		% selects oder de-selects all of them at once),
		% b) noticing a right click on a replicate group label in order to
		% select oder de-select all of that group at once
		%
		if isprop(event.Source.CurrentObject,'Style') && strcmp(event.Source.CurrentObject.Style,'text') && strcmpi(leftstr(event.Source.CurrentObject.Tag,5),'check')
			% this is case b)
			clicked_repl_group = event.Source.CurrentObject.String;
			checkbox_idx = findall(0,'style','checkbox','UserData',clicked_repl_group);
			set(checkbox_idx,'value',~get(checkbox_idx(1),'value'))
			
			if sum(cell2mat(get(check_h,'value'))) > 0
				set(hStart,'Enable','on');
			else
				set(hStart,'Enable','off');
			end
			return
			
		end
		
		% here follow the instructions for case a)
		check_range		= [];
		scroll_offset	= getcolumn(get(gcf,'InnerPosition'),4) * get(vscrollbar,'Value');
		
		startpoint		= get(gcf,'CurrentPoint');
		startpoint		= startpoint(1,1:2);
		startpoint(2)	= startpoint(2) + scroll_offset;
		
		dummy			= get(gcf);
		mouseselectY_1	= startpoint(2); % .* dummy.Position(4) ; % anderes Einheitensystem			

		finalRect		= rbbox;
		
		endpoint		= get(gcf,'CurrentPoint');
		endpoint		= endpoint(1,1:2);
		endpoint		= endpoint + scroll_offset;
		
		dummy			= get(gcf);
		mouseselectY_2	= endpoint(2); % .* dummy.Position(4) ; % anderes Einheitensystem			

		range			= sort([mouseselectY_1 mouseselectY_2])-15/2;

		check_idx		= [];
			
		range(1)		= range(1) + diff(pos(1:2))/4; % diff ist negativ -> addieren. range(1) ist minimum
		range(2)		= range(2) - diff(pos(1:2))/4;

		for ik = 1:anz
			if getcolumn(get(check_h(ik),'position'),2) > range(1) && getcolumn(get(check_h(ik),'position'),2) < range(2),
				check_range = [check_range ik];
			end
		end
		
    end

    function [result] = QuickView_Cb(~, ~, image)
        % "image" zählt von links oben nach rechts durch
        % berechne aus name() die Position in layout-Matrix
		[col_, row_] = calc_pos(name{image});
		str_ = layouttxt{col_,row_};
		
        quick_figure_str	= ['QuickView: ' name{image} ' (' str_ ')'];
		
		
        result              = true;

        if isempty(findall(0,'UserData',quick_figure_str)),
			
			f					= figure;
            f.UserData			= quick_figure_str;
			f.Tag				= 'QuickView';
			
			%if ~biotek_device,
			image_ = image;
			%else
			% Diese Fallunterscheidung ist offenbar nicht mehr richtig:
			% Einzelne BioTek-Files öffnen auf jeden Fall falsche
			% QuickView-Daten ....
			%	image_ = (mod(image-1,8)*12+1+floor((image-1)/8));
			%end
			
            plot(t,mess(image_,:,1));

            if strcmp(replicate_mode,'biol')
                hold on
                for g = 2:size(mess(image_,:,:),3)
                    plot(t,mess(image_,:,g));
                end
                quick_figure_str = [quick_figure_str ' - biological replicate'];
                legend(fname,'interpreter','none')
            end

            xlabel('time [h]');
            ylabel('units');

            title_h = title(quick_figure_str);
            %title_h.HorizontalAlignment = 'left';
			title_h.FontSize = 10;
			title_h.FontWeight = 'normal';
			
            %if drop_h(image).Value == 2, % Typ "Kontrolle"
                
            uicontrol('Style','pushbutton','units','pixel', 'position',[10 360 100 55],'String','<html>Quick-Info:<br>Determine period<br>length manual', ...
				'Callback',{@Quickview_Data_Cb});
                
            %end

        end
    end

    function result = Quickview_Data_Cb(source, ~)
       
        source.String = '<html>Click on at least<br>2 adjacent maxima<br> then ENTER';
		source.BackgroundColor = [1 1 0];
        [x_input, ~] = ginput;
        
        if isempty(x_input)
            result = false;
        else
            result = true;
            
		end
		
        x_input = sort(x_input);
        Periode = mean(diff(x_input));
        Phase   = mean(x_input-Periode.*[0:(numel(x_input)-1)]');
        
        msgbox(['Determined values:' CR 'Period length: ' num2str(Periode,3) ' h' CR 'Phase-shift:' num2str(Phase,3) ' h'])
        
    end

	function [curX,curY_pixel] = getMousePositionOnImage(~, ~)
		
		cursorPoint = get(gca,'CurrentPoint');
		
		curX		= cursorPoint(1,1);
		curY		= cursorPoint(1,2);
		fig_size	= get(gcf,'Position');
		curY_pixel	= curY *(fig_size(4)-fig_size(2)) + fig_size(2);
		
	end

	function dec_hour = convert_Time2DecHour(time_string)
		
		if ischar(time_string)
			
			time		= strsplit(time_string,':');
			dec_hour	= str2num(time{1}) + str2num(time{2})/60 + str2num(time{3})/3600; % /nof_wells
			
		elseif iscell(time_string)
			
			dec_hour = NaN(1,numel(time_string));
			
			for tk = 1:numel(time_string)
				
				time			= strsplit(time_string{tk},':');
				dec_hour(tk)	= str2num(time{1}) + str2num(time{2})/60 + str2num(time{3})/3600; % /nof_wells
				
			end				
			
		end
		
	end

	function annotations = Annotation_input(titel, data, Tag)
		
		% currently obsolete code
		
		annotations = struct('Experimentname', '', 'Experimenter', username, 'Datum', Tag, 'Beschreibung', '', 'Wells', ...
			struct('WellID','','Text',''), 'Replikatgruppen', struct('Replikatgruppe',''));
		
		answers = '';

		while isempty(answers) % ein Drücken von Cancel ist nicht erlaubt (sonst leeres Feld!)
			answers		= inputdlg({['Experimentname (Dateiname: ' titel ')' ],'durchgeführt von', 'am', ...
				['Kurzbeschreibung des Experiments' blanks(30) '.']},'Experiment-Daten', [1 1 1 5], {titel, username, Tag, ''});
		end
		
		annotations.Experimentname		= answers{1};
		annotations.Experimenter		= answers{2};
		annotations.Datum				= answers{3};
		annotations.Beschreibung		= answers{4};
		annotations.Wells.WellID		= data;
		answers							= [];
		anz								= numel(data);
		z								= 1;
		
		if well_annotation
			for i = 1:18:anz
				well_names					= data(i:min(numel(data),i+17));
				answers						= [answers; inputdlg(well_names, ['Bezeichnung/Inhalt der Wells - Seite ' num2str(z)], [1 nof_wells])];	
				z							= z + 1;
			end
		end
		
		annotations.Wells.Text			= answers;

		answer = '';

		while isempty(answer) % ein Drücken von Cancel ist nicht erlaubt (sonst leeres Feld!)

			if nof_replgr < 18
				dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:nof_replgr)')';
				dummy2	= arrayfun(@(x){[num2str(x)]},(1:nof_replgr)')';
				options = struct('Resize','on');
				answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], dummy2, options);
				% war früher mal:
				% answer	= inputdlg({['Replikatgruppe 1' blanks(59) '.'],  'Replikatgruppe 2', 'Replikatgruppe 3', 'Replikatgruppe 4',  'Replikatgruppe 5',  'Replikatgruppe 6', ...
				% 				'Replikatgruppe 7',  'Replikatgruppe 8', 'Replikatgruppe 9', 'Replikatgruppe 10', 'Replikatgruppe 11', 'Replikatgruppe 12' ,  ...
				% 				'Replikatgruppe 13',  'Replikatgruppe 14', 'Replikatgruppe 15', 'Replikatgruppe 16', 'Replikatgruppe 17', 'Replikatgruppe 18' , ...
				% 				'Replikatgruppe 19',  'Replikatgruppe 20', 'Replikatgruppe 21', 'Replikatgruppe 22', 'Replikatgruppe 23', 'Replikatgruppe 24'}, ...
				% 				'Name der Replikatgruppen?', 1, {'1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21', ...
				% 				'22','23','24'});
				
			elseif nof_replgr < 35
				
				dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:18)')';
				dummy2	= arrayfun(@(x){[num2str(x)]},(1:18)')';
				options = struct('Resize','on');
				answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], dummy2, options);
				dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(19:nof_replgr)')';
				dummy2	= arrayfun(@(x){[num2str(x)]},(19:nof_replgr)')';
				answer	= [answer; inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], dummy2, options)];
				
			else
				uiwait(msgbox('Too many possible replicate groups! Window space is too small, please ask author for an update!','modal'))
			end
				
						
		end

		annotations.Replikatgruppen		= answer;
			
	end

	function annotation_f = update_Annotations()
				
		% currently obsolete code
		
		if ~isempty(annotations)
			
			if isfield(annotations{1},'Experimentname')
				titel	= annotations{1}.Experimentname;
			else
				titel = '';
			end
			
			if isfield(annotations{1}.Wells,'WellID')
				data	= annotations{1}.Wells.WellID;
			else
				error('This error should have not been possible, I am really sorry! Please contact author (code 3933)')
			end
			
			if isfield(annotations{1},'Datum')
				Tag		= annotations{1}.Datum;
			else
				error('This error should have not been possible, I am really sorry! Please contact author (code 3939)')
			end
			
		end
		
		
		annotation_f = struct('Experimentname', annotations{1}.Experimentname, 'Experimenter', annotations{1}.Experimenter, 'Datum', annotations{1}.Datum, ...
			'Beschreibung', annotations{1}.Beschreibung, 'Wells', struct('WellID', {annotations{1}.Wells.WellID}, 'Text', {annotations{1}.Wells.Text}), ...
			'Replikatgruppen', {annotations{1}.Replikatgruppen});

		answers		= inputdlg({['Experimentname (Dateiname: ' annotation_f.Experimentname ')' ],'durchgeführt von', 'am', ...
			['Kurzbeschreibung des Experiments' blanks(30) '.']},'Experiment-Daten', [1 1 1 5], {annotation_f.Experimentname, annotation_f.Experimenter, ...
			annotation_f.Datum, annotation_f.Beschreibung});
		
		annotation_f.Experimentname		= answers{1};
		annotation_f.Experimenter			= answers{2};
		annotation_f.Datum				= answers{3};
		annotation_f.Beschreibung			= answers{4};
		annotation_f.Wells.WellID			= data;
		answers							= [];
		anz								= numel(data);
		z								= 1;
		
		for i = 1:18:anz
			well_names					= data(i:min(end,i+17));
			answers						= [answers; inputdlg(well_names, ['Bezeichnung/Inhalt der Wells - Seite ' num2str(z)], [1 nof_wells], annotations{1}.Wells.Text)];	
			z							= z + 1;
		end

		annotation_f.Wells.Text			= answers;
			
		if nof_replgr < 18
			
			dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:nof_replgr)')';
			options = struct('Resize','on');
			answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], annotations{1}.Replikatgruppen, options);
			
		elseif nof_replgr < 35
				
			dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:18)')';
			options = struct('Resize','on');
			answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], annotations{1}.Replikatgruppen(1:18), options);
			
			dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(19:nof_replgr)')';
			answer	= [answer, inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], annotations{1}.Replikatgruppen(19:nof_replgr), options)];
				
		else
			uiwait(msgbox('Too many possible replicate groups! Window space is too small, please ask author for an update!','modal'))
		end
				

		% war früher mal:				
		% answer	= inputdlg({['Replikatgruppe 1' blanks(59) '.'],  'Replikatgruppe 2', 'Replikatgruppe 3', 'Replikatgruppe 4',  'Replikatgruppe 5',  'Replikatgruppe 6', ...
		% 					'Replikatgruppe 7',  'Replikatgruppe 8', 'Replikatgruppe 9', 'Replikatgruppe 10', 'Replikatgruppe 11', 'Replikatgruppe 12' ,  ...
		% 					'Replikatgruppe 13',  'Replikatgruppe 14', 'Replikatgruppe 15', 'Replikatgruppe 16', 'Replikatgruppe 17', 'Replikatgruppe 18' , ...
		% 					'Replikatgruppe 19',  'Replikatgruppe 20', 'Replikatgruppe 21', 'Replikatgruppe 22', 'Replikatgruppe 23', 'Replikatgruppe 24'}, ...
		% 					'Name der Replikatgruppen?', 1, annotations{1}.Replikatgruppen);						
						
		annotation_f.Replikatgruppen = answer;
		
		annotations{1} = annotation_f;
		
		disp('Note: From now on you leave the area of tested software')
		
		save_Annotations(titel, pfad, annotation_f)
		
		close(findobj(0,'Tag',['Well-GUI:' titel])); % schließe altes Fenster
			
 		% Updaten: Replikatgruppen-Namen
		for i = 1:numel(drop_h)
			temp = get(drop_h(i),'String');
			set(drop_h(i),'String',[temp(1:3); annotations{1}.Replikatgruppen])
		end

		%show_Annotation;

	end

	function result = save_Annotations(titel, pfad, annotation_)
		
		filename = [titel '_annotation.mat'];
		save([pfad filename], '-struct', 'annotation_');
		
		result = true;
		
	end


% 	function result = show_Annotation()
% 		% Zeige Annotations an
% 		
% 		for file_idx = 1:file_anz
% 		
% 			[~,filename,~] = fileparts(fname{file_idx});
% 			
% 			if numel(annotations) >= file_idx && ~isempty(annotations{file_idx})
% 				
% 				mbox_h = msgbox(['Das Experiment "' annotations{file_idx}.Experimentname '" (Dateiname: "' filename '"), durchgeführt am ' annotations{file_idx}.Datum ' von "' ...
% 					annotations{file_idx}.Experimenter '", wurde beschrieben durch:' CR CR annotations{file_idx}.Beschreibung]);
% 				mbox_h.UserData = 'Annotation';
% 				% Schließt Fenster nach einer bestimmten Zeit automatisch
% 				timed =  timer('ExecutionMode','singleShot','StartDelay',2,'TimerFcn',@(~,~)myclose(mbox_h));
% 				start(timed);
% 				
% 				f = findobj(0,'Tag',['Well-GUI:' filename]);
% 				if ~isempty(f),
% 					close(f);
% 				end
% 				
% 				f					= figure;
% 				f.Position			= [400-5*file_idx 200-5*file_idx 560*1.75 373*1.75];
% 				f.Tag				= ['Well-GUI:' filename];
% 				f.Name				= [filename ' (identische Skalierung)'];
% 				f.UserData			= 'Annotation';		
% 				
% 				rectangle('position',[0 0 12 8]); % Rahmen
% 				
% 				% BioTek-Daten sind geordnet nach Buchstabe (A01, A02, A03, ...
% 				% Mitras Daten nach Zahlen (A01, B01, C01 ...
% 				
% 				image_idx	= 0;
% 				miny_fig	= Inf;
% 				maxy_fig	= 0;
% 				
% 				if device_mithras,
% 					
% 					for j = 0:11,
% 						for i = 0:7,
% 
% 							sp		= subplot(8,12,j+i*12+1);
% 							if isempty(cellstrfind(name, [char(65+i),repmat('0',2-numel(num2str(j+1)),1), num2str(j+1)],'exakt')),
% 
% 								% Es sind nicht immer alle Wells belegt, die
% 								% leeren einfach überspringen
% 								sp.XAxis.Visible	= 'off';
% 								sp.YAxis.Visible	= 'off';							
% 								sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
% 								sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
% 								sp.Color			= [0.97 0.97 0.97];	
% 								
% 								continue
% 
% 							end
% 							
% 							image_idx = image_idx +1;
% 							hold on
% 
% 							if strcmp(replikat_mode,'biol'),
% 
% 								hold on
% 
% 								% for g = 2:size(mess(image,:,:),3)
% 								% 	plot(t,mess(image,:,g));
% 								% end
% 								dummy = plot(t,mess(image_idx,:,file_idx));
% 							else
% 								dummy = plot(t,mess(image_idx,:,1));
% 							end
% 							
% 							if maxy_fig < max(dummy.Parent.YLim),
% 								maxy_fig = max(dummy.Parent.YLim);
% 							end
% 							if miny_fig > min(dummy.Parent.YLim),
% 								miny_fig = min(dummy.Parent.YLim);
% 							end
% 							
% 							sp.XAxis.Visible	= 'off';
% 							sp.YAxis.Visible	= 'off';							
% 							% sp.Position			= sp.Position+[-.01 -.02 +.01 +0.02];
% 							sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
% 							sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
% 
% 							sp.XLim(2)			= t(end);
% 
% 						end
% 						
% 						figure(f)
% 						
% 					end
% 					
% 				else % wenn biotec-Daten, dann ...
% 					
% 					for i = 0:7,
% 						for j = 0:11,
% 
% 							%image	= 1+j+i*8;
% 
% 							sp = subplot(8,12,j+i*12+1);
% 							
% 							if isempty(cellstrfind(name, [char(65+i),repmat('0',2-numel(num2str(j+1)),1), num2str(j+1)],'exakt')),
% 
% 								% Es sind nicht immer alle Wells belegt, die
% 								% leeren einfach überspringen
% 								sp.XAxis.Visible	= 'off';
% 								sp.YAxis.Visible	= 'off';							
% 								% sp.Position			= sp.Position+[-.01 -.02 +.01 +0.02];
% 								sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
% 								sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
% 								sp.Color			= [0.97 0.97 0.97];
% 
% 								continue
% 
% 							end
% 							
% 							image_idx = image_idx +1;
% 							hold on
% 
% 							if strcmp(replikat_mode,'biol'),
% 
% 								hold on
% 
% 								% for g = 2:size(mess(image,:,:),3)
% 								% 	plot(t,mess(image,:,g));
% 								% end
% 								dummy = plot(t,mess(image_idx,:,file_idx));
% 							else
% 								dummy = plot(t,mess(image_idx,:,1));
% 							end
% 
% 							if maxy_fig < max(dummy.Parent.YLim),
% 								maxy_fig = max(dummy.Parent.YLim);
% 							end
% 							if miny_fig > min(dummy.Parent.YLim),
% 								miny_fig = min(dummy.Parent.YLim);
% 							end
% 							
% 							sp.XAxis.Visible	= 'off';
% 							sp.YAxis.Visible	= 'off';							
% 							sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
% 							sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
% 
% 							sp.XLim(2)			= t(end);
% 						end
% 						
% 						figure(f)
% 					end
% 					
% 				end % biotec oder nicht
% 				
% 				dummy = get(gcf,'Children'); 
% 				set(dummy,'YLim',[miny_fig maxy_fig]); %Alle mit gleicher Y-Achse zeigen
% 				
% 				a					= axes;
% 				a.Position			= a.Position+[-.01 -0.02 +.01 +0.02];
% 				a.XTick				= [1:12]-0.5;
% 				a.XTickLabel		= {'1','2','3','4','5','6','7','8','9','10','11','12'};
% 				a.XAxisLocation		= 'top';
% 				a.YTick				= [1:8]-0.5;
% 				a.YTickLabel		= {'H','G','F','E','D','C','B','A'};
% 				a.Title.String		= f.Name; % annotations{file_idx}.Experimentname;
% 				a.Title.Interpreter = 'none';
% 				a.XLim(2)			= 12;				
% 				a.YLim(2)			= 8;
% 				a.Color				= [.8 .8 .8];
% 				
% 				f					= gcf;
% 				f.Children			= f.Children([2:end 1]); % Letzte Figure nach hinten stellen
% 				
% 			end
% 		end
% 
% 		result = true;
% 		
% 	end


function result = show_Thumbnails()
		% Zeige Thumbnails der Platten an
		
		for file_idx = 1:file_anz
		
			[~,filename,~] = fileparts(fname{file_idx});
			
			%if numel(annotations) >= file_idx && ~isempty(annotations{file_idx})
				
				% mbox_h = msgbox(['Das Experiment "' annotations{file_idx}.Experimentname '" (Dateiname: "' filename '"), durchgeführt am ' annotations{file_idx}.Datum ' von "' ...
				% 	annotations{file_idx}.Experimenter '", wurde beschrieben durch:' CR CR annotations{file_idx}.Beschreibung]);
				% mbox_h.UserData = 'Annotation';
				% % Schließt Fenster nach einer bestimmten Zeit automatisch
				% timed =  timer('ExecutionMode','singleShot','StartDelay',2,'TimerFcn',@(~,~)myclose(mbox_h));
				% start(timed);
				
				f = findobj(0,'Tag',['Well-GUI:' filename]);
				if ~isempty(f)
					close(f);
				end
				
				f					= figure;
				f.Position			= [450-5*file_idx 250-5*file_idx 560*1.75 373*1.75];
				f.Tag				= ['Well-GUI:' filename];
				f.Name				= [filename ' (identical scaled)'];
				f.UserData			= 'Thumbnail';		
				
				rectangle('position',[0 0 12 8]); % Rahmen
				
				% Envision- und BioTek-Daten sind geordnet nach Buchstabe (A01, A02, A03, ...
				% Mitras Daten nach Zahlen (A01, B01, C01 ...
				
				image_idx	= 0;
				miny_fig	= Inf;
				maxy_fig	= 0;
				
				if device_mithras
					
					for j = 0:11
						for i = 0:7

							sp		= subplot(8,12,j+i*12+1);
							
							if isempty(cellstrfind(name, [char(65+i),repmat('0',2-numel(num2str(j+1)),1), num2str(j+1)],'exakt'))

								% Es sind nicht immer alle Wells belegt, die
								% leeren einfach überspringen
								sp.XAxis.Visible	= 'off';
								sp.YAxis.Visible	= 'off';							
								sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
								sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
								sp.Color			= [0.97 0.97 0.97];	
								
								continue

							end
							
							image_idx = image_idx +1;
							hold on

							if strcmp(replicate_mode,'biol')

								hold on

								% for g = 2:size(mess(image,:,:),3)
								% 	plot(t,mess(image,:,g));
								% end
								dummy = plot(t,mess(image_idx,:,file_idx));
							else
								dummy = plot(t,mess(image_idx,:,1));
							end
							
							if maxy_fig < max(dummy.Parent.YLim)
								maxy_fig = max(dummy.Parent.YLim);
							end
							if miny_fig > min(dummy.Parent.YLim)
								miny_fig = min(dummy.Parent.YLim);
							end
							
							sp.XAxis.Visible	= 'off';
							sp.YAxis.Visible	= 'off';							
							% sp.Position		= sp.Position+[-.01 -.02 +.01 +0.02];
							sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
							sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
							sp.XLim(2)			= t(end);

						end
						
						figure(f)
						
					end
					
				else % wenn biotec- oder Envision-Daten, dann ...
					
					for i = 0:7
						for j = 0:11

							%image	= 1+j+i*8;

							sp = subplot(8,12,j+i*12+1);
							
							if isempty(cellstrfind(name, [char(65+i),repmat('0',2-numel(num2str(j+1)),1), num2str(j+1)],'exakt'))

								% Es sind nicht immer alle Wells belegt, die
								% leeren einfach überspringen
								sp.XAxis.Visible	= 'off';
								sp.YAxis.Visible	= 'off';							
								% sp.Position			= sp.Position+[-.01 -.02 +.01 +0.02];
								sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
								sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
								sp.Color			= [0.97 0.97 0.97];

								continue

							end
							
							image_idx = image_idx +1;
							hold on

							if strcmp(replicate_mode,'biol')

								hold on

								% for g = 2:size(mess(image,:,:),3)
								% 	plot(t,mess(image,:,g));
								% end
								dummy = plot(t,mess(image_idx,:,file_idx));
							else
								dummy = plot(t,mess(image_idx,:,1));
							end

							if maxy_fig < max(dummy.Parent.YLim)
								maxy_fig = max(dummy.Parent.YLim);
							end
							if miny_fig > min(dummy.Parent.YLim)
								miny_fig = min(dummy.Parent.YLim);
							end
							
							sp.XAxis.Visible	= 'off';
							sp.YAxis.Visible	= 'off';							
							sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
							sp.Position([3 4])	= [6.01e-02 , 9.60e-02];

							sp.XLim(2)			= t(end);
						end
						
						figure(f)
					end
					
				end % biotec oder nicht
				
				dummy = get(gcf,'Children'); 
				set(dummy,'YLim',[miny_fig maxy_fig]); %Alle mit gleicher Y-Achse zeigen
				
				a					= axes;
				a.Position			= a.Position+[-.01 -0.02 +.01 +0.02];
				a.XTick				= [1:12]-0.5;
				a.XTickLabel		= {'1','2','3','4','5','6','7','8','9','10','11','12'};
				a.XAxisLocation		= 'top';
				a.YTick				= [1:8]-0.5;
				a.YTickLabel		= {'H','G','F','E','D','C','B','A'};
				a.Title.String		= ['Experiment file imported: ' f.Name]; % annotations{file_idx}.Experimentname;
				a.Title.Interpreter = 'none';
				a.XLim(2)			= 12;				
				a.YLim(2)			= 8;
				a.Color				= [.8 .8 .8];
				
				f					= gcf;
				f.Children			= f.Children([2:end 1]); % Letzte Figure nach hinten stellen
				
			%end
		end

		result = true;
		
	end



	function result = show_layout()

		f					= figure;
		f.Position			= [400 200 560*1.75 373*1.75];
		f.Tag				= 'Well-Layout';
		f.Name				= 'Well-Layout';
		f.UserData			= 'Well-Layout';

		
		rectangle('position',[0 0 12 8]); % Rahmen
		a					= gca;
		a.NextPlot			= 'add';
		a.Position			= a.Position+[-.01 -0.02 +.01 +0.02];
		a.XTick				= [1:12]-0.5;
		a.XTickLabel		= {'1','2','3','4','5','6','7','8','9','10','11','12'};
		a.XAxisLocation		= 'top';
		a.YTick				= [1:8]-0.5;
		a.YTickLabel		= {'H','G','F','E','D','C','B','A'};
		a.Title.String		= [f.Name ': ' mergecellorstring(fname)]; % annotations{file_idx}.Experimentname;
		a.Title.Interpreter = 'none';
		a.XLim(2)			= 12;				
		a.YLim(2)			= 8;
		a.Color				= [.8 .8 .8];
		
		% ToDo: This code is currently only valid for 96 well plates
		% Interpreter-option for usage of underscores in group names, see below
		for i = 1:12
			for j = 8:-1:1 % von "A" nach "H"
				% Male Well-Kreise in "Platte" und versehe sie mit
				% Well-Namen
				if isempty(cellstrfind(name, [char(64+9-j) num2str(i,'%02d')]))
					plot(0+i-0.5,0+j-0.5,'o','markersize',40,'Color','black','MarkerFaceColor',[.8 .8 .8])
				else
					plot(0+i-0.5,0+j-0.5,'o','markersize',40,'Color','black','MarkerFaceColor',[1 1 1])
					if ~strcmpi('NaN',layouttxt{9-j,i}) 
						if numel(layouttxt{j,i}) < 11 % Well-Bezeichnung nicht zu lang?
							text(0+i-0.875,0+j-0.5,layouttxt{9-j,i},'Fontsize',7,'Interpreter','none')
						else
							text(0+i-0.875,0+j-0.4,layouttxt{9-j,i}(1:9),'Fontsize',7,'Interpreter','none')
							text(0+i-0.875,0+j-0.6,layouttxt{9-j,i}(10:min([18 numel(layouttxt{9-j,i})])),'Fontsize',7,'Interpreter','Latex')
						end
					else
						text(0+i-0.875,0+j-0.5,'--','Fontsize',7)
					end
				end
			end
		end
		
		
		% f					= gcf;
		% f.Children			= f.Children([2:end 1]); % Letzte Figure nach hinten stellen
		
		%saveas(f,[pathname{1} 'Plattenlayout.png'])
		print(f,[pathname{1} 'Plate_layout.png'],'-dpng','-r0'); %print statt saveas ermöglicht auflösungsoption
		
	end

	function result = old_version
		% Vergleiche Programmversion mit der in der User-Cfg abgelegten zuletzt verwendeten
		% Versionsnummer
		
		v_user		= textscan(version_user,'%c%s%s%s','Delimiter','.');
		v_programm	= textscan(version_str,'%c%s%s%s','Delimiter','.');
		% cell(1) = "v", ... version_str = "v1.2.3"
		
		if str2num(v_user{2}{1}) < str2num(v_programm{2}{1}) || str2num(v_user{3}{1}) < str2num(v_programm{3}{1}) || str2num(v_user{4}{1}) < str2num(v_programm{4}{1}),
			% Ausnutzung der Matlab-Logik bei "OR"-Verknüpfungen: Nur wenn der erste Term FALSE ist,
			% wird der zweite überhaupt geprüft, etc.
			result = true;
		else
			result = false; % --> Dem User ist die aktuelle Version bekannt
		end
	
	end

	% function [reihen, spalten] = calc_subplot(anz)
	% 
	% 	spalten = ceil(sqrt(anz));
	% 	reihen	= ceil(anz/spalten);
	% 
	% end
		
	function allclose_Cb(event, data)
		% Funktion zum Schließen aller Fenster (auch unsichtbarer und
		% geschützter)
		
		tmp = findall(0,'CloseRequestFcn','');
		set(tmp,'CloseRequestFcn','closereq');
		delete(event)
		
	end
		
	function stat = calc_stat(selection, Amp,Dam,Per,Pha_min) %, DeltaPer)
		% Normale Berechnung der Standardabweichungen
		
		stat(1) = std(Amp(selection),'omitnan');
		stat(2) = std(Dam(selection),'omitnan');
		stat(3) = std(Per(selection),'omitnan');
		stat(4) = std(Pha_min(selection),'omitnan');
		%stat(5) = std(DeltaPer(selection),'omitnan');

	end

	function stat_e = calc_stat_e(selection, Basis_Amp,Basis_Dam,Basis_Off)
		% Spezielle Berechnung der Standardabweichungen für Anpassung mit e-Funktion

		stat_e(1) = std(Basis_Amp(selection),'omitnan');
		stat_e(2) = std(Basis_Dam(selection),'omitnan');
		stat_e(3) = std(Basis_Off(selection),'omitnan');

	end

	function joke_Cb(event, data)
		% EasterEgg - Teilfunktion
		
		event.Visible	= 'off';
		msgbox('You''re not serious, are you?')
		joke_done		= true;
		
	end

	function big_meas = wellname_pos(mess_, name)
		% this function helps to transfer a not completely filled matrix into a complete 96-matrix
		
		big_meas = NaN(96, size(mess_,2));
		
		for i = 1:size(mess_,1)
			
			% Note: this layout is used:
			% big_meas (96 table) contains in first column and row: "A01"
			% ... "B01" in 2. row ...
			% ... "A02" in 9. row ...
			
			position				= wellname2tablerow(name{i});
			big_meas(position,:)	= mess_(i,:);
			
		end
			
	end
		
	function result = wellname2tablerow(name_str)
		% Bestimmt aus Wellnamen die Zeile in der Ergebnistabelle
		
		if device_mithras
			result	= (double(name_str(1))-64) + 8 * (str2num(name_str(2:end))-1);
		else
			result	= ((double(name_str(1))-64)-1) * 12 + (str2num(name_str(2:end)));
		end
		
	end
		
	function Raw_anaus_CB(source, eventdata)
		% Callback für den Schaltfläche "Raw"-Daten darstellen on/off
		
		line_idx = findall(source.Parent.Parent,'tag','sim');
		
		switch source.State
			case 'on'
				set(line_idx,'Visible','off');
			case 'off'
				set(line_idx,'Visible','on');
		end
		
		axs = findall(0,'Tag','CombinedResult');
		
		if ~isempty(axs)
		
			for j = 1:numel(axs)
				axs(j).YLim = [min([axs.YLim]) max([axs.YLim])];
			end

		end		
		
	end

	function vscroll_Callback(src,evt)
		% Als Callback-Funktion für den Slider
		
		set(panel,'position',[0 -get(src,'value') 0.965 2])
	end

	function t = zeitrunden(t_) 
		% Rundet Zeitdaten auf ungefähr 2 min
		
		t = round(t_.*30)./30;
		
	end

	function myclose(g_handle)
		% eigene Funktion zum Schließen von Fenstern		
		% hauptsächlich zum Schließen der getimed'ten Message-windows
		
		if ishandle(g_handle)
		 close(g_handle);
		end
	end

	function LoadRepl_Button_Cb(src,evt)
		% Lade Konfiguration für Replikationsgruppen
		
		[filename_, pathname_] = uigetfile( {'*.mat*','replicate-config'}, ...
			'Select configuration for replicate group');
		
		config = load([pathname_ filename_]); % loads "config"
		
		if isfield(config,'data_')
			
			for i_ = 1:numel(drop_h)

				drop_h(i_).Value = config.data_(i_);

					% Usability: Dann gleich auch ankreuzen

					if mod(i_,12)+12*double(mod(i_,12)==0) < 10
						idx_str = [char(double('A')+floor((config.wnames_(i_)-1)/12)) '0' num2str(mod(i_,12)+12*double(mod(i_,12)==0))];
					else
						idx_str = [char(double('A')+floor((config.wnames_(i_)-1)/12)) num2str(mod(i_,12)+12*double(mod(i_,12)==0))];
					end

					% find check_h wo "idx_str" als "Tag" enthalten ist und damit dann:
					idx_ = findobj(check_h,'Tag',idx_str);

					set(idx_,'Value',1);

					if drop_h(i_).Value > 1
						set(idx_,'Value',1);
						% falls noch nicht an:
						set(hStart,'Enable','on');
					else
						set(idx_,'Value',0);
					end

			end

		end
		
	end

	function SaveRepl_Button_Cb(src,evt)
		% Speichere Konfiguration für Replikationsgruppen
		
		filename_	= inputdlg('File name for configuration of replicate group?', '');
		data_		= [];
		wnames_		= [];
		
		for i_ = 1:numel(drop_h)
			data_	= [data_ drop_h(i_).Value];
			wnames_	= [wnames_ str2num(strrep(drop_h(i_).Tag,'check',''))];
		end
		
		config = struct('data_',data_,'wnames_',wnames_);
		
		save([pfad filename_{1}], 'config');
		
		clear config, data_, wnames_;
		
	end

	function [colnr, rownr] = calc_pos(wellname)
		colnr = double(wellname(1))-64;
		rownr = str2num(wellname(2:end));
	end

	function result_str = firstcellorstring(cstr)
		% es kann eine cellstring oder ein string übergeben werden,
		% Rückgabe ist entweder der erste cellstring oder der string selbst
		if iscell(cstr)
			result_str = cstr{1};
		else
			result_str = cstr;
		end
	end


	function result_str = mergecellorstring(cstr, delimiter_str)
		
		if iscell(cstr)
			
			result_str = cstr{1};
			
			for i = 2:numel(cstr)
				result_str = [result_str ' + ' cstr{i}];
			end
			
		else
			result_str = cstr;
		end
		
	end

	function C = MWheel(object, eventdata)

		vpos = get(panel,'Position');
		
		if eventdata.VerticalScrollCount < 0
			vpos(2) = max([-1; vpos(2) - 0.25]);
			set(vscrollbar,'value',min([1;get(vscrollbar,'value')+0.25]));
		elseif eventdata.VerticalScrollCount > 0
			vpos(2) = min([0;vpos(2) + 0.25]);
			set(vscrollbar,'value',max([0;get(vscrollbar,'value')-0.25]));
		end
		
		set(panel,'Position',vpos);
		
	end

  	function str = leftstr(string_,length)
		
		str = '';
		if ischar(string_)
			str = string_(1:min([length, numel(string_)]));
		end
		
	end	

	function closeit(src,event,f_all)
		% function for auto-closing dialog windows, see for explanation in
		% calling code lines above
			f_all_new = findall(0,'Type','figure');
			f_diff = setdiff(f_all_new,f_all);
			if ishandle(f_diff),
				close(f_diff);
			end
		end


end

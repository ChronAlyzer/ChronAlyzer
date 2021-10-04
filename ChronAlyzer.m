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
% The program was developed during my work at the BfR in 2019-2020 and is still
% under further development.
%
% Author: Norman Violet
% E-Mail: norman.violet@bfr.bund.de
% Bundesinstitut für Risikobewertung (BfR)
% German Federal Institute for Risk Assessment
% 10589 Berlin, Germany
%
%
% I use(d) Matlab (Mathworks, 2017a) to script it. 
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
%		7. Remove Figure Menu & Controls (if not run in debugging mode)
%
% ToDo: Further ideas
%	- create heatmaps from deviations to average: Are the differences in cell at the border of the plate greater?
%	
%
% ToDo: Remove ToDos and Notes in the code
% ToDo: Replace "Abort" and "End" buttons by only one button
% ToDo: Update all error codes with the actual line number, add such error codes to all error commands
% ToDo: Add support for other then 96-well-plates again
%

%% Variables initialization

	version_str		= 'v0.9'; % current version - Note: This "number" has to be in CA_changes.m also!
	
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
	Restart			= false;
	tab_pha_h		= []; % handles for entries in the main table (phase, amplification, ....)
	tab_amp_h		= []; % ...	
	tab_dam_h		= []; % ...	
	pha_button		= 1; 
	mouseselectY_1	= [];
	mouseselectY_2	= [];
	kontroll_idx	= NaN;
	medium_idx		= NaN;
	well_annotation = false; % obsolete, was: only if TRUE well annotation were asked for
	s_idx			= [];
% nof_replgr		= 1; % at least one must be there for analyze 
	global_messages	= {}; % to store user choices (like "gap" or "average") which have influence on result, used for proper documentation
	
	fname			= []; % File name (Data source)
	pathname		= []; 
	line_h_global	= []; % some more graphics handle
	file_anz		= 0; % number of data files
	replicate_mode	= ''; % This indicates if biological replicates (multiple plates) are used
	well_names		= '';
	
	general_options	= struct('TimeWeight',false,'LogDiff',false,'ConstParameterPER',true, 'ConstParValue', 24, 'weight_threshhold_time',12); % options - saved in user settings	
    nof_wells       = 96; % ToDo: number of wells - currently no other size is supported (in previous version it was possible to load, but further functions not, so now it is explicitly unsupported)  
	datum_str		= strrep(char(datetime('now')),':','_');  % Date, used for file export
	
	% User-Optionen (default values) - will be asked for in program
	time_weight		= false; % Forcing more weight on measurements in the beginning of the time-series?
	log_diff		= false; % Using the log difference in the calculation of the "error" difference in curve-fitting?
    const_PER       = true; % Period length OR phase-shift must be kept constant, which one?
    const_value		= 24; % default value for constant period length (should be modified below if "const_PER" is FALSE of course)
	
	% measurement data
	mess			= [];	% this is a 3D-matrix; 1-dim well number (so length == 96); 2-dim: entries for all measurements (so length == length(t)); 
							% 3-dim: number of files loaded
	t				= []; % contains a vector of measuring times (valid for all measurements!)
	weight			= []; % contains a weighing factor for the objective function in optimation (the "error" function), but is also needed for missing measurement information
	delta_t			= []; % time difference between measurements; equidistant. If raw data are not equidistantly measured, this had to be modified somehow

	% for annotation - obsolete
	config			= []; % obsolete too
	% Note: there are "Load_Replgr" and "Save_Replgr" which could be re-used
	% for modification of the replicate groups later on, but this
	% functionality is given also in the layout excel file.
	
	% (measurement) device-depending file format options (this is important
	% for the order of the information/wells within the files)
	device_BioTek	= false; % data files are created by BioTek reader
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
		
		CA_changes; % this call imports program changes (stored in variable "greetingtext")
	
	end

	% Shorten text cell in order to show only recent changes
	idx_txt		= strfind(greetingtext,version_user(2:end));
	if isempty(idx_txt)
		uiwait(msgbox('The program version and the history file "CA_changes.m" do not fit together'))
	end
	important	= ['']; % this can be used as a special announcement
	
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
	
	clear quotes_str
	
	% Output of complete greeting text
	
	dummy					= figure('dockcontrols','off','Resize','off','toolbar','none','menubar','none','nextplot','add','color',[1 1 1],'units','pixel');
	dummy.Position([2 3])	= [60 660];
	
	hbestaetigt			= uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, ...
		'String','OK','units','normalized','Position',[.4,.03,.2,.06],'Callback',{@(~,~)myclose(dummy)});
	
	image(image_data);
	logo_axes_h = gca;
	clear image_data;
	
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
	clear enlarge_diff
	
	% Starts timer and call closerequest of greetings window after 
	timed = timer('ExecutionMode','singleShot','StartDelay',10+ceil(numel(greetingtext)/20),'TimerFcn',@(~,~)myclose(dummy)); % creates timer object
	start(timed);
	pause(2) % That's a minimum time the user has to look at the greeting window
	clear greetingtext

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
			[fname{1}, pathname{1}] = uigetfile( {'*.xls*','Mithras / BioTek / Envision result files (xls xlsx)';'*.txt', 'Opera Phenix export file (txt)'}, ...
				[num2str(i) '. Select data file or cancel'],'Select first data file or cancel');
			i = i + 1;
		else
			[fname_, pathname{i}] = uigetfile( {'*.xls*','Mithras / BioTek / Envision result files (xls xlsx)';'*.txt', 'Opera Phenix export file (txt)'}, ...
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
					timed =  timer('ExecutionMode','singleShot','StartDelay',4,'TimerFcn',@(~,~)myclose(mbox_h));
					start(timed);
			end

		end
		
	end % loop is ended if "break" is called by user selection

	clear fname_

	% -------------------
	if isempty(fname) % was file selection aborted by closing selection windows (clicking on the "red cross")? Then abort complete program 
		return
	end
	% -------------------

	system_dependent('DirChangeHandleWarn','Once'); % Reset to default; see comment above (search for "system_dependent")

	file_anz = numel(fname);	% number of selected file
	global_messages = fname;	% store all used file names (yes, maybe it's redundant here, but this variable will contain all user choices)
	
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
	% "t"	:		contains a vector of measuring times (valid for all measurements!)
	% "mess":		this is a 3D-matrix; 1-dim well number (so length == 96); 2-dim: entries for all measurements (so length == length(t)); 
	%				3-dim: number of files loaded
	% "well_names":	cell matrix with strings, containing names of wells ("A01" ,...")	
	% ===================================================================================

%%  ====== start of loop

	for file_idx = 1:file_anz
		
		[~,~,extension] = fileparts(fname{file_idx});
		
		if debug
			disp(['... working on: "' fname{file_idx} '"'])
		end
		
		% Data sources are not always formatted in this way, imported data
		% has to be re-formatted accordingly (or a new import filter must
		% be coded).
		
		switch extension
			
			case '.txt'  % -------------------------------------------------------------------
				
				% could be used for "*.csv" as well
				%
				% Note: this case is not developed further and is be outdated!
				% There is only a basic functionality supported with this file type
				
				% modify text filter to your needs
				
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
				
				t							= messdaten.data(:,9)'./3600;
				t							= zeitrunden(t);
				mess_						= [messdaten.data(:,5)]';
				% ToDo: Currently, there is no check if all time-series are identical in reference to times and wells
				
				first_measurement_idx		= find(messdaten.data(:,4) == 0); % MessInfo sometimes empty
				rows						= messdaten.data(first_measurement_idx,[1:2]);
				
				mess(:,:,file_idx)			= reshape(mess_,numel(find(t==0)),[]);
				weight						= ones(size(mess));				
				t							= unique(t);
				delta_t						= get_delta_t(t);
				
				well_names					= {};
				
				for r_idx = 1:size(rows,1)
					r1					= rows(r_idx,1);
					r2					= ['0' num2str(rows(r_idx,2))];
					well_names{end+1}	= [char(64+r1) extractAfter(r2,strlength(r2)-2)];
				end
				
				device_opera = true; % this "Opera" device can export measurement into TXT files (not used anymore)
				
			case {'.xls','.xlsx'} % -------------------------------------------------------------------
				
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
				% -- BioTek uses "Times" twice; the first in the meta data header, the second in the second column before the measurement data
				
				
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
					
					% Device: BioTek or Mithras
					
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
						
					else % BioTek
						
						device_BioTek	= true;
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
						% Note: BioTek data sheets sometimes contain rows with "00:00:00" times, but otherwise empty.
						% This happens when the measurement is interupted manually at the device.
						
					end
					
				end
				
				if isempty(data_ends)
					data_ends = size(txt,1);
				end
				
				% ------ Importing of file text content starts here ----------------------
				
				% Reading measurement time information
				% First file -> initialize variables "t" and "mess", then use "t_" and "mess_" in order to fit the new and perhaps
				% differently formatted (different time vector) into a unified time vector and a unified measurement matrix.
				% (not: the same goes for "weight")
				
				if file_idx == 1
					
					% ToDo: Add a note to user to select the longest, most complete (no missing measurements) data set first - make's a lot
					% easier

					if device_mithras
						t			= txt(data_starts(1)+1:data_ends(1),1);
						t			= convert_Time2DecHour(t); % Conversion of time from character string
					elseif device_BioTek
						t			= cell2mat(raw(data_starts+1:data_ends,2)) * 24; % Conversion of decimal time into hours
						t			= t'; % Transponieren
					elseif device_envision
						t			= cell2mat(raw(data_starts:data_ends,1)); % No conversion nesessary
						t			= t'; % Transponieren
					end
					
					delta_t					= get_delta_t(t); % find the "default" time distance between measurements
							
				else
					% only for files after the first one

					if device_mithras
						t_			= txt(data_starts(1)+1:data_ends(1),1);
						t_			= convert_Time2DecHour(t_); % Conversion of time from character string
					elseif device_BioTek
						t_			= cell2mat(raw(data_starts+1:data_ends,2)) * 24; % Conversion of decimal time into hours
						t_			= t_'; % Transponieren
					elseif device_envision
						t_			= cell2mat(raw(data_starts:data_ends,1)); % No conversion nesessary
						t_			= t_'; % Transponieren
					end
					
				end
				
				if device_mithras
					well_names		= txt(data_starts(1),2:end); % Well names
				elseif device_BioTek
					well_names		= txt(data_starts(1),4:end); % Well names
				elseif device_envision
					well_names		= txt(data_starts-1 ,3:end); % Well names
				end
				% Note: Perhaps the data are not complete, i.e. not 96 columns for 96-plate: This will be corrected down below
				
				
				% Read measurement values
				%	store this temporarily in "mess_" to perform a sequence of checks first, before integrating this into "mess"
				%	It is a little bit more complicated, because there could be two sets of measurements within one file and
				%	there might be invalid or missing measurement information
				
				for daten_idx = 1:anz_reads
					
					if device_mithras
						
						disp('Mithras data file detected!')
						disp('Note: the program code has to be improved for such files!')
						
						mess_					= cell2mat(raw(data_starts(daten_idx)+1:data_ends(daten_idx),2:end));
						weight_					= ones(size(mess_));
						read_titel(daten_idx)	= raw(data_starts(daten_idx)-1,1); % only used for files containing multiple data sets
						
						% ToDo: There is no TRY-CATCH block for dealing with gaps, like below

					else % = BioTek or Envision measurements

						try
							
							if device_BioTek
								disp('BioTek data file detected! (or special case: test data)')
								mess_					= cell2mat(raw(data_starts(daten_idx)+1:data_ends(daten_idx),4:end));
								read_titel(daten_idx)	= txt(6,2);
							elseif device_envision
								disp('Envision data file detected! (or special case: test data)')
								mess_					= cell2mat(raw(data_starts(daten_idx):data_ends(daten_idx),3:end));
								read_titel(daten_idx)	= fname(daten_idx);
							end
							
							% this IF-ELSEIF loop will fail with non-numerical values (and continue below in TRY-CATCH) ...
							weight_	= ones(size(mess_)); % if everything was imported this weight is correct, otherwise it will be re-created in the TRY-CATCH below
							% ... but if excel cells are empty this will be converted to NaNs which is (in Matlab) an numerical value. So
							% raise the error manually:
							if any(any(isnan(mess_)))
								error('MATLAB:cell2mat:MixedDataTypes','MATLAB:cell2mat:MixedDataTypes');
							end
							
						catch ME
							
 							if strcmp(ME.identifier, 'MATLAB:cell2mat:MixedDataTypes')							
							
								mbox_h = my_msgbox(['There are OVERFLW (or other non-numerical) values within the imported data! You can choose ' ... 
									'between marking these as gaps or to be replaced by the average of the adjacent values (only allowed for solitary entries)'],12);
								mbox_h.Name = ['... while reading "' fname{file_idx} '"'];
								uiwait(mbox_h);
								
								% Let user decide to fill in the gaps (like in previous versions) or to mark the elements as missing (setting weighting factor to zero)							
								% Only single gaps should be filled by an average, if the user opts for it! Because, this is tampering with data .... generally, a bad idea

								answer = questdlg('Set gaps in time-series or replace them by calculated averages?','Non-numerical values found', 'Set gaps', 'Replace by average' , 'Set gaps'); 
								
								% find all non-numerical entries
								% Note: this "raw" importing creates a cell, this must be converted later down
								if device_BioTek
									mess_	= raw(data_starts(daten_idx)+1:data_ends(daten_idx),4:end); % use "raw" to get all kinds of entries
								elseif device_envision
									mess_	= raw(data_starts(daten_idx)+1:data_ends(daten_idx),3:end); % use "raw" to get all kinds of entries
								else
									error('unknown device type (error code "973")');
								end
																
								% replace any "non-numerical" (also "NaN" as text !) by NaN (the numerical Matlab value)
								idx			= find(cellfun(@ischar, mess_)) ; % find non-numerical entries ...
								mess_(idx)	= {NaN}; % replace them by (numerical) NaN ...
								idx			= find(cellfun(@isnan, mess_)); % ... now find all NaN entries.
								
								switch answer
									case 'Set gaps'
										
										% replace invalid entries by "NaN" and set matrix with weighting factors accordingly
										
										mess_(idx)	= {NaN};
										weight_		= ones(size(mess_));
										weight_(idx) = 0;
										
										% As mentioned above, the raw importing method created a cell, we need a matrix
										mess_ = cell2mat(mess_);
										% This is the measurement matrix now, "NaN" entries mark the gaps
										global_messages{end+1} = 'Invalid/Empty data entries are encountered, user selection: "mark as gaps"';

									case 'Replace by average'
										
										% Note: replacement conditions must be checked only within the same well! The "idx" 
										weight_		= ones(size(mess_));
										global_messages{end+1} = 'Invalid7Empty data entries are encountered, user selection: "calculate average"';
										
										% As mentioned above, the raw importing method created a cell, we need a matrix
										mess_ = cell2mat(mess_);
										% This is the measurement matrix now, "NaN" entries mark the gaps
										
										% Note: The following nested IF-conditions are intentionally written in a long, readable format :-)
										
										if numel(idx) == 1
											% only one invalid entry was found
											if idx == 1 % only first measurement is invalid, copy second measurement to this
												mess_(1)	= mess_(2);
												weight_(1)	= 0.5; % reduce weighting factor for this artificial value
											elseif idx == numel(mess_) % only last measurement is invalid, copy second-to-last measurement to this
												mess_(end)	= mess_(end-1);
												weight_(end)	= 0.5; % reduce weighting factor for this artificial value
											else
												% only one entry between start and end is invalid, replace it by the average value of adjacent measurements
												mess_(idx) = round(mean([mess_(idx-1),mess_(idx+1)]));
												weight_(idx) = 0.5;
											end
										else
											% more than one measurement is invalid, make sure, they're not adjacent to each other
											if any(diff(idx)==1)
												mbox_h			= my_msgbox(['There are consecutively OVERFLW values in the time-series. ' ...
													'Please restart ChronAlyzer and, this time, mark these as gaps or edit the file.'],12);
												mbox_h.Color	= [1 .2 .2];
												uiwait(mbox_h);
												error('There are consecutively OVERFLW entries in the data files which can''t be corrected automatically!');
											else
												% all invalid entries can be replaced by the average of adjacent measurements
												% except for the first and last measurement (if invalid at all)
												for i = 1:numel(idx)
													if idx(i) == 1 % first measurement
														mess_(1)	= mess_(2);
														weight_(1)	= 0.5; % reduce weighting factor for this artificial value
													elseif idx(i) == numel(mess_) % last measurement
														mess_(end)	= mess_(end-1);
														weight_(1)	= 0.5; % reduce weighting factor for this artificial value
													else % all entries in-between
														mess_(idx(i)) = round(mean([mess_(idx(i)-1),mess_(idx(i)+1)]));
														weight_(idx(i)) = 0.5;
													end
												end
											end
										end
										
									otherwise
										% no other option left
								end

							else
								% there was another error ...
								rethrow(ME)
							end
							
						end % try catch
					
						% Note: The developement for ChronAlyzer was for Mithras device only at the beginning.
						% It would have been better to use the BioTek layout from the beginning (always 96 wells in file in contrast to Mithras). 
						
						% Note: "mess_" (and later "mess" should have the size of the full plate, e.g. 96 wells
						% -> Check size of measurement matrix and insert columns if missing
						
						if size(mess_,2) < 96 % to few columns (=well)
							
							% ToDo: add support for non 96-well plates
							
							if size(well_names) ~= size(mess_,2)
								mbox_h = my_msgbox('Error: Inconsistent data source - imported well names do not fit to imported measurement columns',12);
								mbox_h.Color = [1 .2 .2]; % red
								uiwait(mbox_h);
								error('Inconsistent data source (error code "1060")')
							end
							
							% ToDo: add support for non 96-well plates
							meas_96		= NaN(size(mess_,1),96);
							weight_96	= zeros(size(meas_96));
							name_		= {};
							
							for plate_column = 1:8 
								for plate_row = 1:12
									
									expected_str = [char(64+plate_column) '0?' num2str(plate_row) '$']; % this "0?" is for the regexpression, can find "A1" as well as "A01"
									name_{(plate_column-1)*12+plate_row} = [char(64+plate_column) rightstr(['0' num2str(plate_row)],2)]; % this is for the replacement of the names only, see below
									idx = cellstrfind(well_names, expected_str);
									
									if ~isempty(idx)
										meas_96(:,(plate_column-1)*12+plate_row)	= mess_(:,idx);
										weight_96(:,(plate_column-1)*12+plate_row)	= weight_(:,idx);
									end
									
								end
							end
							
							well_names	= name_; % replace variable with a complete set of expected names
							mess_	= meas_96;
							weight_ = weight_96;
							
							clear meas_96, name_, weight_96
							
						end
						
						% "reshape" temporary mess_ vector into shape of all previous time-series:
						% Also: new data (file_idx > 1) will be resized according to previous data

						% Needed action here:
						% if new file is longer: Enlarge "mess", fill in "gaps" (i.e. NaN) in "mess" (and in "weight")
						% if new file is shorter: Enlarge "mess_" to size of "mess", fill in "gaps" in "mess_" and "weight_"
						
						if file_idx > 1
							
							if ~(isempty(setdiff(t,t_)) && isempty(setdiff(t_,t)))
								
								% the new time vector "t_" is somehow different to the previous one ("t")
								
								% just checking
								if size(mess_,1) ~= numel(t_)
									uiwait(msgbox('the length of the time vector and the number of measurements are not equal'))
									error('Sorry, this should habe not happened (Error code 1169)')
								end
								
								[t, mess, weight, t_, mess_, weight_] = adapt_timeline(t, mess, weight, t_, mess_, weight_);
								
								%another check
								if t ~= t_
									uiwait(msgbox('the subfunction to modify the new time vector according to the previous one (or vice versa) did not work!'))
									error('Sorry, this should habe not happened (Error code 1177)')
								end
															
							end
						
						end
						
					end
					
				end % loop on all data within a single file
				
				clear daten_idx

				% ===============================================================================================================
				%
				%    Now, add "mess_" into the 3-d "mess" (also "weight")
				%
				% ===============================================================================================================
				
				if anz_reads == 1 % only one time-series within the current file
					
					%mess_ = mess_'; % ToDo: check, if this is needed
					
					if file_idx == 1
						
						% at first loop run: initialize the 3d-variables
						mess	= NaN(size(mess_,1),size(mess_,2),file_anz);
						weight	= NaN(size(mess_,1),size(mess_,2),file_anz);
						
					end
											
					if size(mess_,2) == 96 % well information has to be in this order: A1, A2, A3, ... A12, B1, B2, ...
						
						mess(:,  :,file_idx)	= wellname_pos(mess_,   well_names); % this call orders the columns if needed
						weight(:,:,file_idx)	= wellname_pos(weight_, well_names); 
						
					else
						error('Sorry, plate size not yet supported (error code: "1225") - please contact author')
					end

					clear mess_;
				
				else % anz_reads > 1 -> true only if there are multiple data sets within one file (only ever noticed with Mithras (I think))
					
					% =============================================================================================
					%
					% Note: Beware! This ELSE-branch is old. It must be checked and probably re-worked, too!
					%
					% =============================================================================================
					
					mbox_h = my_msgbox(['There are more than one time-series in this file. Please consider to seperate these into several files.' ...
						'This option was thought to conduct some on-the-fly calculations for exactly two time-series within one (and only one) file. ' ... 
						'Please beware: This is an "antique" part of the code.'],12);
					uwait(mbox_h);
					
					a = ['1. Datensatz = ' read_titel{1} ' - ' read_titel{2}];
					b = ['2. Datensatz = ' read_titel{2} ' - ' read_titel{1}];
					
					% ToDo: Documentation is needed for this question - I can't remember since we don't use the Mithras device
					% anymore (since several years)
					% It was used for different wave-length detections, I suppose
					answer = questdlg('Which set of data do you want to modify?','Modification',a, b, a);
					
					switch answer
						case a
							mess_{1} = mess_{1} - mess_{2};
						case b
							mess_{2} = mess_{2} - mess_{1};
					end
					
					mess(:,:,1) = mess_{1}';
					mess(:,:,2) = mess_{2}';
					
				end % if anz_read
				
			otherwise  % -------------------------------------------------------------------
				
				warning(['unknown file type: "' fname{file_idx} '"']);
				continue
				
		end % switch (file) extension
		
		% checking data
		if numel(t) < 5 % and this
			uiwait(msgbox('The imported files do not contain time series or at least too few measurements!','','modal'))
			error('The imported files do not contain time series?!');
		end

		
		% ToDo (important): change "weight" to 3-D also, according to "mess"

				
%% ====== Import Layout (only once, when importing the first file) -- (still inside loop)
		
		if file_idx == 1
			
			OK = false;
			
			while ~OK
				
				mbox_h = my_msgbox(['Next: Please select a) a data file with the used wells layout (if not available press cancel), ' ...
					'b) then select the Excel cells containing the labels of each well AND the row and column with labels (A-H, 1-12)'],12);				
				
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
					
					layouttxt = cellfun(@num2str,layoutraw,'UniformOutput',false); % converts all into text, even NaN
					
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
						
						clear wi
						
						if ~isempty(delete_rowidx)
							layoutraw(delete_rowidx,:)=[];
						end
						
						if ((size(layoutraw,1)-1) * (size(layoutraw,2)-1)) < numel(well_names)
							warning(['Layout data not complete? For each well on the plate should exist a corresponding Excel cell entry ' ...
								'AND additionally the labels of the rows and columns (e.g. "A-H" and "1-12")!'])
						end
						
						OK = true;
						clear delete_rowidx
					end
					
					layouttxt = cellfun(@num2str,layoutraw,'UniformOutput',false); % converts everything into text, even NaN
					layouttxt = layouttxt(2:end,2:end); % cut labels (A-H, 1-12)
					
				end
				
			end % repeat file selection until data are good (or arbitrary)
			
			rname_group_layout = setxor(unique(layouttxt),'NaN');
% anz_gruppen_layout	= numel(rname_group_layout);
			
		end
		
	end % loop ends after all selected files are imported


%% some clean-up after all data are imported (loop end)

	clear t_  t_old_out  t_out
	clear annotations  answer  anz_reads
	clear data_ends  data_starts  dummy, 
	clear enum  gruss_text_h  layoutraw
	clear raw  txt
	clear weight_ mess_

	% this is a quick & dirty fix:
	if device_mithras % ToDo (check): Is this needed anymore? there is a function above that, perhaps, fixes this also ...?
		num_sorted		= true; % Mithras data are order by numbers (A1, B1, ..., H1, A2, ...)
	else
		num_sorted		= false; % BioTek and Envision are order by letters (A1, A2, ..., A12, B1, B2, ...)
	end
	
	if strcmp(replicate_mode,'biol') && device_mithras
		
		well_names		= asort(unique(well_names));
		well_names		= reshape(well_names.anr,1,[]);
		anz				= numel(well_names);
	
	else
		anz				= numel(well_names);
	end

	% ToDo: Add support for other plate layouts as well
	if anz ~= 96
		uiwait(msgbox('Sorry, the current version can handle 96 well plates only!'))
		error('Sorry, the current version can handle 96 well plates only!')
	end
	
	well_names			= expand_well_name(well_names); % expands name, e.g. "A2" -> "A02"
	
	% check again
	if any(any(diff(reshape(cell2mat(cellfun(@size,well_names,'UniformOutput',false))',2,numel(well_names)),2,2)))
		uiwait(msgbox('Error: Imported well descriptions are not in the anticipated format (e.g. "B05")','','modal'));
		error('Imported well descriptions are not in the anticipated format (error code 1363)')
	end

	[~,filename,~] = fileparts(fname{1}); % take this file name as title for analysis
	
	% ===================================================================================
	% Outcome of this section (as stated at the beginning of the big loop):
	% "t":		contains a vector of measuring times (valid for all measurements!)
	% "mess":	this is a 3D-matrix; 1-dim well number (so length == 96); 2-dim: entries for all measurements (so length == length(t));
	%				3-dim: number of files loaded
	% "name":	cell matrix with strings, containing names of wells ("A01" ,...")
	% "weight":	3-D matrix, like "mess", containing the weighting factors for the objective function in optimization. Special: "0" for
	%				missing values
	% ===================================================================================
	
	
%% Show thumbnail ansd plate layout	

	% ===============================================
	
	show_Thumbnails;
	show_layout;
	% ToDo: Since plate layout is imported from xls file, there's no real need to display it. Perhaps just to enable the user to see if the
	% correct file was selected and loaded?
	
	% ===============================================

%% Viewing of biological replicates

	% General idea of work-flow: If biological replicates are loaded, these are not averaged immediately (in contrast to technical replicates)
	% Still, it might be interesting to see the difference between several plates

	if file_anz > 1 % only makes sense if there are indeed more than one plate involved

		stdabw	= std(mess,0,3,'omitnan'); % calculate standard deviation
		% Note: "omitnan" ignores single NaN entries - it can always happen that a well or a single measurement (time & well) failed

		% For the percentage calculation I set the minimum to 0.1 in order to prevent division by zero - and this is only for display of
		% course. The percentage value refers to the first selected plate.
		
		f				= figure;
		f.Position		= [50   50  970  800];
		if strcmp(replicate_mode, 'biol')
			f.Name		= 'Comparison of biological replicates: Average value and standard deviations (+/-)';
		else
			f.Name		= 'Comparison of biological replicates';
		end
		f.NumberTitle	= 'off';

		subplot_x	= 12; % for plate layout
		subplot_y	= 8; 
		k			= 0; % this is the actual image counter
		
		for i = 1:subplot_x
			for j = 1:subplot_y

				k = k + 1; % could have been calculated out of i and j also
				
				subplot(subplot_y, subplot_x, k)

				plot(t,mean(mess(:,k,:),3,'omitnan'),'k:',t,mean(mess(:,k,:),3,'omitnan')+stdabw(:,k),'k-', ...
					t,mean(mess(:,k,:),3,'omitnan')-stdabw(:,k),'k-'); % "mean" ist für biol.-Repl.-Fall !

				k_to_name = k; % Matrix was changed, since we used BioTek device
				title([well_names{k_to_name} ],'fontsize',8);
				
				if i == subplot_x % ToDo: If lowest row is not full, xlabel had to be moved to second-to-last row
					xlabel('t [h]')
				end
		 
				curax			= gca;
				curax.XLim(2)	= t(end);
				
				if any(stdabw(k,:)) > 0 && (max(mean(mess(k,:,:),3,'omitnan')+stdabw(k,:)) > min(mean(mess(k,:,:),3,'omitnan')-stdabw(k,:)))
					% if not, the wells are probably missing data
					curax.YLim(2)	= max(mean(mess(k,:,:),3,'omitnan')+stdabw(k,:));
					curax.YLim(1)	= min(mean(mess(k,:,:),3,'omitnan')-stdabw(k,:));
				end
				
				curax.FontSize	= 6;
				
			end
		end
		
		% re-scale all figure to the same dimension
		idx = findobj(f,'Type','axes');
		for i = 1:numel(idx)
			idx(i).YLim = [max(0,min([idx.YLim])) max([idx.YLim])];
		end

		figure(f);
        
        help_text = uicontrol('Style','text','fontsize',11, 'String', ['The average and standard deviation from all biological ' ...
			'replicates are shown here, NOT individual time series!'],'units','normalized','Position',[.05,.935,.5,.05]);
        
		hbestaetigt = uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, 'tooltip', ...
			'Only standard deviation and average is shown, NOT the individual time-series!', 'String', ...
			'I confirm to have noticed these, continue ...','units','normalized','Position',[.55,.95,.4,.04],'Callback',{@OK_Button_Cb});
		
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
		
		if OK 
			hbestaetigt.Visible = 'off';
		end
		
		OK	= false;
		
	end
	
	
%% Init of GUI 

	% Note: This table was much smaller and simplier in the beginning
	% and I made several wrong decisions during coding this from today's perspective.
	
	OK = false; % restore default value (even if last loop was left by a "break" commanc)

	mainfig_max		= min([1200 monitor(4)-50]); % 1280
	%mainfig_max	= 1025;
	mainfig_min		= 45;

	old_fig = findobj(0,'tag','Table');


	% create main gui figure
	if isempty(old_fig)

		tabelle_fig_h = figure;
		set(gcf,'dockcontrols','off','Resize','off','toolbar','none','menubar','none','tag','Table',...
		'Position',[45 mainfig_min 1200 mainfig_max], 'Color', [1 1 1], ...
		'numbertitle','off');
		set(gca,'visible','off','clipping','off','position',[0.0 0.0 1 1]);
		set(gcf,'WindowButtonDownFcn', @Mouse_Select_Down_Cb);
		set(gcf,'windowscrollWheelFcn',@MWheel);
		set(gcf,'CloseRequestFcn',@allclose_Cb);
		
		panel		= uipanel('position',[0 -1 0.985 1],'Tag','uipanel');	
		vscrollbar	= uicontrol('style','slider','units','normalized','position',[.985 0 .015 1],'value',1,'Tag','uiscroll','callback',@vscroll_Callback);
		
		xlim([0 1]);
		ylim([0 1]);

		panel.Position(4) = 2; % Panel is bigger than figure, move current "view" to top of panel (user can use scroll bar to scroll down)
		
		if ~isempty(replicate_mode) % biological replicate
			tabelle_fig_h.Name	= strjoin(fname,' + ');	% if there are multiple filenames, put them all together
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
	
	% Buttons for ordering of wells
	buttongroup_h0	= uibuttongroup('parent',panel,'Position',[.01 0.975 .08 .02], 'clipping','on');
	s0				= uicontrol('Style','Radio','String','1','units','normalized', 'tooltip','Sorting by number', ...
		'pos',[.55 0.15 .3 .4],'parent',buttongroup_h0,'HandleVisibility','off','Callback',{@Sort_1_Cb});

	s1				= uicontrol('Style','Radio','String','A','units','normalized', 'tooltip','Sortierung by letter', ...
		'pos',[.2 0.15 .3 .4],'parent',buttongroup_h0,'HandleVisibility','off','Callback',{@Sort_A_Cb}, 'value',1);

	sort_text_h		= uicontrol('parent', panel,'style','text','String','Order of Wells','units','normalized','pos',[0.015 .9875 .07 .0065]);		
	
	% Buttons for normalization of results
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
	
	pos		= 968 + round((mainfig_max-mainfig_min) - 15.7*((1:anz+1)+2)); % vertical pixel positions for (later) results in row

	if strcmp(replicate_mode, 'biol')
			
		anz_rep = sum(sum(~isnan(mess(:,:,:)),1)>1,3); % How many time-series exist for every single well? (it counts if at least one measurement exists)
			
	else
		
		anz_rep = []; % if only one plate was used, this would equal to one, but in this case don't use that information anyway
		
	end
	
	for i = 1:anz
        
		% Note (for debugging): The mouse event as well as the "QuickView-Cb" (and maybe more in the meantime)
		% need a variable which is only assigned a value to, after calling "Sort_A_Cb()". Keep this in mind if you a step-wise debugging
		% here! New Note: This information might be outdated, since "Sort_A_Cb()" seems not to be called in general.
        
		% create the well labels ...
		if strcmp(replicate_mode, 'biol')
			
            t_h(i)	= uicontrol('parent',panel,'Style','pushbutton','units','pixel', 'position',[32 pos(i)-8 50 15],'String',[well_names{i} ' (x' num2str(anz_rep(i)) ')'], ...
                'Callback',{@QuickView_Cb,i});
		else
			
            t_h(i)	= uicontrol('parent',panel,'Style','pushbutton','units','pixel', 'tooltip', 'click to display raw data', 'position',[32 pos(i)-8 50 15],'String',well_names{i}, ...
                'Callback',{@QuickView_Cb,i});
		end
		
		% ... and the check boxes ...
		check_h(i)	= uicontrol('parent',panel,'Style','checkbox','value',0,'units','pixel', 'tooltip','select well for analysis', ...
			'position',[0 pos(i)-8 15 15],'Tag',well_names{i},'Callback',{@Sample_Button_Cb}); % set UserData some more lines below
		
		% ... and now the annotation with the replicate group name. But first grab that string:
		% The replicate group names was imported by the user, its content is stored in a matrix in "layouttext", so calculate the position
		% of the name depending on the well name:
		[col_, row_]	= calc_pos(well_names{i});
		str_			= layouttxt{col_,row_}; 

		% Now create the annoation text
		% Note: in older version the replicate group was not fixed, so a dropdown menu was used here. That's why the variable is called
		% "drop..."
		
		value = cellstrfind(rname_group_layout, str_,'exact'); % numbering or replicate groups, that's easier to store
		
 		drop_h(i)	= uicontrol('parent',panel,'Style','text','String',str_, 'tooltip','right click on replicate group name to select all wells belonging to this group', ...
 					'units','pixel','Position',[90 pos(i)-7 100 12],'Tag',['check' num2str(i)],'Callback',{@Select_dropbox_Cb},'fontsize',6, 'value',value);
		set(check_h(i),'UserData',str_); % with this information the callback function can easily know what replicate group this checkbox belongs to.			
				
	end
	
	uica_h	= uicontrol('parent',panel,'Style','checkbox','value',0,'units','pixel', 'tooltip','all on/off', 'BackgroundColor', [1 0 0], ...
			'position',[0 pos(1)-8+18 15 15],'Tag',['check' num2str(i)],'Callback',{@On_Off_Cb}); % this is the check-all-or-none checkbox
		
	if device_mithras % ToDo: Is this really needed anymore?
		Sort_A_Cb();
	else
		%Sort_1_Cb(); -- nothing to do, already sorted that way
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
	
	hEnde		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[1 .2 .2],'fontsize',12, 'tooltip','Quits program after analysis',  ...
		'String','End','units','normalized','Position',[.9,.965,.1,.04],'Callback',{@Ende_Button_Cb},'Enable','off');

	hSaveTab		= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.2 .2 1],'fontsize',12, 'tooltip','Save result table in *.xls file',  ...
		'String','Save Tab','units','normalized','Position',[.7,.965,.1,.04],'Callback',{@SaveTab_Button_Cb},'Enable','off');

	hSaveFigs	= uicontrol('parent',panel,'Style','pushbutton','backgroundcolor',[.3 .3 0.8],'fontsize',11, 'tooltip','Save all graphic figures and result table',  ...
		'String','Save Figs','units','normalized','Position',[.6,.965,.1,.04],'Callback',{@SaveFigs_Button_Cb},'Enable','off');

	% these are not needed right away
	hHilfe.Visible = 'off';
	hLoadR.Visible = 'off';
	hSaveR.Visible = 'off';
	
	messdaten_fuer_Neustart = mess; % store measurement, because of user actions (outliers/noisy peaks) the original imported measurements might be modified.
	% If the user chooses to re-start (re-run) the analysis, the original data should be available once more. Note: Beware! Actually these
	% are NOT the original data, because the user already had to decide what has to be done with missing/invalid entries (mark as gap or
	% calculate average).
	

%% Initialization of all GUI elements
	
	while ~Ende % Loop until user break
		
		% Note: At the beginning the user should have the option to re-run the analysis with the same measurements but with modified
		% options. This was asked to be very fast, so I tried to minimize the amount of needed re-initialisation, but actually I failed: 
		% At least it appears that I forgot some variables ... Debugging was not easy at that time, since other program features needed
		% their completion and then it became clear that this feature wasn't a use case at all. So I spent not much time on the debugging.
		% Note 2: As a side-effect the Re-Start was enabled again. The program runs, though, a robust test was not conducted.

		hEnde.Enable		= 'off';
		hNeustart.Enable	= 'off';
		hNeustart.Visible	= 'off';
		hSaveTab.Visible	= 'off';
		hSaveFigs.Visible	= 'off';
		hSaveFigs.Enable	= 'off';

		if Restart

			OK				= false;
			hStart.Enable	= 'on';
			hStop.Enable	= 'on';
			hStart.Visible	= 'on';
			hStop.Visible	= 'on';
			s0.Enable		= 'on';
			s1.Enable		= 'on';
			hOptions.Visible= 'on';
			mess			= messdaten_fuer_Neustart;
		
			Amp				= NaN(anz,1);
			Dam				= NaN(anz,1);
			Per				= NaN(anz,1);
			Pha				= NaN(anz,1);
			Basis_Amp		= NaN(anz,1);
			Basis_Dam		= NaN(anz,1);
			Basis_Off		= NaN(anz,1);
			Fehler			= NaN(anz,1);
			checkbox_platte = [];

			d_idx = findobj(tabelle_fig_h,'tag','table_entry');
			delete(d_idx);

			Restart = false;

		end
		
		if debug
			% in debugging mode switch on figure controls
			set(gcf,'dockcontrols','on','Resize','on','toolbar','auto','menubar','figure')
		end

		
%% Wait-Loop until User pressed the Start-button

		% this loop is for selecting the well for analysis, but also other functions like QuickView can be used

		while ~(OK || Stop) % wait for either event (Note: pressing the buttons sets the global variables OK or Stop)
			try
				if sum(cell2mat(get(check_h,'value'))) == 0
					% as long as no well is checked the START button is disabled
					hStart.Enable = 'off';
				end
			catch
				% an error might occur if the main figure was closed in the meantime.
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
					

%% GUI clean-up, grab user choices (options) and freeze window

		% After pressing START disable button or even let them disappear for the time being
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

		% Read-out of checkboxes. Note, because order of checkboxes can be changed get the checkbox _handles_ !
		% Note: unchecked -> value = 0 -> "find" command can't find those zeros
		checkbox_idx				= find(cell2mat(get(check_h,'value')));
		
		% get some options. 
		% ToDo: Move all these options to the options window
		ausreisser				= ausreisser_h.Value;
		debug					= debug_h.Value;
		
		% this is old code, maybe it is useful later again
		%e_funkt				= e_funkt_h.Value;
		%Options.e_funkt_flag	= e_funkt;
		%BaseLineOption			= 100 * MWglaett + 10 * Normiert + 1 * e_funkt; % Basislinie = 100, wenn MWglaett (=default), = 10 wenn Normiert, sonst 1 (e-func nicht mehr unterstützt

		BaseLineOption			= 100; % fixed to the only option that was developed further lately
		
		% ToDo: Currently "Options" and "general_options" are used, only one of these variables is really needed!
		Options.BaseLineOption	= BaseLineOption;
		Options.ausreisser_flag	= ausreisser;
		Options.time_weight		= time_weight;
		Options.log_diff		= log_diff;
        Options.NoSound         = NoSound;
		Options.debug			= debug;
		Options.const_PER		= const_PER;
        Options.const_value		= const_value;
		Options.weight_threshhold_time = general_options.weight_threshhold_time;
		

%% Defining of replicate groups
		
		% Definition: Replicate groups of wells on a single plate which were used in the same way (i.e. the same experiment was conducted in
		% them). The terms is actually an abbreviation and should read "technical replicate group". The time-series are averaged BEFORE
		% analysis.
		% The original idea for this feature was a little bit different, which might explain some weired code lines (which I honestly tried
		% to remove without breaking the program :-) )

		for i = 1:anz   % loop through all wells
	
			% disable all checkboxes for well that are not selected
			set(drop_h(i),'Enable','off');
			if ~ismember(i,checkbox_idx)
				check_h(i).Enable   = 'off';
				t_h(i).Enable       = 'off';
				continue % nothing else to do with wells that were not selected
			end

			% Zuordnung: Zu welcher Replikatgruppe gehört aktuelle Checkbox?
			% 1    = leer
			% 2    = Kontrollgruppe
			% 3    = Medium
			% 4-27 = Replikatgruppen
			% die bedeutung der gruppennamen und position entfiel mit
			% version 0.8

			checkbox_replgr(i)	= get(drop_h(i),'value'); % grab number of replicate group
			
			% get title for this well (calculate plate position from number and extract string from layout name matrix (loaded via file) )
			[col_, row_]	= calc_pos(well_names{i});
			str_			= layouttxt{col_,row_};
			titel_str{i}	= [well_names{i} ' - ' str_]; % this variable is used much later only once - ToDo: is it really needed?

			% Look for special names in replicate group names: "control" or "medium" can be used for normalization of the results later.
			if isnan(kontroll_idx) && contains(lower(str_),'ontrol','IgnoreCase',true)
				% looking for "ontrol" because this is the same in English (control) and in German (Kontrolle)
				kontroll_idx = i; % only one index is needed to "mark" the replicate group
			end
			if isnan(medium_idx) && contains(lower(str_),'medium','IgnoreCase',true)
				medium_idx = i;
			end

		end
		
		
%% Supervision of replicate groups by user & (possible) de-selection of single wells in replicate groups (because they "just don't fit to the rest of the group"

		% This section presents every replicate group with its members (=individual time-series) and their average. Additionally, the
		% summed up, squared error to this average is shown. The user can see easily which time-series does (or do) not fit the the
		% remaining ones and can de-select them  before the analysis starts, just by clicking on the line in the figure. The well can
		% be re-selected on the main gui. With every change the average has to re-calculated, of course.

		dummy = my_msgbox(['Please, check each time series for outlier time-series first. After that, the average of each ' ...
			'individual replicate group will be calculated and used instead of the original values'],12);
		
		timed = timer('ExecutionMode','singleShot','StartDelay',5,'TimerFcn',@(~,~)myclose(dummy));
			% Schließt Fenster nach einer bestimmten Zeit automatisch
			
		start(timed);

		% I have to and will re-code the following loop completely, because it is doing too much at once. Due to the historic evolution of
		% this section its complexity became maximized. :-(
		
		for file_idx = 1:file_anz

			for replgr_id = unique(checkbox_replgr) % loop through all replicate groups

				if isnan(replgr_id)
					continue
				end
				
				% Note: Program has changed its logic: Each replicate group must only contain sz least one element (=well) now

				anz_in_replgr = sum(checkbox_replgr == replgr_id); % number of elements in the current group

				if anz_in_replgr < 2
					% this replicate "group" does contain only one well, so jump this break
					checkbox_platte{file_idx, replgr_id} = find(replgr_id == checkbox_replgr);
					continue
				end
				
				% Calculating for the whole replicate group
				if strcmp(replicate_mode,'biol')
					
					checkbox_idx_in_replgr{replgr_id}		= find(checkbox_replgr == replgr_id); % Group wells in the same replicate group
					checkbox_platte{file_idx, replgr_id}	= checkbox_idx_in_replgr{replgr_id}; % Store this for all plates
					
					for j = checkbox_platte{file_idx, replgr_id}(end:-1:1)
						
						if isnan(mess(1,j,file_idx)) % first (1) measurement data exists in well "j"
							checkbox_platte{file_idx, replgr_id}(find(j == checkbox_platte{file_idx, replgr_id})) = []; % Delete this well - ToDo: Why?
						end
					end
					
					if isempty(checkbox_platte{file_idx, replgr_id}) % not a single time-series left, not average calculation possible
						mittelwerte(replgr_id,:)	= NaN;
					else
						anz_in_replgr_auf_Platte	= numel(checkbox_platte{file_idx, replgr_id});
						mittelwerte_				= sum(mess(:,checkbox_platte{file_idx, replgr_id} ,file_idx),3,'omitnan') / anz_in_replgr_auf_Platte; % "omitnan" important!
						mittelwerte(replgr_id,:)	= sum(mittelwerte_,2);
					end
					
				else % only a single plate was selected (note: probably still several wells in this group)
					
					checkbox_idx_in_replgr{replgr_id}		= find(checkbox_replgr == replgr_id); % Group wells in the same replicate group
					checkbox_platte{file_idx, replgr_id}	= checkbox_idx_in_replgr{replgr_id}; % Store this for all plates

					mittelwerte(replgr_id,:)				= sum(mess(:,checkbox_idx_in_replgr{replgr_id}) ,2) / anz_in_replgr;	

				end

				replf_h				= figure;
				replf_h.DeleteFcn	= '@my_closereq;';
				replf_h.NumberTitle	= 'off';		
				replf_h.Name		= ['Replicate group: "' rname_group_layout{replgr_id} '" - ' num2str(file_idx) '. plate ("' fname{file_idx} '")'];
				replf_h.Position	= [50 70 950 900];
				set(gcf,'Tag','TechnRg');

				hbestaetigt		= uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, 'tooltip','Show next replicate group', ...
				'String','Next group','units','normalized','Position',[.43,.95,.25,.04],'Callback',{@OK_Button_Cb});

				hhelp1			= uicontrol('Style','text','String',['Click on a curve to de-select well' newline '(re-select well on main window list)'],'units','normalized','Position',[.165,.95,.2,.04]);
				OK				= false;
				OK_Close		= false;
				sub1_h			= subplot(2,1,1);
				
				if ~isempty(mittelwerte(replgr_id,:))
					% plot average
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

				% summed up, squared error
				sub2_h					= subplot(2,1,2);
				if ~isempty(mittelwerte(replgr_id,:))				
					error_plot_h		= plot(t,zeros(size(mittelwerte(replgr_id,:))));
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
						
						plot_MW_h.YData			= mittelwerte(replgr_id,:); % update data
						err						= [];
						multiplot_Samples_h		= [];
						checkbox_temp			= checkbox_idx_in_replgr{replgr_id};
								
						for ii = checkbox_temp
							err						= [err; (mess(:,ii, file_idx) - mittelwerte(replgr_id,:)).^2 ];
							multiplot_Samples_h(ii) = plot(mw_axis, t,mess(:,ii, file_idx));
							hold on
							set(multiplot_Samples_h(ii),'ButtonDownFcn',{@Mouse_Select_CB});
						end
						
						% update legend
						legend(mw_axis,['Averaged' well_names(checkbox_temp)]);
						
						if mean(err) == 0 % this can be the case if there's only one well
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
						
						% Now, all is set. Next: wait in this loop for changes by the user and exit the loop when the user has finished (by
						% clicking on "NEXT GROUP" button)
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
										mittelwerte(replgr_id,:) = sum(mess(:,checkbox_temp(plot_on), file_idx),2) / numel(checkbox_temp(plot_on));
									else
										mittelwerte(replgr_id,:) = NaN(size(t));
									end
									
									set(plot_MW_h,'ydata',mittelwerte(replgr_id,:));
									
									if sum(plot_on) > 1
										
										err = [];
										
										for ii = checkbox_temp(plot_on)
											err = [err; (mess(:,ii, file_idx) - mittelwerte(replgr_id,:)).^2 ];
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
								error('Please do not de-select all wells! (error code 2205)')
							end
							selected_checkbox_in_replgr						= tmp(1);
							mess(:,selected_checkbox_in_replgr, file_idx)	= mittelwerte(replgr_id,:);
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
		
		% ----------------------------------------------------------------------------------------------------		

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
						figure_savename = [strrep(figure_savename,'"','_') '_' datum_str];
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
	
		% ===============================================
		%
		% Now, all wells/time-series are selected for the analysis
		%
		% ===============================================

		
%% Last preparations before calling the actual analyis sub routines
        
		% Ddelete all table entries (if they exist)
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
			dummy = msgbox(['For each imported plate there will be an invidual fitting for each well (or replicate group if defined). Results will be merged at the end.']);
			timed = timer('ExecutionMode','singleShot','StartDelay',15,'TimerFcn',@(~,~)myclose(dummy));
			start(timed);
			pause(3)
		end
		
	
		% Here comes another approach to program auto-time-out windows:
		% The idea is from several Mathworks community and
		% file exchange entries: First, make a list of all open figures,
		% then start a timer object. Open dialog as usually (this opens another figure, but one that
		% we can't get the figure handle for). At the end of the timer, compare
		% current list of figures with the stored list of figure. The
		% difference must be the dialog window. Close that. Finally, deal with empty
		% returns and so on. Advantage of this method: The dialog function (here: questdlg) does not have to be changed in anyway
		
		f_all	= findall(0,'Type','figure');
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

		% Note: Unnecessary windows should be closed, in particular if debug mode is used, because the program can easily open many dozens
		% of windows, which will slow down the system!
		

disp('Re-work done up to this code line')
keyboard	

%% Start of loop for actual analysis

					% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    % +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


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
					
					[col_, row_] = calc_pos(well_names{i});
					akt_gruppe_str = layouttxt{col_,row_};
					
					sample_name = ['Well: ' well_names{i} ' - group: "' akt_gruppe_str '"'];
					
					disp([CR 'Adaption for: ' char(171) sample_name char(187) ' - biological replicate No.: ' num2str(file_idx)])
					
					
					% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    % +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
					% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    
					if strcmp(replicate_mode,'biol')
						
						%vorhanden = reshape(find(~isnan(mess(i,1,:))),1,[],1); % In diesen Dateien sind Daten zu dem aktuell Well ("i")
						
						if exist('mittelwerte','var') && size(mittelwerte,1) >= checkbox_replgr(i)
							% [fit_param_, Abbruch, Options] = findChronoParameter(t,mess(i,:,file_idx), ...
							% 	[sample_name ' - Replikat ' num2str(file_idx)], mittelwerte(checkbox_replgr(i),:), Options);
							
							[fit_param_, Abbruch, Options] = findChronoParameter(t,mess(:,i,file_idx), ...
								[sample_name ' - plate (replicate) No.: ' num2str(file_idx)], mess(:,checkbox_platte{file_idx, replgr_id},file_idx), Options);
							
							
						else
							
							[fit_param_, Abbruch, Options] = findChronoParameter(t,mess(:,i,file_idx), ...
								[sample_name ' - plate (replicate) No: ' num2str(file_idx)], NaN, Options);

						end
						
						Options.results{i}	= fit_param_;
						fit_param_.Pha		= fit_param_.Pha * 60; % Umrechnung von [h] in [min]
						
						%fit_param{file_idx} = fit_param_;
						fit_param = fit_param_;
						
					else
						
						[fit_param, Abbruch, Options] = findChronoParameter(t,mess(:,i), sample_name, ...
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
					if BaseLineOption == 1 % 1 = e_funktion
						
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

					if device_BioTek || device_envision % quick but dirty ...
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

		samples	= well_names(~isnan(Amp(:,1))); %name(1:numel(Amp))';
		
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

		while ~(Ende || Restart)
			
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
	
	result = Options.results; % Does subfunctions work as intended?
	
	
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
			
			switch BaseLineOption
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
					if get(findall(0,'Tag',well_names{wells(jj)}),'value') == 0
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
						[col_, row_]		= calc_pos(well_names{used_wells(jj)});
						header_wellname{kk}	= layouttxt{col_,row_};
					end
					wellname{kk} = [wellname{kk} well_names(used_wells(jj))];
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

		Restart						= true;
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
		
% 		if strcmp(answer,'Yes')
% 			update_Annotations();
% 		end
		
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
		
			[sorted, s_idx] = sort(well_names); 
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
			
			if device_BioTek || device_envision
				s_idx = asort(well_names);
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
		[col_, row_] = calc_pos(well_names{image});
		str_ = layouttxt{col_,row_};
		
        quick_figure_str	= ['QuickView: ' well_names{image} ' (' str_ ')'];
		
		
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
			
            plot(t,mess(:,image_,1));

            if strcmp(replicate_mode,'biol')
                hold on
                for g = 2:size(mess(:,image_,:),3)
                    plot(t,mess(:,image_,g));
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

% 	function annotations = Annotation_input(titel, data, Tag)
% 		
% 		% currently obsolete code
% 		
% 		annotations = struct('Experimentname', '', 'Experimenter', username, 'Datum', Tag, 'Beschreibung', '', 'Wells', ...
% 			struct('WellID','','Text',''), 'Replikatgruppen', struct('Replikatgruppe',''));
% 		
% 		answers = '';
% 
% 		while isempty(answers) % ein Drücken von Cancel ist nicht erlaubt (sonst leeres Feld!)
% 			answers		= inputdlg({['Experimentname (Dateiname: ' titel ')' ],'durchgeführt von', 'am', ...
% 				['Kurzbeschreibung des Experiments' blanks(30) '.']},'Experiment-Daten', [1 1 1 5], {titel, username, Tag, ''});
% 		end
% 		
% 		annotations.Experimentname		= answers{1};
% 		annotations.Experimenter		= answers{2};
% 		annotations.Datum				= answers{3};
% 		annotations.Beschreibung		= answers{4};
% 		annotations.Wells.WellID		= data;
% 		answers							= [];
% 		anz								= numel(data);
% 		z								= 1;
% 		
% 		if well_annotation
% 			for i = 1:18:anz
% 				well_names					= data(i:min(numel(data),i+17));
% 				answers						= [answers; inputdlg(well_names, ['Bezeichnung/Inhalt der Wells - Seite ' num2str(z)], [1 nof_wells])];	
% 				z							= z + 1;
% 			end
% 		end
% 		
% 		annotations.Wells.Text			= answers;
% 
% 		answer = '';
% 
% 		while isempty(answer) % ein Drücken von Cancel ist nicht erlaubt (sonst leeres Feld!)
% 
% 			if nof_replgr < 18
% 				dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:nof_replgr)')';
% 				dummy2	= arrayfun(@(x){[num2str(x)]},(1:nof_replgr)')';
% 				options = struct('Resize','on');
% 				answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], dummy2, options);
% 				% war früher mal:
% 				% answer	= inputdlg({['Replikatgruppe 1' blanks(59) '.'],  'Replikatgruppe 2', 'Replikatgruppe 3', 'Replikatgruppe 4',  'Replikatgruppe 5',  'Replikatgruppe 6', ...
% 				% 				'Replikatgruppe 7',  'Replikatgruppe 8', 'Replikatgruppe 9', 'Replikatgruppe 10', 'Replikatgruppe 11', 'Replikatgruppe 12' ,  ...
% 				% 				'Replikatgruppe 13',  'Replikatgruppe 14', 'Replikatgruppe 15', 'Replikatgruppe 16', 'Replikatgruppe 17', 'Replikatgruppe 18' , ...
% 				% 				'Replikatgruppe 19',  'Replikatgruppe 20', 'Replikatgruppe 21', 'Replikatgruppe 22', 'Replikatgruppe 23', 'Replikatgruppe 24'}, ...
% 				% 				'Name der Replikatgruppen?', 1, {'1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21', ...
% 				% 				'22','23','24'});
% 				
% 			elseif nof_replgr < 35
% 				
% 				dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:18)')';
% 				dummy2	= arrayfun(@(x){[num2str(x)]},(1:18)')';
% 				options = struct('Resize','on');
% 				answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], dummy2, options);
% 				dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(19:nof_replgr)')';
% 				dummy2	= arrayfun(@(x){[num2str(x)]},(19:nof_replgr)')';
% 				answer	= [answer; inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], dummy2, options)];
% 				
% 			else
% 				uiwait(msgbox('Too many possible replicate groups! Window space is too small, please ask author for an update!','modal'))
% 			end
% 				
% 						
% 		end
% 
% 		annotations.Replikatgruppen		= answer;
% 			
% 	end
% 
% 	function annotation_f = update_Annotations()
% 				
% 		% currently obsolete code
% 		
% 		if ~isempty(annotations)
% 			
% 			if isfield(annotations{1},'Experimentname')
% 				titel	= annotations{1}.Experimentname;
% 			else
% 				titel = '';
% 			end
% 			
% 			if isfield(annotations{1}.Wells,'WellID')
% 				data	= annotations{1}.Wells.WellID;
% 			else
% 				error('This error should have not been possible, I am really sorry! Please contact author (code 3933)')
% 			end
% 			
% 			if isfield(annotations{1},'Datum')
% 				Tag		= annotations{1}.Datum;
% 			else
% 				error('This error should have not been possible, I am really sorry! Please contact author (code 3939)')
% 			end
% 			
% 		end
% 		
% 		
% 		annotation_f = struct('Experimentname', annotations{1}.Experimentname, 'Experimenter', annotations{1}.Experimenter, 'Datum', annotations{1}.Datum, ...
% 			'Beschreibung', annotations{1}.Beschreibung, 'Wells', struct('WellID', {annotations{1}.Wells.WellID}, 'Text', {annotations{1}.Wells.Text}), ...
% 			'Replikatgruppen', {annotations{1}.Replikatgruppen});
% 
% 		answers		= inputdlg({['Experimentname (Dateiname: ' annotation_f.Experimentname ')' ],'durchgeführt von', 'am', ...
% 			['Kurzbeschreibung des Experiments' blanks(30) '.']},'Experiment-Daten', [1 1 1 5], {annotation_f.Experimentname, annotation_f.Experimenter, ...
% 			annotation_f.Datum, annotation_f.Beschreibung});
% 		
% 		annotation_f.Experimentname		= answers{1};
% 		annotation_f.Experimenter			= answers{2};
% 		annotation_f.Datum				= answers{3};
% 		annotation_f.Beschreibung			= answers{4};
% 		annotation_f.Wells.WellID			= data;
% 		answers							= [];
% 		anz								= numel(data);
% 		z								= 1;
% 		
% 		for i = 1:18:anz
% 			well_names					= data(i:min(end,i+17));
% 			answers						= [answers; inputdlg(well_names, ['Bezeichnung/Inhalt der Wells - Seite ' num2str(z)], [1 nof_wells], annotations{1}.Wells.Text)];	
% 			z							= z + 1;
% 		end
% 
% 		annotation_f.Wells.Text			= answers;
% 			
% 		if nof_replgr < 18
% 			
% 			dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:nof_replgr)')';
% 			options = struct('Resize','on');
% 			answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], annotations{1}.Replikatgruppen, options);
% 			
% 		elseif nof_replgr < 35
% 				
% 			dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(1:18)')';
% 			options = struct('Resize','on');
% 			answer	= inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], annotations{1}.Replikatgruppen(1:18), options);
% 			
% 			dummy	= arrayfun(@(x){['Replikatgruppe ' num2str(x)]},(19:nof_replgr)')';
% 			answer	= [answer, inputdlg(dummy, 'Name der Replikatgruppen?',[ 1 50], annotations{1}.Replikatgruppen(19:nof_replgr), options)];
% 				
% 		else
% 			uiwait(msgbox('Too many possible replicate groups! Window space is too small, please ask author for an update!','modal'))
% 		end
% 				
% 
% 		% war früher mal:				
% 		% answer	= inputdlg({['Replikatgruppe 1' blanks(59) '.'],  'Replikatgruppe 2', 'Replikatgruppe 3', 'Replikatgruppe 4',  'Replikatgruppe 5',  'Replikatgruppe 6', ...
% 		% 					'Replikatgruppe 7',  'Replikatgruppe 8', 'Replikatgruppe 9', 'Replikatgruppe 10', 'Replikatgruppe 11', 'Replikatgruppe 12' ,  ...
% 		% 					'Replikatgruppe 13',  'Replikatgruppe 14', 'Replikatgruppe 15', 'Replikatgruppe 16', 'Replikatgruppe 17', 'Replikatgruppe 18' , ...
% 		% 					'Replikatgruppe 19',  'Replikatgruppe 20', 'Replikatgruppe 21', 'Replikatgruppe 22', 'Replikatgruppe 23', 'Replikatgruppe 24'}, ...
% 		% 					'Name der Replikatgruppen?', 1, annotations{1}.Replikatgruppen);						
% 						
% 		annotation_f.Replikatgruppen = answer;
% 		
% 		annotations{1} = annotation_f;
% 		
% 		disp('Note: From now on you leave the area of tested software')
% 		
% 		save_Annotations(titel, pfad, annotation_f)
% 		
% 		close(findobj(0,'Tag',['Well-GUI:' titel])); % schließe altes Fenster
% 			
%  		% Updaten: Replikatgruppen-Namen
% 		for i = 1:numel(drop_h)
% 			temp = get(drop_h(i),'String');
% 			set(drop_h(i),'String',[temp(1:3); annotations{1}.Replikatgruppen])
% 		end
% 
% 		%show_Annotation;
% 
% 	end
% 
% 	function result = save_Annotations(titel, pfad, annotation_)
% 		
% 		filename = [titel '_annotation.mat'];
% 		save([pfad filename], '-struct', 'annotation_');
% 		
% 		result = true;
% 		
% 	end
% 

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
% 				else % wenn BioTek-Daten, dann ...
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
% 				end % BioTek oder nicht
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
				f.Name				= ['"' filename '" (identical scaled)'];
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
							
							if isempty(cellstrfind(well_names, [char(65+i),repmat('0',2-numel(num2str(j+1)),1), num2str(j+1)],'exakt'))

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
								dummy = plot(t,mess(:,image_idx,file_idx));
							else
								dummy = plot(t,mess(:,image_idx,1));
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
					
				else % wenn BioTek- oder Envision-Daten, dann ...
					
					for i = 0:7
						for j = 0:11

							%image	= 1+j+i*8;

							sp = subplot(8,12,j+i*12+1);
							
							if isempty(cellstrfind(well_names, [char(65+i),repmat('0',2-numel(num2str(j+1)),1), num2str(j+1)],'exakt'))

								% Es sind nicht immer alle Wells belegt, die leeren einfach überspringen
								sp.XAxis.Visible	= 'off';
								sp.YAxis.Visible	= 'off';							
								% sp.Position			= sp.Position+[-.01 -.02 +.01 +0.02];
								sp.Position([1 2])  = [j*0.0659+0.12, (7-i)*0.1055+0.0915];
								sp.Position([3 4])	= [6.01e-02 , 9.60e-02];
								sp.Color			= [0.97 0.97 0.97];

								continue

							end
							
							image_idx = image_idx + 1;
							hold on

							if strcmp(replicate_mode,'biol')

								hold on

								% for g = 2:size(mess(image,:,:),3)
								% 	plot(t,mess(image,:,g));
								% end
								dummy = plot(t,mess(:,image_idx,file_idx));
							else
								dummy = plot(t,mess(:,image_idx,1));
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
					
				end % BioTek oder nicht
				
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
				if isempty(cellstrfind(well_names, [char(64+9-j) num2str(i,'%02d')]))
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
		% Compare version numbers: Up to which one has the user already seen them (stored in user config)
	
		v_user		= textscan(version_user,'%c%s%s%s','Delimiter','.');
		v_programm	= textscan(version_str,'%c%s%s%s','Delimiter','.');
		% cell(1) = "v", ... version_str = "v1.2.3"
		
		if str2num(v_user{2}{1}) < str2num(v_programm{2}{1}) || str2num(v_user{3}{1}) < str2num(v_programm{3}{1}) || ...
				(~isempty(v_user{4}) && str2num(v_user{4}{1}) < str2num(v_programm{4}{1}))
			result = true;
		else
			result = false; % --> user already knows the most recent version
		end
	
	end

	function allclose_Cb(event, data)
		% if this function is invoked, all figures without a closereqfcn (i.e. those can't be closed by normal meaning) are looked for,
		% and their closereqfnc is set again (so they're becoming closeable again).
		% The invoking figure is closed at the same time.
		% This is solely used for the main GUI: If this window is closed the program aborts, and the user should be able to close all other figures
		
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
		% Note: This function is almost obsolete (after re-work of work-flow), but it calls "wellname2tablerow" (see there)
		
		big_meas = NaN(size(mess_,1),96); % ToDo: add support for different plate sizes
		
		for i = 1:size(mess_,2)
			
			position				= wellname2tablerow(name{i});
			big_meas(:,position)	= mess_(:,i);
			
		end
			
	end
		
	function result = wellname2tablerow(name_str)
		% Note: Columns in data files are ordered depending on the device ("Mithras" was different, for example)
		% This function ensures the following order:
		% (the ChronAlyzer requires/expects this column layout)
		% A01, A02, A03, ... A11, A12, B01, B02, ... H11, H12
		
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
		% returns (at most) <length> characters from the left end of "string_"
		str = '';
		if ischar(string_)
			str = string_(1:min([length, numel(string_)]));
		end
		
	end	

  	function str = rightstr(string_,length)
		% returns (at most) <length> characters from the right end of "string_"
		str = '';
		if ischar(string_)
			str = string_(max([1,end-(length-1)]):end); 
		end
		
	end	



	function closeit(src,event,f_all)
		% function for auto-closing dialog windows, see for explanation in
		% calling code lines above
			f_all_new = findall(0,'Type','figure');
			f_diff = setdiff(f_all_new,f_all);
			if ishandle(f_diff)
				close(f_diff);
			end
	end

	function d_t = get_delta_t(t)

		% perhaps "t" is already equidistant?
		t_diff = unique(diff(t));
		
		if numel(t_diff) == 1
			% yes, so that's easy now
			d_t = t_diff;
		else
			% okay, not so easy, hopefully the times in the data files are written too precisely, so let's start with some rounding first
			t_diff = unique(diff(zeitrunden(t)));  % rounding to approx. 2 minutes. 
		end

		if numel(t_diff) == 1 % is it now ok?
			% yes!
			d_t = t_diff;
		else
			% now, it's getting complicated: This can happen, if some maybe even adjacent measurements were missing. Or the whole experiment
			% was measured manually. This would be nasty, because the whole concept in the algorithm would not work, then.
			% So let's assume there are just some measurements missing and let's find the most common time distance between measurement:
			d_t = median(diff(zeitrunden(t)));
			% ToDo: Maybe add some user interaction to make sure this is the correct approach here?
		end


	end

	function [t_out, t_old_out] = fit_t2vector(t_in, d_t)
					
	% This function creates a equidistant time vector, that means, that all time value are equally distant between t(1) and t(end)
	% e.g. "0.0, 0.5, 1.0, 1.5, 2.0, ..." - Thus missing measurements during the experimentare are taken care of.
	
		t_out		= 0:d_t:t_in(end);
		if all(ismember(t_out, t_in)) && all(ismember(t_in, t_out))
			t_out = [];
		end
		t_old_out	= t_in;
	
	end

	function [mess_out,t_out] = fit_meas2vector(mess_in, t_new_in, t_old_in)
					
	% This function creates a new measurement matrix, corresponding to the equidistant time vector, thus creating new rows if needed
	% It expects that "t_old_in" is a sub-group of "t_new_in", i.e. every (!) element of t_old_in is member of t_new_in
	
		if isempty(setxor(t_new_in, t_old_in)) % this internally compares length and elements of those vectors at the same time
			
			mess_out = mess_in; % both are equal, so just return input
			
		else
			
			t_out		= unique([t_new_in t_old_in]); % create a unified time vector
			
			mess_out	= NaN(numel(t_out), size(mess_in,2),size(mess_in,3)); % create a measurement matrix with the new (time) size
			
			for j = 1:size(mess_in,3)
				for i = 1:numel(t_out)
					
					if ismember(t_out(i),t_new_in)
						mess_out(i,:,j) = mess_in(find(t_new_in(i) == t_new_in)); % copy every row (=time) that exists in "mess_in" to "mess_out"
					end
					
				end
			end
			
		end

	end

	function g_handle = my_msgbox(txt_str,font_size)
		% msgbox with adjustable fontsize, re-sizes msgbox window
		g_handle						= msgbox(txt_str);
		child							= get(findobj(g_handle,'type','Axes'),'Children');
		child.FontSize					= font_size;
		[dimension]						= child.Extent;
		g_handle.OuterPosition([3 4])	= [dimension(3)+20 dimension(4)+70];
	end

	function name = expand_well_name(name)
		% expand name: "A2" -> "A02"
		% "name" is expected to be a cell of strings
		
		for i = 1:numel(name)
			if numel(name{i}) == 2 % nur "B2" anstatt von "B02"
	            name{i} = [name{i}(1) '0' name{i}(2)];
			end
		end
		
	end

	function [t_previous, mess_previous, weight_previous, t_new, mess_new, weight_new] = adapt_timeline(t_previous, mess_previous, weight_previous, t_new, mess_new, weight_new)

		% ToDo: Another check to see if all measurements were taken at the same time intervalls (delta_t)?

		t_all = unique([t_previous, t_new]);

		for i = 1:numel(t_all)

			if ~ismember(t_all(i),t_new)
				% this measurement time (t_all(i)) does not occur in t_new
				t_idx = find(t_new < t_all(i),1,'last');
				if isempty(t_idx)
					% first time is new
					t_new		= [t_all(i) t_new];
					mess_new	= [NaN mess_new];
					weight_new	= [0 weight_new];
				else
					t_new		= [t_new(1:t_idx)			t_all(i)					t_new(t_idx+1:end)];
					mess_new	= [mess_new(1:t_idx,:);		NaN(1,  size(mess_new,2));	mess_new(t_idx+1:end,:)];
					weight_new	= [weight_new(1:t_idx,:);	zeros(1,size(mess_new,2));	weight_new(t_idx+1:end,:)];
				end

			elseif ~ismember(t_all(i),t_previous)

				% this measurement time (t_all(i)) does not occur in t_previous
				% Note: Handling is a little bit different, because mess_previous/weight_previous can be 3-D

				t_idx		= find(t_new < t_all(i),1,'last');
				fill_NaN	= NaN(  1, size(mess_previous,2), size(mess_previous,3));
				fill_zero	= zeros(1, size(mess_previous,2), size(mess_previous,3));

				if isempty(t_idx)
					% first time is new
					t_previous		= [t_all(i) t_previous];
					mess_previous	= cat(1, fill_NaN,   mess_previous);
					weight_previous	= cat(1, fill_zeros, weight_previous);
				else
					t_previous		= [t_previous(1:t_idx)					t_all(i)	t_previous(t_idx+1:end)];
					mess_previous	= cat(1,mess_previous(1:t_idx,:,:),		fill_NaN,	mess_previous(t_idx+1:end,:,:));
					weight_previous	= cat(1,weight_previous(1:t_idx,:,:),	fill_zero,	weight_previous(t_idx+1:end,:,:));
				end

			end

		end
		
		clear fill_zero fill_NaN

	end

	
end

function [fit_param,Status,Options] = findChronoParameter(t,y_mess,name,repl_mittelwert,Options_in)
% This program is part of the ChronAlyzer. For more details and license
% information, please look there.
%
% Copyright (c) 2017-2021 Norman Violet     == MIT License ==
%
%
% ----------------------------------------------------------------------
% INPUT:
% t:				time vector of measurement
% y_mess:			measurement vector
% name:				name of replicate group (or well)
% repl_mittelwert:	(not used)
% Options_in:		Options passed to this sub-function
%
% OUTPUT:
% fit_param:		optimal model parameter set (curve-fitting)
% Status:			TRUE if interrupted by user, otherwise FALSE
% Options:			Actual used options, can be passed to another run
%
% ----------------------------------------------------------------------
%
% ToDo: 
%
% ToDo: complete the translation to English, add more comments
% ToDo: remove figure menu / toolbar from figures
% ----------------------------------------------------------------------
%
% Note: Actually, there are two effects which cause the peaks to be tilted: The
% overall trend and the damping of the amplitude also!
%
% ----------------------------------------------------------------------
%
% Note: "disp" command outputs are not for users without Matlab: They don't
% have that output window!
%
% ----------------------------------------------------------------------



%% INIT


% I am lazy and sometimes I just start the wrong file, so here's my
% work-around:
if nargin == 0
	ChronAlyzer
	return
end


% A previous program run, which was aborted or interrupted can leave figures
% open. Figures with "working..." in it, can't be closed so easily, because
% their close-function was deactivated. So, look for these figures and
% close them ...

search_old_figs = findall(0, 'tag','working');
if ~isempty(search_old_figs)
	for i = 1:numel(search_old_figs)
		try
			parent_h = get(search_old_figs(i),'Parent'); 
			set(get(parent_h,'Parent'),'CloseRequestFcn','closereq')
			close(get(parent_h,'Parent'))
		catch ME
		end
	end
end


%% Declaration of Variables

	
	Stop			= false;
	OK				= false;
	% Change		= false;
	
	
	% fun_h			= @kurve; % handle to model function
	
	max_t_filter	= [];
	Y				= [];
	T				= [];
	t_sim			= []; % for optimization
	y_sim			= []; % for optimization
	plot_h2			= []; % handle to plot
	
	Dam_sign		= 0; % sign of damping (positiv means amplitude of data is increasing)
	pso_show_flag	= false; % Display off (or lower frequently updates) when PSO is running
	max_h_Start		= 36;		% Für die GUI (xlim), Auswertung von 0 bis max_h_Start 
		
	
	% read "Options_in" struct
	if isfield(Options_in,'Debug')
		debug						= OPTS.Debug;
	else
		debug						= false;
	end
	if isfield(Options_in,'start_at')
		start_at					= Options_in.start_at;
	else
		start_at					= t(1); % should be zero
	end
	if isfield(Options_in,'end_at')
		end_at						= Options_in.end_at;
	else
		end_at						= t(end);
	end
	
	if isfield(Options_in,'ausreisser_flag')
		Options.ausreisser_flag		= Options_in.ausreisser_flag;
	else
		Options.ausreisser_flag		= true;
	end
	if isfield(Options_in,'Basislinienoption')
		Options.Basislinienoption	= Options_in.Basislinienoption;
	else
		Options.Basislinienoption	= 100;
	end

	if isfield(Options_in,'time_weight')
		Options.time_weight			= Options_in.time_weight;
	else
		keyboard
		Options.time_weight			= 1;
	end

	if isfield(Options_in,'log_diff')
		Options.log_diff			= Options_in.log_diff;
	else
		Options.log_diff			= false;
	end

	if isfield(Options_in,'const_PER')
		Options.const_PER			= Options_in.const_PER;
	else
		keyboard
		Options.const_PER			= true;
	end
	if isfield(Options_in,'const_value')
		Options.const_value			= Options_in.const_value;
	else
		keyboard
		Options.const_value			= 24;
	end
	if isfield(Options_in,'weight_threshhold_time')
		Options.weight_threshhold_time		= Options_in.weight_threshhold_time;
	else
		Options.weight_threshhold_time		= 12;
	end
	if (isfield(Options_in,'NoSound') && Options_in.NoSound) || audiodevinfo(0) < 1
		NoSound						= true;
	else
		NoSound						= false;
	end
	
	% find first time index with "full" weighting factor (after fade-in)
	weight_idx						= find(t >= Options.weight_threshhold_time,1,'first');

	Options.ausreisser_liste		= [];
		
    
%% ------------------------------------
	
	if ~NoSound
        try
            [Y, FS]		= audioread('calibrationlockeddiagnosticunderway.mp3');
            sound_obj	= audioplayer(Y,FS);
            play(sound_obj)
			pause(1)
        catch
            sound_obj	= [];
            Y			= [];
            FS			= [];
        end
	end
	
	% create additional icons for menubar
	try
		toolbar_icon1 = imread('delete_raw_icon.tif'); % return values are integer
		toolbar_icon1 = double(toolbar_icon1(:,:,1:3))./255; % but needed are values 0..1
	catch
		toolbar_icon1 = ones(16,16,3);
		for i = 1:16
			toolbar_icon1(i,i,:) = 0;
			toolbar_icon1(17-i,i,:) = 0;
		end
	end
	
	try
		toolbar_icon2 = imread('limited_range_icon.tif'); % return values are integer
		toolbar_icon2 = double(toolbar_icon2(:,:,1:3))./255; % but needed are values 0..1
	catch
		toolbar_icon2 = ones(16,16,3);
		for i = 2:15
			toolbar_icon2(i,2,:)	= 0;
			toolbar_icon2(i,15,:)	= 0;
		end
		for i = [2:4, 13:15]
			toolbar_icon2(2,i,:)	= 0;
			toolbar_icon2(15,i,:)	= 0;
		end
		
	end

	
	
	
%% Manually mark and remove noisy peaks

	figaus_h	= findobj(0,'Tag','Basis');

	if isempty(figaus_h)
		figaus_h	= figure('Position',[40, 40, 1250, 550],'numbertitle','off','Tag','Basis');
	else
		set(figaus_h,'Position',[40, 40, 1250, 550]);
	end
	set(figaus_h,'Position',[40, 40, 1250, 550],'DeleteFcn',@my_closereq);
	
	figure(figaus_h);

	plot_h	= findobj(figaus_h,'tag','messdaten');

	if isempty(plot_h)
		plot_h	= plot(t,y_mess,'tag','messdaten');
		xlabel('time [h]');
		hold on;
	else
		set(plot_h,'xdata',t,'ydata',y_mess);
		delete(findobj(gca,'linestyle',':','tag',''));
	end

	t_lim = get(gca,'xlim');
	set(gca,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
	grid

	if Options.ausreisser_flag
		
		disp('Marking of noisy peaks')
		plot_h.Marker = '.';
		title('Mark and ignore noisy peaks');	

		hOK		= uicontrol('Style','pushbutton','backgroundcolor',[0 1 0], ...
			'String','Erledigt','Position',[1150,525,70,25],'Callback',{@OK_Button_Cb});
		hRemove = uicontrol('Style','pushbutton', 'tooltip',sprintf(['Select time periods in which data will be presumed to be noisy peaks\n' ...
			'and won''t be used. (Note: The gap will be visually ''filled'' by a line.)']), ...
			'String','Mark noisy peaks','Position',[20,525,140,25],'Callback',{@Remove_Button_Cb},'backgroundcolor',[1 .2 .2]);

		while ~OK && ishandle(plot_h)
			% Solange Grafik da und nicht auf OK gedrückt
			drawnow
		end
		
		set(hOK,'enable','off','visible','off');
		set(hRemove,'enable','off','visible','off');
		delete(hOK)
		delete(hRemove)
		plot_h.Marker = 'none';

	else
		
		disp('User doesn''t want/need to mark noisy peaks')
		title('User Selection: No need to remove noisy peaks') % this title will be replaced before user can see it
		Options.ausreisser_liste = [];

	end
	
	OK = false;
	
%% Analyze from ... to ... - Asking user for this information and cut data accordingly

	if ~exist('start_at','var') || isempty(start_at)
		
		default_start	= 6;
		
		fill_h = fill([t(1) t(weight_idx) t(weight_idx) t(1)] + default_start,reshape([get(gca,'ylim');get(gca,'ylim')],1,4),[t(1) t(weight_idx) t(weight_idx) t(1)],'LineStyle','-.');
		colormap('gray')
		brighten(.7)
		uistack(fill_h,'down');
	
		disp('Setting analyzing range ...')
		figure(figaus_h);
		
		% delete lines and arrows (if from previous run)
		line_h 	= findall(0,'UserData','VertLine');
		delete(line_h)
		arrow_h = findall(0,'UserData','Arrow');
		delete(arrow_h)
		
		xlim([0 max_h_Start]);
	 	tit_h = title('Analyze from hour                ?   (use keyboard or mousewheel)', 'Units','normalized');
		tit_h.Position(1) = 0.495;

		figaus_h.Name = ['Using "' name '" as an example'];
		figaus_h.WindowScrollWheelFcn = @WheelMoves_cb;

		buttongroup_h	= uibuttongroup('Position',[0.915 0.65 .08 .2], 'clipping','on');

%		uic_zoom = uicontrol('Style','Radio','String','Zoom','units','normalized', 'tooltip','Vergrößert den Ausschnitt', ...
%					'pos',[.25 .7 .5 .2],'parent',buttongroup_h,'HandleVisibility', ...
%					'off','callback',@Zoom_CB); ist kaputt
		uic_lin = uicontrol('Style','Radio','String','Lin','units','normalized', 'tooltip','Linear axis',...
					'pos',[.25 .4 .5 .2],'parent',buttongroup_h,'HandleVisibility','off','callback',@Lin_CB);
		uic_log = uicontrol('Style','Radio','String','Log','units','normalized', 'tooltip','Logarithmic axis', ...
					'pos',[.25 .1 .5 .2],'parent',buttongroup_h,'HandleVisibility','off','callback',@Log_CB);
		set(uic_lin,'value',1);

		set(figaus_h,'CloseRequestFcn',''); % closereq
		
		
		startzeit_box_h = uicontrol('Style','edit', 'String',num2str(default_start), 'Units','normalized', 'Position', [0.455 0.93 0.03 0.04], ...
				'UserData','StartTime', 'Callback',{@readinput_cb});
		startline_h		= line([default_start default_start],get(gca,'Ylim'),'UserData','VertLine','Color',[0 0 0]);
		ax_h			= gca;
		arrow_h			= set_arrow(ax_h, default_start, 1); % Zeichne Arrow nach rechts
		hbestaetigt		= uicontrol('Style','pushbutton','backgroundcolor',[0 1 0],'fontsize',12, 'tooltip','Proceed with selection', ...
		'String','Confirm','units','normalized','Position',[.85,.95,.1,.04],'Callback',@OK_Button_Cb);
		
		while ~OK
			drawnow
			pause(0.2)
		end
		
		figure(figaus_h);
		delete(findobj('type','patch'))
		
		OK			= false;
		start_at	= str2num(startzeit_box_h.String);
		hbestaetigt.String = 'Confirm';
		
		delete(arrow_h)
		delete(tit_h)
		delete(startline_h)
		
		xlim([min([t(end)*0.25,36]) t(end)]);
		tit_h = title('Analyze from hour               to hour                ?  (use keyboard - "e" to select end - or mousewheel)', 'Units','normalized');
		startzeit_box_h.Position(1) = 0.387;
		tit_h.Position(1)			= 0.54;
		startzeit_box_h.Enable		= 'off';
				
		if ax_h.XLim(2) > 60
			default_end = floor(60+0.66*(ax_h.XLim(2)-60));
		else
			default_end = min(max(60, ax_h.XLim(2) - 6),ax_h.XLim(2));
			default_end = 1/4*round(default_end*4);
		end

		endzeit_box_h = uicontrol('Style','edit', 'String',num2str(default_end), 'Units','normalized', 'Position', [0.478 0.93 0.03 0.04], ...
				'UserData','EndTime', 'Callback',{@readinput_cb});
			
		endline_h		= line([default_end default_end],get(gca,'Ylim'),'UserData','VertLine','Color',[0 0 0]);
		arrow_h			= set_arrow(ax_h, default_end, -1); % Zeichne Arrow nach links

		while ~OK
			drawnow
			pause(0.2)
		end
		
		OK		= false;
		
		end_at	= str2num(endzeit_box_h.String);
		if end_at > max(t)
			end_at = max(t);
			endzeit_box_h.String = num2str(end_at);
		end

		Options.start_at	= start_at; % zeitliche Angabe in echten Stunden; zur Rückgabe und Weiterverwendung bei nächstem Sample
		Options.end_at		= end_at; % zur Rückgabe und Weiterverwendung bei nächstem Sample

		% xlim('auto');
		
	else
		% damit der nächste Aufruf diese Daten weitergibt
		Options.start_at	= start_at; % zur Rückgabe und Weiterverwendung bei nächstem Sample
		Options.end_at		= end_at;

	end

	uic_zoom.Enable	= 'off';
	uic_lin.Enable	= 'off';
	uic_log.Enable	= 'off';


%% Plot aktualisieren

	% main window
	tabelle_fig_h		= findall(0,'tag','Table');
	tabelle_fig_h.Name	= [regexprep(tabelle_fig_h.Name,' - .*','') ' - Analysis from hour: ' num2str(start_at) ...
		' to hour: ' num2str(end_at) ];
	delete(figaus_h); % time range window

	xdata	= t; % xdata und ydata sind die vollständigen Datensätze
	ydata	= y_mess;
	
	% User has defined range for analysis
	idx1	= find(xdata > start_at,1,'first'); % dies sind die Indizes zu den Zeiten
	idx2	= find(xdata >=  end_at,1,'first');
	
	% limit data to defined range
	T = xdata(idx1:idx2); % T und Y sind gekürzte Datensätze
	Y = ydata(idx1:idx2);


%% Pre-filter (Smoothing)
   % (....)

	y_gefiltert = Y; % Smoothing at this point concurrently deactivated (because it is deemed as unneccessary))'])

	if debug
		figure;

		plot(t,ydata,T,Y);
		
		if ~isempty(strfind(name,'group'))
			title(['Debug output - ' name(strfind(name,'group'):end)],'Interpreter','Latex')
		else
			title(['Debug output - ' name]); 	
		end

		legend({'unused (averaged) data','used range of (averaged) data'})
		xlabel('time [h]');
		ylabel('units');
	end
	

	if ~isempty(strfind(name,'group'))
		% better naming for replicate groups in figure titles
		name_ = name(strfind(name,'group'):end);
	else
		name_ = name;
	end
	
%% Basislinie finden (Zweite Filterung nach Grundform)
	
	% Auf was soll das Fitting angewendet werden?
	
	if Options.Basislinienoption == 1 % Method "e-Funktion"

		% THIS BRANCH WON'T BE DEVELOPED FURTHER
		X0_Basis 	= [Y(1), 0.02, 0]; %, 1000]; % Start, Damping, Offset P1

		OPTS				= optimset('fminsearch');
		OPTS.TolFun			= 1e-7;
		OPTS.TolX			= 1e-7;
		OPTS.MaxFunEvals    = 500 * numel(X0_Basis);
		OPTS.MaxIter        = 500 * numel(X0_Basis);
		OPTS.StepTolerance	= 1e-8;
		if debug
			OPTS.Display = 'iter-detailed';
		end

		[X,FVAL,EXITFLAG,OUTPUT] = fminsearch(@expkurve,X0_Basis,OPTS);
		%[X,FVAL,EXITFLAG,OUTPUT] = fminunc(@expkurve,X0_Basis,OPTS);
		
		StartValue	= X(1);
		Dam			= X(2);
		Offset		= X(3);
		% P1		= X(4);

		if debug
			disp(['Results of fitting to exp. function: Starting value = ' num2str(StartValue) '; Damping = ' num2str(Dam) '; Offset = ' num2str(Offset)])
		end
		
		fit_param.Basis_Amp = StartValue;
		fit_param.Basis_Dam = Dam;
		fit_param.Basis_Off = Offset;
		%fit_param.Basis_P1	= P1;

		
		%% Messdaten um Basislinie bereinigen:
		t			= T;
		y_mess_korr	= Y - (StartValue .* exp(-Dam .* T) + Offset); %  - (P1./(1+T)));

	else % Option 10 und 100 ("Normiert" und "Mittelwert")
	
		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		
		if true % ToDo: create option to switch between both methods
			disp('Calculate drift approximation - method 1: Moving Horizon Average')

			if Options.Basislinienoption == 10 % Methode: Normiert
				% alle Messdaten werden zunächst auf den ersten Datenpunkt (der gewählten) Range normiert
				% da ydata schon verkürzt wurde, sind idx nicht mehr notwendig
				y_mess_korr	= y_gefiltert ./ y_gefiltert(1);
			else
				y_mess_korr = y_gefiltert;
			end

			% oben schon gemacht T = xdata(idx1:idx2); % jetzt ist auch T verkürzt, passt nun zu ydata bzw. Y
		
			% ToDo:
			% Hier kann und muss überprüft werden, ob das GleitMW_Zeitfenster wirklich gut gewählt ist und ob ein gleitender Mittelwert wirklich sinnvoll ist:
			% Problem: Ähnliche Messkurven aber mit deutlich unterschiedlichen Amplituden können nach der Prozedur sehr ähnliche Amplituden haben -> Informationsverlust!!
			GleitMW_Zeitfenster = 12; % ToDo: moving horizon average (in hours), multiples of 6 are working good, why?

			WindowSize = round(GleitMW_Zeitfenster/mean(unique(diff(T)))); % Umrechnung von Stunden in Anzahl Messzeitpunkte

			a	= 1;
			b	= 1/WindowSize .* ones(1,WindowSize); % Koeffizienten

			y_baseline1 = my_filter(b,a,y_mess_korr); % Forward ...
			y_baseline2 = my_filter(b,a,y_mess_korr(end:-1:1)); % Backward ...
			y_baseline2 = y_baseline2(end:-1:1);		
			y_symaverage	= .5 .* (y_baseline1 + y_baseline2); % -> symmetrischer Mittelwert

			if Options.Basislinienoption == 10 % Methode: Normiert		
				y_mess_korr	= y_mess_korr - y_symaverage;
			else % Options.Basislinienoption == 100 % Methode: Mittelwert
				y_mess_korr	= y_mess_korr - y_symaverage;
			end

			clear a b
			
			max_t_filter = max(T); % is used for scaling figures

			if debug

				figure

				if Options.Basislinienoption == 10 % Methode: Normiert

					plot(T,y_mess_korr)
					hold on
					plot(T,y_mess_korr,T,y_gefiltert);
					plot(T,y_baseline1,':',T,y_baseline2,':');
					legend({'Smoothed (Input)','','Normalized (Output)',['moving horizon average (' num2str(GleitMW_Zeitfenster) ' [h])'], ...
						'MW (Forward)','MW (Backward)'});

				else % Options.Basislinienoption == 100 % Methode: Mittelwert

					%plot(xdata,ydata,'b:');
					plot(T,Y,'b-');
					hold on
					plot(T,y_baseline1,'k:',T,y_baseline2,'k:');
					plot(T,mean([y_baseline1;y_baseline2]),'k-');			 
					plot(T,y_mess_korr,'r');
					legend({'used (averaged) data)',['forward moving horizon average (' num2str(GleitMW_Zeitfenster) ' [h])'], ...
						['backward moving horizon average (' num2str(GleitMW_Zeitfenster) ' [h])'],'mean MHA','Result: Normalized (Output)'});
				end

				title(['Debug: Normalisation of data:' newline 'Measurement, moving horizon average (back+forward)' newline 'Result: Measurement - mean(MHA)'])

				xlim([0 max_t_filter * 1.15]);
				t_lim = get(gca,'xlim');

				if max(t_lim) > 80
					set(gca,'xTick',0:12:floor(t_lim(2)/12)*12,'xticklabels',arrayfun(@num2str,[0:12:floor(t_lim(2)/12)*12],'UniformOutput',false));
				else
					set(gca,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
				end

				grid

				if ~isempty(strfind(name,'group'))
					name_ = name(strfind(name,'group'):end);
				else
					name_ = name;
				end

				title(['Debug output: ' strrep(name_,'group: ','') ':' newline 'MHA method for normalizing'],'Interpreter','none'); % Interpreter-option for usage of underscores in group names

				% resize figure because above latex option does not calculate
				% needed vertical space correctly
				temp_h = gcf;	
				temp_h.Position([2 4]) = [290 550];
				temp_h = gca;
				temp_h.Position([2 4]) = [0.15 0.7];
				clear temp_h

				xlabel(['time [h]' newline 'For best results black line should be oscillating slightly only' newline '(depends on "used" intervall)']);
				ylabel('units');
				% ToDo: Perhaps oscillating of MHA can be used for
				% automatically suggesting a good time intervall ?

			end % if debug			
		
		% - - option 2 - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		else		
			% calculate turning points
			disp('Calculate drift approximation - method 2: Turning Points')		
			
			turn			= [];
			smooth_range	= 18; % ToDo: Should depend on sampling frequency?
			y_mess_smooth	= smooth(Y,smooth_range,'rloess');

			[iHi,iLo,iCr]	= findextrema(smooth(diff(y_mess_smooth)));
			iHi		= iHi + 1; % because of using diff in previous line
			iLo		= iLo + 1;
			turn	= T(unique([iHi; iLo])); % in hrs
			turn_Y	= [];

			for i = 1:numel(turn)
				turn_Y = [turn_Y, interp1(T,Y,turn(i),'nearest')];
			end

			[P,S]	= polyfit(turn,turn_Y,3);
			polynom	= polyval(P,T);
			% ToDo: Ist das eine bessere Anpassung? User entscheiden lassen?
			y_mess_korr	= y_gefiltert - polynom;
			
			if debug
				figure
				plot(T,Y,'b-');
				hold on
				plot(T,polynom,'k');
				plot(T,y_mess_korr,'r');
				grid
				xlabel(['time [h]' newline 'For best results black line should be oscillating slightly only' newline '(depends on "used" intervall)']);
				ylabel('units');
				legend({'used (averaged) data)', 'Polynom through turning points','Result: Normalized (Output)'});
				title(['Debug output: ' strrep(name_,'group: ','') ':' newline  'Turning point method for normalizing'],'Interpreter','none')
			end
			
		end
		% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	end


%% Variablenwerte nach Filterungen neu benennen

	t_filter	= T;
	y_gefiltert = y_mess_korr;


%% Abbruch (User hat Stop gedrückt)

	if Stop
		fit_param = [];
		Status = true;
		return
	end

%% Abschätzung der Startwerte und Constraints für Optimierung

	%if ~exist('X0_main','var') || isempty(X0_main)
		[schaetz_Amp, schaetz_Pha_idx]	= max(abs(y_gefiltert));
		% X0 = Amplitude, Dam, Per, Phase, deltaPer

hold on
% creates background color gradient to visualize the auto-decreased
% weighing factor in the objective function

		
		if Options.const_PER
			% period length is constant, get approximation for phase-shift
			
			% Smooth measurements, look for extrema to deriviate phase-shift
			smooth_range	= 24; % ToDo: Should depend on sampling frequency?
			y_mess_smooth	= smooth(y_mess_korr,smooth_range,'rloess');
			[iHi,iLo,iCr]	= findextrema(y_mess_smooth);
			
			if debug
				% add plot to last debug figure)
				hold on
				plot(T,y_mess_smooth,'r-.');
				legend({'used (averaged) data)',['forward moving horizon average (' num2str(GleitMW_Zeitfenster) ' [h])'], ...
					['backward moving horizon average (' num2str(GleitMW_Zeitfenster) ' [h])'],'mean MHA','Result: Normalized (Output)','Smoothed result (for extreme values)'});
				
			end
			
			% let user check validity of these extreme values
			figure('name',strrep(name_,'group: ',''))
			plot(T,y_mess_smooth,'k','ButtonDownFcn', @extreme_marker_click_Cb);
			
			grid
			hold on

			fill_h = fill([t(1) t(weight_idx) t(weight_idx) t(1)]+start_at,reshape([get(gca,'ylim');get(gca,'ylim')],1,4),[t(1) t(weight_idx) t(weight_idx) t(1)],'LineStyle','-.');

			colormap('gray')
			brighten(.7)
			uistack(fill_h,'down');

			extremes_h	= [];

			for i = 1:numel(iHi)
				extremes_h(i) = plot(T(iHi(i)),y_mess_smooth(iHi(i)),'r*','ButtonDownFcn', @extreme_marker_click_Cb);
			end
			for i = 1:numel(iLo)
				extremes_h(i) = plot(T(iLo(i)),y_mess_smooth(iLo(i)),'b*','ButtonDownFcn', @extreme_marker_click_Cb);
			end
disp('die Grafik sind nach Müll aus, sobald ein outlier markiert wird, liegt das an dem nicht mehr äquidistanten T?')
keyboard
			xlim([0 max_t_filter * 1.15]);
			t_lim = get(gca,'xlim');

			if max(t_lim) > 80 % scaling of xlabels
				set(gca,'xTick',0:12:floor(t_lim(2)/12)*12,'xticklabels',arrayfun(@num2str,[0:12:floor(t_lim(2)/12)*12],'UniformOutput',false));
			else
				set(gca,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
			end

	
			title(['Check extreme values: Click on marker to delete' newline 'Click on line to add a extreme marker' newline ...
				'Close window to continue after deletion'])
			uiwait(gcf)
			
			% look for 2nd maximum and minimum (more robust than 1st)
			low_2nd			= mod(t_filter(iLo(2)),24); % if greater than 24)
			high_2nd		= mod(t_filter(iHi(2))-12,24); % if greater than 24)
			PHA				= mean([low_2nd, high_2nd])-12; 
			
			if debug
				
				figure('name',strrep(name_,'group: ',''))
				plot(T,y_mess_korr,'k:',T,y_mess_smooth,'k',T(iHi),y_mess_smooth(iHi),'r*',T(iLo),y_mess_smooth(iLo),'b*');
				grid
				hold on
				fill_h = fill([t(1) t(weight_idx) t(weight_idx) t(1)],reshape([get(gca,'ylim');get(gca,'ylim')],1,4),[t(1) t(weight_idx) t(weight_idx) t(1)],'LineStyle','-.');
				colormap('gray')
				brighten(.7)
				uistack(fill_h,'down');
				
				extremes_h	= [];
				
				for i = 1:numel(iHi)
					plot(T(iHi(i)),y_mess_smooth(iHi(i)),'r*');
				end
				for i = 1:numel(iLo)
					plot(T(iLo(i)),y_mess_smooth(iLo(i)),'b*');
				end
				
				xlim([0 max_t_filter * 1.15]);
				t_lim = get(gca,'xlim');
				
				if max(t_lim) > 80 % scaling of xlabels
					set(gca,'xTick',0:12:floor(t_lim(2)/12)*12,'xticklabels',arrayfun(@num2str,[0:12:floor(t_lim(2)/12)*12],'UniformOutput',false));
				else
					set(gca,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
				end

				title(['Debug output:' newline 'Normalized data and selected extrem values'])
				legend({'normalized data','smoothed normalized'})
				
			end
			
			if mean(diff(y_mess_smooth(iHi))) > 0
				% amplitude is increasing
				Dam_sign = 1;
				Dam_x0 = -0.05; % sorry, in equation there's another minus sign
			elseif mean(diff(y_mess_smooth(iHi))) < 0
				% amplitude decreases
				Dam_sign = -1;
				Dam_x0 = 0.05; % sorry, in equation there's another minus sign
			else
				% not sure
				Dam_sign = 0;
				Dam_x0 = 0;
			end
				
			X0_main = [	abs(schaetz_Amp)/2, Dam_x0, Options.const_value, PHA, 1];
			
			
		else
			% todo: vorverarbeitung wie im IF-Fall oben
			X0_main = [	abs(schaetz_Amp)/2, 0.05, 24, Options.const_value, 1];
		
		end
		
	%end

%% Prepare output figure from optimization

	fig_h = findall(0,'Tag',['findfit_' name],'Type','figure');
	
	if isempty(fig_h)
		fig_h = figure;
		set(fig_h,'Tag',['findfit_' name],'Name',name, 'UserData','Ausgabe');
	else
		% offenbar fehlt manchmal der Tag
		set(fig_h,'Tag',['findfit_' name],'Name',name, 'UserData','Ausgabe');
	end

	max_t_filter = max(t_filter); % wird in nested functions gebraucht, daher -> global
	
	set(fig_h,'UserData','Output','CloseRequestFcn',''); % closereq % Damit Fenster nicht geschlossen werden kann
	
	toolbar_h	= findall(fig_h,'type','uitoolbar');
	
	th1		= uitoggletool(toolbar_h, 'CData', toolbar_icon1, 'HandleVisibility','off','TooltipString','raw data on/off','ClickedCallback',@Raw_anaus_CB);
	th2		= uitoggletool(toolbar_h, 'CData', toolbar_icon2, 'HandleVisibility','off','TooltipString','full experimental time yes/no','ClickedCallback',@Limited_anaus_CB);
	
	% ToDo: Beschriftung prüfen, Ausgabe soll immer erfolgen, also nicht
	% nur debug, überlegen, was hier gezeigt werden soll
	
	figure(fig_h); % Plotting some lines again, in non-debug mode now
	plot_h = plot(t_filter,y_gefiltert,'k-', 'tag','rawdata','UserData','Limited');
	hold on

	fill_h = fill([t(1) t(weight_idx) t(weight_idx) t(1)],reshape([get(gca,'ylim');get(gca,'ylim')],1,4),[t(1) t(weight_idx) t(weight_idx) t(1)],'LineStyle','-.');
	colormap('gray')
	brighten(.7)
	uistack(fill_h,'down');			

	xlim([0 max_t_filter * 1.15]);
	t_lim = get(gca,'xlim');

	if max(t_lim) > 80 % scaling of xlabels
		set(gca,'xTick',0:12:floor(t_lim(2)/12)*12,'xticklabels',arrayfun(@num2str,[0:12:floor(t_lim(2)/12)*12],'UniformOutput',false));
	else
		set(gca,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
	end

	grid

	title([strrep(name_,'- group: ','(') ':' newline 'Adjusted raw data' newline '(by subtracting moving horizon average)'],'Interpreter','none');
	xlabel('time [h]');
	ylabel('units');

	t_sim				= t_filter; % copy values to global variables, used in optimization subroutine
	y_sim				= y_gefiltert;

	if ~NoSound
        try
            play(sound_obj,FS);
			pause(1)
        catch
        end
	end
	
	if ~isempty(findall(0, 'tag','working'))
		search_old_figs = findall(0, 'tag','working');
		for i = 1:numel(search_old_figs)
			try
				parent_h = get(search_old_figs(i),'Parent'); 
				set(get(parent_h,'Parent'),'CloseRequestFcn','closereq')
				close(get(parent_h,'Parent'))
			catch ME
			end
		end
	end
	
	
%% Voroptimierung

	figure(fig_h);
	
	wait_text_h = text(0,0,'working ...','FontSize',48,'Color',[.7 .7 .7],'Units','normalized', 'Tag', 'working', 'UserData', '+');
	wait_text_h.Position(2) = 0.5 + wait_text_h.Extent(4)/2;
	wait_text_h.Position(1) = 0.5 - wait_text_h.Extent(3)/2;


	% +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	% ToDo: Mögliche Erweiterung für Frequenz-Analyse (oder auch
	% Alternative für Rauschentfernung)
	% - - - 	% Kurze FFT-Auswertung
	% - - - 	Y_FFT		= fft(y_mess);
	% - - - 	L			= numel(Y_FFT);
	% - - - 	P_2			= abs(Y_FFT/L);
	% - - - 	P_1			= P_2(1:L/2+1);
	% - - - 	P_1(2:end-1) = 2*P_1(2:end-1);
	% - - - 	Fs			= unique(diff(t))/1800;
	% - - - 	f			= Fs * (0:(L/2)) / L;
	% - - - 	figure
	% - - - 	plot(f,P_1)
	% - - - 	title('Single-Sided Amplitude Spectrum of X(t)')
	% - - - 	xlabel('f (Hz)')
	% - - - 	ylabel('|P1(f)|')
	% - - - 	max(P_1)
	% - - - 	[fft_max,max_idx] = max(P_1);
	% - - - 	max_periode = 1/f(max_idx)/3600;
	% - - - 	disp(['Stärkster Signal-Anteil bei einer Periode von ' num2str(max_periode) ' h ermittelt.']);
	%
	% +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	
	% add starting and ending values of mean(MHA) to X0, this can be used
	% for fast optimization (in constraints)										 


	% X0 = Amplitude, Dam, Per, Phase
	delete(findobj('type','patch'))
	title('Particle Swarm Optimization: To find good starting values')
	tic;

	pso_show_flag = true; % flag, display off during iterations
	swarm_size = 10;

	if Dam_sign > 0
		% ToDo: calculate lower and upper bounds, then only one line of calling
		% PSO
		% Note: If Dam_sign positiv or negativ, this influences the allowed
		% range of values for PHA: If 
		if Options.const_PER
			if PHA > 0
				[X,yMin] = pso(fun_h,[0,-0.05,0],[1000,0,12],swarm_size); % ,np,inertia,acceleration,iteration,varargin)	
			else
				[X,yMin] = pso(fun_h,[0,-0.05,-12],[1000,-0.01,0],swarm_size); % ,np,inertia,acceleration,iteration,varargin)				
			end
		else
			[X,yMin] = pso(fun_h,[0,-0.05,20],[1000,0,26],swarm_size); % ,np,inertia,acceleration,iteration,varargin)	
		end
	else
		if Options.const_PER
			if PHA > 0
				[X,yMin] = pso(fun_h,[300,0,0],[1000,0.05,12],swarm_size); % ,np,inertia,acceleration,iteration,varargin)	
			else
				[X,yMin] = pso(fun_h,[200,0.05,-18],[1500,0.1,6],swarm_size); % ,np,inertia,acceleration,iteration,varargin)	
				% ToDo Constraints überall gleichsetzen
			end
		else
			[X,yMin] = pso(fun_h,[300,0,20],[1000,0.05,26],swarm_size); % ,np,inertia,acceleration,iteration,varargin)	
		end
	end
	
	legend({'Selected range of measurement', 'model simulation'})
	pso_show_flag	= false;
	[yMin,y_sim]			= fun_h(X); % recall to have really the best y_sim

	set(plot_h,'YData',y_sim')
	disp( '              Ampl.   -Dam           Per /Phase')
	disp(['PSO-Resultat: ' num2str(X')])

%% Hauptoptimierung

	OPTS				= optimset('fminsearch');
	OPTS.TolFun			= 1e-5;
	OPTS.TolX			= 1e-5;

	OPTS.MaxFunEvals    = 400 * numel(X0_main);
	OPTS.MaxIter        = 400 * numel(X0_main);
	
	title('Main optimization')
	% [X,FVAL,EXITFLAG,OUTPUT]	= fminsearch(fun_h,X0_main,OPTS); % old method
	[X,FVAL,EXITFLAG,OUTPUT]	= fminsearch(fun_h,X,OPTS); % old method

	%find min/max difference within first 24 hours
	% t24			= find(t_sim-t_sim(1) >= 24,1','first');
	% y_intervall = max(Y(1:t24)) - min(Y(1:t24));
	% give subfunction (and optimization some supporting values for good
	% starting values und boundaries (every parameter that follows X0_main)
	%[X,FVAL,EXITFLAG,OUTPUT] = analyze_circadian(t_sim,[X0_main, (y_baseline1(1)+y_baseline2(1))/2, (y_baseline1(end)+y_baseline2(end))/2, y_intervall],Y,OPTS); % outsourced improved method
	%ToDo: Ab hier brauche ich meinen modellierten Verlauf, also den um die
	%e-Funktion bereinigten und um die x-Achse schwingend .....
	% 																		
	% +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+


%% Aufarbeitung der Resultate	
	
	figure(fig_h);
	
	delete(wait_text_h)
    
	[I,verlauf] = feval(fun_h,X);
	
	% prepare output, add the fourth parameter
	if Options.const_PER
		X(4) = X(3);
		X(3) = Options.const_value;
	else
		% x(3) has not changed
        X(4) = Options.const_value; 
	end
	
	% Calculate useful "units" from the four parameter values:
	% amplitude - the first measured extremum
	% damping - the percentage (!) of the change from 1st to 2nd extremum
	% phase - converte from [h] into [min]
	
	% caveat: "verlauf" is simulated, but only within the selected
	% range! 
	
	first_extremwert_idx	= find(diff(sign(diff(verlauf)))~=0,1,'first');
	if isempty(first_extremwert_idx)
		msgbox('Error: No extrem values found! No periodical signal as input used? Otherwise please contact author!');
		first_extremwert = NaN;
	else
		first_extremwert	= abs(verlauf(first_extremwert_idx));
		% ToDo: Hier prüfen, ob der Verlauf wirklich um null schwankt,
		% sonst hilft dieser Wert nichts								  
	end

	fit_param.Amp	= first_extremwert;
	fit_param.Dam	= 100 * exp(-X(2) * X(3)) - 100; % Berechnung der Abnahme von Extremwert zu Extremwert
	fit_param.Per	= X(3);
	fit_param.Pha	= X(4);		
	

	% Erklärung für die Dämpfung-Umrechnung: 
	%	E-Funktion als Dämpfung hat zur Folge, dass der prozentuale Abfall
	%	in einem beliebigen Zeitintervall (aber mit festgelegter Länge)
	%	immer gleich ist!
	%
	%		exp(-X(2) * X(3)) --> X(2) = Dampfung und X(3) =  Periode (zB. 24 Stunden)
	%		=> X(3) = t_(n+1) - t_n = "delta_t"
	%		=> exp(-Dam * delta_t)
	%		<==> exp(-t_(n+1)*Dam) - exp(-t_n * Dam)
	%		<==> f(t_(n+1)) - f(t_n)
	%
	% Bei Halbierung -> "-50%", wenn zweites Extrem sogar nur ein Viertel
	% so hoch wie erstes Extrem, dann -> "-75%"
	

		
	if fit_param.Pha > 0 % Phasenverschiebung auf max. eine Periode beschränken
		fit_param.Pha = mod(fit_param.Pha,fit_param.Per);
	else
		fit_param.Pha = -mod(-fit_param.Pha,fit_param.Per);
	end


	if abs(fit_param.Pha) > 0.5 * fit_param.Per % if there's a big positiv phase-shift this is equal to a smaller negative phase-shift
		fit_param.Pha = fit_param.Per - abs(fit_param.Pha);
	end

	fit_param.Pha		= fit_param.Pha * 60; % convert now into [min]
	
	%fit_param.DeltaPer	= X(5);
	
	fit_param.Fehler	= 100 * FVAL / numel(t); % normiert auf Anzahl Messzeitpunkte

	

	figure(fig_h); % to make sure it's still the correct figure

	title('Fitted model to normalized measurement');
	legend({'Selected range of measurement','curve-fitted model'}); % ignoring pre-selected range, it's not mentioned
	
	set(fig_h,'CloseRequestFcn','closereq'); % Nun darf Fenster wieder geschlossen werden

	disp(['Amp (in range):   '          num2str(fit_param.Amp,'%0.4f') ...
		'  -  Dam:   '       num2str(fit_param.Dam,'%0.4f [%%]') ...
		'  -  Per:     '     num2str(fit_param.Per,'%0.4f [h]') ...
		'  -  Pha:  '        num2str(fit_param.Pha,'%0.4f [min]') ...
		... %'  -  DeltaPer:    ' num2str(fit_param.DeltaPer,'%0.2f') ...
		'  -  Error:    '   num2str(fit_param.Fehler,'%0.2f')]);

	Status = Stop;
	
	
	% end of subroutine, returning to ChronAlyzer main

	
%% nested functions =====================================================

	function [I,varargout] = kurve(PARAM)
		
		Amp			= PARAM(1); % amplitude
		Dam			= PARAM(2); % damping
		
		if Options.const_PER
			Per = Options.const_value;
			Pha = PARAM(3);
		else
			Per = PARAM(3);
			Pha = Options.const_value;
		end			
		
		%deltaPer	= PARAM(5);
		% pso_show_flag = ~isempty(cellstrfind({Cons.name},'pso')); this is
		% now a global variable
		Cons		= 0;
		
		%deltaPer = 1; % currently deactivated

        y_sim	= Amp .* exp(-Dam .* t_sim) .*  cos(2 .* pi .* (t_sim -Pha) ./ Per); % simulation of the model
		
		if nargout == 2
			varargout{1} = y_sim;
		end
		
		t_show	= 0:uniquetol(diff(t_sim),1e-2):t_sim(1);
		y_show	= Amp .* exp(-Dam .* t_show) .*  cos(2 .* pi .* (t_show - Pha) ./ Per);   % visualizing the unselected range of time as well     

		if nargout == 2 % if called with 2 variables only function call for y_sim is needed
			I = NaN;
			return
		end
		
		plot_h		= findobj(fig_h, 'tag','sim');
		working_h	= findobj(fig_h, 'tag','working');
		
		switch working_h.UserData
			
			case '+'
				if max(working_h.Color) < (.90-0.1)
					working_h.Color = working_h.Color + .01;
				else
					working_h.UserData = '-';
				end

			case '-'
				if min(working_h.Color) > (0.05+0.01)
					working_h.Color = working_h.Color - .01;
				else
					working_h.UserData = '+';
				end
		end
		
		drawnow
		
		if ~pso_show_flag || (toc > 1)
			
			if exist('plot_h','var')
				delete(plot_h);
			end
			if exist('plot_h2','var')
				delete(plot_h2);
			end
			
			plot_h	= plot(gca(fig_h),t_sim,y_sim,'b','tag','sim');
			plot_h2 = plot(t_show,y_show,'b--');
			
			if Options.Basislinienoption == 10 % = normiert
				ylim([-1.5 1.5]);
			end
			
			%set(plot_h,'tag','sim');
			tic;
			
		end
		
		if Options_in.log_diff
			ydiff = log(abs(Y - y_sim));
		else
			ydiff = (Y - y_sim).^2;
			if any(Y == 0)
				error('STOP: Division by zero (Error code 1010)')
			end
			%ydiff = (1 - (y_sim ./ Y)).^2; % Berechnung als "Fehlerprozent
			%-> spätere Zeiträume mit kleineren Amplituden werden nicht
			%anders gewichtet - fehlerhaft!!!
		end
		 
		% Gütefunktional ------------------------------------
		if Options_in.time_weight
			%I = sum(ydiff./exp(-Dam.*(t-t(1))))/(numel(Y)*max(Y));
			% Achtung: "Dam" in der Auswertung macht die Güte von Dam abhängig!!! Besser in Constraints
			I = sum(ydiff./exp(0.015.*(t_sim-t_sim(1))))/(numel(Y)*max(Y));
		else
			%I = sum(ydiff)/(numel(Y)*max(Y));
			% auto decrease weight until

			I = sum(ydiff(1:weight_idx).*linspace(0,1,weight_idx))/(numel(Y)*max(Y)); % decreased weight within first <weight_threshhold_time> hrs
			I = I + sum(ydiff(weight_idx+1:end))/(numel(Y)*max(Y));
		end
		
		
		% Constraints
		if Dam_sign ~= sign(-Dam) % sorry, equation reads "-Dam" so the value of the variable is switched
			Cons = Cons + I; % ToDo: Should be depend on extent of sign error
		end
			
		if Options.const_PER
			% if constant PER then only calulate constraint for PHA
			
			% Phase-shift should be less than half period length
			% This constraints tries to prevent multiple solutions
			Cons = Cons + max([0,abs(Pha)-Per/2])^4;			
		else
			% if constant PHA then only calulate constraint for PER
			
			% PERiod should be some 24, not far away from that value
			% +/- 4 hours are allowed range of difference to 24 hrs
			Cons = Cons + 2*max([0, abs(Per-24)^2 - 4]);
		end
		
		
		% sqrt: CONS-Wert springt schnell bei Grenzwert und steigt dann
		% allmählich langsamer aber stetig weiter
		%Cons = Cons + sqrt(max([10000 abs(Amp)]) - 10000); % mit PER = const ist das der Hauptfaktor?!
		
		
        %C4		= -min([0 Dam]); % negative Dämpfungm also Ansteigen der Amplitude wird bestraft
		% Hinweis: Dies ist für einige Zelllinien / Medien offenbar doch kein "Fehler"
		% aktuell daher:
		%C4		= -min([0 Dam + 0.075]) * 10; % Erst ab Dämpfung "-0.075" wird bestraft
		%Cons(4) = C4/(C4 + 0.005) * 1000;
		
		%Cons(4) = 1./(1+exp(-C4)) .* 100; % Funktionswwert 0-100
		%Cons(4) = sqrt(-C4)*100;
		% CONS-Funktion steigt linear und kontinuierlich mit immer stärkerer Dampfung
		% ab (0.075) an.
%Cons = Cons + max([0 -Dam-0.075]);
		
        %I = (I + sum(Cons(2:4))) * Cons(1);
%I = I + sum(Cons(1:4));
% if abs(y_sim(1)-y_mess_korr(1)) >	100
% 	Cons = (abs(y_sim(1)-y_mess_korr(1))) - 100;
% 	I = I + Cons;
% end

		% calculated simulation should hit the identified extreme values
		% ...
		I2 = 0;
		I2 = I2 + 100 .* sum((y_mess_korr(iHi) - y_sim(iHi)).^2);
		I2 = I2 + 100 .* sum((y_mess_korr(iLo) - y_sim(iLo)).^2);

		I = I + I2;
		
		% help to find the direction of first slope
		if sign(mean(diff(y_sim(1:5)))) ~= sign(mean(diff(y_mess_korr(1:5))))
			Cons = Cons + (mean(diff(y_sim(1:5))) - mean(diff(y_mess_korr(1:5))))^2;
		end

%         set(fig_h,'name',[name '  Goodness of fit: ' num2str(I,'%2.2e ') ' - in detail: fit(Per): ' num2str(Cons(1),'%2.2e') ...
% 			' fit(Pha): ' num2str(Cons(2),'%2.2e') ' fit(Amp): ' num2str(Cons(3),'%2.2e') ' fit(Dam): ' num2str(Cons(4),'%2.2e')]);


		I = I + Cons;
		
		if ~pso_show_flag
			set(fig_h,'name',[name '  Goodness of fit: ' num2str(I,'%2.2e ') ' - of this, constraints: ' num2str(Cons,'%2.2e')]);
			drawnow
		end
		
	end

% -------------

	function I = expkurve(PARAM)
		% wird bei Basislinie-Anpassung verwendet (wenn exp_Kurve als
        % Option gewählt)
		
disp('programm should not reach this here')
disp('todo: keyboard is active')
keyboard		

		StartValue	= PARAM(1);
		Dam			= PARAM(2);
		Offset		= PARAM(3);
		%P1			= PARAM(4);
		
		P1		= 0; % Funktion für PARAM4 'out of order'
		
		y_sim	= StartValue .* exp(-Dam .* T) + Offset - (P1./(1+T));
		

		if ~exist('fig_h','var')
			fig_h	= figure;
		
            %plot_h		= findobj(fig_h, 'tag','sim');
            plot_h	= plot(gca(fig_h),T,y_sim,'b:.', 'tag','sim');
            %set(plot_h,'tag','sim');
            hold on
            plot_orig_h = plot(t,ydata,':');
        
		end
		
        % update
		plot_h.YData = y_sim;
		
        % 		if exist('plot_h','var'),
        % 			delete(plot_h);
        % 		end
		
		
		I = sum((log(Y) -log( y_sim)).^2)/(numel(Y) * max(Y));
		
		set(fig_h,'name',[name '  Goodness of fit: ' num2str(I,'%2.4e ') ' - StartValue: ' num2str(StartValue,'%2.2e') ...
			' - Dam: ' num2str(Dam,'%2.3e') ' - Off: ' num2str(Offset,'%2.2e')]); % ' - P1: ' num2str(P1,'%2.2e')]);

		drawnow
		
	end

	function Stop_Button_Cb(source,eventdata)
		disp('Abbruch');
		OK		= true;
		Stop	= true;
	end



	function OK_Button_Cb(source,eventdata)
		disp('OK');
		OK = true;
	end


	function Remove_Button_Cb(source,eventdata)
		
		%disp('Remove');
		
		set(hRemove,'enable','off');
		set(hOK,'enable','off');

		old_title = get(gca,'title');
		old_title = old_title.String;
		title(['Click on left border of peak for the next (' num2str(numel(Options.ausreisser_liste)/2+1) '.) removal!']);
		
		[x1,~]						= ginput(1);
		title('Now, click on right border of this peak!');
		[x2,~]						= ginput(1);
		
		x = [x1 x2];
		
		set(hRemove,'enable','on');
		set(hOK,'enable','on');
		title(old_title);
		
		Options.ausreisser_liste	= [Options.ausreisser_liste,x];
		x							= sort(x);
		% ToDo: peak removal was done by removing measurements completely
		% This raises problems somewhere in the code. so a solution could
		% be to replace the measurements by a linear line between left and
		% right side of the chosen interval. But ...
		% ToDo: ... this solution is not good! There might be time-series
		% with missing time-points all from the beginning! Such a case must
		% be dealt with, too!
		
		del_idx						= find(t > x(1) & t < x(2));
		
		t(del_idx)					= [];
		y_mess(del_idx)				= [];
		set(plot_h,'xdata',t,'ydata',y_mess);
		
	end

	function Slider_Cb(source,eventdata)
		
		SliderValue			= round(2*get(source, 'Value'))/2;
		WindowSizeStunden	= SliderValue;
		% Change				= true;
		
		set(hSlider,'value',SliderValue);
		set(hText_akt,'String',['Current: ' num2str(WindowSizeStunden) ' h']);
		
	end

	function result = isodd(value)
		if value == round(value/2)*2
			result = false;
		else
			result = true;
		end
	end

	function Zoom_CB(source,eventdata)
		
		ydata		= get(get(gca,'children'),'ydata');
		x_limits	= xlim;
		idx			= find(get(get(gca,'children'),'xdata')>x_limits(2),1,'first');
		set(gca,'ylim',[0.9*min(ydata(1:idx)) round(4*std(ydata)+mean(ydata))]);
		
	end

	function Log_CB(source,eventdata)
		set(gca,'YScale','log');
		set(gca,'yLimMode','auto');
	end

	function Lin_CB(source,eventdata)
		set(gca,'yLimMode','auto');
		set(gca,'YScale','linear');
	end

	function x_new = my_filter(b,a,x_old)
		
		filter_size = numel(b);
		x_new		= filter(b,a,x_old);
		
		for k = filter_size:-1:1
			x_new(1:k)				= filter(1/k .* ones(1,k),a,x_old(1:k));
		end
		
	end

	function my_closereq(source,eventdata)
		OK = true;
		delete(gcf);
	end

	function Raw_anaus_CB(source, eventdata)
		
		line_idx = findall(source.Parent.Parent,'tag','rawdata');
		
		switch source.State
			case 'on'
				set(line_idx,'Visible','off');
			case 'off'
				set(line_idx,'Visible','on');
		end
		
	end

	function Limited_anaus_CB(source, eventdata)
		
		line_idx = findall(source.Parent.Parent,'userdata','Limited');
		
		switch source.State
			case 'on'
				set(line_idx,'Visible','off');
				xlim('auto');
			case 'off'
				set(line_idx,'Visible','on');
				xlim([0 max_t_filter * 1.15]);
		end
		
	end

	function WheelMoves_cb(source, data)
		
		delta_t				= 0.25; % Einheit "Stunde"
		new_x				= data.VerticalScrollCount * delta_t;
		tmp					= findall(0,'UserData','VertLine');
		
		
		if tmp.XData(1) + new_x < 0 % below zero not allowed
			new_x = -abs(tmp.XData(1));
			%tmp.XData([1 2])	= tmp.XData([1 2]) + new_x; % Jeweils eine Viertelstunde
		end

		%t_max = get(get(tmp,'Parent'),'XLim'); % above t_max not allowed
		%t_max = t_max(2);
		t_startmax = t(end) - 12; % this is the latest start allowed
		
		if strcmp(get(startzeit_box_h,'Enable'),'on') && tmp.XData(1) + new_x > t_startmax 
			% input of start time active
			new_x = 0; % t_max - tmp.XData(2);
		end
		
		if strcmp(get(startzeit_box_h,'Enable'),'off') && tmp.XData(1) + new_x > t(end) 
			% input of start time active
			new_x = 0; % t_max - tmp.XData(2);
		end
		
		if strcmp(get(startzeit_box_h,'Enable'),'off') && tmp.XData(1) + new_x <=  str2num(startzeit_box_h.String) + 12 
			% input of end time active
			new_x = 0;
		end
		
		
		tmp.XData([1 2])	= tmp.XData([1 2]) + new_x; % Jeweils eine Viertelstunde
		
		tmp					= findall(0,'UserData','StartTime');
		if strcmp(tmp.Enable,'on')
			tmp.String	= num2str(str2num(tmp.String) + new_x);
			direct = 1;
		else
			tmp			= findall(0,'UserData','EndTime');
			tmp.String	= num2str(str2num(tmp.String) + new_x);
			direct = -1;
		end
		
		move_arrow(new_x, 1, direct);
		
		patch_h = findall(gcf,'Type','patch');
		if ~isempty(patch_h)
			patch_h.XData = patch_h.XData + new_x;
		end
		
	end
		
	function readinput_cb(source,data)
		
		if ~isempty(strfind(source.String,','))
			source.String = strrep(source.String,',','.');
		end
		new_value = str2num(source.String);
        
		switch source.UserData
			case 'StartTime'
				
                if isempty(new_value) % was left blank or user entered "end" (or any alphanum)
                    new_value = t(1);
                    startzeit_box_h.String = num2str(new_value);
				end
				if new_value < 0
					new_value = t(1);
					startzeit_box_h.String = num2str(new_value);
				end
				if new_value > t(end)-12
					new_value = t(end)-12;
					startzeit_box_h.String = num2str(new_value);
				end
				
                startline_h.XData([1 2]) = new_value;
				direct = 1;
				
			case 'EndTime'
                if isempty(new_value) % was left blank or user entered "end"
                    new_value = t(end);
					new_value = max([new_value, str2num(startzeit_box_h.String)]);
                    endzeit_box_h.String = num2str(new_value);
				end
                if new_value < str2num(startzeit_box_h.String) + 12 % was left blank or user entered "end"
                    new_value = str2num(startzeit_box_h.String) + 12;
                    endzeit_box_h.String = num2str(new_value);
				end
                if new_value > t(end) % was left blank or user entered "end"
                    new_value = t(end);
                    endzeit_box_h.String = num2str(new_value);
				end
				
				endline_h.XData([1 2]) = new_value;
				direct = -1;
		end
		
		move_arrow(new_value, 2, direct); % Pfeil auch aktualisieren
		patch_h = findall(gcf,'Type','patch');
		if ~isempty(patch_h)
			xd = Options_in.weight_threshhold_time;
			patch_h.XData = [new_value new_value+xd new_value+xd new_value];
		end		

	end

	function arrow_h = set_arrow(ax_h, x_val, direction)
		
		yrange			= (ax_h.YLim(2) - ax_h.YLim(1));
		arrow_h(1)		= line([x_val x_val + 2 * direction],            [3/4*yrange   3/4*yrange] + ax_h.YLim(1),'UserData','Arrow','Color',[0 0 0]);
		arrow_h(2)		= line([x_val + direction x_val + 2 * direction],[0.775*yrange 3/4*yrange] + ax_h.YLim(1),'UserData','Arrow','Color',[0 0 0]);		
		arrow_h(3)		= line([x_val + direction x_val + 2 * direction],[0.725*yrange 3/4*yrange] + ax_h.YLim(1),'UserData','Arrow','Color',[0 0 0]);				
		
		arrow_h(4)		= line([x_val x_val + 2 * direction],            [1/4*yrange   1/4*yrange] + ax_h.YLim(1),'UserData','Arrow','Color',[0 0 0]);
		arrow_h(5)		= line([x_val + direction x_val + 2 * direction],[0.275*yrange 1/4*yrange] + ax_h.YLim(1),'UserData','Arrow','Color',[0 0 0]);		
		arrow_h(6)		= line([x_val + direction x_val + 2 * direction],[0.225*yrange 1/4*yrange] + ax_h.YLim(1),'UserData','Arrow','Color',[0 0 0]);				
		
	end

	function move_arrow(x_val, mode, direc)
		% Mode 1 = relative Koordinaten
		% Mode 2 = absolute Koordinaten
		% direc 1 = Pfeil nach rechts
		% direc 2 = Pfeil nach links
		
		arrow_h = findall(0,'UserData','Arrow');
		if direc == 1
			old_base_values = min(min(cell2mat(get(arrow_h,'XData')))); % nur für mode == 2
		else
			old_base_values = max(max(cell2mat(get(arrow_h,'XData')))); % nur für mode == 2
		end
		diff_x_pos		= cell2mat(get(arrow_h,'XData')) - old_base_values;
		
		for i = 1:numel(arrow_h)
			
			if mode == 1
			
				set(arrow_h(i),'XData',x_val + get(arrow_h(i),'XData'));
				
			elseif mode == 2
				
				
				set(arrow_h(i),'XData', x_val + diff_x_pos(i,:));
				
			end
				
		end
		
	end

	function extreme_marker_click_Cb(source, event)
		
		time = get(source,'XData');
					
		if numel(time) == 1
		
			% hit on marker to delete it
			
			if ~isempty(find(T(iHi) == time))
				iHi(find(T(iHi) == time)) = [];
			elseif ~isempty(find(T(iLo) == time))
				iLo(find(T(iLo) == time)) = [];
			else
				disp('error')
			end
			
			delete(source),
			
		else
			% add another marker
			new_time = event.IntersectionPoint(1);
			
			[new_time_,ntime_idx] = findnearest(T, new_time);
			
			
			if event.IntersectionPoint(2) > 0
				answer = questdlg('Is this a maximum?','Type of extreme point','yes','no','yes');
				if strcmp(answer, 'yes')
					flag = +1;
				else
					flag = -1;
				end
					
			else
				answer = questdlg('Is this a minimum?','Type of extreme point','yes','no','yes');
				if strcmp(answer, 'yes')
					flag = -1;
				else
					flag = +1;
				end

			end
			
			% add marker into plot
			switch flag
				case -1
					% minimum
					extremes_h(end+1) = plot(new_time_,y_mess_smooth(ntime_idx),'b*','ButtonDownFcn', @extreme_marker_click_Cb);					
					iLo = sort([iLo; ntime_idx]);					
				case 1
					% maximum
					extremes_h(end+1) = plot(new_time_,y_mess_smooth(ntime_idx),'r*','ButtonDownFcn', @extreme_marker_click_Cb);
					iHi = sort([iHi; ntime_idx]);
			end
						
		end
	end

	function [value,varargout] = findnearest(array, value_in)
			
			% find nearest element in array to value
			array_diff	= abs(array - value_in);
			[~,idx]		= min(array_diff);
			value		= array(idx);
			varargout{1} = idx;
						
	end

end
function [X,FVAL,EXITFLAG,OUTPUT] =	analyze_circadian(t_sim,X0,Y,OPTS)
%
% This program is part of the ChronAlyzer. For more details and license
% information, please look there.
%
% Copyright (c) 2017-2021 Norman Violet     == MIT License ==
%
%
% =======================================================================
% =======================================================================
% ||  This file/subfunction is currently NOT USED by ChronAnalyzer !!  ||
% ||  But it will be used again, after some major re-works in the      ||
% ||  "ChronAlyzer.m" and "findChronoParameter.m" files.               ||
% =======================================================================
% =======================================================================
%
%
% ----------------------------------------------------------------------
% INPUT:
% t_sim:	vector with measurement times
% X0:		start values for model parameters
% Y:		real measurements
% OPTS:		options
%
% OUTPUT:
% X:		optimal model parameter values
% FVAL:		fitness value of the model ("difference" to measurement)
% EXITFLAG: code for exit reason of optimizers
% OUTPUT:	additional information about the optimization process
%
% ----------------------------------------------------------------------
%
% ToDo: If there's a positive trend, curve-fitting does not seem to work
% well - check this!
%
% ToDo: To support the automatic detection and the time frame defined by
% "period_min" and "period_max" the user should be able to set the number
% of the minima (and/or maxima ?).
%
% ToDo: Complete the translation to English, add more comments
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

	MHA_startvalue	= [];
	MHA_endvalue	= [];
	MHA_peaksize	= [];

	if numel(X0) >= 8 % should be true only for method 1
		MHA_startvalue	= X0(6);
		MHA_endvalue	= X0(7);
		MHA_peaksize	= X0(8)/2;
	end
		
	if isfield(OPTS,'Minima_Optimierung')
		Minima_Optimierung	= OPTS.Minima_Optimierung;
	else
		Minima_Optimierung	= true;
	end
	if isfield(OPTS,'time_weight')
		time_weight			= OPTS.time_weight;
	else
		time_weight			= false;
	end
	if isfield(OPTS,'Debug')
		debug				= OPTS.Debug;
	else
		debug				= false;
	end
	if isfield(OPTS,'delta')
		% Note: delta is the constant (!) difference between measurement
		% time points! Main program must make sure that all time points are
		% equidistant!
		delta				= OPTS.delta; % ToDo: currently this is not supported, but should be!
	else
		delta				= 0.5;
	end
	
	% plausible limits for period lengths, used as constraints in
	% optimization:
	period_min	= 22; 
	period_max	= 26;
	% Note: Because of the overlaying trend the peaks are "tilted"!
	% Therefore the "real" peak is shifted, depending on the slope of the
	% trend. If the trend is falling (decreasing) the peaks are tilted
	% left: the peaks appear to be earlier than they actually are. Because
	% of this effect the peak time can be shifted by 0.5 hours (in our
	% experience). Because of the flattening slope (if the trend is
	% falling) the effect size decreases over time. 
	% Conclusion: Don't set too tight limits!
	
			 
	first_mini	= 18; % [hour] Up to this time the first minimum should have been measure (ToDo: Make this an "general option")
	
	% variables for optimization messages that should be not repeated endlessly
	msg_str		= '';
	msg_oldstr	= '';
	
	method		= []; % this is a flag for choosing different optimization targets (pre-optimization and main optimization):
	% "0": optimize without constraints, 
	% "1" currently not used, 
	% "2" regular optimization
	
	max_t_show = max(t_sim) * 1.15; % move max of xlim to +15% of last measurement time
	
	% set options for matlab optimizer
	OPTS				= optimset('fminsearch');
	OPTS.TolFun			= 1e-7;
	OPTS.TolX			= 1e-7;
	OPTS.MaxFunEvals    = 500 * numel(X0);
	OPTS.MaxIter        = 500 * numel(X0);
	OPTS.StepTolerance	= 1e-8;
	

%%	

	disp([newline newline])
	disp('=========Circadian analysis subroutine started==============')

	disp([newline newline])

	msg_str		= '';

	disp('===================== Step 1 =====================')
	disp('Approximation of an averaging exponential function')
	disp('==================================================')

	disp([newline newline])

	% -------------------------------------------------------

	fig_h	= figure; 

	set(fig_h,'Position',[50   550   560   420]);

	plot_h	= [];
	y_sim	= [];

	method = 0; % optimzation without contraints

	% initial parameter set (the curve-fitting starts here)
	% not used in PSO, only in fminsearch/fminunc
	X0_ = X0([1 2 4]); % ToDo: (Important) Use passed variable values or not?
	X0_ = [600 0.014 190];


	[X,FVAL,EXITFLAG,OUTPUT] = fminunc(@expkurve,X0_,OPTS);
	% Note: This call automatically saves the best simulation (best fitted curve)
	% in the global variable "y_sim" which is here (!) the simulation
	% of the detected trend. To prevent misunderstanding, this
	% renaming:

	sim_trend	= y_sim;
	y_sim		= []; % to prevent misuse

	% alternatively you can use the particle swarm optimizer here:
	% as noted above, PSO doesn't use initial starting point, but
	% searches "randomly" within the whole parameter space. Because of
	% this, it needs min/max limits for every parameter. Currently this
	% is realized by "0" and "1000" but that may not fit (especially
	% when negativ values are needed, too).
	% [X,FVAL] = pso(@expkurve,zeros(size(X0_)),1e3 .* ones(size(X0_)));

	StartValue	= X(1);
	Dam			= X(2);
	Offset		= X(3);


	% graphical output of result
	legend({'approx. exp. fcn','supporting points (= measurement)'})
	xlabel('time [h]')
	grid

	xlim([0 max_t_show]);
	t_lim = get(gca,'xlim');

	if max(t_lim) > 80
		set(gca,'xTick',0:12:floor(t_lim(2)/12)*12,'xticklabels',arrayfun(@num2str,[0:12:floor(t_lim(2)/12)*12],'UniformOutput',false));
	else
		set(gca,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
	end
	title('Step 1a: Approximation of an averaging exponential function')

	disp('Model equation: y_sim	= StartValue * exp(-(Damping) * t) + Offset')
	disp(['Results after the fitting: Startwert = ' num2str(StartValue) '; Offset = ' num2str(Offset) '; Damping = ' num2str(Dam)]);% ...


	% ------------------------------------

	figure 

	set(gcf,'Position',[ 50   40   560   420]);

	de_trended_y = Y - sim_trend; % Measurement (Y) - Trend-Curve (sim_trend) = de-trended measurement

	plot(t_sim,de_trended_y,'b');
	hold on

	grid
	xlabel('time [h]')
	xlim([0 max_t_show]);
	t_lim = get(gca,'xlim');

	if max(t_lim) > 80
		set(gca,'xTick',0:12:floor(t_lim(2)/12)*12,'xticklabels',arrayfun(@num2str,[0:12:floor(t_lim(2)/12)*12],'UniformOutput',false));
	else
		set(gca,'xTick',0:6:floor(t_lim(2)/6)*6,'xticklabels',arrayfun(@num2str,[0:6:floor(t_lim(2)/6)*6],'UniformOutput',false));
	end
	title(['Step 1b: De-trended measurements' newline '(after subtraction of the identified exp. function)'])


%% ======================================================

	disp('============ Step 2 ============')
	disp(['Improving the approximation by searching and optimizing minima' newline]) 

	method			= 2; % regular optimization
	smooth_value	= 7;

	Y_smooth		= smooth(Y,smooth_value,'rloess');


	% Note: In the following code lines the first minimum is looked
	% for. After that, all subsequent minima and maxima can be looked
	% for much more easily within a tight time frame (definded by
	% "period_min/max").


	anz_period_max = ceil(t_sim(end)/period_min);  % This is the expected max number of minima
	anz_period_min = floor(t_sim(end)/period_max); % This is the expceted min number of minima

	sensivity		= 1; % peakfinder sensivity
	OK				= false;

	while ~OK
		% in this loop the subfunction "peakfinder" searches for peaks.
		% The sensivity will be changed until "enough" peaks are found
		sensivity	= sensivity * 1.1;
		fmin		= peakfinder(de_trended_y,(max(Y_smooth)-min(Y_smooth))/sensivity ,[] , -1, false, false);
		if numel(fmin) >= anz_period_min
			break % number of minima found that were at least expected
		end
	end

	if t_sim(fmin(1)) > first_mini / delta
		% the first minimum within the defined bounds was not detected
		% by the above loop, look now again but only at the beginning
		% of the time-series again
		fmin = peakfinder(Y_smooth(1:first_mini*delta),(max(Y_smooth)-min(Y_smooth))/sensivity ,[] , -1, false, false);
	end

	% Note: the first miminum is saved in "t_sim(fmin(1))" now
	fmin_new = fmin(1);


	disp('Searching for minima in measurements:')
	disp([' 1. minimum found at t = ' num2str(fmin_new) ', continue search ' num2str(period_min) ' to ' num2str(period_max) ' hours later'])
	disp('(intervall depends on allowed range for circadian rhythms)')

	for minima_idx = 2:anz_period_max
		% Looking for subsequent minima
		% Caveat: Before and after a minimum there must be at least four (as coded below)
		% more measurements, otherwise a minimum can't be detected by "peakfinder"

		% in each loop run calculate the new time frame where the next
		% minimum is expected, depending on the last minimum found

		T_search_start_idx	= min([numel(Y_smooth), fmin_new(minima_idx - 1) + period_min/delta - 4]);
		T_search_end_idx	= min([numel(Y_smooth), fmin_new(minima_idx - 1) + period_max / delta + 4]);

		% ToDo: (suggestion) Perhaps this search can be improved by
		% using a larger search intervall, but still allow findings
		% only in the expected time frame.

		disp([newline 'Searching for the ' num2str(minima_idx) '. minimum within t = (' num2str(t_sim(T_search_start_idx)) ',' num2str(t_sim(T_search_end_idx)) ')'])

		if T_search_end_idx - T_search_start_idx < 4 % number of data points
			% break loop because time frame is too short to contain a searchable minimum
			% this happens at the end of the time-series, so no error
			disp('Time intervall too short, aborting search')
			break
		end

		erste_Anpassung = de_trended_y(T_search_start_idx:T_search_end_idx); % de-trended measurements

		OK			= false;
		sensivity	= 4; % peakfinder sensivity

		while ~OK

			selector	= (max(erste_Anpassung) - min(erste_Anpassung))/sensivity;
			fmin		= unique(peakfinder(erste_Anpassung,selector,[],-1,false,false)); % Caveat: "fmin" contains time index of this specific intervall only!

			% reduziere Indizes auf Bereich des tatsächlich
			% erwarteten Minimums
			if numel(fmin) > 1
				if debug
					disp(' ... too many minima found; looking more closely ...')
				end
				fmin = fmin(T_search_start_idx + fmin >= fmin_new(end) + period_min/delta);
				fmin = fmin(T_search_start_idx + fmin <= fmin_new(end) + period_max/delta);
			end
			if numel(fmin) > 1
				if debug
					disp(' ... still too many minima; smoothing data again ...') 
				end
				Y_interval_smooth	= smooth(Y(T_search_start_idx:T_search_end_idx),10,'rloess')';
				erste_Anpassung		= Y_interval_smooth - sim_trend(T_search_start_idx:T_search_end_idx);
				continue
			end

			if numel(fmin) < 1
				sensivity = sensivity + 1;
			elseif numel(fmin) > 1
				sensivity = sensivity * 0.9;
			else
				OK = true;
			end

		end

		if numel(fmin) == 1
			fmin_new(minima_idx) = fmin(1) + (T_search_start_idx -1);
			disp(['Next minimum found in smoothed & normalized data at t = ' num2str(t_sim(fmin_new(end)))])
		end

	end


	fmin = fmin_new;


	% ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	if numel(fmin) < 2
		fprintf(2,['Too few minima found! Algorithm will probably fail, sorry!' newline])
		pause
	end

	fprintf([newline 'Result: Minima were found at t = [ '])
	fprintf(2,[num2str(t_sim(fmin),' %2.1f') ' '])
	fprintf([']' newline])

	disp([newline '(Note: Due to distorsion, caused by the exponential(-like) function and ' newline ...
		'the not perfect approximation of that unknown function,' newline ...
		'these are not the "real" times of minima. Also, there is measurement noise of course)' newline])

	T_	= t_sim(fmin);
	Y_	= Y(fmin);
	fmin_orig = fmin; % Dies sind die Indizes der gerade identifizierten Minima
	% -----------------------------------------------------------

	fig_h	= figure; % figure 4
	fig_h.Position = [1240    700    560    420];

	% auf null setzen:
	%Y_ = Y_; % - min(Y);
	%X0 	= [max(Y_), 0.015, min(Y_)]; %, 20, 0]; %, 1000]; % Start, Damping, Offset, Start2, Dam2

	% Benutze alte Ergebnisse als Startwert
	X0 = X;
	% kürze aber auf drei Parameter: Start * exp(-Dam) + Off
	X0 = X0(1:3);
	% und setze den Start auf den niedrigsten Wert von Y (nicht
	% Y_ !) und den Offset auf 0
	X0(1) = min(Y);
	X0(3) = 0;


	% -----------------------------------------------------------

	plot_h	= [];
	y_sim	= [];

	T_orig	= t_sim;
	Y_orig	= Y;

	t_sim	= T_;
	Y		= Y_;

	% 1. e-Fkt Anpassung
	[X,FVAL,EXITFLAG,OUTPUT] = fminunc(@expkurve,X0,OPTS);

	%[X,FVAL,EXITFLAG,OUTPUT] = fmincon(@expkurve,X0,[],[],[],[],[0 0 0],[],[],OPTS);

	stuetz_h = findobj(fig_h,'Marker','+');
	stuetz_h.MarkerSize = 10;

	StartValue	= X(1);
	Dam			= X(2);
	Offset		= X(3);
	%StartValue2	= X(4);
	%Dam2		= X(5);

	y_sim = StartValue .* exp(-Dam .* T_orig) + Offset; % + StartValue2 .* exp(-Dam2.*T_orig);

	% 	plot_h.YData = y_sim;
	% 	plot_h.XData = T_orig;

	plot_h.YData = y_sim;
	plot_h.XData = T_orig;


	plot(T_orig,Y_orig,'k.:') % originale Messdaten


% 			diff2 = y_sim; % Resultat der Optimierung


	plot(T_orig, Y_smooth,'g-') 

	Fehler =  FVAL; % sum(((Y - y_sim)-(O-Off)).^2)/numel(y_sim);



	title('Methode 2: Schätzung mit Hilfe der Minima')
	legend({'e-fcn approximating minima','optimized minima (from measurement)', 'measurement data', 'Smoothed measurement data'})

	if ~Minima_Optimierung
		disp(['Ergebnisse der E-Funktion-Anpassung: Startwert = ' num2str(StartValue) '; Offset = ' num2str(Offset) '; Damping = ' num2str(Dam)]); % ...
		%'Startwert2 = ' num2str(StartValue2) '; Damping2 = ' num2str(Dam2)])
	else
		disp(['Vorläufige Ergebnisse E-Funktion-Anpassung an Minima:' newline 'Startwert = ' num2str(StartValue) '; Offset = ' num2str(Offset) '; Damping = ' num2str(Dam)]);% ...
		%'Startwert2 = ' num2str(StartValue2) '; Damping2 = ' num2str(Dam2)])
	end
	disp(['  -> führt zu einem Fehler von: ' num2str(Fehler)])


%%  -------------------------Optimierung der Stützstellen---------------------------

	if Minima_Optimierung % evtl. 2. e-Fkt Anpassung

		disp([newline 'Weitere Optimierung der Stützstellen'])

		fig_h = figure;
		fig_h.Position = [1240 380 560 420];
		plot_h = [];

		% Note: Mit (hier von rechts nach links) anwachsender Steigung
		% der e-Fkt wird das Minimum der Sinus-Fkt. immer weiter
		% verschoben (in Richtung höhere Zeit). Folgender "Trick" ist
		% mir eingefallen, um von der aktuell geschätzten e-Fkt auf die
		% Verschiebung der Minima zu schließen. Mit diesen angepassten
		% Minima sollte sich im nächsten Schritt eine besser angepasste
		% e-Fkt bestimmen lassen. Dazu schaue ich mir die Maxima
		% an:

		fmax = [];
		%y_sim = Y_orig;
		for ii = 1:numel(fmin)
			mess_min = Y_orig(fmin(ii));
		end


		iter	= 0;
		OK		= false;
		str		= '';
		str_old = '';

		while ~OK

			iter = iter + 1;
			% Finde die Maxima der Hilfsfunktion "y_sim - mess_min
			% - Y_orig"
			fmax = peakfinder((y_sim - mess_min)-(Y_orig),(max(Y_smooth)-min(Y_smooth))/sensivity ,[] , 1, false, false);

			if numel(fmax) < numel(fmin)
				str = ['Zuwenige Maxima (' num2str(numel(fmax)) ') in smoothed-Daten entdeckt (erwartet: ' num2str(numel(fmin)) ...
					')! Detektions-Sensibilität wird angepasst' newline];
				if ~strcmp(str,str_old)
					fprintf(2,str)
				end
				sensivity = sensivity * 1.1;

			elseif numel(fmax) > numel(fmin)
				str = ['Too many maxima (' num2str(numel(fmax)) ') in smoothed data detected (expected: ' num2str(numel(fmin)) ...
					')! Detection sensibilität will be lowered.' newline];
				if ~strcmp(str,str_old)
					fprintf(2,str)
				end

				sensivity = sensivity * 0.8;

			elseif numel(fmax) < 2
				str = ['Too few maxima (' num2str(numel(fmax)) ') in smoothed data detected (at least 2 ' ...
					'are required)! Detection sensibility will be raised' newline];
				if ~strcmp(str,str_old)
					fprintf(2,str)
				end

				sensivity = sensivity * 1.1;

			else
				OK = true;
			end

			if iter > 80
				fprintf(2,['SNR not sufficient! Cannot detect peaks successfully for identification' newline])
				keyboard
			end

			str_old = str;

		end

		disp('Die Auswertung der Hilfsfunktionen ermöglicht eine Modifikation der Minima, um als Stützstellen der neuen Anpassung zu dienen.')


		for ii = 1:numel(fmax)
			if ii > numel(fmax)
				disp(['Verbesserung des Zeitpunkts des ' num2str(ii,'%01.0g') '.ten Minimums auf t = NaN' ...
				' (Original-Daten: t = ' num2str(T_orig(fmin_orig(ii))) ')'])
			elseif ii > numel(fmin_orig)
				disp(['Verbesserung des Zeitpunkts des ' num2str(ii,'%01.0g') '.ten Minimums auf t = ' num2str(T_orig(fmax(ii)),'%04.3g') ...
				' (Original-Daten: t = NaN )'])
			else
				disp(['Verbesserung des Zeitpunkts des ' num2str(ii,'%01.0g') '.ten Minimums auf t = ' num2str(T_orig(fmax(ii)),'%04.3g') ...
				' (Original-Daten: t = ' num2str(T_orig(fmin_orig(ii))) ')'])
			end
		end	


		t_sim	= T_orig(fmax);
		Y		= Y_orig(fmax);

		% Ein weiteres Problem wird durch die abklingende Amplitude
		% der Schwingung selbst verursacht: Die Minima steigen
		% dadurch nämlich wieder an, sobald die e-Fkt soweit
		% abgeklungen ist, dass die durch sie hervorgerufenen
		% Änderungen vernachlässigbar ist. Im Optimierungsschritt wird
		% "nur" eine fallende e-Fkt angepasst, diese kann die
		% steigenden Werte nicht erreichen. Daher die grobe
		% Anpassung der y-Werte.

		disp('Modifiziere nun die y-Werte der Stützstellen')

		Y_new = Y - (20 - 20 * exp(-t_sim * delta * 0.02)); % exp. Modell - ACHTUNG: Woher nimmt man die Parameterwerte?

		for i = 1:numel(Y_new)
			disp(['Änderung beim ' num2str(i) '.ten Minimum von y = ' num2str(Y(i),'%4.8g') ' auf y = ' num2str(Y_new(i),'%4.8g')])
		end

		disp('Führe nun mit diesen Stützstellen neue Anpassung der e-Fkt aus')

		Y = Y_new;

		[X,FVAL,EXITFLAG,OUTPUT] = fmincon(@expkurve,X,[],[],[],[],[0 0 0],[],[],OPTS);

		StartValue	= X(1);
		Dam			= X(2);
		Offset		= X(3);
		%StartValue2	= X(4);
		%Dam2		= X(5);


		%hold on

		plot(T_orig,Y_orig,':')

		stuetz_h = findobj(fig_h,'Marker','+');
		stuetz_h.MarkerSize = 10;

		y_sim = StartValue .* exp(-Dam .* T_orig) + Offset;

		plot_h.YData = y_sim;
		plot_h.XData = T_orig;

		%plot(T_orig,E,'r');

		% p2_1_offset_b = y_sim(1) - E(1);
		% p2_2_h =  plot(T_orig,E + p2_1_offset_b,'r:','lineWidth',2);

		%diff1 = E; % originale e-Fkt
% 				diff2 = y_sim; % Resultat der Optimierung


		plot(T_orig(fmin),Y_orig(fmin),'x');
%				plot(T_orig(fmin_orig),Y_orig(fmin_orig),'o');

		title('Optimierung der Stützstellen (Minima)')
		legend({'angepasste e-Fkt','Stützstellen (optimierte Minima)','Messdaten-Verlauf','orig. e-Fkt', 'verschobene orig. e-Fkt','ursprüngliche Minima (Stützstellen)','echte Minima'})
		disp([newline 'Ergebnisse der 2. E-Funktion-Anpassung: Startwert = ' num2str(StartValue) '; Offset = ' num2str(Offset) '; Damping = ' num2str(Dam) ])

		%				T_orig = [];

	end

	Y_orig = [];

	disp('===================================')
						   

%%
% 	function I = diffkurve(Offset_param)
						
% 		
% 		%Offset	= PARAM;
% 		I		= sum((diff1-(diff2-Offset_param)).^2)/numel(y_sim);
% 		set(gcf,'name',['Goodness of fit: ' num2str(I,'%2.4e ') ' - Offset: ' num2str(Offset_param,'%2.2e')]);   
% 		 
% 	end

	function I = expkurve(PARAM,OPTS)
		
		StartValue		= PARAM(1);
		Dam				= PARAM(2);
		Offset			= PARAM(3);
% if ndims(PARAM) == 3,
% 	PARAM = PARAM(1,:,:);
% end
% 		MHA_startvalue	= [];
% 		MHA_endvalue	= [];
% 		MHA_peaksize	= [];
		
		if numel(PARAM) > 3
			%StartValue2	= PARAM(4);
			%Dam2			= PARAM(5);
% 			if numel(PARAM) == 8 % should be valid only for method 1
% 				MHA_startvalue	= PARAM(6);
% 				MHA_endvalue	= PARAM(7);
% 				MHA_peaksize	= PARAM(8)/2;
% 			end
		end
		
		%y_plot	= StartValue .* exp(-(Dam) .* t_sim) + Offset; % + StartValue2 .* exp(-Dam2.*t_sim);
		
		if ~isempty(MHA_startvalue) && MHA_endvalue > MHA_startvalue
			% special case for increasing signal level
			y_sim	= StartValue .* (1 - exp(-(Dam) .* t_sim)) + Offset; % + StartValue2 .* exp(-Dam2.*t_sim);
		else
			y_sim	= StartValue .* exp(-(Dam) .* t_sim) + Offset; % + StartValue2 .* exp(-Dam2.*t_sim);
		end
		
  
		if ~ishandle(fig_h)
			fig_h	= figure;
		end
		
		if isempty(plot_h) || ~ishandle(plot_h)
			plot_h	= plot(gca(fig_h),t_sim,y_sim,'b:.', 'tag','sim');
			hold on
			if numel(t_sim) > 10
				plot_orig_h = plot(t_sim,Y,'+','MarkerSize',3);
			else
				plot_orig_h = plot(t_sim,Y,'+','MarkerSize',8);
			end
			
		end
		
		% update
		plot_h.YData = y_sim;
		
		%I = sum((Y - y_sim).^2)/numel(y_sim); %/(numel(Y) * max(Y));
		
		if time_weight
			I = sum(ydiff./exp(0.015.*(t_sim-t_sim(1))))/(numel(Y)*max(Y));
		else
			I = sum(((Y - y_sim)./exp(0.015.*(t_sim-t_sim(1)))).^2)/numel(y_sim); %/(numel(Y) * max(Y));
		end
		
		
%%
		%constraint	= [];
		
		flag		= false;
		
  
 		% Strafterm wenn e-Funktion am Anfang zu hoch/niedrig anfängt
		% Note: Es wird schon bestraft, wenn der Wert genau darüber liegt,
		% denn die e-Fkt soll auf jeden Fall darunter liegen
		%
		% "y_sim" ist die Simulation, "Y" die Measurements
		%
		
		if method == 1
			%constraint = (y_sim(1) - MHA_startvalue)^2;
			constraint = DistanceToIntervall(y_sim(1),MHA_startvalue,MHA_peaksize)^2;
			% if sign(y_sim(1)-Y(1)) ~= sign(mean(diff(Y(1:4))))
			% 	% echte Werte fallen am Anfang, Simulation sollte nicht
			% 	% noch tiefer starten (oder umgekehrt)
			% 	constraint = (y_sim(1)-Y(1))^2;
			% else
			% 	constraint = 0;
			% end
		elseif method == 2
			constraint =  0; % anderes Optimierungsziel ....(y_sim(1)-Y_orig(1))^2;
		end

		if method == 1 && sqrt(constraint) > MHA_peaksize/2 % was: 10
			
			if y_sim(1) < MHA_startvalue % Y(1)

					msg_str = ['Simulierter Anfangswert deutlich zu niedrig! Bestrafung aktiv (+ ~' num2str(round(constraint,-2)) ')'];

					if ~strcmp(msg_str,msg_oldstr) && debug
						fprintf(2,[msg_str  newline])
					end

					msg_oldstr = msg_str;

					flag = true;

			elseif y_sim(1) > MHA_startvalue % Y(1)

					msg_str = ['Simulierter Anfangswert deutlich zu hoch! Bestrafung aktiv (+ ~' num2str(round(constraint,-2)) ')'];

					if ~strcmp(msg_str,msg_oldstr) && debug
						fprintf(2,[msg_str  newline])
					end

					msg_oldstr = msg_str;

					flag = true;
			end
			
		end
		
		if flag
			I = I + constraint;
		end

		% Strafterm wenn e-Funktion am Ende zu hoch/niedrig anfängt
		% Note: Es wird schon bestraft, wenn der Wert genau darüber liegt,
		% denn die e-Fkt soll auf jeden Fall darunter liegen
		
		if method == 1
			%constraint = (y_sim(end) - MHA_endvalue)^2; %(y_sim(end)-Y(end))^2;
			constraint = DistanceToIntervall(y_sim(end),MHA_endvalue,MHA_peaksize)^2;
		elseif method == 2
			constraint = 0; % anderes Optimierungsziel ....(y_sim(end)-Y_orig(end))^2;
		end
		
		if method == 1 && constraint > MHA_peaksize/2 % was: 10
			
			if y_sim(end) < MHA_endvalue % Y(end)

					msg_str = ['Simulierter Endwert deutlich zu niedrig! Bestrafung aktiv (+ ~' num2str(round(constraint,-2)) ')'];

					if ~strcmp(msg_str,msg_oldstr) && debug
						fprintf(2,[msg_str  newline])
					end

					msg_oldstr = msg_str;

					flag = true;

			elseif y_sim(end) > MHA_endvalue % Y(end)

					msg_str = ['Simulierter Endwert deutlich zu hoch! Bestrafung aktiv (+ ~' num2str(round(constraint,-2)) ')'];

					if ~strcmp(msg_str,msg_oldstr) && debug
						fprintf(2,[msg_str  newline])
					end

					msg_oldstr = msg_str;

					flag = true;
			end
			
		end
		
		if flag
			I = I + constraint;
		end		
	
		set(fig_h,'name',['Goodness of fit: ' num2str(I,'%2.4e ') ' - StartValue: ' num2str(StartValue,'%2.2e') ...
			' - Dam: ' num2str(Dam,'%2.3e') ' - Off: ' num2str(Offset,'%2.2e')]); % ' - P1: ' num2str(P1,'%2.2e')]);
		
		drawnow
		
	end

	function distance = DistanceToIntervall(testx, center, range)
		if isempty(center) || isempty(range)
			distance = 0;
			return
		end
		if testx > center + range
			distance = testx - (center+range);
		elseif testx < center - range
			distance = center - range - testx;
		else
			distance = 0;
		end
	end

end
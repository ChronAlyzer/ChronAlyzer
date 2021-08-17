function [x,yMin] = pso(fun,lb,ub,np,inertia,acceleration,iteration,varargin)
%
% [x,yMin] = pso(fun,np,lb,ub,inertia,acceleration,iteration)
%
% Particle Swarm Optimization
% v1.3.0.0
%
% --------------------------
% PSO finds the global minimum for a constraint function (convex or non-convex)
%   with multiple variables using the particle swarm optimization method.
%
%   X = PSO(FUN,np,A,B) starts at np random values within inequalities A*X<=B
%   and finds a minimum X to the function FUN, subject to the linear inequalities A*X <= B.
%   FUN accepts input X and returns a scalar function value F evaluated at X.
%   A is a N*P matrix, where N is the constraint function number and P is 
%   the dimension of the FUN variables. B is a N*1 vector. np is the number
%   of particles you want to use to find the minimum.
%
%   X = PSO(FUN,np,A,B,INERTIA) finds the global minimum of the FUN with a
%   certain INERTIA value. Usually it is set to be 0.1. Inertia means that
%   how much the particles want to stay in where they are currently.
%
%   X = PSO(FUN,np,A,B,INERTIA,CORRECTION_FACTOR) finds the global minimum
%   of FUN with a correction factor with respect to the current global
%   minimum value within the particles. CORRECTION_FACTOR value is always
%   set to be 2.
%
%   X = PSO(FUN,np,A,B,INERTIA,CORRECTION_FACTOR,ITERITION) finds the
%   global minimum of FUN with a certain iteration number. The higher the
%   ITERATION number is, the more accurate the global result will be while
%   the longer the algorithm will run to find the solution. ITERATION value
%   is set to be 50 as default.
%
%   [X,FVAL] = FMINCON(FUN,np,...) returns the value of the objective 
%   function FUN at the solution X.
%
%   Examples:
%     FUN:
%       function [out]=DeJong_f2(in)
%       x= in(:,1);
%       y= in(:,2);
%       out = 100*(x.^2 - y).^2 + (1-x).^2;
%       end
%     np:
%       np = 30; % 20 ~ 50
%     A:
%       A = [eye(2);-eye(2)];
%     B:
%       b = 10*ones(4,1); % -10<=x1<=10, -10<=x2<=10
%     PSO:
%       [x,fval] = pso(@DeJong_f2,np,A,b);
%     
%   Editor: Yan Ou
%   Date: 2013/05/10
%
% --------------------------
%
%
% Editor: Yan Ou
% Date: 2013/10/07
% orginally published on mathworks central
% Cite as: 
% Yan Ou (2013). Particle Swarm Optimization (https://www.mathworks.com/matlabcentral/fileexchange/41708-particle-swarm-optimization), MATLAB Central File Exchange. Retrieved October 10, 2013. 
%
%
% Copyright (c) 2013, Yan Ou
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
% 
% * Redistributions of source code must retain the above copyright notice, this
%   list of conditions and the following disclaimer.
% 
% * Redistributions in binary form must reproduce the above copyright notice,
%   this list of conditions and the following disclaimer in the documentation
%   and/or other materials provided with the distribution
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
% FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
% DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
% OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%
% ----------------------------------------------
% slightly modified and added comments by Norman Violet
% in October/November 2013
% ----------------------------------------------


% set the default value for the inertia, acceleration, iteration

	if nargin < 7

		iteration = 1000;

		if nargin < 6

			acceleration(1:2) = 1.496; % Bratton & Kennedy, Defining a standard for pso, 2007

			if nargin < 5

				inertia = 0.73; % Bratton & Kennedy, Defining a standard for pso, 2007

				if nargin < 4

					np = ceil(10 + 2 * sqrt(2 * length(ub))); % Clerc, Confinements and biases in pso, 2006 - scheint mir ein bisschen wenig (in ABC_Parameteridentifikation wird ein höherer Wert gewählt)

				end

			end

		end
	end

	if isempty(inertia) == 1
		inertia = 0.73;
	end

	if isempty(acceleration) == 1
		acceleration(1:2) = 1.496;
	end

	if isscalar(acceleration)
		acceleration(2) = acceleration;
	end

	if isempty(np),
		np = ceil(10 + 2 * sqrt(2 * length(ub)));
	else
		np = ceil(np);
	end

	xIni = [];
	vIni = [];

	swarm = zeros(np,5,numel(ub));
	% Hinweis zum Aufbau von "swarm"
	% Erste Dimension (Zeilen): Jede Zeile steht für einen Partikel
	% Zweite Dimension enthält die verschiedenen Einträge wie beispielsweise Ort, Geschwindigkeit und Güte
	% Die dritte Dimension ist nur bei einigen Elementen vorhanden, und zwar nur bei Ort und Geschwindigkeit.
	% Gibt es nur einen Optimierungsparameter, so ist "swarm" eine zweidimensionale Matrix. Jeder weitere Parameter
	% führt dann zur dritten Dimension

	for i = 1:np

		result_ok = false;

		while ~result_ok,
			for j = 1:numel(ub),
                % Ursprünglicher Code hat auch ein Problem, wenn lb und
                % ub deutlich kleiner als 1 ist. Im Extremfall wird
                % nämlich immer entweder zu 0 oder zu 1 gerundet.
                % factor berücksichtigt die Dimension der kleinsten (abs) Grenze
                if abs(lb(j)) > sqrt(eps) && abs(ub(j)) > sqrt(eps), 
                    factor = 1000 * max(1,-log10(min([abs(lb(j)) abs(ub(j))] )));
                else
                    factor = 1000;
                end
                %if exist('randi','builtin'), % existiert randi schon? In alten Matlabs nämlich nicht
    			%	xIni(j) = randi([round(lb(j) * factor),            round(ub(j) * factor)],          1, 1) / factor; % wähle zufälligen Ort zwischen "lb" und "ub"
        		%	vIni(j) = randi([round(-abs(ub(j)-lb(j))) * factor/2,round(abs(ub(j)-lb(j))) * factor/2], 1, 1) / factor; % Geschwindigkeitsvektor zufällig, mit Faktor 1/2 (-> 500)
                %else
                    xIni(j) = round(factor*(rand*(ub(j)-lb(j))+lb(j)))/factor;
                    vIni(j) = round(factor*(rand*(ub(j)-lb(j))-0.5*(ub(j)-lb(j))))/factor;
                %end
			end

			swarm(i,1,:) = xIni; % Ort (Parametersatz) eines Partikels
			swarm(i,2,:) = vIni; % Geschwindigkeit(vektor) eines Partikels
			swarm(i,3,:) = xIni; % bisher bester Ort eines Partikels
			swarm(i,4,1) = fun(xIni,varargin{:});  % Gütewert von bisher besten Ort eines Partikels
			%swarm(i,5,:) = NaN[];   % bisher bester globaler Ort

			if isnan(swarm(i,4,1)) || isempty(swarm(i,4,1))
				result_ok = false;
			else
				result_ok = true;
			end
		end
	end




	[tempValue, tempIndex] = min(swarm(:, 4, 1));

	gbest = swarm(tempIndex, 3, :); % gbest = global best

	gbestValue = fun(gbest,varargin{:}); % Initialisierung eines Vektors für alle besten Gütewerte (pro Iteration)
	stopValue = 100; % the stop criteria of the iteration - zweifelhafte Einstellung ....!!!!


	reshaped_ub = reshape(ub,1,1,length(ub));
	reshaped_lb = reshape(lb,1,1,length(lb));			

	% run particle swarm optimization algorithm to converge the particle swarm

	for iter = 1 : iteration

		for i = 1 : np

			% Berechne neuen Partikelort: Alter Ort + Geschwindigkeit
			newParticle = swarm(i, 1, :) + swarm(i, 2, :);

			
			if any(newParticle < reshaped_lb) || any(newParticle > reshaped_ub),
				% Wenn ein Partikel nun außerhalb der Grenzen liegt, muss der Partikel "repariert" werden
				% dazu existieren verschiedene Methoden:
				% 1. "nearest": Der Partikel wird auf die nächstliegende Grenze gesetzt.
				% newParticle = min(newParticle,reshaped_ub);
				% newParticle = max(newParticle,reshaped_lb);
				% 2. "shrink": Der Partikel verfolgt seinen Kurs weiter und stoppt an der Grenze
				
				repair = [];
				
				for j = 1:numel(ub)
					if newParticle(j) < reshaped_lb(j),
						repair(j) = (reshaped_lb(j) - swarm(i,1,j)) / swarm(i,2,j);
					elseif newParticle(j) > reshaped_ub(j)
						repair(j) = (reshaped_ub(j) - swarm(i,1,j)) / swarm(i,2,j);
					else
						repair(j) = 1;
					end
				end
				
				repair		= min(repair);
				newParticle = swarm(i, 1, :) + repair .* swarm(i, 2, :);
				
				% 3. "random": Neuer Partikelort wird wie bei Erstinitialisierung neu gewählt
				% 4. "reflect": Die Partikelbewegung wird an der Grenze reflektiert 
				% 5. "intermediate": Ein neuer Ort zwischen aktuellen und Grenze wird bestimmt
				% 6. "resample": Die Komponenten des Geschwindigkeitsvektor werden zufällig geändert
				

				% Der Geschwindigkeitsvektor sollte ebenfalls angepasst werden, auch hier existieren verschiedene Optionen
				% 1. "unmodified": Vektor bleibt unverändert
				% 2. "adjust": Der Vektor wird so angepasst, dass
				
				swarm(i, 2, :) = newParticle - swarm(i,1,:) .* (1-rand(1,1,length(ub))/3); % damit im nächsten Schritt nicht wieder ganz an den Rand

			end
			
			% calculate the new particle position
			swarm(i, 1, :) = newParticle;

			val = fun(swarm(i,1,:),varargin{:});          % fitness evaluation

			if val == -1,  % durch Report-STOP
				disp('User-Abbruch (Güte == NaN)');
				break
			end
			
			if val < swarm(i, 4, 1)                 % if new position is better
				swarm(i, 3, :)	= swarm(i,1,:);		% aktualisiere besten Ort des Partikels
				swarm(i, 4, 1)	= val;              % und aktualisiere den dazu passenden besten Gütewert
			end
			
		end

		% stop criteria
		if val == -1,
			break
		end		
		
		[tempValue, tempIndex] = min(swarm(:, 4, 1));        % bestimme aktuell beste Gütewert ...

		if (tempValue < gbestValue)

			gbest				= swarm(tempIndex, 3, :);	% .... und den dazugehörigen Ort
			swarm(1,5,:)		= gbest;					% aktualisiere den global besten Ort
			gbestValue(end+1)	= fun(gbest,varargin{:});				% und füge den neuen besten Gütewert in die Liste ein

		end



		% Bestimme neue Geschwindigkeit
		for i = 1:np

			pbest = swarm(i, 3, :); % aktuell bester Ort eines Partikels

			swarm(i, 2, :) = inertia * swarm(i, 2, :) ... % Trägheit x Geschwindigkeit
				+ acceleration(1) * rand(1,1,size(xIni,2)) .* (pbest - swarm(i, 1, :)) ... % Beschleunigung in Richtung des individuell besten Orts
				+ acceleration(2) * rand(1,1,size(xIni,2)) .* (gbest - swarm(i, 1, :));    % Beschleunigung in Richtung des global besten Orts
		end

		
		if numel(gbestValue) > 10

			stopValue			= sum(log(gbestValue(end-10:end)));
			deltaGbestValue		= abs(gbestValue(2:end) - gbestValue(1:end-1));
			deltaGbestValueLog	= log(deltaGbestValue(deltaGbestValue~=0));

			if length(deltaGbestValueLog) > 10
				sumDelta = sum(deltaGbestValueLog(end-10:end));
			else
				sumDelta = sum(deltaGbestValueLog);
			end

			if sumDelta < stopValue/2
				break;
			end

		end

	end

	% Rückgabewerte
	[temp, gbest]	= min(swarm(:, 4, 1)); % bestes Partikel finden
	x				= squeeze(swarm(gbest, 1, :)); % Ort
	%yMin			= fun(x,[],min(gbestValue(gbestValue>0))); % Gütewert ausrechnen und einen letzten Plot darstellen mit den besten Ergebnis
	yMin			= fun(x,varargin{:});
	disp(['Ergebnis der PSO:' char(10) 'Beste erreichte Güte: ' num2str(yMin) ' nach ' num2str(iter) ' Iterationen']);

end
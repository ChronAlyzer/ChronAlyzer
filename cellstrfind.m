function index = cellstrfind(cellstr, suchstring, varargin)
	%
	% index = cellstrfind({'ABC' 'BBB' 'abc' 'xyz'},'B') --> index = [ 1 2 3]
	%
	% mit der Option 'exact' wird die exakte Zeichenkette f¸r eine ‹bereinstimmung verlangt
	%
	% index = cellstrfind({'ABC' 'BBB' 'abc' 'xyz'},'ABC','exact') --> index =  1 oder
	% index = cellstrfind({'ABC' 'BBB' 'abc' 'xyz'},'ABC','match') --> index =  1	
	%
	% mit der Option 'unsorted' wird ein case-insensitive "Mengenvergleich" durchgef¸hrt
	% index = cellstrfind({'ABC' 'CBA' 'abc' 'abcdef'},'ABC','unsorted') --> index =  [1 2 3 4] oder	
	% index = cellstrfind({'ABC' 'CBA' 'abc' 'abcdef'},'ABCD','unsorted') --> index =  [4] oder	
	%
	% N. Violet 2009
	%
	% cellstrfind sucht in einem Cell-Array nach suchstring und
	% gibt die Indizes der Cells zur¸ck, in denen suchstring gefunden wird.
	% "option" kann den String 'exact' enthalten, dann wird nuch nur ein Teil-String
	% gesucht, sondern der gesamte String identisch sein.
	%
	% Der Suchstring kann ein regul‰rer Ausdruck sein, da 'regexp' verwendet wird.
	% Tipp: suchstring = '^Text' sucht in den einzelnen Zeichenketten von cellstr 
	% am jeweiligen Zeilenanfang nach Text, w‰hrend
	% suchstring = 'Text$' nur Treffer mit Text am Zeilenende findet
	%
	% ACHTUNG: Da der Suchstring ein regul‰rer Ausdruck sein kann, wird er auch immer so aufgefasst.
	% In der Regel werden f¸r einen reg. Ausdruck bestimmte Zeichenfolgen benutzt, die selten in
	% normalen Texten auftauchen, zum Beispiel "$" oder "\n", aber leider auch Klammern.
	% Die Suche nach "Test(normal)" wird also als regul‰rer Ausdruck aufgefasst und dementsprechend
	% f¸hrt der Vergleich mit dem Text (!) "Test(normal)" zu keiner ‹bereinstimmung!.
	% Problematisch sind runde Klammernpaare, eckige Klammernpaare, geschweifte Klammernpaare mit
	% einer Zahl darin, das Caret-Zeichen (^), Dollarzeichen ($), in einigen F‰llen das
	% Backslash-Zeichen (\) wenn gefolgt von bestimmten Buchstaben oder einer Zahl, der Hochstrich
	% (|), der Punkt (.) K÷NNTE zu einem Eindeutigkeitsproblem f¸hren da er ein wildcard-Zeichen
	% ist, w‰hrend die anderen wildcards; das Fragezeichen, der Stern (*) und das Pluszeichen sicher
	% zu einem Fehler f¸hren,
	% 
	
	if ~ischar(suchstring), error('Kein String ¸bergeben!'); end;
	if ~iscell(cellstr), error('Keine Cell ¸bergeben!');  end;
	 
	%DEFAULTS:
	match		= false;
	matchCase	= false;
	matchOrder	= true;
	
	if nargin > 2, %... Optionen angegeben:
		for k = 1:length(varargin),
			switch lower(varargin{k}),
				case {'matchorder','match order', 'regexp'},			matchOrder	= true;
				case {'exakt', 'exact', 'match'},						match		= true;
				case {'matchcase', 'match case'},						matchCase	= true;
				case {'no match order', 'unsorted search', 'unsorted'},	matchOrder	= false;
				otherwise,
					error('Unbekannte Option ¸bergeben');
			end % switch
		end % for k
	end

	if (~isempty(cellstr) && ~iscell(cellstr)) || iscell(suchstring),
		error('Falsche ‹bergabe-Parameter')
	end

	index = [];
	
	if match, %exakt Match --> strcmp (keine Wildcards/regexp's erlaubt)
		
		for i = 1:numel(cellstr),
			if strcmp(cellstr{i},suchstring),	index = [index i];				end;
		end
		
	else % mit Wildcards (regexp) oder mit beliebiger Reihenfolge oder Groﬂ/Kleinschreibung egal
		
		if ~matchCase,
			suchstring = lower(suchstring);
			for i = 1:numel(cellstr),			cellstr{i} = lower(cellstr{i});	end;
		end
		
		if matchOrder || nargin == 2,
			for i = 1:numel(cellstr),
				if  ~isempty( cellstr{i}) && ~isempty(  regexp( cellstr{i}, suchstring, 'once' )  ),
					index = [index i];
				end
			end
		else
			%Reihenfolge egal:
			for i = 1:numel(cellstr),
				if  all(ismember( suchstring, cellstr{i})),
					index = [index i];
				end
			end
		end
	end
	
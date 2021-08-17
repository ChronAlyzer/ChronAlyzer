function quote = quotes()

% author: Norman Violet
% part of "ChronAlyzer" 

% Example file

quotes_source = ...
{'" The best way to predict the future is to invent it."         - Alan Kay',
'"A pessimist sees the difficulty in every opportunity; an optimist sees the opportunity in every difficulty."         - Sir Winston Churchill (1874-1965)',
'"A pint of sweat saves a gallon of blood."         - General George S. Patton (1885-1945)',
'"Don''t let it end like this. Tell them I said something."         - last words of Pancho Villa (1877-1923)',
'"Every normal man must be tempted at times to spit upon his hands, hoist the black flag, and begin slitting throats."         - Henry Louis Mencken (1880-1956)',
'"Everything that can be invented has been invented."         - Charles H. Duell, Commissioner, U.S. Office of Patents, 1899',
};


r_str = '000'; % add more zeroes if you have more than 999 lines of quotes, modify the markes code lines also

while strcmp(r_str,'000') % modify this too
	% my own random function
	tic;
	pause(0.01);
	t		= toc;
	t_str	= num2str(t*rand,'%15.14f');  % modify this too
	r_str	= t_str(end-3:end-1); % modify this too
end
r		= str2num(r_str);
idx		= ceil(r/1000 * numel(quotes_source)); % modify this too

if numel(quotes_source) > 999 % modify this too
	warning('Modify source code, there are too many entries! :-) ')
end

quote = [quotes_source{idx} newline];

end
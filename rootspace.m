function y = rootspace(d1, d2, n)
%LINSPACE Linearly spaced vector.
%   LINSPACE(X1, X2) generates a row vector of 100 linearly
%   equally spaced points between X1 and X2.
%
%   LINSPACE(X1, X2, N) generates N points between X1 and X2.
%   For N = 1, LINSPACE returns X2.
%
%   Class support for inputs X1,X2:
%      float: double, single
%
%   See also LOGSPACE, COLON.

%   Copyright 1984-2016 The MathWorks, Inc.
% modified: "reverse square" space

if nargin == 2
    n = 50;
end


y = linspace(d1, d2, n).^.75;

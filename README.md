# ChronAlyzer 👋

This progam was published together with a tech report, which you can find here <...>. For the short documentation/guide, I provided here, it is strongly recommended that you read that tech report first. At least, as long as program and documentation are still under further development.

## What does the ChronAlyzer do (very short version)?

### Motivation:
The circadian rhythm is of central importance for living organisms and allows them to adjust their physiological parameters to recurring environmental changes. It is characterized by a 24-hour rhythm triggered by the day-night cycle. A facing challenge is the visualization and characterization of rhythmic signals generated by cellular reporter systems, employing clock controlled rhythmic Luciferase activity or GFP expression, as only limited software are available for the determination of the physical parameters of such signals. 

### Result:
Here we present the software ChronAlyzer, which is applicable for the processing and characterization of rhythmic signals. It allows the selection and grouping of technical and biological replicates as well as an interactive and transparent processing of comprehensive datasets. 

### Work-flow:
1. Import data files from Plate Readers (xls or csv) - an adaption to different devices might be necessary (please contact me). 
2. Check time-series for outliers and use replicate groups. 
3. Start analysis for finding these parameter: amplitude, period length, phase-shift and damping (an effect often observed in in-vitro experiments). 

## Provided files and requirements

You can download the Matlab script files (written in Matlab2017b) or the ready-to-use Win10 executable. This executable does not contain the Matlab runtime library, but you can download it for free at, https://de.mathworks.com/products/compiler/matlab-runtime.html Please carefully select the correct version: R2017b (9.3) !

For installing the Matlab runtime library you'll need Windows administator rights! Here are more information about installing the runtime library: https://de.mathworks.com/help/compiler_sdk/dotnet/install-the-matlab-runtime.html

## Author
Norman Violet
Bundesinstitut für Risikobewertung
Berlin, Germany



## Third-party functions
This program uses some functions provided by others. These are: asort.m (alphanumeric sort), findextrema (find extreme values, peaks) and pso (particle swarm optimzation), all downloaded from MATLAB Central File Exchange. The authorships are listed here, but documented in more detail in the corresponding source files:

### ASORT
%(version of 13th December 2006)
% 
% downloaded from Mathworks File Exchange February 2017
% 
% https://de.mathworks.com/matlabcentral/fileexchange/7212-asort-a-pedestrian-alphanumeric-string-sorter

### FINDEXTREMA
% Siyi Deng; 05-29-2009;
% sdeng@uci.edu; UCI HNL;
% https://de.mathworks.com/matlabcentral/fileexchange/24306-findextrema

### PSO
% Editor: Yan Ou
% Date: 2013/10/07
% orginally published on mathworks central
% Cite as: 
% Yan Ou (2013). Particle Swarm Optimization (https://www.mathworks.com/matlabcentral/fileexchange/41708-particle-swarm-optimization), MATLAB Central File Exchange.

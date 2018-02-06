%   SELM - Stacked Extreme Learning Machine Class
%   Train and Predict a Stacked network based on Extreme Learning Machine
%
%   This code was implemented based on the following paper:
%
%   [1] Zhou, H., Huang, G.-B., Lin, Z., Wang, H., & Soh, Y. C. (2014).
%       Stacked Extreme Learning Machines.
%       IEEE Transactions on Cybernetics, PP(99), 1.
%       https://doi.org/10.1109/TCYB.2014.2363492
%       (http://ieeexplore.ieee.org/document/6937189/)
%
%
%   Attributes:
%       Attributes between *.* must be informed.
%       S-ELM objects must be created using name-value pair arguments (see the Usage Example).
%
%         *numberOfInputNeurons*:   Number of neurons in the input layer.
%                Accepted Values:   Any positive integer.
%
%          numberOfHiddenNeurons:   Number of neurons in the hidden layer
%                Accepted Values:   Any positive integer (defaut = 1000).
%
%               reducedDimension:   Number of nodes after the PCA dimensionality reduction. See [1].
%                Accepted Values:   Any integer between 1 and numberOfInputNeurons-1. (default 100)
%
%        regularizationParameter:   Regularization Parameter (defaut = 1000)
%                Accepted Values:   Any positive real number.
%
%             maxNumberOfModules:   Number of modules of the network
%                Accepted Values:   Any positive integer number. (default = 100)
%
%             activationFunction:   Activation funcion for hidden layer
%                Accepted Values:   Function handle (see [1]) or one of these strings:
%                                       'sig':     Sigmoid (default)
%                                       'sin':     Sine
%                                       'hardlim': Hard Limit
%                                       'tribas':  Triangular basis function
%                                       'radbas':  Radial basis function
%
%                           seed:   Seed to generate the pseudo-random values.
%                                   This attribute is for reproducible research.
%                Accepted Values:   RandStream object or a integer seed for RandStream.
%
%       Attributes generated by the code:
%
%                    inputWeight:   Weight matrix that connects the input
%                                   layer to the hidden layer
%
%            biasOfHiddenNeurons:   Bias of hidden units
%
%                   outputWeight:   Weight matrix that connects the hidden
%                                   layer to the output layer

%                 stackedModules:   List of module objects of the network
%
%
%   Methods:
%
%       obj = SELM(varargin):        Creates RELM objects. varargin should be in
%                                    pairs. Look attributes
%
%       obj = obj.train(X,Y):        Method for training. X is the input of size N x n,
%                                    where N is (# of samples) and n is the (# of features).
%                                    Y is the output of size N x m, where m is (# of multiple outputs)
%
%       Yhat = obj.predict(X):       Predicts the output for X.
%
%   Usage Example:
%
%       load iris_dataset.mat
%       X    = irisInputs';
%       Y    = irisTargets';
%       selm  = SELM('numberOfInputNeurons', 4, 'numberOfHiddenNeurons', 100);
%       selm  = selm.train(X, Y);
%       Yhat = selm.predict(X)

%   License:
%
%   Permission to use, copy, or modify this software and its documentation
%   for educational and research purposes only and without fee is here
%   granted, provided that this copyright notice and the original authors'
%   names appear on all copies and supporting documentation. This program
%   shall not be used, rewritten, or adapted as the basis of a commercial
%   software or hardware product without first obtaining permission of the
%   authors. The authors make no representations about the suitability of
%   this software for any purpose. It is provided "as is" without express
%   or implied warranty.
%
%       Federal University of Espirito Santo (UFES), Brazil
%       Computers and Neural Systems Lab. (LabCISNE)
%       Authors:    F. K. Inaba, B. L. S. Silva, D. L. Cosmo
%       email:      labcisne@gmail.com
%       website:    github.com/labcisne/ELMToolbox
%       date:       Jan/2018

classdef SELM
    properties (SetAccess = protected, GetAccess = public)
        reducedDimension = 100
        stackedModules
        maxNumberOfModules = 100
        activationFunction = @(x) 1 ./ (1 + exp(-x));
        numberOfHiddenNeurons = 1000;
        numberOfInputNeurons
        regularizationCoefficient = 1000
        seed = [];
    end
    
    methods
        function obj = SELM(varargin)
            
            if mod(nargin,2) ~= 0
                exception = MException('SELM:ParameterError','Params must be given in pairs');
                throw (exception)
            end
            
            for i=1:2:nargin
                if isprop(obj,varargin{i})
                    obj.(varargin{i}) = varargin{i+1};
                else
                    exception = MException('SELM:ParameterError','Given parameter does not exist');
                    throw (exception)
                end
            end
            
            if isnumeric(obj.seed) && ~isempty(obj.seed)
                obj.seed = RandStream('mt19937ar','Seed', obj.seed);
            elseif ~isa(obj.seed, 'RandStream')
                obj.seed = RandStream.getGlobalStream();
            end
            
            if isequal(class(obj.activationFunction),'char')
                switch lower(obj.activationFunction)
                    case {'sig','sigmoid'}
                        %%%%%%%% Sigmoid
                        obj.activationFunction = @(tempH) 1 ./ (1 + exp(-tempH));
                    case {'sin','sine'}
                        %%%%%%%% Sine
                        obj.activationFunction = @(tempH) sin(tempH);
                    case {'hardlim'}
                        %%%%%%%% Hard Limit
                        obj.activationFunction = @(tempH) double(hardlim(tempH));
                    case {'tribas'}
                        %%%%%%%% Triangular basis function
                        obj.activationFunction = @(tempH) tribas(tempH);
                    case {'radbas'}
                        %%%%%%%% Radial basis function
                        obj.activationFunction = @(tempH) radbas(tempH);
                        %%%%%%%% More activation functions can be added here
                end
            elseif ~isequal(class(obj.activationFunction),'function_handle')
                exception = MException('SELM:activationFunctionError','Hidden activation function not supported');
                throw (exception)
            end
            
            obj.stackedModules = [];
            
        end
        
        function self = train(self,inputData,outputData)
            lastHiddenOutput = [];
            while length(self.stackedModules) < self.maxNumberOfModules
                
                params = cell(1,2*8);
                params(1:2) = {'numberOfInputNeurons',self.numberOfInputNeurons};
                params(3:4) = {'numberOfHiddenNeurons',self.numberOfHiddenNeurons};
                params(5:6) = {'regularizationParameter',self.regularizationCoefficient};
                params(7:8) = {'activationFunction',self.activationFunction};
                params(9:10) = {'reducedDimension',self.reducedDimension};
                params(11:12) = {'isFirstLayer',isempty(self.stackedModules)};
                params(13:14) = {'isLastLayer',isequal(length(self.stackedModules),self.maxNumberOfModules-1)};
                params(15:16) = {'seed',self.seed};
                
                newModule = SELMModule(params{:});
                [newModule, lastHiddenOutput] = newModule.train(inputData,outputData,lastHiddenOutput);
                self.stackedModules = [self.stackedModules, newModule];
            end
        end
        
        function outhat = predict(self, inputData)
            lastHiddenOutput = [];
            for i = 1:length(self.stackedModules)-1
                lastHiddenOutput = self.stackedModules(i).hiddenLayerOutput(inputData,lastHiddenOutput)*self.stackedModules(i).pcaMatrix;
            end
            outhat = self.stackedModules(end).predict(inputData,lastHiddenOutput);
        end
        
        
        % Function used to predict the outputs in every module
        % If you want to use this function, please comment the line
        % "self.outputWeight = [];" in the training function of the
        % SELMModule class. These variables are not needed to predict
        % the final output of the network, so they are 'cleared'. However,
        % they are needed to predict the output in every module.
        %
        %         function predCell = predictModules(self,inputData)
        %
        %             lastHiddenOutput = [];
        %             for i = 1:length(self.stackedLayers)-1
        %                 predCell{i} = self.stackedLayers(i).predict(inputData,lastHiddenOutput);
        %                 lastHiddenOutput = self.stackedLayers(i).hiddenLayerOutput(inputData,lastHiddenOutput)*self.stackedLayers(i).pcaMatrix;
        %
        %             end
        %             outhat = self.stackedLayers(end).predict(inputData,lastHiddenOutput);
        %
        %
        %             predCell{i+1} = outhat;
        %
        %         end
        
    end
    
end
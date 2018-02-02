% OSRELM - Online Sequential Regularized Extreme Learning Machine Class
%   Train and Predict a SLFN based on Online Sequential Regularized Extreme Learning Machine
%
%   This code was implemented based on the following paper:
%
%   [1] Zhifei Shao, Meng Joo Er, An online sequential learning algorithm 
%       for regularized Extreme Learning Machine, Neurocomputing, Volume 173, 
%       Part 3, 2016, Pages 778-788, ISSN 0925-2312, 
%       https://doi.org/10.1016/j.neucom.2015.08.029.
%       (http://www.sciencedirect.com/science/article/pii/S0925231215011820)
%        
%   Attributes: 
%       Attributes between *.* must be informed.
%       OSRELM objects must be created using name-value pair arguments (see the Usage Example).
%
%         *numberOfInputNeurons*:   Number of neurons in the input layer.
%                Accepted Values:   Any positive integer.
%
%          numberOfHiddenNeurons:   Number of neurons in the hidden layer
%                Accepted Values:   Any positive integer (defaut = 1000).
%
%       regularizationParameter:   Regularization Parameter (defaut = 1000)
%                Accepted Values:   Any positive real number.
%
%           activationFunction:     Activation funcion for hidden layer   
%              Accepted Values:     Function handle (see [1]) or one of these strings:
%                                       'sig':     Sigmoid (default)
%                                       'sin':     Sine
%                                       'hardlim': Hard Limit
%                                       'tribas':  Triangular basis function
%                                       'radbas':  Radial basis function
%
%                         seed:     Seed to generate the pseudo-random values.
%                                   This attribute is for reproducible research.
%              Accepted Values:     RandStream object or a integer seed for RandStream.
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
%
%               pMat, tMat, hMat:   Matrices used for sequentially updating  
%                                   the outputWeight matrix
%
%   Methods:
%
%         obj = OSRELM(varargin):   Creates OSRELM objects. varargin should be in
%                                   pairs. Look attributes.
%
%           obj = obj.train(X,Y):   Method for training. X is the input of size N x n,
%                                   where N is (# of samples) and n is the (# of features).
%                                   Y is the output of size N x m, where m is (# of multiple outputs)
%                            
%          Yhat = obj.predict(X):   Predicts the output for X.
%
%   Usage Example:
%
%       load iris_dataset.mat
%       X    = irisInputs';
%       Y    = irisTargets';
%       osrelm  = OSRELM('numberOfInputNeurons', 4, 'numberOfHiddenNeurons',100);
%       osrelm  = osrelm.train(X, Y);
%       Yhat = osrelm.predict(X)

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


classdef OSRELM
    properties
        regularizationParameter = 1000
        numberOfHiddenNeurons = 1000
        activationFunction = 'sig'
        numberOfInputNeurons = []
        inputWeight = []
        biasOfHiddenNeurons = []
        outputWeight = []
        seed = []
        pMat = []
        tMat = []
        hMat = []
    end
    methods
        function obj = OSRELM(varargin)
            for i = 1:2:nargin
                obj.(varargin{i}) = varargin{i+1};
            end
            if isnumeric(obj.seed) && ~isempty(obj.seed)
                obj.seed = RandStream('mt19937ar','Seed', obj.seed);
            elseif ~isa(obj.seed, 'RandStream')
                obj.seed = RandStream.getGlobalStream();
            end
            if isempty(obj.numberOfInputNeurons)
                throw(MException('OSRELM:EmptynumberOfInputNeurons','Empty Number of Input Neurons'));
            end
            obj.inputWeight = rand(obj.seed, obj.numberOfInputNeurons, obj.numberOfHiddenNeurons)*2-1;
            obj.biasOfHiddenNeurons = rand(obj.seed, 1, obj.numberOfHiddenNeurons);
            
            if ~isa(obj.activationFunction,'function_handle') && ischar(obj.activationFunction)
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
            else
                throw(MException('OSRELM:activationFunctionError','Error Activation Function'));
            end
        end
        function self = train(self, X, Y)
            tempH = X*self.inputWeight + repmat(self.biasOfHiddenNeurons,size(X,1),1);
            H = self.activationFunction(tempH);
            clear X;
            if isempty(self.pMat)
                if(size(H,1)<self.numberOfHiddenNeurons)                    
                    self.hMat = H;
                    self.tMat = Y; clear H Y;
                    self.pMat = pinv(self.hMat*self.hMat' + eye(size(self.hMat,1))/self.regularizationParameter);
                    self.outputWeight = self.hMat' * ((self.hMat*self.hMat' + eye(size(self.hMat,1))/self.regularizationParameter) \ self.tMat);
                else                    
                    self.pMat = pinv(eye(self.numberOfHiddenNeurons)/self.regularizationParameter + H'*H);
                    self.outputWeight = (eye(self.numberOfHiddenNeurons)/self.regularizationParameter + H' * H) \ H' * Y;                    
                end
            else
                if(size(self.pMat,1)<self.numberOfHiddenNeurons)
                    if ((size(self.pMat,1)+size(H,1))>self.numberOfHiddenNeurons) 
                        self.hMat = [self.hMat; H];
                        self.tMat = [self.tMat; Y]; clear H Y;
                        self.pMat = pinv(eye(self.numberOfHiddenNeurons)/self.regularizationParameter + self.hMat'*self.hMat);
                        self.outputWeight = (eye(self.numberOfHiddenNeurons)/self.regularizationParameter + self.hMat' * self.hMat) \ self.hMat' * self.tMat;
                        self.hMat = [];
                        self.tMat =[];
                    else                              
                        invS = pinv((H*H'+eye(size(H,1))/self.regularizationParameter)-H*self.hMat'*self.pMat*self.hMat*H');
                        A = self.pMat + self.pMat*self.hMat*H'*invS*H*self.hMat'*self.pMat;
                        B = -self.pMat*self.hMat*H'*invS;
                        C = -invS*H*self.hMat'*self.pMat;
                        self.hMat = [self.hMat; H];
                        self.pMat = [A B; C invS];
                        self.tMat = [self.tMat; Y]; clear H Y A B C invS;
                        self.outputWeight = self.hMat' * self.pMat * self.tMat;
                    end
                else                    
                    self.pMat = self.pMat - self.pMat * H' * ((eye(size(H,1)) + H * self.pMat * H') \ H) * self.pMat;
                    self.outputWeight = self.outputWeight + self.pMat * H' * (Y - H * self.outputWeight);
                end                
            end
        end
        
        function Yhat = predict(self, X)
            tempH = X*self.inputWeight + repmat(self.biasOfHiddenNeurons,size(X,1),1);
            clear X;
            H = self.activationFunction(tempH);
            Yhat = H * self.outputWeight;
        end
    end
end
%% trainMLModels.m
% Treina modelos de machine learning para correlacionar parâmetros de síntese com propriedades
%
% Sintaxe:
%   [models, results] = trainMLModels(samples, varargin)
%
% Parâmetros de Entrada:
%   samples  - Célula ou array de estruturas de amostras com dados analisados
%   varargin - Pares nome-valor para parâmetros opcionais:
%     'TargetProperties'   - Propriedades alvo para predição (cell array, padrão: todas)
%     'InputFeatures'      - Características de entrada para os modelos (cell array, padrão: automático)
%     'ModelTypes'         - Tipos de modelos a treinar (cell array, padrão: {'regression', 'svm', 'ann'})
%     'ValidationMethod'   - Método de validação ('kfold', 'holdout', padrão: 'kfold')
%     'ValidationParam'    - Parâmetro de validação (k para k-fold, fração para holdout, padrão: 5)
%     'Standardize'        - Padronizar dados (padrão: true)
%     'OptimizeHyperparams' - Otimizar hiperparâmetros (padrão: true)
%
% Saída:
%   models  - Estrutura contendo os modelos treinados
%   results - Estrutura contendo resultados da validação e métricas de desempenho
%
% Exemplo:
%   [models, results] = trainMLModels(samples, 'ModelTypes', {'regression', 'ann'});
%
% Ver também: predictProperties, visualizeCorrelations, extractFeatures

function [models, results] = trainMLModels(samples, varargin)
    % Verificar argumentos de entrada
    if ~iscell(samples) && ~isstruct(samples)
        error('O parâmetro "samples" deve ser um array de estruturas ou uma célula de amostras.');
    end
    
    % Converter para célula se for estrutura
    if isstruct(samples) && ~isempty(samples)
        if numel(samples) == 1
            samples_cell = {samples};
        else
            samples_cell = cell(1, numel(samples));
            for i = 1:numel(samples)
                samples_cell{i} = samples(i);
            end
        end
    else
        samples_cell = samples;
    end
    
    % Verificar se há amostras suficientes
    if numel(samples_cell) < 3
        error('São necessárias pelo menos 3 amostras para treinar modelos de machine learning.');
    end
    
    % Configurar parser de entrada
    p = inputParser;
    p.CaseSensitive = false;
    p.KeepUnmatched = true;
    
    % Adicionar parâmetros
    addParameter(p, 'TargetProperties', {}, @(x) isempty(x) || iscell(x));
    addParameter(p, 'InputFeatures', {}, @(x) isempty(x) || iscell(x));
    addParameter(p, 'ModelTypes', {'regression', 'svm', 'ann'}, @(x) iscell(x));
    addParameter(p, 'ValidationMethod', 'kfold', @(x) ismember(lower(x), {'kfold', 'holdout'}));
    addParameter(p, 'ValidationParam', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'Standardize', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
    addParameter(p, 'OptimizeHyperparams', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
    
    % Analisar argumentos
    parse(p, varargin{:});
    
    % Extrair características e propriedades das amostras
    [features, properties, feature_names, property_names] = extractFeatures(samples_cell, ...
        'TargetProperties', p.Results.TargetProperties, ...
        'InputFeatures', p.Results.InputFeatures);
    
    % Inicializar estruturas de saída
    models = struct();
    results = struct(...
        'feature_names', {feature_names}, ...
        'property_names', {property_names}, ...
        'validation_method', p.Results.ValidationMethod, ...
        'validation_param', p.Results.ValidationParam, ...
        'model_metrics', struct(), ...
        'feature_importance', struct() ...
    );
    
    % Padronizar dados se solicitado
    if p.Results.Standardize
        [features_std, mu_features, sigma_features] = zscore(features);
        [properties_std, mu_properties, sigma_properties] = zscore(properties);
        
        % Armazenar parâmetros de padronização
        results.standardization = struct(...
            'features_mean', mu_features, ...
            'features_std', sigma_features, ...
            'properties_mean', mu_properties, ...
            'properties_std', sigma_properties ...
        );
        
        % Usar dados padronizados para treinamento
        X = features_std;
        Y = properties_std;
    else
        X = features;
        Y = properties;
    end
    
    % Treinar modelos para cada propriedade alvo
    for i = 1:length(property_names)
        property_name = property_names{i};
        y = Y(:, i);
        
        % Inicializar estrutura para esta propriedade
        models.(property_name) = struct();
        results.model_metrics.(property_name) = struct();
        
        % Treinar diferentes tipos de modelos
        for j = 1:length(p.Results.ModelTypes)
            model_type = lower(p.Results.ModelTypes{j});
            
            % Treinar modelo específico
            switch model_type
                case 'regression'
                    [model, metrics] = trainRegressionModel(X, y, feature_names, property_name, p.Results);
                case 'svm'
                    [model, metrics] = trainSVMModel(X, y, feature_names, property_name, p.Results);
                case 'ann'
                    [model, metrics] = trainANNModel(X, y, feature_names, property_name, p.Results);
                case 'ensemble'
                    [model, metrics] = trainEnsembleModel(X, y, feature_names, property_name, p.Results);
                otherwise
                    warning('Tipo de modelo desconhecido: %s. Ignorando.', model_type);
                    continue;
            end
            
            % Armazenar modelo e métricas
            models.(property_name).(model_type) = model;
            results.model_metrics.(property_name).(model_type) = metrics;
        end
        
        % Calcular importância das características para esta propriedade
        results.feature_importance.(property_name) = calculateFeatureImportance(X, y, feature_names, models.(property_name));
    end
    
    % Calcular correlações entre características e propriedades
    results.correlations = calculateCorrelations(features, properties, feature_names, property_names);
    
    % Exibir mensagem de confirmação
    fprintf('Treinamento de modelos concluído com sucesso.\n');
    fprintf('Treinados %d modelos para %d propriedades alvo.\n', ...
            length(p.Results.ModelTypes), length(property_names));
end

% Função auxiliar para treinar modelo de regressão linear
function [model, metrics] = trainRegressionModel(X, y, feature_names, property_name, params)
    % Configurar validação cruzada
    if strcmpi(params.ValidationMethod, 'kfold')
        cv = cvpartition(length(y), 'KFold', params.ValidationParam);
    else % holdout
        cv = cvpartition(length(y), 'HoldOut', params.ValidationParam);
    end
    
    % Inicializar arrays para armazenar resultados da validação
    n_folds = cv.NumTestSets;
    rmse_values = zeros(n_folds, 1);
    r2_values = zeros(n_folds, 1);
    mae_values = zeros(n_folds, 1);
    models_cv = cell(n_folds, 1);
    
    % Realizar validação cruzada
    for k = 1:n_folds
        % Dividir dados
        if strcmpi(params.ValidationMethod, 'kfold')
            train_idx = cv.training(k);
            test_idx = cv.test(k);
        else % holdout
            train_idx = cv.training;
            test_idx = cv.test;
        end
        
        X_train = X(train_idx, :);
        y_train = y(train_idx);
        X_test = X(test_idx, :);
        y_test = y(test_idx);
        
        % Treinar modelo
        if params.OptimizeHyperparams
            % Usar stepwiselm para seleção automática de características
            mdl = stepwiselm(X_train, y_train, 'linear', ...
                'Upper', 'linear', ... % Modelo linear sem interações
                'Criterion', 'aic', ... % Critério de informação de Akaike
                'PEnter', 0.05, ... % p-valor para entrar no modelo
                'PRemove', 0.10, ... % p-valor para remover do modelo
                'Verbose', 0); % Não mostrar saída
        else
            % Modelo de regressão linear simples
            mdl = fitlm(X_train, y_train);
        end
        
        % Armazenar modelo
        models_cv{k} = mdl;
        
        % Fazer predições
        y_pred = predict(mdl, X_test);
        
        % Calcular métricas
        rmse_values(k) = sqrt(mean((y_test - y_pred).^2));
        r2_values(k) = 1 - sum((y_test - y_pred).^2) / sum((y_test - mean(y_test)).^2);
        mae_values(k) = mean(abs(y_test - y_pred));
    end
    
    % Treinar modelo final com todos os dados
    if params.OptimizeHyperparams
        final_model = stepwiselm(X, y, 'linear', ...
            'Upper', 'linear', ...
            'Criterion', 'aic', ...
            'PEnter', 0.05, ...
            'PRemove', 0.10, ...
            'Verbose', 0);
    else
        final_model = fitlm(X, y);
    end
    
    % Extrair coeficientes e termos do modelo
    coefficients = final_model.Coefficients.Estimate;
    variable_names = final_model.CoefficientNames;
    
    % Criar estrutura do modelo
    model = struct(...
        'type', 'regression', ...
        'model', final_model, ...
        'coefficients', coefficients, ...
        'variable_names', {variable_names}, ...
        'feature_names', {feature_names}, ...
        'property_name', property_name ...
    );
    
    % Criar estrutura de métricas
    metrics = struct(...
        'rmse_mean', mean(rmse_values), ...
        'rmse_std', std(rmse_values), ...
        'r2_mean', mean(r2_values), ...
        'r2_std', std(r2_values), ...
        'mae_mean', mean(mae_values), ...
        'mae_std', std(mae_values), ...
        'cv_models', {models_cv}, ...
        'cv_partition', cv ...
    );
end

% Função auxiliar para treinar modelo SVM
function [model, metrics] = trainSVMModel(X, y, feature_names, property_name, params)
    % Configurar validação cruzada
    if strcmpi(params.ValidationMethod, 'kfold')
        cv = cvpartition(length(y), 'KFold', params.ValidationParam);
    else % holdout
        cv = cvpartition(length(y), 'HoldOut', params.ValidationParam);
    end
    
    % Inicializar arrays para armazenar resultados da validação
    n_folds = cv.NumTestSets;
    rmse_values = zeros(n_folds, 1);
    r2_values = zeros(n_folds, 1);
    mae_values = zeros(n_folds, 1);
    models_cv = cell(n_folds, 1);
    
    % Realizar validação cruzada
    for k = 1:n_folds
        % Dividir dados
        if strcmpi(params.ValidationMethod, 'kfold')
            train_idx = cv.training(k);
            test_idx = cv.test(k);
        else % holdout
            train_idx = cv.training;
            test_idx = cv.test;
        end
        
        X_train = X(train_idx, :);
        y_train = y(train_idx);
        X_test = X(test_idx, :);
        y_test = y(test_idx);
        
        % Treinar modelo
        if params.OptimizeHyperparams
            % Otimizar hiperparâmetros
            svm_params = struct(...
                'BoxConstraint', optimizableVariable('BoxConstraint', [1e-3, 1e3], 'Transform', 'log'), ...
                'Epsilon', optimizableVariable('Epsilon', [1e-3, 1], 'Transform', 'log'), ...
                'KernelFunction', categorical({'linear', 'gaussian'}) ...
            );
            
            % Função objetivo para otimização
            objective = @(params) kfoldLoss(fitrsvm(X_train, y_train, ...
                'BoxConstraint', params.BoxConstraint, ...
                'Epsilon', params.Epsilon, ...
                'KernelFunction', char(params.KernelFunction), ...
                'Standardize', true, ...
                'KFold', 3));
            
            % Realizar otimização bayesiana
            results = bayesopt(objective, svm_params, ...
                'MaxObjectiveEvaluations', 20, ...
                'Verbose', 0);
            
            % Obter melhores hiperparâmetros
            best_params = results.XAtMinObjective;
            
            % Treinar modelo com melhores hiperparâmetros
            mdl = fitrsvm(X_train, y_train, ...
                'BoxConstraint', best_params.BoxConstraint, ...
                'Epsilon', best_params.Epsilon, ...
                'KernelFunction', char(best_params.KernelFunction), ...
                'Standardize', true);
        else
            % Modelo SVM padrão
            mdl = fitrsvm(X_train, y_train, 'KernelFunction', 'gaussian', 'Standardize', true);
        end
        
        % Armazenar modelo
        models_cv{k} = mdl;
        
        % Fazer predições
        y_pred = predict(mdl, X_test);
        
        % Calcular métricas
        rmse_values(k) = sqrt(mean((y_test - y_pred).^2));
        r2_values(k) = 1 - sum((y_test - y_pred).^2) / sum((y_test - mean(y_test)).^2);
        mae_values(k) = mean(abs(y_test - y_pred));
    end
    
    % Treinar modelo final com todos os dados
    if params.OptimizeHyperparams
        % Usar os melhores hiperparâmetros encontrados
        final_model = fitrsvm(X, y, ...
            'BoxConstraint', best_params.BoxConstraint, ...
            'Epsilon', best_params.Epsilon, ...
            'KernelFunction', char(best_params.KernelFunction), ...
            'Standardize', true);
    else
        final_model = fitrsvm(X, y, 'KernelFunction', 'gaussian', 'Standardize', true);
    end
    
    % Criar estrutura do modelo
    model = struct(...
        'type', 'svm', ...
        'model', final_model, ...
        'feature_names', {feature_names}, ...
        'property_name', property_name ...
    );
    
    % Criar estrutura de métricas
    metrics = struct(...
        'rmse_mean', mean(rmse_values), ...
        'rmse_std', std(rmse_values), ...
        'r2_mean', mean(r2_values), ...
        'r2_std', std(r2_values), ...
        'mae_mean', mean(mae_values), ...
        'mae_std', std(mae_values), ...
        'cv_models', {models_cv}, ...
        'cv_partition', cv ...
    );
end

% Função auxiliar para treinar modelo de rede neural
function [model, metrics] = trainANNModel(X, y, feature_names, property_name, params)
    % Configurar validação cruzada
    if strcmpi(params.ValidationMethod, 'kfold')
        cv = cvpartition(length(y), 'KFold', params.ValidationParam);
    else % holdout
        cv = cvpartition(length(y), 'HoldOut', params.ValidationParam);
    end
    
    % Inicializar arrays para armazenar resultados da validação
    n_folds = cv.NumTestSets;
    rmse_values = zeros(n_folds, 1);
    r2_values = zeros(n_folds, 1);
    mae_values = zeros(n_folds, 1);
    models_cv = cell(n_folds, 1);
    
    % Realizar validação cruzada
    for k = 1:n_folds
        % Dividir dados
        if strcmpi(params.ValidationMethod, 'kfold')
            train_idx = cv.training(k);
            test_idx = cv.test(k);
        else % holdout
            train_idx = cv.training;
            test_idx = cv.test;
        end
        
        X_train = X(train_idx, :);
        y_train = y(train_idx);
        X_test = X(test_idx, :);
        y_test = y(test_idx);
        
        % Treinar modelo
        if params.OptimizeHyperparams
            % Otimizar hiperparâmetros
            ann_params = struct(...
                'LayerSizes', optimizableVariable('LayerSizes', [1, 20], 'Type', 'integer'), ...
                'Activations', categorical({'relu', 'tanh'}) ...
            );
            
            % Função objetivo para otimização
            objective = @(params) annCVLoss(X_train, y_train, params);
            
            % Realizar otimização bayesiana
            results = bayesopt(objective, ann_params, ...
                'MaxObjectiveEvaluations', 15, ...
                'Verbose', 0);
            
            % Obter melhores hiperparâmetros
            best_params = results.XAtMinObjective;
            
            % Treinar modelo com melhores hiperparâmetros
            hidden_layer_size = best_params.LayerSizes;
            activation = char(best_params.Activations);
            
            % Criar rede neural
            net = fitnet(hidden_layer_size);
            net.trainFcn = 'trainlm'; % Levenberg-Marquardt
            net.divideFcn = 'dividerand';
            net.divideMode = 'sample';
            net.divideParam.trainRatio = 0.7;
            net.divideParam.valRatio = 0.15;
            net.divideParam.testRatio = 0.15;
            net.trainParam.showWindow = false;
            
            % Definir função de ativação
            for i = 1:hidden_layer_size
                net.layers{i}.transferFcn = activation;
            end
            
            % Treinar rede
            [net, tr] = train(net, X_train', y_train');
            mdl = struct('net', net, 'tr', tr);
        else
            % Modelo de rede neural padrão
            net = fitnet(10); % 10 neurônios na camada oculta
            net.trainFcn = 'trainlm';
            net.divideFcn = 'dividerand';
            net.divideMode = 'sample';
            net.divideParam.trainRatio = 0.7;
            net.divideParam.valRatio = 0.15;
            net.divideParam.testRatio = 0.15;
            net.trainParam.showWindow = false;
            
            % Treinar rede
            [net, tr] = train(net, X_train', y_train');
            mdl = struct('net', net, 'tr', tr);
        end
        
        % Armazenar modelo
        models_cv{k} = mdl;
        
        % Fazer predições
        y_pred = mdl.net(X_test')';
        
        % Calcular métricas
        rmse_values(k) = sqrt(mean((y_test - y_pred).^2));
        r2_values(k) = 1 - sum((y_test - y_pred).^2) / sum((y_test - mean(y_test)).^2);
        mae_values(k) = mean(abs(y_test - y_pred));
    end
    
    % Treinar modelo final com todos os dados
    if params.OptimizeHyperparams
        % Usar os melhores hiperparâmetros encontrados
        hidden_layer_size = best_params.LayerSizes;
        activation = char(best_params.Activations);
        
        % Criar rede neural
        net = fitnet(hidden_layer_size);
        net.trainFcn = 'trainlm';
        net.divideFcn = 'dividerand';
        net.divideMode = 'sample';
        net.divideParam.trainRatio = 0.7;
        net.divideParam.valRatio = 0.15;
        net.divideParam.testRatio = 0.15;
        net.trainParam.showWindow = false;
        
        % Definir função de ativação
        for i = 1:hidden_layer_size
            net.layers{i}.transferFcn = activation;
        end
    else
        % Modelo de rede neural padrão
        net = fitnet(10);
        net.trainFcn = 'trainlm';
        net.divideFcn = 'dividerand';
        net.divideMode = 'sample';
        net.divideParam.trainRatio = 0.7;
        net.divideParam.valRatio = 0.15;
        net.divideParam.testRatio = 0.15;
        net.trainParam.showWindow = false;
    end
    
    % Treinar rede final
    [net, tr] = train(net, X', y');
    final_model = struct('net', net, 'tr', tr);
    
    % Criar estrutura do modelo
    model = struct(...
        'type', 'ann', ...
        'model', final_model, ...
        'feature_names', {feature_names}, ...
        'property_name', property_name ...
    );
    
    % Criar estrutura de métricas
    metrics = struct(...
        'rmse_mean', mean(rmse_values), ...
        'rmse_std', std(rmse_values), ...
        'r2_mean', mean(r2_values), ...
        'r2_std', std(r2_values), ...
        'mae_mean', mean(mae_values), ...
        'mae_std', std(mae_values), ...
        'cv_models', {models_cv}, ...
        'cv_partition', cv ...
    );
end

% Função auxiliar para treinar modelo ensemble
function [model, metrics] = trainEnsembleModel(X, y, feature_names, property_name, params)
    % Configurar validação cruzada
    if strcmpi(params.ValidationMethod, 'kfold')
        cv = cvpartition(length(y), 'KFold', params.ValidationParam);
    else % holdout
        cv = cvpartition(length(y), 'HoldOut', params.ValidationParam);
    end
    
    % Inicializar arrays para armazenar resultados da validação
    n_folds = cv.NumTestSets;
    rmse_values = zeros(n_folds, 1);
    r2_values = zeros(n_folds, 1);
    mae_values = zeros(n_folds, 1);
    models_cv = cell(n_folds, 1);
    
    % Realizar validação cruzada
    for k = 1:n_folds
        % Dividir dados
        if strcmpi(params.ValidationMethod, 'kfold')
            train_idx = cv.training(k);
            test_idx = cv.test(k);
        else % holdout
            train_idx = cv.training;
            test_idx = cv.test;
        end
        
        X_train = X(train_idx, :);
        y_train = y(train_idx);
        X_test = X(test_idx, :);
        y_test = y(test_idx);
        
        % Treinar modelo
        if params.OptimizeHyperparams
            % Otimizar hiperparâmetros
            ensemble_params = struct(...
                'Method', categorical({'Bag', 'LSBoost'}), ...
                'NumLearningCycles', optimizableVariable('NumLearningCycles', [10, 100], 'Type', 'integer'), ...
                'MinLeafSize', optimizableVariable('MinLeafSize', [1, 20], 'Type', 'integer') ...
            );
            
            % Função objetivo para otimização
            objective = @(params) kfoldLoss(fitrensemble(X_train, y_train, ...
                'Method', char(params.Method), ...
                'NumLearningCycles', params.NumLearningCycles, ...
                'MinLeafSize', params.MinLeafSize, ...
                'KFold', 3));
            
            % Realizar otimização bayesiana
            results = bayesopt(objective, ensemble_params, ...
                'MaxObjectiveEvaluations', 15, ...
                'Verbose', 0);
            
            % Obter melhores hiperparâmetros
            best_params = results.XAtMinObjective;
            
            % Treinar modelo com melhores hiperparâmetros
            mdl = fitrensemble(X_train, y_train, ...
                'Method', char(best_params.Method), ...
                'NumLearningCycles', best_params.NumLearningCycles, ...
                'MinLeafSize', best_params.MinLeafSize);
        else
            % Modelo ensemble padrão (Random Forest)
            mdl = fitrensemble(X_train, y_train, 'Method', 'Bag');
        end
        
        % Armazenar modelo
        models_cv{k} = mdl;
        
        % Fazer predições
        y_pred = predict(mdl, X_test);
        
        % Calcular métricas
        rmse_values(k) = sqrt(mean((y_test - y_pred).^2));
        r2_values(k) = 1 - sum((y_test - y_pred).^2) / sum((y_test - mean(y_test)).^2);
        mae_values(k) = mean(abs(y_test - y_pred));
    end
    
    % Treinar modelo final com todos os dados
    if params.OptimizeHyperparams
        % Usar os melhores hiperparâmetros encontrados
        final_model = fitrensemble(X, y, ...
            'Method', char(best_params.Method), ...
            'NumLearningCycles', best_params.NumLearningCycles, ...
            'MinLeafSize', best_params.MinLeafSize);
    else
        final_model = fitrensemble(X, y, 'Method', 'Bag');
    end
    
    % Criar estrutura do modelo
    model = struct(...
        'type', 'ensemble', ...
        'model', final_model, ...
        'feature_names', {feature_names}, ...
        'property_name', property_name ...
    );
    
    % Criar estrutura de métricas
    metrics = struct(...
        'rmse_mean', mean(rmse_values), ...
        'rmse_std', std(rmse_values), ...
        'r2_mean', mean(r2_values), ...
        'r2_std', std(r2_values), ...
        'mae_mean', mean(mae_values), ...
        'mae_std', std(mae_values), ...
        'cv_models', {models_cv}, ...
        'cv_partition', cv ...
    );
end

% Função auxiliar para calcular importância das características
function importance = calculateFeatureImportance(X, y, feature_names, models)
    % Inicializar estrutura de importância
    importance = struct();
    
    % Calcular importância para cada tipo de modelo
    model_types = fieldnames(models);
    
    for i = 1:length(model_types)
        model_type = model_types{i};
        model = models.(model_type);
        
        switch model_type
            case 'regression'
                % Para regressão linear, usar coeficientes padronizados
                mdl = model.model;
                
                % Calcular coeficientes padronizados
                coefs = mdl.Coefficients.Estimate(2:end); % Ignorar intercepto
                
                % Normalizar para soma = 1
                if sum(abs(coefs)) > 0
                    importance_values = abs(coefs) / sum(abs(coefs));
                else
                    importance_values = ones(length(coefs), 1) / length(coefs);
                end
                
            case 'svm'
                % Para SVM, usar análise de sensibilidade
                mdl = model.model;
                
                % Calcular importância por análise de sensibilidade
                importance_values = zeros(size(X, 2), 1);
                
                for j = 1:size(X, 2)
                    % Perturbar cada característica e medir o impacto
                    X_perturbed = X;
                    X_perturbed(:, j) = X_perturbed(:, j) + 0.1 * std(X(:, j));
                    
                    % Predizer com dados perturbados
                    y_pred_orig = predict(mdl, X);
                    y_pred_pert = predict(mdl, X_perturbed);
                    
                    % Calcular mudança média
                    importance_values(j) = mean(abs(y_pred_pert - y_pred_orig));
                end
                
                % Normalizar para soma = 1
                if sum(importance_values) > 0
                    importance_values = importance_values / sum(importance_values);
                else
                    importance_values = ones(size(X, 2), 1) / size(X, 2);
                end
                
            case 'ann'
                % Para redes neurais, usar análise de sensibilidade
                net = model.model.net;
                
                % Calcular importância por análise de sensibilidade
                importance_values = zeros(size(X, 2), 1);
                
                for j = 1:size(X, 2)
                    % Perturbar cada característica e medir o impacto
                    X_perturbed = X;
                    X_perturbed(:, j) = X_perturbed(:, j) + 0.1 * std(X(:, j));
                    
                    % Predizer com dados perturbados
                    y_pred_orig = net(X')';
                    y_pred_pert = net(X_perturbed')';
                    
                    % Calcular mudança média
                    importance_values(j) = mean(abs(y_pred_pert - y_pred_orig));
                end
                
                % Normalizar para soma = 1
                if sum(importance_values) > 0
                    importance_values = importance_values / sum(importance_values);
                else
                    importance_values = ones(size(X, 2), 1) / size(X, 2);
                end
                
            case 'ensemble'
                % Para modelos ensemble, usar importância de características integrada
                mdl = model.model;
                
                % Obter importância de características
                importance_values = predictorImportance(mdl);
                
                % Normalizar para soma = 1
                if sum(importance_values) > 0
                    importance_values = importance_values / sum(importance_values);
                else
                    importance_values = ones(size(X, 2), 1) / size(X, 2);
                end
                
            otherwise
                % Para outros modelos, usar correlação com a variável alvo
                importance_values = abs(corr(X, y, 'type', 'Spearman'));
                
                % Normalizar para soma = 1
                if sum(importance_values) > 0
                    importance_values = importance_values / sum(importance_values);
                else
                    importance_values = ones(size(X, 2), 1) / size(X, 2);
                end
        end
        
        % Criar tabela de importância
        importance_table = table(feature_names', importance_values, ...
            'VariableNames', {'Feature', 'Importance'});
        
        % Ordenar por importância
        importance_table = sortrows(importance_table, 'Importance', 'descend');
        
        % Armazenar na estrutura
        importance.(model_type) = importance_table;
    end
    
    % Calcular importância média entre todos os modelos
    avg_importance = zeros(length(feature_names), 1);
    
    for i = 1:length(model_types)
        model_type = model_types{i};
        
        % Obter importância para este modelo
        imp_table = importance.(model_type);
        
        % Adicionar à média
        for j = 1:length(feature_names)
            feature = feature_names{j};
            idx = find(strcmp(imp_table.Feature, feature));
            
            if ~isempty(idx)
                avg_importance(j) = avg_importance(j) + imp_table.Importance(idx);
            end
        end
    end
    
    % Normalizar média
    avg_importance = avg_importance / length(model_types);
    
    % Criar tabela de importância média
    avg_importance_table = table(feature_names', avg_importance, ...
        'VariableNames', {'Feature', 'Importance'});
    
    % Ordenar por importância
    avg_importance_table = sortrows(avg_importance_table, 'Importance', 'descend');
    
    % Armazenar na estrutura
    importance.average = avg_importance_table;
end

% Função auxiliar para calcular correlações
function correlations = calculateCorrelations(features, properties, feature_names, property_names)
    % Calcular matriz de correlação
    data = [features, properties];
    corr_matrix = corr(data, 'type', 'Spearman');
    
    % Extrair correlações entre características e propriedades
    n_features = size(features, 2);
    n_properties = size(properties, 2);
    
    feature_property_corr = corr_matrix(1:n_features, n_features+1:end);
    
    % Criar tabela de correlações
    correlations = struct(...
        'matrix', feature_property_corr, ...
        'feature_names', {feature_names}, ...
        'property_names', {property_names} ...
    );
end

% Função auxiliar para perda de validação cruzada em redes neurais
function loss = annCVLoss(X, y, params)
    % Extrair parâmetros
    hidden_layer_size = params.LayerSizes;
    activation = char(params.Activations);
    
    % Configurar validação cruzada
    cv = cvpartition(length(y), 'KFold', 3);
    
    % Inicializar array para armazenar erros
    mse_values = zeros(cv.NumTestSets, 1);
    
    % Realizar validação cruzada
    for k = 1:cv.NumTestSets
        % Dividir dados
        train_idx = cv.training(k);
        test_idx = cv.test(k);
        
        X_train = X(train_idx, :);
        y_train = y(train_idx);
        X_test = X(test_idx, :);
        y_test = y(test_idx);
        
        % Criar rede neural
        net = fitnet(hidden_layer_size);
        net.trainFcn = 'trainlm';
        net.divideFcn = 'dividerand';
        net.divideMode = 'sample';
        net.divideParam.trainRatio = 0.7;
        net.divideParam.valRatio = 0.15;
        net.divideParam.testRatio = 0.15;
        net.trainParam.showWindow = false;
        
        % Definir função de ativação
        for i = 1:hidden_layer_size
            net.layers{i}.transferFcn = activation;
        end
        
        % Treinar rede
        [net, ~] = train(net, X_train', y_train');
        
        % Fazer predições
        y_pred = net(X_test')';
        
        % Calcular erro
        mse_values(k) = mean((y_test - y_pred).^2);
    end
    
    % Retornar erro médio
    loss = mean(mse_values);
end

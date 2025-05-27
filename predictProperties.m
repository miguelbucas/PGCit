%% predictProperties.m
% Prediz propriedades de amostras usando modelos de machine learning treinados
%
% Sintaxe:
%   [predictions, confidence] = predictProperties(samples, models, results, varargin)
%
% Parâmetros de Entrada:
%   samples  - Célula ou array de estruturas de amostras para predição
%   models   - Estrutura contendo modelos treinados (saída de trainMLModels)
%   results  - Estrutura contendo resultados do treinamento (saída de trainMLModels)
%   varargin - Pares nome-valor para parâmetros opcionais:
%     'ModelType'          - Tipo de modelo a usar para predição (padrão: 'best')
%     'ConfidenceInterval' - Calcular intervalo de confiança (padrão: true)
%     'ConfidenceLevel'    - Nível de confiança (padrão: 0.95)
%
% Saída:
%   predictions - Estrutura contendo predições para cada propriedade
%   confidence  - Estrutura contendo intervalos de confiança para cada predição
%
% Exemplo:
%   [predictions, confidence] = predictProperties(new_samples, models, results, 'ModelType', 'regression');
%
% Ver também: trainMLModels, extractFeatures, visualizeCorrelations

function [predictions, confidence] = predictProperties(samples, models, results, varargin)
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
    
    % Verificar se há amostras
    if numel(samples_cell) < 1
        error('É necessário pelo menos 1 amostra para predição.');
    end
    
    % Configurar parser de entrada
    p = inputParser;
    p.CaseSensitive = false;
    p.KeepUnmatched = true;
    
    % Adicionar parâmetros
    addParameter(p, 'ModelType', 'best', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ConfidenceInterval', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
    addParameter(p, 'ConfidenceLevel', 0.95, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
    
    % Analisar argumentos
    parse(p, varargin{:});
    
    % Extrair características das amostras
    [features, ~, feature_names, ~] = extractFeatures(samples_cell, ...
        'InputFeatures', results.feature_names);
    
    % Verificar se as características correspondem às esperadas pelos modelos
    if length(feature_names) ~= length(results.feature_names)
        warning('Número de características extraídas (%d) difere do esperado pelos modelos (%d).', ...
                length(feature_names), length(results.feature_names));
    end
    
    % Padronizar dados se necessário
    if isfield(results, 'standardization')
        % Aplicar padronização usando os parâmetros do treinamento
        features_std = (features - results.standardization.features_mean) ./ results.standardization.features_std;
        
        % Usar dados padronizados para predição
        X = features_std;
    else
        X = features;
    end
    
    % Inicializar estruturas de saída
    predictions = struct();
    confidence = struct();
    
    % Obter lista de propriedades
    property_names = results.property_names;
    
    % Predizer cada propriedade
    for i = 1:length(property_names)
        property_name = property_names{i};
        
        % Verificar se o modelo existe para esta propriedade
        if ~isfield(models, property_name)
            warning('Modelo para a propriedade "%s" não encontrado. Ignorando.', property_name);
            continue;
        end
        
        % Determinar qual modelo usar
        if strcmpi(p.Results.ModelType, 'best')
            % Encontrar o melhor modelo com base no R²
            model_types = fieldnames(results.model_metrics.(property_name));
            best_r2 = -Inf;
            best_model_type = '';
            
            for j = 1:length(model_types)
                model_type = model_types{j};
                r2 = results.model_metrics.(property_name).(model_type).r2_mean;
                
                if r2 > best_r2
                    best_r2 = r2;
                    best_model_type = model_type;
                end
            end
            
            if isempty(best_model_type)
                warning('Não foi possível determinar o melhor modelo para a propriedade "%s". Ignorando.', property_name);
                continue;
            end
            
            model_type = best_model_type;
        else
            model_type = p.Results.ModelType;
            
            if ~isfield(models.(property_name), model_type)
                warning('Modelo do tipo "%s" para a propriedade "%s" não encontrado. Ignorando.', ...
                        model_type, property_name);
                continue;
            end
        end
        
        % Obter modelo
        model = models.(property_name).(model_type);
        
        % Fazer predição
        pred_values = predictWithModel(X, model);
        
        % Despadronizar se necessário
        if isfield(results, 'standardization')
            pred_values = pred_values * results.standardization.properties_std(i) + ...
                         results.standardization.properties_mean(i);
        end
        
        % Armazenar predições
        predictions.(property_name) = struct(...
            'values', pred_values, ...
            'model_type', model_type ...
        );
        
        % Calcular intervalos de confiança se solicitado
        if p.Results.ConfidenceInterval
            conf_intervals = calculateConfidenceIntervals(X, model, results.model_metrics.(property_name).(model_type), ...
                                                         p.Results.ConfidenceLevel);
            
            % Despadronizar intervalos de confiança se necessário
            if isfield(results, 'standardization')
                conf_intervals = conf_intervals * results.standardization.properties_std(i) + ...
                               results.standardization.properties_mean(i);
            end
            
            % Armazenar intervalos de confiança
            confidence.(property_name) = struct(...
                'intervals', conf_intervals, ...
                'level', p.Results.ConfidenceLevel ...
            );
        end
    end
    
    % Exibir mensagem de confirmação
    fprintf('Predição concluída com sucesso.\n');
    fprintf('Preditas %d propriedades para %d amostras.\n', ...
            length(fieldnames(predictions)), numel(samples_cell));
end

% Função auxiliar para fazer predição com modelo específico
function pred_values = predictWithModel(X, model)
    % Inicializar array de predições
    pred_values = zeros(size(X, 1), 1);
    
    % Fazer predição com base no tipo de modelo
    switch model.type
        case 'regression'
            % Modelo de regressão linear
            pred_values = predict(model.model, X);
            
        case 'svm'
            % Modelo SVM
            pred_values = predict(model.model, X);
            
        case 'ann'
            % Modelo de rede neural
            pred_values = model.model.net(X')';
            
        case 'ensemble'
            % Modelo ensemble
            pred_values = predict(model.model, X);
            
        otherwise
            error('Tipo de modelo desconhecido: %s', model.type);
    end
end

% Função auxiliar para calcular intervalos de confiança
function conf_intervals = calculateConfidenceIntervals(X, model, metrics, conf_level)
    % Inicializar matriz de intervalos de confiança
    % Cada linha é uma amostra, colunas são [limite_inferior, limite_superior]
    conf_intervals = zeros(size(X, 1), 2);
    
    % Calcular valor crítico para o nível de confiança
    alpha = 1 - conf_level;
    z_critical = norminv(1 - alpha/2);
    
    % Fazer predição com modelo
    pred_values = predictWithModel(X, model);
    
    % Calcular intervalos de confiança com base no tipo de modelo
    switch model.type
        case 'regression'
            % Para regressão linear, usar erro padrão da predição
            if isfield(metrics, 'rmse_std')
                std_error = metrics.rmse_std;
            else
                std_error = metrics.rmse_mean * 0.1; % Estimativa conservadora
            end
            
            conf_intervals(:, 1) = pred_values - z_critical * std_error;
            conf_intervals(:, 2) = pred_values + z_critical * std_error;
            
        case {'svm', 'ann', 'ensemble'}
            % Para modelos mais complexos, usar erro médio de validação cruzada
            if isfield(metrics, 'rmse_mean')
                std_error = metrics.rmse_mean;
            else
                % Usar erro médio absoluto se RMSE não estiver disponível
                std_error = metrics.mae_mean * 1.25; % Aproximação: RMSE ≈ 1.25 * MAE
            end
            
            conf_intervals(:, 1) = pred_values - z_critical * std_error;
            conf_intervals(:, 2) = pred_values + z_critical * std_error;
            
        otherwise
            error('Tipo de modelo desconhecido: %s', model.type);
    end
end

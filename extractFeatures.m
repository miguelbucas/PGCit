%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% extractFeatures.m - Extração de características para machine learning
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ÍNDICE DE FUNÇÕES:
% ------------------
% [Linha 23]  extractFeatures            - Função principal de extração de características
% [Linha 154] extractAvailableProperties - Extrai propriedades disponíveis de uma amostra
% [Linha 270] extractAvailableFeatures   - Extrai características disponíveis de uma amostra
% [Linha 455] extractFeatureValue        - Extrai o valor de uma característica específica
% [Linha 665] extractPropertyValue       - Extrai o valor de uma propriedade específica
%
% Extrai características e propriedades de amostras para uso em machine learning
%
% Sintaxe:
%   [features, properties, feature_names, property_names] = extractFeatures(samples, varargin)
%
% Parâmetros de Entrada:
%   samples  - Célula ou array de estruturas de amostras com dados analisados
%   varargin - Pares nome-valor para parâmetros opcionais:
%     'TargetProperties'   - Propriedades alvo para predição (cell array, padrão: todas)
%     'InputFeatures'      - Características de entrada para os modelos (cell array, padrão: automático)
%
% Saída:
%   features       - Matriz de características (cada linha é uma amostra, cada coluna uma característica)
%   properties     - Matriz de propriedades (cada linha é uma amostra, cada coluna uma propriedade)
%   feature_names  - Célula com nomes das características
%   property_names - Célula com nomes das propriedades
%
% Exemplo:
%   [features, properties, feature_names, property_names] = extractFeatures(samples, 'TargetProperties', {'glass_transition_temp'});
%
% Ver também: trainMLModels, predictProperties, visualizeCorrelations

function [features, properties, feature_names, property_names] = extractFeatures(samples, varargin)
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
    if numel(samples_cell) < 1
        error('É necessário pelo menos 1 amostra para extrair características.');
    end
    
    % Configurar parser de entrada
    p = inputParser;
    p.CaseSensitive = false;
    p.KeepUnmatched = true;
    
    % Adicionar parâmetros
    addParameter(p, 'TargetProperties', {}, @(x) isempty(x) || iscell(x));
    addParameter(p, 'InputFeatures', {}, @(x) isempty(x) || iscell(x));
    
    % Analisar argumentos
    parse(p, varargin{:});
    
    % Extrair todas as propriedades disponíveis na primeira amostra
    all_properties = extractAvailableProperties(samples_cell{1});
    
    % Filtrar propriedades alvo, se especificadas
    if ~isempty(p.Results.TargetProperties)
        target_properties = p.Results.TargetProperties;
        
        % Verificar se todas as propriedades solicitadas existem
        for i = 1:length(target_properties)
            if ~ismember(target_properties{i}, all_properties)
                warning('Propriedade "%s" não encontrada nas amostras. Ignorando.', target_properties{i});
                target_properties{i} = '';
            end
        end
        
        % Remover propriedades inválidas
        target_properties = target_properties(~cellfun(@isempty, target_properties));
        
        if isempty(target_properties)
            error('Nenhuma das propriedades alvo especificadas foi encontrada nas amostras.');
        end
    else
        % Usar todas as propriedades disponíveis
        target_properties = all_properties;
    end
    
    % Extrair todas as características disponíveis na primeira amostra
    all_features = extractAvailableFeatures(samples_cell{1});
    
    % Filtrar características de entrada, se especificadas
    if ~isempty(p.Results.InputFeatures)
        input_features = p.Results.InputFeatures;
        
        % Verificar se todas as características solicitadas existem
        for i = 1:length(input_features)
            if ~ismember(input_features{i}, all_features)
                warning('Característica "%s" não encontrada nas amostras. Ignorando.', input_features{i});
                input_features{i} = '';
            end
        end
        
        % Remover características inválidas
        input_features = input_features(~cellfun(@isempty, input_features));
        
        if isempty(input_features)
            error('Nenhuma das características de entrada especificadas foi encontrada nas amostras.');
        end
    else
        % Usar todas as características disponíveis
        input_features = all_features;
    end
    
    % Inicializar matrizes de características e propriedades
    n_samples = numel(samples_cell);
    n_features = length(input_features);
    n_properties = length(target_properties);
    
    features = zeros(n_samples, n_features);
    properties = zeros(n_samples, n_properties);
    
    % Extrair características e propriedades de cada amostra
    for i = 1:n_samples
        sample = samples_cell{i};
        
        % Extrair características
        for j = 1:n_features
            feature_name = input_features{j};
            features(i, j) = extractFeatureValue(sample, feature_name);
        end
        
        % Extrair propriedades
        for j = 1:n_properties
            property_name = target_properties{j};
            properties(i, j) = extractPropertyValue(sample, property_name);
        end
    end
    
    % Definir nomes das características e propriedades
    feature_names = input_features;
    property_names = target_properties;
    
    % Verificar se há valores NaN
    if any(isnan(features(:)))
        warning('Algumas características contêm valores NaN. Considere pré-processar os dados.');
    end
    
    if any(isnan(properties(:)))
        warning('Algumas propriedades contêm valores NaN. Considere pré-processar os dados.');
    end
    
    % Exibir mensagem de confirmação
    fprintf('Extração de características concluída com sucesso.\n');
    fprintf('Extraídas %d características e %d propriedades de %d amostras.\n', ...
            n_features, n_properties, n_samples);
end

% Função auxiliar para extrair propriedades disponíveis
function properties = extractAvailableProperties(sample)
    % Inicializar lista de propriedades
    properties = {};
    
    % Verificar se a amostra tem propriedades
    if ~isfield(sample, 'properties')
        return;
    end
    
    % Extrair propriedades de síntese
    if isfield(sample.properties, 'synthesis')
        synthesis_fields = fieldnames(sample.properties.synthesis);
        
        for i = 1:length(synthesis_fields)
            field = synthesis_fields{i};
            value = sample.properties.synthesis.(field);
            
            % Adicionar apenas propriedades numéricas
            if isnumeric(value) && isscalar(value)
                properties{end+1} = ['synthesis_', field];
            end
        end
    end
    
    % Extrair propriedades derivadas de FTIR
    if isfield(sample.properties, 'ftir_derived')
        ftir_fields = fieldnames(sample.properties.ftir_derived);
        
        for i = 1:length(ftir_fields)
            field = ftir_fields{i};
            value = sample.properties.ftir_derived.(field);
            
            % Adicionar apenas propriedades numéricas
            if isnumeric(value) && isscalar(value)
                properties{end+1} = ['ftir_', field];
            end
        end
    end
    
    % Extrair propriedades derivadas de TGA
    if isfield(sample.properties, 'tga_derived')
        tga_fields = fieldnames(sample.properties.tga_derived);
        
        for i = 1:length(tga_fields)
            field = tga_fields{i};
            value = sample.properties.tga_derived.(field);
            
            % Adicionar apenas propriedades numéricas
            if isnumeric(value) && isscalar(value)
                properties{end+1} = ['tga_', field];
            end
        end
    end
    
    % Extrair propriedades derivadas de DSC
    if isfield(sample.properties, 'dsc_derived')
        dsc_fields = fieldnames(sample.properties.dsc_derived);
        
        for i = 1:length(dsc_fields)
            field = dsc_fields{i};
            value = sample.properties.dsc_derived.(field);
            
            % Adicionar apenas propriedades numéricas
            if isnumeric(value) && isscalar(value)
                properties{end+1} = ['dsc_', field];
            end
        end
    end
    
    % Extrair propriedades derivadas de solubilidade
    if isfield(sample.properties, 'solubility_derived')
        solubility_fields = fieldnames(sample.properties.solubility_derived);
        
        for i = 1:length(solubility_fields)
            field = solubility_fields{i};
            value = sample.properties.solubility_derived.(field);
            
            % Adicionar apenas propriedades numéricas
            if isnumeric(value) && isscalar(value)
                properties{end+1} = ['solubility_', field];
            elseif isstruct(value)
                % Para estruturas, extrair campos numéricos
                subfields = fieldnames(value);
                
                for j = 1:length(subfields)
                    subfield = subfields{j};
                    subvalue = value.(subfield);
                    
                    if isnumeric(subvalue) && isscalar(subvalue)
                        properties{end+1} = ['solubility_', field, '_', subfield];
                    end
                end
            end
        end
    end
    
    % Extrair outras propriedades
    if isfield(sample.properties, 'other')
        other_fields = fieldnames(sample.properties.other);
        
        for i = 1:length(other_fields)
            field = other_fields{i};
            value = sample.properties.other.(field);
            
            % Adicionar apenas propriedades numéricas
            if isnumeric(value) && isscalar(value)
                properties{end+1} = ['other_', field];
            end
        end
    end
end

% Função auxiliar para extrair características disponíveis
function features = extractAvailableFeatures(sample)
    % Inicializar lista de características
    features = {};
    
    % Extrair características de síntese
    if isfield(sample, 'synthesis')
        synthesis_fields = fieldnames(sample.synthesis);
        
        for i = 1:length(synthesis_fields)
            field = synthesis_fields{i};
            value = sample.synthesis.(field);
            
            % Adicionar apenas características numéricas
            if isnumeric(value) && isscalar(value)
                features{end+1} = ['synthesis_', field];
            end
        end
    end
    
    % Extrair características de FTIR
    if isfield(sample, 'measurements') && isfield(sample.measurements, 'ftir') && ...
       isfield(sample.measurements.ftir, 'processed') && sample.measurements.ftir.processed
        
        % Adicionar índices espectrais
        if isfield(sample.measurements.ftir, 'spectral_indices')
            indices = fieldnames(sample.measurements.ftir.spectral_indices);
            
            for i = 1:length(indices)
                index_name = indices{i};
                features{end+1} = ['ftir_index_', index_name];
            end
        end
        
        % Adicionar intensidades de picos principais
        if isfield(sample.measurements.ftir, 'peaks')
            for i = 1:length(sample.measurements.ftir.peaks)
                peak = sample.measurements.ftir.peaks(i);
                features{end+1} = ['ftir_peak_', num2str(peak.wavenumber)];
            end
        end
    end
    
    % Extrair características de TGA
    if isfield(sample, 'measurements') && isfield(sample.measurements, 'tga') && ...
       isfield(sample.measurements.tga, 'processed') && sample.measurements.tga.processed
        
        % Adicionar temperaturas de decomposição
        if isfield(sample.measurements.tga, 'decomposition_stages')
            for i = 1:length(sample.measurements.tga.decomposition_stages)
                stage = sample.measurements.tga.decomposition_stages(i);
                features{end+1} = ['tga_stage', num2str(i), '_onset'];
                features{end+1} = ['tga_stage', num2str(i), '_endset'];
                features{end+1} = ['tga_stage', num2str(i), '_weight_loss'];
            end
        end
        
        % Adicionar temperaturas características
        if isfield(sample.measurements.tga, 'characteristic_temperatures')
            temps = fieldnames(sample.measurements.tga.characteristic_temperatures);
            
            for i = 1:length(temps)
                temp_name = temps{i};
                features{end+1} = ['tga_temp_', temp_name];
            end
        end
    end
    
    % Extrair características de DSC
    if isfield(sample, 'measurements') && isfield(sample.measurements, 'dsc_heating') && ...
       isfield(sample.measurements.dsc_heating, 'processed') && sample.measurements.dsc_heating.processed
        
        % Adicionar transições térmicas
        if isfield(sample.measurements.dsc_heating, 'transitions')
            transitions = fieldnames(sample.measurements.dsc_heating.transitions);
            
            for i = 1:length(transitions)
                transition = transitions{i};
                features{end+1} = ['dsc_heating_', transition, '_onset'];
                features{end+1} = ['dsc_heating_', transition, '_peak'];
                features{end+1} = ['dsc_heating_', transition, '_endset'];
            end
        end
        
        % Adicionar entalpias
        if isfield(sample.measurements.dsc_heating, 'enthalpies')
            enthalpies = fieldnames(sample.measurements.dsc_heating.enthalpies);
            
            for i = 1:length(enthalpies)
                enthalpy = enthalpies{i};
                features{end+1} = ['dsc_heating_enthalpy_', enthalpy];
            end
        end
    end
    
    % Extrair características de DSC (resfriamento)
    if isfield(sample, 'measurements') && isfield(sample.measurements, 'dsc_cooling') && ...
       isfield(sample.measurements.dsc_cooling, 'processed') && sample.measurements.dsc_cooling.processed
        
        % Adicionar transições térmicas
        if isfield(sample.measurements.dsc_cooling, 'transitions')
            transitions = fieldnames(sample.measurements.dsc_cooling.transitions);
            
            for i = 1:length(transitions)
                transition = transitions{i};
                features{end+1} = ['dsc_cooling_', transition, '_onset'];
                features{end+1} = ['dsc_cooling_', transition, '_peak'];
                features{end+1} = ['dsc_cooling_', transition, '_endset'];
            end
        end
        
        % Adicionar entalpias
        if isfield(sample.measurements.dsc_cooling, 'enthalpies')
            enthalpies = fieldnames(sample.measurements.dsc_cooling.enthalpies);
            
            for i = 1:length(enthalpies)
                enthalpy = enthalpies{i};
                features{end+1} = ['dsc_cooling_enthalpy_', enthalpy];
            end
        end
    end
    
    % Extrair características de solubilidade
    if isfield(sample, 'measurements') && isfield(sample.measurements, 'solubility')
        solvent_fields = fieldnames(sample.measurements.solubility);
        
        % Remover campos de histórico
        solvent_fields = solvent_fields(~contains(solvent_fields, '_history'));
        
        for i = 1:length(solvent_fields)
            solvent = solvent_fields{i};
            
            if isfield(sample.measurements.solubility.(solvent), 'processed') && ...
               sample.measurements.solubility.(solvent).processed
                
                % Adicionar parâmetros de van't Hoff
                if isfield(sample.measurements.solubility.(solvent), 'vant_hoff_params')
                    params = fieldnames(sample.measurements.solubility.(solvent).vant_hoff_params);
                    
                    for j = 1:length(params)
                        param = params{j};
                        
                        % Adicionar apenas parâmetros numéricos
                        value = sample.measurements.solubility.(solvent).vant_hoff_params.(param);
                        if isnumeric(value) && isscalar(value)
                            features{end+1} = ['solubility_', solvent, '_vant_hoff_', param];
                        end
                    end
                end
                
                % Adicionar parâmetros termodinâmicos
                if isfield(sample.measurements.solubility.(solvent), 'thermodynamic_params')
                    params = fieldnames(sample.measurements.solubility.(solvent).thermodynamic_params);
                    
                    for j = 1:length(params)
                        param = params{j};
                        
                        % Adicionar apenas parâmetros numéricos
                        value = sample.measurements.solubility.(solvent).thermodynamic_params.(param);
                        if isnumeric(value) && isscalar(value)
                            features{end+1} = ['solubility_', solvent, '_thermo_', param];
                        end
                    end
                end
                
                % Adicionar parâmetros adicionais
                if isfield(sample.measurements.solubility.(solvent), 'additional_params')
                    params = fieldnames(sample.measurements.solubility.(solvent).additional_params);
                    
                    for j = 1:length(params)
                        param = params{j};
                        
                        % Adicionar apenas parâmetros numéricos
                        value = sample.measurements.solubility.(solvent).additional_params.(param);
                        if isnumeric(value) && isscalar(value)
                            features{end+1} = ['solubility_', solvent, '_', param];
                        end
                    end
                end
            end
        end
    end
end

% Função auxiliar para extrair valor de uma característica
function value = extractFeatureValue(sample, feature_name)
    % Inicializar valor como NaN (caso não seja encontrado)
    value = NaN;
    
    % Dividir nome da característica em partes
    parts = strsplit(feature_name, '_');
    
    % Extrair características de síntese
    if strcmp(parts{1}, 'synthesis') && isfield(sample, 'synthesis')
        field = strjoin(parts(2:end), '_');
        
        if isfield(sample.synthesis, field)
            value = sample.synthesis.(field);
        end
        
        return;
    end
    
    % Extrair características de FTIR
    if strcmp(parts{1}, 'ftir') && isfield(sample, 'measurements') && ...
       isfield(sample.measurements, 'ftir') && isfield(sample.measurements.ftir, 'processed') && ...
       sample.measurements.ftir.processed
        
        % Índices espectrais
        if strcmp(parts{2}, 'index') && isfield(sample.measurements.ftir, 'spectral_indices')
            index_name = strjoin(parts(3:end), '_');
            
            if isfield(sample.measurements.ftir.spectral_indices, index_name)
                value = sample.measurements.ftir.spectral_indices.(index_name);
            end
            
            return;
        end
        
        % Picos
        if strcmp(parts{2}, 'peak') && isfield(sample.measurements.ftir, 'peaks')
            peak_wavenumber = str2double(parts{3});
            
            % Encontrar pico mais próximo
            min_diff = Inf;
            
            for i = 1:length(sample.measurements.ftir.peaks)
                peak = sample.measurements.ftir.peaks(i);
                diff = abs(peak.wavenumber - peak_wavenumber);
                
                if diff < min_diff
                    min_diff = diff;
                    value = peak.intensity;
                end
            end
            
            return;
        end
    end
    
    % Extrair características de TGA
    if strcmp(parts{1}, 'tga') && isfield(sample, 'measurements') && ...
       isfield(sample.measurements, 'tga') && isfield(sample.measurements.tga, 'processed') && ...
       sample.measurements.tga.processed
        
        % Estágios de decomposição
        if strncmp(parts{2}, 'stage', 5) && isfield(sample.measurements.tga, 'decomposition_stages')
            stage_num = str2double(parts{2}(6:end));
            
            if stage_num <= length(sample.measurements.tga.decomposition_stages)
                stage = sample.measurements.tga.decomposition_stages(stage_num);
                
                if strcmp(parts{3}, 'onset')
                    value = stage.onset_temperature;
                elseif strcmp(parts{3}, 'endset')
                    value = stage.endset_temperature;
                elseif strcmp(parts{3}, 'weight_loss')
                    value = stage.weight_loss_percent;
                end
            end
            
            return;
        end
        
        % Temperaturas características
        if strcmp(parts{2}, 'temp') && isfield(sample.measurements.tga, 'characteristic_temperatures')
            temp_name = strjoin(parts(3:end), '_');
            
            if isfield(sample.measurements.tga.characteristic_temperatures, temp_name)
                value = sample.measurements.tga.characteristic_temperatures.(temp_name);
            end
            
            return;
        end
    end
    
    % Extrair características de DSC (aquecimento)
    if strcmp(parts{1}, 'dsc') && strcmp(parts{2}, 'heating') && ...
       isfield(sample, 'measurements') && isfield(sample.measurements, 'dsc_heating') && ...
       isfield(sample.measurements.dsc_heating, 'processed') && sample.measurements.dsc_heating.processed
        
        % Transições térmicas
        if isfield(sample.measurements.dsc_heating, 'transitions')
            transition_name = parts{3};
            
            if isfield(sample.measurements.dsc_heating.transitions, transition_name)
                transition = sample.measurements.dsc_heating.transitions.(transition_name);
                
                if strcmp(parts{4}, 'onset')
                    value = transition.onset;
                elseif strcmp(parts{4}, 'peak')
                    value = transition.peak;
                elseif strcmp(parts{4}, 'endset')
                    value = transition.endset;
                end
            end
            
            return;
        end
        
        % Entalpias
        if strcmp(parts{3}, 'enthalpy') && isfield(sample.measurements.dsc_heating, 'enthalpies')
            enthalpy_name = strjoin(parts(4:end), '_');
            
            if isfield(sample.measurements.dsc_heating.enthalpies, enthalpy_name)
                value = sample.measurements.dsc_heating.enthalpies.(enthalpy_name);
            end
            
            return;
        end
    end
    
    % Extrair características de DSC (resfriamento)
    if strcmp(parts{1}, 'dsc') && strcmp(parts{2}, 'cooling') && ...
       isfield(sample, 'measurements') && isfield(sample.measurements, 'dsc_cooling') && ...
       isfield(sample.measurements.dsc_cooling, 'processed') && sample.measurements.dsc_cooling.processed
        
        % Transições térmicas
        if isfield(sample.measurements.dsc_cooling, 'transitions')
            transition_name = parts{3};
            
            if isfield(sample.measurements.dsc_cooling.transitions, transition_name)
                transition = sample.measurements.dsc_cooling.transitions.(transition_name);
                
                if strcmp(parts{4}, 'onset')
                    value = transition.onset;
                elseif strcmp(parts{4}, 'peak')
                    value = transition.peak;
                elseif strcmp(parts{4}, 'endset')
                    value = transition.endset;
                end
            end
            
            return;
        end
        
        % Entalpias
        if strcmp(parts{3}, 'enthalpy') && isfield(sample.measurements.dsc_cooling, 'enthalpies')
            enthalpy_name = strjoin(parts(4:end), '_');
            
            if isfield(sample.measurements.dsc_cooling.enthalpies, enthalpy_name)
                value = sample.measurements.dsc_cooling.enthalpies.(enthalpy_name);
            end
            
            return;
        end
    end
    
    % Extrair características de solubilidade
    if strcmp(parts{1}, 'solubility') && isfield(sample, 'measurements') && ...
       isfield(sample.measurements, 'solubility')
        
        solvent = parts{2};
        
        if isfield(sample.measurements.solubility, solvent) && ...
           isfield(sample.measurements.solubility.(solvent), 'processed') && ...
           sample.measurements.solubility.(solvent).processed
            
            % Parâmetros de van't Hoff
            if strcmp(parts{3}, 'vant') && strcmp(parts{4}, 'hoff') && ...
               isfield(sample.measurements.solubility.(solvent), 'vant_hoff_params')
                
                param_name = strjoin(parts(5:end), '_');
                
                if isfield(sample.measurements.solubility.(solvent).vant_hoff_params, param_name)
                    value = sample.measurements.solubility.(solvent).vant_hoff_params.(param_name);
                end
                
                return;
            end
            
            % Parâmetros termodinâmicos
            if strcmp(parts{3}, 'thermo') && ...
               isfield(sample.measurements.solubility.(solvent), 'thermodynamic_params')
                
                param_name = strjoin(parts(4:end), '_');
                
                if isfield(sample.measurements.solubility.(solvent).thermodynamic_params, param_name)
                    value = sample.measurements.solubility.(solvent).thermodynamic_params.(param_name);
                end
                
                return;
            end
            
            % Parâmetros adicionais
            if isfield(sample.measurements.solubility.(solvent), 'additional_params')
                param_name = strjoin(parts(3:end), '_');
                
                if isfield(sample.measurements.solubility.(solvent).additional_params, param_name)
                    value = sample.measurements.solubility.(solvent).additional_params.(param_name);
                end
                
                return;
            end
        end
    end
end

% Função auxiliar para extrair valor de uma propriedade
function value = extractPropertyValue(sample, property_name)
    % Inicializar valor como NaN (caso não seja encontrado)
    value = NaN;
    
    % Dividir nome da propriedade em partes
    parts = strsplit(property_name, '_');
    
    % Extrair propriedades de síntese
    if strcmp(parts{1}, 'synthesis') && isfield(sample, 'properties') && ...
       isfield(sample.properties, 'synthesis')
        
        field = strjoin(parts(2:end), '_');
        
        if isfield(sample.properties.synthesis, field)
            value = sample.properties.synthesis.(field);
        end
        
        return;
    end
    
    % Extrair propriedades derivadas de FTIR
    if strcmp(parts{1}, 'ftir') && isfield(sample, 'properties') && ...
       isfield(sample.properties, 'ftir_derived')
        
        field = strjoin(parts(2:end), '_');
        
        if isfield(sample.properties.ftir_derived, field)
            value = sample.properties.ftir_derived.(field);
        end
        
        return;
    end
    
    % Extrair propriedades derivadas de TGA
    if strcmp(parts{1}, 'tga') && isfield(sample, 'properties') && ...
       isfield(sample.properties, 'tga_derived')
        
        field = strjoin(parts(2:end), '_');
        
        if isfield(sample.properties.tga_derived, field)
            value = sample.properties.tga_derived.(field);
        end
        
        return;
    end
    
    % Extrair propriedades derivadas de DSC
    if strcmp(parts{1}, 'dsc') && isfield(sample, 'properties') && ...
       isfield(sample.properties, 'dsc_derived')
        
        field = strjoin(parts(2:end), '_');
        
        if isfield(sample.properties.dsc_derived, field)
            value = sample.properties.dsc_derived.(field);
        end
        
        return;
    end
    
    % Extrair propriedades derivadas de solubilidade
    if strcmp(parts{1}, 'solubility') && isfield(sample, 'properties') && ...
       isfield(sample.properties, 'solubility_derived')
        
        if length(parts) >= 3 && strcmp(parts{2}, 'solvent')
            % Propriedade específica de um solvente
            solvent = parts{3};
            field = strjoin(parts(4:end), '_');
            
            if isfield(sample.properties.solubility_derived, solvent) && ...
               isfield(sample.properties.solubility_derived.(solvent), field)
                value = sample.properties.solubility_derived.(solvent).(field);
            end
        elseif length(parts) >= 3 && strcmp(parts{2}, 'combined')
            % Propriedade combinada
            field = strjoin(parts(3:end), '_');
            
            if isfield(sample.properties.solubility_derived, 'combined') && ...
               isfield(sample.properties.solubility_derived.combined, field)
                value = sample.properties.solubility_derived.combined.(field);
            end
        else
            % Propriedade geral
            field = strjoin(parts(2:end), '_');
            
            if isfield(sample.properties.solubility_derived, field)
                value = sample.properties.solubility_derived.(field);
            end
        end
        
        return;
    end
    
    % Extrair outras propriedades
    if strcmp(parts{1}, 'other') && isfield(sample, 'properties') && ...
       isfield(sample.properties, 'other')
        
        field = strjoin(parts(2:end), '_');
        
        if isfield(sample.properties.other, field)
            value = sample.properties.other.(field);
        end
        
        return;
    end
end

function [sample, results] = analyzeDSC_wrapper_final(sample, varargin)
% ANALYZEDSC_WRAPPER_FINAL - Versão final corrigida do wrapper para análise DSC
%
% Esta função é um wrapper para analyzeDSC que corrige todos os problemas:
% 1. Remove caracteres acentuados nos nomes de campos
% 2. Usa abordagem alternativa para análise da curva de resfriamento
% 3. Implementa tratamento de erros robusto
%
% Sintaxe:
%   [sample, results] = analyzeDSC_wrapper_final(sample, varargin)
%
% Entradas:
%   sample - Estrutura de dados contendo as medições DSC
%   varargin - Parâmetros opcionais a serem passados para analyzeDSC
%
% Saídas:
%   sample - Estrutura de dados atualizada com resultados DSC
%   results - Estrutura contendo resultados da análise DSC
%
% Autor: PGCit Analyzer Team, 2025
% Versão: Final (26/05/2025)

    % Inicializar resultado padrão caso ocorram erros
    results = struct();
    results.heating = struct('transitions', struct([]));
    results.cooling = struct('transitions', struct([]));
    results.combined = struct();
    
    try
        % Verificar se a amostra contém dados DSC
        if ~isfield(sample, 'measurements') || ...
           (~isfield(sample.measurements, 'dsc_heating') && ...
            ~isfield(sample.measurements, 'dsc_cooling'))
            warning('Amostra não contém dados DSC.');
            return;
        end
        
        % Processar curva de aquecimento
        if isfield(sample.measurements, 'dsc_heating')
            heating_data = sample.measurements.dsc_heating;
            if isfield(heating_data, 'temperature') && isfield(heating_data, 'heat_flow')
                [heating_results] = analyzeHeatingCurve_safe(heating_data.temperature, heating_data.heat_flow);
                results.heating = heating_results;
            end
        end
        
        % Processar curva de resfriamento
        if isfield(sample.measurements, 'dsc_cooling')
            cooling_data = sample.measurements.dsc_cooling;
            if isfield(cooling_data, 'temperature') && isfield(cooling_data, 'heat_flow')
                [cooling_results] = analyzeCoolingCurve_safe(cooling_data.temperature, cooling_data.heat_flow);
                results.cooling = cooling_results;
            end
        end
        
        % Consolidar resultados
        results.combined = consolidateResults(results.heating, results.cooling);
        
        % Atualizar propriedades da amostra
        if ~isfield(sample, 'properties')
            sample.properties = struct();
        end
        sample.properties.dsc = results;
        
    catch e
        warning('Erro durante análise DSC: %s', e.message);
    end
    
    %% Funções auxiliares
    
    function [heating_results] = analyzeHeatingCurve_safe(temperature, heat_flow)
        % Função segura para analisar a curva de aquecimento
        
        % Inicializar resultados
        heating_results = struct();
        heating_results.transitions = [];
        
        % Verificar se há dados suficientes
        if length(temperature) < 5 || length(heat_flow) < 5
            warning('Dados insuficientes para análise da curva de aquecimento');
            return;
        end
        
        % Corrigir orientação dos vetores
        temperature = temperature(:);
        heat_flow = heat_flow(:);
        
        % Determinar orientação da temperatura
        is_increasing_temp = (temperature(end) > temperature(1));
        
        % Verificar se é necessário inverter para análise
        if ~is_increasing_temp
            temperature = flipud(temperature);
            heat_flow = flipud(heat_flow);
        end
        
        % Suavizar a curva usando filtro de média móvel
        window_size = min(11, floor(length(heat_flow)/5));
        if mod(window_size, 2) == 0
            window_size = window_size + 1; % Garantir que seja ímpar
        end
        heat_flow_smooth = smooth(heat_flow, window_size, 'moving');
        
        % Calcular a derivada primeira do fluxo de calor
        dhf_dt = zeros(size(heat_flow_smooth));
        for i = 2:length(heat_flow_smooth)-1
            dhf_dt(i) = (heat_flow_smooth(i+1) - heat_flow_smooth(i-1)) / (temperature(i+1) - temperature(i-1));
        end
        
        % Lista para armazenar as transições
        transitions = [];
        
        % Identificar transição vítrea (Tg)
        % A Tg aparece como uma inflexão (mudança na derivada)
        [~, tg_idx] = max(abs(dhf_dt(1:round(length(dhf_dt)/2))));
        tg = temperature(tg_idx);
        tg_transition = struct(...
            'type', 'Transicao vitrea', ...
            'onset_temp', tg - 5, ...
            'peak_temp', tg, ...
            'endset_temp', tg + 5);
        
        transitions = [transitions, tg_transition];
        
        % Identificar fusão (Tm)
        % A fusão aparece como um pico endotérmico (positivo)
        % Buscar na segunda metade da curva
        start_idx = round(length(heat_flow_smooth)/2);
        end_idx = length(heat_flow_smooth);
        [max_val, max_idx] = max(heat_flow_smooth(start_idx:end_idx));
        max_idx = max_idx + start_idx - 1;
        
        % Verificar se o pico é significativo
        if max_val > mean(heat_flow_smooth) + 2*std(heat_flow_smooth)
            tm = temperature(max_idx);
            
            % Encontrar onset e endset
            onset_idx = max_idx;
            for i = max_idx:-1:1
                if heat_flow_smooth(i) < max_val/2
                    onset_idx = i;
                    break;
                end
            end
            
            endset_idx = max_idx;
            for i = max_idx:length(heat_flow_smooth)
                if heat_flow_smooth(i) < max_val/2
                    endset_idx = i;
                    break;
                end
            end
            
            if isempty(endset_idx), endset_idx = length(heat_flow); end
            
            tm_transition = struct(...
                'type', 'Fusao', ...
                'onset_temp', temperature(onset_idx), ...
                'peak_temp', tm, ...
                'endset_temp', temperature(min(endset_idx, length(temperature))));
            
            transitions = [transitions, tm_transition];
        end
        
        % Armazenar todas as transições
        heating_results.transitions = transitions;
    end

    function [cooling_results] = analyzeCoolingCurve_safe(temperature, heat_flow)
        % Função segura para analisar a curva de resfriamento usando uma
        % abordagem alternativa que não depende do msbackadj
        
        % Inicializar resultados
        cooling_results = struct();
        cooling_results.transitions = [];
        
        % Verificar se há dados suficientes
        if length(temperature) < 5 || length(heat_flow) < 5
            warning('Dados insuficientes para análise da curva de resfriamento');
            return;
        end
        
        % Corrigir orientação dos vetores
        temperature = temperature(:);
        heat_flow = heat_flow(:);
        
        % Determinar orientação da temperatura
        is_decreasing_temp = (temperature(end) < temperature(1));
        
        % Verificar se é necessário inverter para análise
        if ~is_decreasing_temp
            temperature = flipud(temperature);
            heat_flow = flipud(heat_flow);
        end
        
        % Suavizar a curva usando filtro de média móvel
        window_size = min(11, floor(length(heat_flow)/5));
        if mod(window_size, 2) == 0
            window_size = window_size + 1; % Garantir que seja ímpar
        end
        heat_flow_smooth = smooth(heat_flow, window_size, 'moving');
        
        % Lista para armazenar as transições
        transitions = [];
        
        % Identificar cristalização (Tc)
        % A cristalização aparece como um pico exotérmico (negativo)
        [min_val, min_idx] = min(heat_flow_smooth);
        tc = temperature(min_idx);
        
        % Verificar se o pico é significativo
        if min_val < mean(heat_flow_smooth) - 2*std(heat_flow_smooth)
            % Encontrar onset (início do pico)
            onset_idx = min_idx;
            threshold = min_val + 0.5 * (0 - min_val); % 50% da altura do pico
            
            for i = min_idx:-1:1
                if heat_flow_smooth(i) >= threshold
                    onset_idx = i;
                    break;
                end
            end
            
            % Encontrar endset (fim do pico)
            endset_idx = min_idx;
            for i = min_idx:length(heat_flow_smooth)
                if heat_flow_smooth(i) >= threshold
                    endset_idx = i;
                    break;
                end
            end
            
            % Garantir que os índices estão dentro dos limites
            onset_idx = max(1, min(onset_idx, length(temperature)));
            endset_idx = max(1, min(endset_idx, length(temperature)));
            
            tc_transition = struct(...
                'type', 'Cristalizacao', ...
                'onset_temp', temperature(onset_idx), ...
                'peak_temp', tc, ...
                'endset_temp', temperature(endset_idx));
            
            transitions = [transitions, tc_transition];
        end
        
        % Armazenar todas as transições
        cooling_results.transitions = transitions;
    end
    
    function [combined_results] = consolidateResults(heating_results, cooling_results)
        % Função para consolidar resultados de aquecimento e resfriamento
        
        combined_results = struct();
        
        % Extrair valores de interesse do aquecimento
        for i = 1:length(heating_results.transitions)
            trans = heating_results.transitions(i);
            if strcmp(trans.type, 'Transicao vitrea')
                combined_results.tg = trans.peak_temp;
            elseif strcmp(trans.type, 'Fusao')
                combined_results.tm = trans.peak_temp;
            end
        end
        
        % Extrair valores de interesse do resfriamento
        for i = 1:length(cooling_results.transitions)
            trans = cooling_results.transitions(i);
            if strcmp(trans.type, 'Cristalizacao')
                combined_results.tc = trans.peak_temp;
            end
        end
        
        % Calcular grau de cristalinidade se possível
        if isfield(combined_results, 'tm') && isfield(combined_results, 'tc')
            combined_results.crystallinity_index = (combined_results.tm - combined_results.tc) / combined_results.tm;
        end
    end
end

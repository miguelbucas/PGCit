function [sample, results] = analyzeSolubility_wrapper(sample, varargin)
% ANALYZESOLUBILITY_WRAPPER - Wrapper para analyzeSolubility que corrige problemas de campos ausentes
%
% Esta função é um wrapper para analyzeSolubility que adiciona o campo solvent_type
% e garante que o campo inv_temperature exista antes de chamar a função original.
%
% Sintaxe:
%   [sample, results] = analyzeSolubility_wrapper(sample, varargin)
%
% Entradas:
%   sample - Estrutura contendo dados da amostra
%   varargin - Parâmetros opcionais para controlar a análise
%
% Saídas:
%   sample - Estrutura da amostra atualizada com resultados
%   results - Estrutura contendo resultados da análise

    % Verificar e preparar os dados de solubilidade
    if isfield(sample, 'measurements') && isfield(sample.measurements, 'solubility')
        solubility_data = sample.measurements.solubility;
        solvent_fields = fieldnames(solubility_data);
        
        % Processar cada solvente
        for i = 1:length(solvent_fields)
            solvent_key = solvent_fields{i};
            
            % 1. Verificar e adicionar campo inv_temperature
            if ~isfield(solubility_data.(solvent_key), 'inv_temperature') && ...
               isfield(solubility_data.(solvent_key), 'temperature_K')
                fprintf('Adicionando campo inv_temperature para o solvente %s\n', solvent_key);
                sample.measurements.solubility.(solvent_key).inv_temperature = ...
                    1 ./ sample.measurements.solubility.(solvent_key).temperature_K;
            end
            
            % 2. Adicionar campo solvent_type baseado no nome do solvente
            if ~isfield(solubility_data.(solvent_key), 'solvent_type')
                fprintf('Adicionando campo solvent_type para o solvente %s\n', solvent_key);
                
                % Mapear nomes comuns de solventes
                switch lower(solvent_key)
                    case 'agua'
                        solvent_type = 'Água';
                    case 'etanol'
                        solvent_type = 'Etanol';
                    case 'metanol'
                        solvent_type = 'Metanol';
                    case 'acetona'
                        solvent_type = 'Acetona';
                    case 'dmso'
                        solvent_type = 'DMSO';
                    case 'dmf'
                        solvent_type = 'DMF';
                    otherwise
                        solvent_type = solvent_key; % Usar o próprio nome como tipo
                end
                
                sample.measurements.solubility.(solvent_key).solvent_type = solvent_type;
            end
        end
    end
    
    % Chamar a função original com os dados preparados
    try
        [sample, results] = analyzeSolubility(sample, varargin{:});
    catch e
        fprintf('Erro em analyzeSolubility: %s\n', e.message);
        
        % Implementação alternativa simplificada se a original falhar
        fprintf('Usando implementação alternativa simplificada...\n');
        
        % Inicializar parser de parâmetros
        p = inputParser;
        addParameter(p, 'SmoothingWindow', 5, @isnumeric);
        addParameter(p, 'SmoothingOrder', 2, @isnumeric);
        addParameter(p, 'PlotResults', false, @islogical);
        parse(p, varargin{:});
        
        % Inicializar estrutura de resultados
        results = struct();
        
        % Processar cada solvente
        if isfield(sample, 'measurements') && isfield(sample.measurements, 'solubility')
            solubility_data = sample.measurements.solubility;
            solvent_fields = fieldnames(solubility_data);
            
            % Criar subcampo solvents na estrutura de resultados
            results.solvents = struct();
            
            for i = 1:length(solvent_fields)
                solvent_key = solvent_fields{i};
                solvent_data = solubility_data.(solvent_key);
                
                % Extrair dados
                if isfield(solvent_data, 'temperature') && ...
                   isfield(solvent_data, 'temperature_K') && ...
                   isfield(solvent_data, 'solubility') && ...
                   isfield(solvent_data, 'ln_solubility')
                    
                    temperature = solvent_data.temperature;
                    temperature_K = solvent_data.temperature_K;
                    solubility = solvent_data.solubility;
                    ln_solubility = solvent_data.ln_solubility;
                    
                    % Calcular inverso da temperatura se não existir
                    if isfield(solvent_data, 'inv_temperature')
                        inv_temperature = solvent_data.inv_temperature;
                    else
                        inv_temperature = 1 ./ temperature_K;
                    end
                    
                    % Calcular parâmetros termodinâmicos usando equação de Van't Hoff
                    % ln(x) = -ΔH/RT + ΔS/R
                    coefs = polyfit(inv_temperature, ln_solubility, 1);
                    slope = coefs(1);
                    intercept = coefs(2);
                    
                    % Calcular entalpia e entropia
                    R = 8.314;  % Constante dos gases (J/mol·K)
                    enthalpy = -slope * R / 1000;  % kJ/mol
                    entropy = intercept * R;  % J/mol·K
                    
                    % Calcular energia livre de Gibbs a 25°C (298.15 K)
                    gibbs_free_energy = enthalpy - (298.15 * entropy / 1000);  % kJ/mol
                    
                    % Valores ajustados pela equação
                    fitted_values = polyval(coefs, inv_temperature);
                    
                    % Calcular R²
                    y_mean = mean(ln_solubility);
                    ss_total = sum((ln_solubility - y_mean).^2);
                    ss_residual = sum((ln_solubility - fitted_values).^2);
                    r_squared = 1 - (ss_residual / ss_total);
                    
                    % Armazenar resultados
                    solvent_results = struct(...
                        'enthalpy', enthalpy, ...
                        'entropy', entropy, ...
                        'gibbs_free_energy', gibbs_free_energy, ...
                        'r_squared', r_squared, ...
                        'slope', slope, ...
                        'intercept', intercept, ...
                        'fitted_values', fitted_values);
                    
                    results.solvents.(solvent_key) = solvent_results;
                    
                    fprintf('  Processado solvente %s: ΔH = %.2f kJ/mol, ΔS = %.2f J/mol·K, R² = %.4f\n', ...
                        solvent_key, enthalpy, entropy, r_squared);
                else
                    fprintf('  Dados incompletos para o solvente %s. Pulando...\n', solvent_key);
                end
            end
            
            % Adicionar resultados às propriedades da amostra
            sample.properties.solubility = results;
        else
            fprintf('  Nenhum dado de solubilidade encontrado na amostra.\n');
        end
    end
end

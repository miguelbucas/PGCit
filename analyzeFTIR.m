%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% analyzeFTIR.m - Análise de espectroscopia FTIR para polímeros PGCit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ÍNDICE DE FUNÇÕES:
% ------------------
% [Linha 26]  analyzeFTIR                - Função principal de análise FTIR
% [Linha 136] identifyFunctionalGroups    - Identifica grupos funcionais nos espectros
% [Linha 292] initFunctionalGroupDB       - Inicializa base de dados de grupos funcionais
% [Linha 379] calculateConfidence         - Calcula nível de confiança para identificações
% [Linha 475] createDefaultFTIRLibrary    - Cria biblioteca padrão de espectros FTIR
% [Linha 584] calculateSpectralIndices    - Calcula índices espectrais para caracterização
%
% Analisa espectros FTIR para identificar grupos funcionais e características estruturais
%
% Sintaxe:
%   [sample, results] = analyzeFTIR(sample, varargin)
%
% Parâmetros de Entrada:
%   sample   - Estrutura da amostra contendo dados FTIR
%   varargin - Pares nome-valor para parâmetros opcionais:
%     'SmoothingWindow'   - Tamanho da janela para suavização (padrão: 9)
%     'SmoothingOrder'    - Ordem do polinômio para suavização (padrão: 3)
%     'BaselineCorrection' - Aplicar correção de linha base (padrão: true)
%     'PeakThreshold'     - Limiar para detecção de picos (padrão: 0.05)
%     'UseReferenceLibrary' - Usar biblioteca de referência (padrão: true)
%     'ReferenceLibraryPath' - Caminho para biblioteca de referência (padrão: '')
%
% Saída:
%   sample  - Estrutura da amostra atualizada com resultados da análise
%   results - Estrutura contendo resultados detalhados da análise
%
% Exemplo:
%   [sample, results] = analyzeFTIR(sample, 'SmoothingWindow', 15);
%
% Ver também: importFTIR, analyzeTGA, analyzeDSC, analyzeSolubility

function [sample, results] = analyzeFTIR(sample, varargin)
    % Verificar argumentos de entrada
    validateattributes(sample, {'struct'}, {}, 'analyzeFTIR', 'sample', 1);
    
    % Verificar se a amostra contém dados FTIR
    if ~isfield(sample, 'measurements') || ~isfield(sample.measurements, 'ftir')
        error('A amostra não contém dados FTIR. Importe os dados primeiro usando importFTIR.');
    end
    
    % Configurar parser de entrada
    p = inputParser;
    p.CaseSensitive = false;
    p.KeepUnmatched = true;
    
    % Adicionar parâmetros
    addParameter(p, 'SmoothingWindow', 9, @(x) isnumeric(x) && isscalar(x) && x > 0 && mod(x, 2) == 1);
    addParameter(p, 'SmoothingOrder', 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'BaselineCorrection', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
    addParameter(p, 'PeakThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'UseReferenceLibrary', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
    addParameter(p, 'ReferenceLibraryPath', '', @(x) ischar(x) || isstring(x));
    
    % Analisar argumentos
    parse(p, varargin{:});
    
    % Extrair dados FTIR da amostra
    ftir_data = sample.measurements.ftir;
    wavenumbers = ftir_data.wavenumbers;
    absorbance = ftir_data.absorbance;
    
    % Verificar se os números de onda estão em ordem decrescente (comum em FTIR)
    % msbackadj exige vetores estritamente crescentes
    if wavenumbers(1) > wavenumbers(end) % Se está em ordem decrescente
        % Inverter ordem para tornar crescente
        wavenumbers = flip(wavenumbers);
        absorbance = flip(absorbance);
        fprintf('FTIR: Números de onda invertidos para ordem crescente (4000 -> 400 para 400 -> 4000)\n');
    end
    
    % Inicializar estrutura de resultados
    results = struct();
    
    % 1. Suavização do espectro usando filtro Savitzky-Golay
    absorbance_smooth = sgolayfilt(absorbance, p.Results.SmoothingOrder, p.Results.SmoothingWindow);
    results.absorbance_smooth = absorbance_smooth;
    
    % 2. Correção de linha base (se solicitado)
    if p.Results.BaselineCorrection
        % Adicionar diretório utils ao path para encontrar msbackadj_safe
        utils_path = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'utils');
        if ~contains(path, utils_path)
            addpath(utils_path);
        end
        
        % Usar wrapper seguro para msbackadj para correção de linha base
        [absorbance_corrected, baseline] = msbackadj_safe(wavenumbers, absorbance_smooth, ...
            'WindowSize', round(length(wavenumbers)/10), ...
            'StepSize', round(length(wavenumbers)/20), ...
            'Quantile', 0.1);
        
        results.absorbance_corrected = absorbance_corrected;
        results.baseline = baseline;
    else
        absorbance_corrected = absorbance_smooth;
        results.absorbance_corrected = absorbance_corrected;
        results.baseline = zeros(size(absorbance_smooth));
    end
    
    % 3. Detecção de picos
    % Encontrar picos usando findpeaks
    [peak_heights, peak_positions, peak_widths, peak_prominences] = findpeaks(absorbance_corrected, wavenumbers, ...
        'MinPeakHeight', p.Results.PeakThreshold * max(absorbance_corrected), ...
        'MinPeakProminence', p.Results.PeakThreshold * max(absorbance_corrected) / 2, ...
        'SortStr', 'descend');
    
    % Organizar informações de picos
    peaks = struct(...
        'positions', peak_positions, ...
        'heights', peak_heights, ...
        'widths', peak_widths, ...
        'prominences', peak_prominences ...
    );
    
    results.peaks = peaks;
    
    % 4. Identificação de grupos funcionais
    functional_groups = identifyFunctionalGroups(wavenumbers, absorbance_corrected, peaks);
    results.functional_groups = functional_groups;
    
    % 5. Comparação com biblioteca de referência (se solicitado)
    if p.Results.UseReferenceLibrary
        reference_results = compareWithReferenceLibrary(wavenumbers, absorbance_corrected, p.Results.ReferenceLibraryPath);
        results.reference_comparison = reference_results;
    end
    
    % 6. Cálculo de índices e razões importantes
    indices = calculateSpectralIndices(wavenumbers, absorbance_corrected, peaks);
    results.spectral_indices = indices;
    
    % Atualizar a estrutura da amostra com os resultados
    sample.measurements.ftir.processed = true;
    sample.measurements.ftir.analysis_date = datetime('now');
    sample.measurements.ftir.peaks = peaks;
    sample.measurements.ftir.functional_groups = functional_groups;
    sample.measurements.ftir.spectral_indices = indices;
    
    if p.Results.UseReferenceLibrary && isfield(results, 'reference_comparison')
        sample.measurements.ftir.reference_comparison = results.reference_comparison;
    end
    
    % Adicionar propriedades derivadas à amostra
    if ~isfield(sample, 'properties')
        sample.properties = struct();
    end
    
    % Adicionar propriedades baseadas na análise FTIR
    sample.properties.ftir_derived = struct(...
        'esterification_degree', indices.esterification_degree, ...
        'hydroxyl_content', indices.hydroxyl_content, ...
        'crosslinking_index', indices.crosslinking_index ...
    );
    
    % Exibir mensagem de confirmação
    fprintf('Análise FTIR concluída com sucesso.\n');
    fprintf('Detectados %d picos significativos.\n', length(peaks.positions));
    fprintf('Identificados %d grupos funcionais.\n', length(fieldnames(functional_groups)));
end

% Função auxiliar para identificar grupos funcionais
function groups = identifyFunctionalGroups(wavenumbers, absorbance, peaks)
    % Inicializar estrutura para grupos funcionais
    groups = struct();
    
    % Definir base de dados de grupos funcionais para espectros FTIR
    % Formato: {Número de onda mínimo, Número de onda máximo, Nome do grupo, Classe, Descrição, Intensidade típica}
    functionalGroupDB = initFunctionalGroupDB();
    
    % Verificar se wavenumbers está em ordem crescente ou decrescente
    isDescending = wavenumbers(1) > wavenumbers(end);
    
    % Garantir que os dados estão como vetores coluna
    wavenumbers = wavenumbers(:);
    absorbance = absorbance(:);
    
    % Para cada grupo funcional na base de dados
    for i = 1:length(functionalGroupDB)
        minWavenumber = functionalGroupDB{i}{1};
        maxWavenumber = functionalGroupDB{i}{2};
        groupName = functionalGroupDB{i}{3};
        className = functionalGroupDB{i}{4};
        groupDesc = functionalGroupDB{i}{5};
        expectedIntensity = functionalGroupDB{i}{6};
        
        % Determinar a região de interesse no espectro
        if isDescending
            band_indices = find(wavenumbers <= maxWavenumber & wavenumbers >= minWavenumber);
        else
            band_indices = find(wavenumbers >= minWavenumber & wavenumbers <= maxWavenumber);
        end
        
        if ~isempty(band_indices)
            % Encontrar o pico mais proeminente na região
            [max_abs, max_idx] = max(absorbance(band_indices));
            max_wavenumber = wavenumbers(band_indices(max_idx));
            
            % Definir um limiar baseado na intensidade esperada
            intensityMap = struct('weak', 0.2, 'medium', 0.4, 'strong', 0.6);
            intensity_threshold = intensityMap.(expectedIntensity) * max(absorbance);
            
            if max_abs > intensity_threshold
                % Encontrar o pico correspondente na lista de picos detectados
                peak_idx = find(ismember(peaks.positions, max_wavenumber) | ...
                               abs(peaks.positions - max_wavenumber) < 10);
                
                if ~isempty(peak_idx)
                    % Usar informações do pico detectado
                    peak_position = peaks.positions(peak_idx(1));
                    peak_height = peaks.heights(peak_idx(1));
                    peak_width = peaks.widths(peak_idx(1));
                    peak_prominence = peaks.prominences(peak_idx(1));
                    
                    % Determinar a qualidade da correspondência
                    intensity_match = determineIntensityMatch(peak_height, expectedIntensity);
                    
                    % Determinar o nível de confiança baseado na correspondência
                    confidence = calculateConfidence(intensity_match, peak_prominence);
                    
                    % Criar nome de campo compatível com MATLAB
                    field_name = strrep(strrep(groupName, ' ', '_'), '-', '_');
                    field_name = strrep(field_name, '=', '_');
                    field_name = strrep(field_name, '/', '_');
                    
                    % Adicionar informações ao grupo funcional
                    groups.(field_name) = struct(...
                        'wavenumber', peak_position, ...
                        'absorbance', peak_height, ...
                        'width', peak_width, ...
                        'confidence', confidence, ...
                        'description', sprintf('%s: %s (%s)', className, groupDesc, expectedIntensity), ...
                        'raw_position', max_wavenumber, ...
                        'raw_absorbance', max_abs);
                else
                    % Usar método alternativo quando o pico não está na lista de picos
                    % Calcular a largura da banda usando FWHM (Full Width at Half Maximum)
                    try
                        half_max = max_abs / 2;
                        band_values = absorbance(band_indices);
                        wave_values = wavenumbers(band_indices);
                        
                        % Encontrar pontos que cruzam half_max
                        above_threshold = band_values > half_max;
                        transitions = diff([0; above_threshold; 0]);
                        rising_edges = find(transitions == 1);
                        falling_edges = find(transitions == -1) - 1;
                        
                        if ~isempty(rising_edges) && ~isempty(falling_edges)
                            % Garantir que temos um par válido
                            if rising_edges(1) > falling_edges(1)
                                falling_edges = falling_edges(2:end);
                            end
                            if length(rising_edges) > length(falling_edges)
                                rising_edges = rising_edges(1:length(falling_edges));
                            end
                            
                            % Calcular a largura como a média das FWHMs encontradas
                            widths = abs(wave_values(falling_edges) - wave_values(rising_edges));
                            avg_width = mean(widths);
                            
                            % Criar nome de campo compatível com MATLAB
                            field_name = strrep(strrep(groupName, ' ', '_'), '-', '_');
                            field_name = strrep(field_name, '=', '_');
                            field_name = strrep(field_name, '/', '_');
                            
                            % Adicionar com nível de confiança menor
                            groups.(field_name) = struct(...
                                'wavenumber', max_wavenumber, ...
                                'absorbance', max_abs, ...
                                'width', avg_width, ...
                                'confidence', 0.6, ... % Confiança menor para picos não detectados por findpeaks
                                'description', sprintf('%s: %s (%s)', className, groupDesc, expectedIntensity), ...
                                'raw_position', max_wavenumber, ...
                                'raw_absorbance', max_abs);
                        end
                    catch
                        % Se o cálculo da FWHM falhar, ainda adicionar com largura estimada
                        field_name = strrep(strrep(groupName, ' ', '_'), '-', '_');
                        field_name = strrep(field_name, '=', '_');
                        field_name = strrep(field_name, '/', '_');
                        
                        % Estimar largura baseado na região analisada
                        est_width = (maxWavenumber - minWavenumber) / 5;
                        
                        groups.(field_name) = struct(...
                            'wavenumber', max_wavenumber, ...
                            'absorbance', max_abs, ...
                            'width', est_width, ...
                            'confidence', 0.5, ... % Confiança ainda menor
                            'description', sprintf('%s: %s (%s)', className, groupDesc, expectedIntensity), ...
                            'raw_position', max_wavenumber, ...
                            'raw_absorbance', max_abs);
                    end
                end
            end
        end
    end
    
    % Adicionar interpretações específicas para PGCit
    if isfield(groups, 'C_O_ester') && isfield(groups, 'C_O_acid')
        % Razão entre éster e ácido indica grau de esterificação
        ratio = groups.C_O_ester.absorbance / groups.C_O_acid.absorbance;
        groups.esterification_ratio = struct(...
            'value', ratio, ...
            'description', 'Razão entre C=O de éster e ácido (indica grau de esterificação)');
    end
    
    % Verificar presença de grupos hidroxila
    if isfield(groups, 'O_H_stretching')
        % Presença de grupos OH indica potencial para reticulação
        groups.hydroxyl_presence = struct(...
            'value', groups.O_H_stretching.absorbance, ...
            'description', 'Presença de grupos hidroxila (potencial para reticulação)');
    end
end

% Função auxiliar para inicializar a base de dados de grupos funcionais
function functionalGroupDB = initFunctionalGroupDB()
    % Inicializa a base de dados de grupos funcionais para espectros FTIR
    % Baseado em tabelas de referência de espectroscopia FTIR
    
    functionalGroupDB = {
        % Formato: {Número de onda mínimo, Número de onda máximo, Nome do grupo, Classe, Descrição, Intensidade típica}
        % Região de estiramento O-H
        [3584, 3700, 'O-H stretching', 'alcohol', 'Free OH', 'medium'], ...
        [3200, 3550, 'O-H stretching', 'alcohol', 'Hydrogen bonded OH', 'strong'], ...
        [2500, 3300, 'O-H stretching', 'carboxylic acid', 'Hydrogen bonded OH', 'strong'], ...
        
        % Região de estiramento N-H
        [3300, 3500, 'N-H stretching', 'primary amine', 'Two bands', 'medium'], ...
        [3300, 3400, 'N-H stretching', 'secondary amine', 'Single band', 'medium'], ...
        
        % Região de estiramento C-H
        [3270, 3330, 'C-H stretching', 'alkyne', 'Terminal alkyne', 'strong'], ...
        [3000, 3100, 'C-H stretching', 'alkene', 'sp2 C-H', 'medium'], ...
        [2840, 3000, 'C-H stretching', 'alkane', 'sp3 C-H', 'medium'], ...
        [2700, 2830, 'C-H stretching', 'aldehyde', 'Two weak bands', 'medium'], ...
        
        % Região de estiramento C=O
        [1800, 1830, 'C=O stretching', 'acid chloride', 'Acyl chloride', 'strong'], ...
        [1735, 1750, 'C=O stretching', 'ester', 'Saturated ester', 'strong'], ...
        [1720, 1740, 'C=O stretching', 'aldehyde', 'Saturated aldehyde', 'strong'], ...
        [1710, 1720, 'C=O stretching', 'ketone', 'Saturated ketone', 'strong'], ...
        [1700, 1725, 'C=O stretching', 'carboxylic acid', 'Saturated acid', 'strong'], ...
        [1680, 1710, 'C=O stretching', 'carboxylic acid', 'α,β-unsaturated acid', 'strong'], ...
        [1630, 1690, 'C=O stretching', 'amide', 'Amide I band', 'strong'], ...
        
        % Região de estiramento C=C
        [1620, 1680, 'C=C stretching', 'alkene', 'Non-conjugated', 'medium'], ...
        [1600, 1620, 'C=C stretching', 'aromatic', 'Ring stretching', 'medium'], ...
        
        % Região de flexão N-H
        [1550, 1640, 'N-H bending', 'amide', 'Amide II band', 'strong'], ...
        [1600, 1640, 'N-H bending', 'amine', 'Primary amine', 'medium'], ...
        
        % Região de flexão C-H
        [1430, 1470, 'C-H bending', 'alkane', 'CH2 scissoring', 'medium'], ...
        [1370, 1390, 'C-H bending', 'alkane', 'CH3 symmetric', 'medium'], ...
        
        % Região de estiramento C-O
        [1200, 1250, 'C-O stretching', 'ester', 'Aromatic ester', 'strong'], ...
        [1150, 1200, 'C-O stretching', 'ester', 'Aliphatic ester', 'strong'], ...
        [1050, 1150, 'C-O stretching', 'alcohol', 'Primary alcohol', 'strong'], ...
        [1100, 1200, 'C-O stretching', 'alcohol', 'Secondary/tertiary alcohol', 'strong'], ...
        
        % Região de estiramento C-N
        [1180, 1360, 'C-N stretching', 'amine', 'Aliphatic amine', 'medium'], ...
        [1300, 1400, 'C-N stretching', 'amide', 'Amide III band', 'medium'], ...
        
        % Região de flexão =C-H
        [900, 990, 'C-H bending', 'alkene', 'Out-of-plane bend', 'strong'], ...
        [650, 900, 'C-H bending', 'aromatic', 'Out-of-plane bend', 'strong'], ...
        
        % Halogênios
        [500, 800, 'C-Cl stretching', 'halo compound', 'Chloroalkane', 'strong'], ...
        [500, 680, 'C-Br stretching', 'halo compound', 'Bromoalkane', 'strong'], ...
        
        % Região fingerprint específica de polímeros
        [1100, 1300, 'C-O-C stretching', 'ether', 'Ether bridge', 'strong'], ...
        [840, 880, 'C-O-C bending', 'epoxide', 'Epoxide ring', 'medium'], ...
        [750, 810, 'C-C stretching', 'polyethylene', 'CH2 rocking', 'medium']
    };
end

% Função auxiliar para determinar a correspondência da intensidade
function match = determineIntensityMatch(measured_intensity, expected_intensity)
    % Converte intensidade esperada em valor numérico
    expected_map = struct('weak', 0.3, 'medium', 0.6, 'strong', 0.9);
    expected_value = expected_map.(expected_intensity);
    
    % Normaliza a intensidade medida para o intervalo [0, 1]
    measured_norm = measured_intensity / max(measured_intensity);
    
    % Calcula a diferença entre esperado e medido
    diff = abs(measured_norm - expected_value);
    
    % Retorna um valor de correspondência entre 0 e 1
    match = max(0, 1 - (diff / 0.5));
end

% Função auxiliar para calcular o nível de confiança
function conf = calculateConfidence(intensity_match, prominence)
    % Normaliza a proeminência para o intervalo [0, 1]
    prom_norm = min(1, prominence / 0.2);
    
    % Combina os fatores para determinar a confiança
    conf = 0.4 * intensity_match + 0.6 * prom_norm;
    
    % Garante que está no intervalo [0, 1]
    conf = max(0, min(1, conf));
end

% Função auxiliar para comparar com biblioteca de referência
function results = compareWithReferenceLibrary(wavenumbers, absorbance, library_path)
    % Inicializar resultados
    results = struct(...
        'similarity_scores', [], ...
        'best_match', struct(), ...
        'similar_spectra', {} ...
    );
    
    % Carregar biblioteca de referência
    try
        if isempty(library_path)
            % Usar biblioteca padrão (criar uma biblioteca simples para demonstração)
            library = createDefaultFTIRLibrary();
        else
            % Carregar biblioteca do arquivo especificado
            if exist(library_path, 'file')
                load(library_path, 'ftir_library');
                library = ftir_library;
            else
                warning('Biblioteca de referência não encontrada. Usando biblioteca padrão.');
                library = createDefaultFTIRLibrary();
            end
        end
        
        % Verificar se a biblioteca tem a estrutura esperada
        if ~isfield(library, 'spectra') || ~isfield(library, 'metadata')
            error('Formato de biblioteca inválido.');
        end
        
        % Calcular similaridade com cada espectro na biblioteca
        n_spectra = length(library.spectra);
        similarity_scores = zeros(1, n_spectra);
        
        for i = 1:n_spectra
            ref_spectrum = library.spectra{i};
            
            % Interpolar espectro de referência para os mesmos números de onda
            ref_absorbance_interp = interp1(ref_spectrum.wavenumbers, ref_spectrum.absorbance, ...
                                           wavenumbers, 'linear', 0);
            
            % Normalizar espectros para comparação
            abs_norm = absorbance / max(absorbance);
            ref_abs_norm = ref_absorbance_interp / max(ref_absorbance_interp);
            
            % Calcular coeficiente de correlação
            similarity_scores(i) = corr(abs_norm, ref_abs_norm);
        end
        
        % Ordenar por similaridade
        [sorted_scores, indices] = sort(similarity_scores, 'descend');
        
        % Armazenar resultados
        results.similarity_scores = similarity_scores;
        
        % Armazenar os 3 melhores matches (ou menos se não houver 3)
        n_matches = min(3, n_spectra);
        results.similar_spectra = cell(1, n_matches);
        
        for i = 1:n_matches
            idx = indices(i);
            results.similar_spectra{i} = struct(...
                'spectrum', library.spectra{idx}, ...
                'metadata', library.metadata{idx}, ...
                'similarity_score', sorted_scores(i) ...
            );
        end
        
        % Armazenar o melhor match
        if n_spectra > 0
            best_idx = indices(1);
            results.best_match = struct(...
                'spectrum', library.spectra{best_idx}, ...
                'metadata', library.metadata{best_idx}, ...
                'similarity_score', sorted_scores(1) ...
            );
        end
        
    catch ME
        warning('Erro ao comparar com biblioteca de referência: %s', ME.message);
        results.error = ME.message;
    end
end

% Função auxiliar para criar uma biblioteca FTIR padrão
function library = createDefaultFTIRLibrary()
    % Criar uma biblioteca simples com alguns espectros de referência
    
    % Inicializar biblioteca
    library = struct(...
        'spectra', cell(1, 3), ...
        'metadata', cell(1, 3), ...
        'bands', struct(...
            'OH', [3200, 3600], ...
            'CH', [2800, 3000], ...
            'C_O_ester', [1700, 1750], ...
            'C_O_acid', [1680, 1710], ...
            'C_O_C', [1050, 1250], ...
            'C_OH', [1000, 1100] ...
        ) ...
    );
    
    % Criar números de onda comuns
    wavenumbers = 4000:-1:400;
    
    % Espectro 1: PGCit com alta esterificação
    absorbance1 = zeros(size(wavenumbers));
    % Adicionar picos característicos
    absorbance1 = absorbance1 + 0.5 * exp(-((wavenumbers - 3400)/100).^2); % OH
    absorbance1 = absorbance1 + 0.7 * exp(-((wavenumbers - 2950)/50).^2);  % CH
    absorbance1 = absorbance1 + 1.0 * exp(-((wavenumbers - 1720)/30).^2);  % C=O éster
    absorbance1 = absorbance1 + 0.2 * exp(-((wavenumbers - 1690)/30).^2);  % C=O ácido
    absorbance1 = absorbance1 + 0.8 * exp(-((wavenumbers - 1150)/80).^2);  % C-O-C
    
    library.spectra{1} = struct(...
        'wavenumbers', wavenumbers, ...
        'absorbance', absorbance1, ...
        'peaks', struct(...
            'positions', [3400, 2950, 1720, 1690, 1150], ...
            'intensities', [0.5, 0.7, 1.0, 0.2, 0.8] ...
        ) ...
    );
    
    library.metadata{1} = struct(...
        'name', 'PGCit Alta Esterificação', ...
        'glycerol_fraction', 1.0, ...
        'citric_acid_fraction', 1.0, ...
        'catalyst_type', 'H2SO4', ...
        'catalyst_concentration', 0.5, ...
        'esterification_degree', 'Alto', ...
        'source', 'Referência padrão', ...
        'notes', 'Polímero com alta razão éster/ácido' ...
    );
    
    % Espectro 2: PGCit com média esterificação
    absorbance2 = zeros(size(wavenumbers));
    % Adicionar picos característicos
    absorbance2 = absorbance2 + 0.7 * exp(-((wavenumbers - 3400)/100).^2); % OH
    absorbance2 = absorbance2 + 0.6 * exp(-((wavenumbers - 2950)/50).^2);  % CH
    absorbance2 = absorbance2 + 0.7 * exp(-((wavenumbers - 1720)/30).^2);  % C=O éster
    absorbance2 = absorbance2 + 0.4 * exp(-((wavenumbers - 1690)/30).^2);  % C=O ácido
    absorbance2 = absorbance2 + 0.6 * exp(-((wavenumbers - 1150)/80).^2);  % C-O-C
    
    library.spectra{2} = struct(...
        'wavenumbers', wavenumbers, ...
        'absorbance', absorbance2, ...
        'peaks', struct(...
            'positions', [3400, 2950, 1720, 1690, 1150], ...
            'intensities', [0.7, 0.6, 0.7, 0.4, 0.6] ...
        ) ...
    );
    
    library.metadata{2} = struct(...
        'name', 'PGCit Média Esterificação', ...
        'glycerol_fraction', 1.0, ...
        'citric_acid_fraction', 1.0, ...
        'catalyst_type', 'H2SO4', ...
        'catalyst_concentration', 0.3, ...
        'esterification_degree', 'Médio', ...
        'source', 'Referência padrão', ...
        'notes', 'Polímero com média razão éster/ácido' ...
    );
    
    % Espectro 3: PGCit com baixa esterificação
    absorbance3 = zeros(size(wavenumbers));
    % Adicionar picos característicos
    absorbance3 = absorbance3 + 0.9 * exp(-((wavenumbers - 3400)/100).^2); % OH
    absorbance3 = absorbance3 + 0.5 * exp(-((wavenumbers - 2950)/50).^2);  % CH
    absorbance3 = absorbance3 + 0.4 * exp(-((wavenumbers - 1720)/30).^2);  % C=O éster
    absorbance3 = absorbance3 + 0.8 * exp(-((wavenumbers - 1690)/30).^2);  % C=O ácido
    absorbance3 = absorbance3 + 0.4 * exp(-((wavenumbers - 1150)/80).^2);  % C-O-C
    
    library.spectra{3} = struct(...
        'wavenumbers', wavenumbers, ...
        'absorbance', absorbance3, ...
        'peaks', struct(...
            'positions', [3400, 2950, 1720, 1690, 1150], ...
            'intensities', [0.9, 0.5, 0.4, 0.8, 0.4] ...
        ) ...
    );
    
    library.metadata{3} = struct(...
        'name', 'PGCit Baixa Esterificação', ...
        'glycerol_fraction', 1.0, ...
        'citric_acid_fraction', 1.0, ...
        'catalyst_type', 'Nenhum', ...
        'catalyst_concentration', 0, ...
        'esterification_degree', 'Baixo', ...
        'source', 'Referência padrão', ...
        'notes', 'Polímero com baixa razão éster/ácido' ...
    );
end

% Função auxiliar para calcular índices espectrais
function indices = calculateSpectralIndices(wavenumbers, absorbance, peaks)
    % Inicializar estrutura de índices
    indices = struct();
    
    % Definir regiões de interesse
    roi = struct(...
        'OH_region', [3200, 3600], ...
        'CH_region', [2800, 3000], ...
        'C_O_ester_region', [1700, 1750], ...
        'C_O_acid_region', [1680, 1710], ...
        'C_O_C_region', [1050, 1250] ...
    );
    
    % Calcular intensidades integradas para cada região
    roi_names = fieldnames(roi);
    for i = 1:length(roi_names)
        region_name = roi_names{i};
        region_range = roi.(region_name);
        
        % Encontrar índices na região
        region_indices = find(wavenumbers >= region_range(1) & wavenumbers <= region_range(2));
        
        if ~isempty(region_indices)
            % Calcular área sob a curva na região
            region_area = trapz(wavenumbers(region_indices), absorbance(region_indices));
            indices.([region_name '_area']) = region_area;
            
            % Encontrar intensidade máxima na região
            [max_intensity, max_idx] = max(absorbance(region_indices));
            indices.([region_name '_max']) = max_intensity;
            indices.([region_name '_max_wavenumber']) = wavenumbers(region_indices(max_idx));
        else
            indices.([region_name '_area']) = 0;
            indices.([region_name '_max']) = 0;
            indices.([region_name '_max_wavenumber']) = NaN;
        end
    end
    
    % Calcular índices específicos para PGCit
    
    % Grau de esterificação: razão entre C=O éster e C=O ácido
    if isfield(indices, 'C_O_ester_region_area') && isfield(indices, 'C_O_acid_region_area')
        if indices.C_O_acid_region_area > 0
            indices.esterification_degree = indices.C_O_ester_region_area / indices.C_O_acid_region_area;
        else
            indices.esterification_degree = Inf;
        end
    else
        indices.esterification_degree = NaN;
    end
    
    % Conteúdo de hidroxila: intensidade relativa da região OH
    if isfield(indices, 'OH_region_max')
        indices.hydroxyl_content = indices.OH_region_max / max(absorbance);
    else
        indices.hydroxyl_content = NaN;
    end
    
    % Índice de reticulação: razão entre C-O-C e OH
    if isfield(indices, 'C_O_C_region_area') && isfield(indices, 'OH_region_area') && indices.OH_region_area > 0
        indices.crosslinking_index = indices.C_O_C_region_area / indices.OH_region_area;
    else
        indices.crosslinking_index = NaN;
    end
    
    % Índice de alifaticidade: intensidade relativa da região CH
    if isfield(indices, 'CH_region_max')
        indices.aliphaticity_index = indices.CH_region_max / max(absorbance);
    else
        indices.aliphaticity_index = NaN;
    end
end

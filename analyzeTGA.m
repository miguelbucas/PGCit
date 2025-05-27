%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% analyzeTGA.m - Análise termogravimétrica (TGA) para polímeros PGCit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ÍNDICE DE FUNÇÕES:
% ------------------
% [Linha 43]   analyzeTGA                 - Função principal de análise TGA
% [Linha 246]  identifyDecompositionStages - Identifica estágios de decomposição térmica
% [Linha 366]  calculateCharacteristicTemperatures - Calcula temperaturas características
% [Linha 420]  compareWithReferenceLibrary - Compara curvas com biblioteca de referência
% [Linha 478]  calculateContentParameters - Calcula parâmetros de conteúdo (umidade, voláteis, etc)
% [Linha 542]  calculateThermalStabilityIndex - Calcula índice de estabilidade térmica
%   2. Detecção e caracterização de estágios de decomposição térmica
%   3. Cálculo de temperaturas características (T_onset, T_endset, T5, T10, T50, T90)
%   4. Determinação de conteúdo de umidade, voláteis, carbono fixo e resíduo
%   5. Comparação com biblioteca de referência para identificação de padrões
%
% As análises de TGA são cruciais para caracterizar a estabilidade térmica dos polímeros
% PGCit, permitindo avaliar sua adequação para aplicações específicas como embalagens,
% dispositivos biomédicos, ou materiais de construção sustentáveis.
%
% Sintaxe:
%   [sample, results] = analyzeTGA(sample, varargin)
%
% Parâmetros de Entrada:
%   sample   - Estrutura da amostra contendo dados TGA já importados
%              Deve ter um campo 'measurements.tga' com subcampos:
%              - temperature: vetor de temperaturas (em °C)
%              - weight_percent: vetor de massa percentual
%              - dtg: derivada termogravimétrica (opcional)
%
%   varargin - Pares nome-valor para parâmetros opcionais:
%     'SmoothingWindow'    - Tamanho da janela para suavização da curva TGA (padrão: 9)
%     'SmoothingOrder'     - Ordem do polinômio para filtro Savitzky-Golay (padrão: 3)
%     'DerivativeSmoothingWindow' - Tamanho da janela para suavização da DTG (padrão: 15)
%     'PeakThreshold'      - Limiar para detecção de picos DTG (padrão: 0.05)
%     'UseReferenceLibrary' - Usar biblioteca de referência (padrão: true)
%     'ReferenceLibraryPath' - Caminho para biblioteca de referência (padrão: '')
%
% Saída:
%   sample  - Estrutura da amostra atualizada com resultados da análise
%   results - Estrutura contendo resultados detalhados da análise
%
% Exemplo:
%   [sample, results] = analyzeTGA(sample, 'SmoothingWindow', 15);
%
% Ver tambÃ©m: importTGA, analyzeFTIR, analyzeDSC, analyzeSolubility

function [sample, results] = analyzeTGA(sample, varargin)
    %% ImplementaÃ§Ã£o da funÃ§Ã£o de anÃ¡lise termogravimÃ©trica (TGA)
    %
    % Esta funÃ§Ã£o processa dados de TGA de pololi­meros PGCit para extrair
    % informaÃ§Ãµes sobre decomposiÃ§Ã£o tÃ©rmica e estabilidade
    
    %% 1. ValidaÃ§Ã£o dos argumentos de entrada
    % Verificar se o primeiro argumento Ã© uma estrutura vÃ¡lida
    validateattributes(sample, {'struct'}, {}, 'analyzeTGA', 'sample', 1);
    
    % Verificar se a amostra contÃ©m dados TGA necessÃ¡rios para anÃ¡lise
    if ~isfield(sample, 'measurements') || ~isfield(sample.measurements, 'tga')
        error('A amostra nÃ£o contÃ©m dados TGA. Importe os dados primeiro usando importTGA.');
    end
    
    %% 2. ConfiguraÃ§Ã£o do parser de parÃ¢metros opcionais
    % O uso do InputParser permite configuraÃ§Ã£o flexÃ­vel do algoritmo
    p = inputParser;
    p.CaseSensitive = false;     % Nomes de parÃ¢metros nÃ£o diferenciam maiÃºsculas/minÃºsculas
    p.KeepUnmatched = true;      % Ignorar parÃ¢metros nÃ£o reconhecidos sem gerar erro
    
    % DefiniÃ§Ã£o dos parÃ¢metros com valores padrÃ£o e funÃ§Ãµes de validaÃ§Ã£o
    addParameter(p, 'SmoothingWindow', 9, @(x) isnumeric(x) && isscalar(x) && x > 0 && mod(x, 2) == 1);
    addParameter(p, 'SmoothingOrder', 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'DerivativeSmoothingWindow', 15, @(x) isnumeric(x) && isscalar(x) && x > 0 && mod(x, 2) == 1);
    addParameter(p, 'PeakThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'UseReferenceLibrary', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
    addParameter(p, 'ReferenceLibraryPath', '', @(x) ischar(x) || isstring(x));
    
    % Analisar os argumentos fornecidos
    parse(p, varargin{:});
    
    %% 3. ExtraÃ§Ã£o dos dados TGA armazenados na estrutura da amostra
    tga_data = sample.measurements.tga;
    temperature = tga_data.temperature;        % Vetor de temperaturas (em Â°C)
    weight_percent = tga_data.weight_percent;  % Vetor de massa percentual (0-100%)
    
    % Verificar se a DTG jÃ¡ estÃ¡ disponÃ­vel nos dados importados
    if isfield(tga_data, 'dtg')
        dtg_raw = tga_data.dtg;
    else
        dtg_raw = [];
    end
    
    % Inicializar estrutura de resultados
    results = struct();
    results.temperature = temperature;
    results.weight_percent = weight_percent;
    results.dtg_raw = dtg_raw;
    
    %% 4. PrÃ©-processamento dos dados TGA
    % SuavizaÃ§Ã£o da curva TGA usando filtro Savitzky-Golay
    weight_smooth = sgolayfilt(weight_percent, p.Results.SmoothingOrder, p.Results.SmoothingWindow);
    results.weight_smooth = weight_smooth;
    
    % CÃ¡lculo da derivada termogravimÃ©trica (DTG)
    dtg = gradient(weight_smooth, temperature);
    
    % SuavizaÃ§Ã£o da curva DTG
    dtg_smooth = sgolayfilt(dtg, p.Results.SmoothingOrder, p.Results.DerivativeSmoothingWindow);
    results.dtg_smooth = dtg_smooth;
    
    %% 5. DetecÃ§Ã£o de picos na curva DTG
    % Os picos DTG sÃ£o negativos (representam perda de massa)
    [peak_heights, peak_positions, peak_widths, peak_prominences] = findpeaks(-dtg_smooth, temperature, ...
        'MinPeakHeight', p.Results.PeakThreshold * max(-dtg_smooth), ...
        'MinPeakProminence', p.Results.PeakThreshold * max(-dtg_smooth) / 2, ...
        'SortStr', 'descend');
    
    % Converter alturas de pico de volta para valores negativos
    peak_heights = -peak_heights;
    
    % Organizar informaÃ§Ãµes dos picos em uma estrutura
    peaks = struct(...
        'positions', peak_positions, ...
        'heights', peak_heights, ...
        'widths', peak_widths, ...
        'prominences', peak_prominences ...
    );
    
    results.peaks = peaks;
    
    %% 6. Identificação e caracterização dos estágios de decomposição térmica
    % Identificar estágios de decomposição térmica
    % Código inline para evitar problemas com a função externa
    n_peaks = length(peaks.positions);
    decomposition_stages = cell(1, n_peaks);
    
    % Para cada pico DTG, identificar o estágio de decomposição correspondente
    for i = 1:n_peaks
        peak_temp = peaks.positions(i);
        peak_height = peaks.heights(i);
        peak_width = peaks.widths(i);
        
        % Estimar início e fim do estágio com a largura do pico
        half_width = peak_width / 2;
        start_temp = peak_temp - half_width;
        end_temp = peak_temp + half_width;
        
        % Ajustar limites para estarem dentro do intervalo de temperatura
        start_temp = max(start_temp, min(temperature));
        end_temp = min(end_temp, max(temperature));
        
        % Encontrar índices correspondentes
        [~, start_idx] = min(abs(temperature - start_temp));
        [~, peak_idx] = min(abs(temperature - peak_temp));
        [~, end_idx] = min(abs(temperature - end_temp));
        
        % Calcular perda de massa no estágio
        weight_start = weight_smooth(start_idx);
        weight_end = weight_smooth(end_idx);
        mass_loss = weight_start - weight_end;
        mass_loss_pct = (mass_loss / weight_smooth(1)) * 100;
        
        % Criar estrutura para o estágio
        stage = struct(...
            'start_temp', temperature(start_idx), ...
            'peak_temp', peak_temp, ...
            'end_temp', temperature(end_idx), ...
            'weight_start', weight_start, ...
            'weight_end', weight_end, ...
            'mass_loss', mass_loss_pct, ...
            'peak_dtg', peak_height ...
        );
        
        % Adicionar classificação baseada na temperatura
        if peak_temp < 150
            stage.type = 'Umidade';
        elseif peak_temp < 250
            stage.type = 'Grupos laterais não-reticulados';
        elseif peak_temp < 400
            stage.type = 'Descarboxilação/Despolimerização';
        else
            stage.type = 'Carbonização';
        end
        
        % Adicionar estágio ao array
        decomposition_stages{i} = stage;
    end
    
    % Converter cell array para array de estruturas
    if ~isempty(decomposition_stages)
        decomposition_stages = [decomposition_stages{:}];
    else
        decomposition_stages = struct([]);
    end
    results.decomposition_stages = decomposition_stages;
    
    %% 7. Cálculo de temperaturas características
    characteristic_temps = calculateCharacteristicTemperatures(temperature, weight_smooth);
    results.characteristic_temps = characteristic_temps;
    
    %% 8. ComparaÃ§Ã£o com biblioteca de referÃªncia (se solicitado)
    if p.Results.UseReferenceLibrary
        reference_results = compareWithReferenceLibrary(temperature, weight_smooth, dtg_smooth, p.Results.ReferenceLibraryPath);
        results.reference_comparison = reference_results;
    end
    
    %% 9. CÃ¡lculo de parÃ¢metros adicionais
    params = calculateTGAParameters(temperature, weight_smooth, dtg_smooth, decomposition_stages);
    results.params = params;
    
    %% 10. Atualizar a estrutura da amostra com os resultados
    % Criar campo de propriedades se nÃ£o existir
    if ~isfield(sample, 'properties')
        sample.properties = struct();
    end
    
    % Calcular o Ã­ndice de estabilidade tÃ©rmica
    thermal_stability_idx = calculateThermalStabilityIndex(characteristic_temps, params);
    
    % Armazenar um resumo dos resultados TGA na estrutura da amostra
    sample.properties.tga_results = struct();
    sample.properties.tga_results.decomposition_stages = length(decomposition_stages);
    
    % Temperaturas caracterÃ­sticas
    if isfield(characteristic_temps, 'T_onset')
        sample.properties.tga_results.T_onset = characteristic_temps.T_onset;
    else
        sample.properties.tga_results.T_onset = NaN;
    end
    
    if isfield(characteristic_temps, 'T_endset')
        sample.properties.tga_results.T_endset = characteristic_temps.T_endset;
    else
        sample.properties.tga_results.T_endset = NaN;
    end
    
    if isfield(characteristic_temps, 'T5')
        sample.properties.tga_results.T5 = characteristic_temps.T5;
    else
        sample.properties.tga_results.T5 = NaN;
    end
    
    if isfield(characteristic_temps, 'T10')
        sample.properties.tga_results.T10 = characteristic_temps.T10;
    else
        sample.properties.tga_results.T10 = NaN;
    end
    
    if isfield(characteristic_temps, 'T50')
        sample.properties.tga_results.T50 = characteristic_temps.T50;
    else
        sample.properties.tga_results.T50 = NaN;
    end
    
    if isfield(characteristic_temps, 'T90')
        sample.properties.tga_results.T90 = characteristic_temps.T90;
    else
        sample.properties.tga_results.T90 = NaN;
    end
    
    % ParÃ¢metros de composiÃ§Ã£o
    if isfield(params, 'moisture_content')
        sample.properties.tga_results.moisture_content = params.moisture_content;
    else
        sample.properties.tga_results.moisture_content = 0;
    end
    
    if isfield(params, 'volatile_content')
        sample.properties.tga_results.volatile_content = params.volatile_content;
    else
        sample.properties.tga_results.volatile_content = 0;
    end
    
    if isfield(params, 'fixed_carbon')
        sample.properties.tga_results.fixed_carbon = params.fixed_carbon;
    else
        sample.properties.tga_results.fixed_carbon = 0;
    end
    
    if isfield(params, 'residue_content')
        sample.properties.tga_results.residue_content = params.residue_content;
    else
        sample.properties.tga_results.residue_content = 0;
    end
    
    % Ã�ndice de estabilidade tÃ©rmica
    sample.properties.tga_results.thermal_stability_index = thermal_stability_idx;
    
    %% 11. Feedback para o usuÃ¡rio
    % Usar verificaÃ§Ã£o para garantir que o campo nome existe
    if isfield(sample, 'name')
        sample_name = sample.name;
    else
        sample_name = 'Amostra desconhecida';
    end
    
    fprintf('\n========== AnÃ¡lise TGA de %s ==========\n', sample_name);
    fprintf('AnÃ¡lise concluÃ­da com sucesso.\n');
    fprintf('Detectados %d estÃ¡gios de decomposiÃ§Ã£o.\n', length(decomposition_stages));
    
    % Exibir informaÃ§Ãµes sobre os estÃ¡gios de decomposiÃ§Ã£o
    for i = 1:length(decomposition_stages)
        fprintf('EstÃ¡gio %d: %.1f-%.1f Â°C (Perda: %.1f%%, Pico DTG: %.1f Â°C)\n', ...
            i, decomposition_stages(i).start_temp, decomposition_stages(i).end_temp, ...
            decomposition_stages(i).mass_loss, decomposition_stages(i).peak_temp);
    end
    
    % Exibir informaÃ§Ãµes sobre temperaturas caracterÃ­sticas e composiÃ§Ã£o
    if isfield(characteristic_temps, 'T50')
        fprintf('\nTemperatura de decomposiÃ§Ã£o (T50): %.1f Â°C\n', characteristic_temps.T50);
    end
    fprintf('ResÃ­duo final a %.1f Â°C: %.1f%%\n', max(temperature), params.residue_content);

    % Inicializar array de estágios
    n_peaks = length(peaks.positions);
    stages = cell(1, n_peaks);

    % Para cada pico DTG, identificar o estágio de decomposição correspondente
    for i = 1:n_peaks
        peak_temp = peaks.positions(i);
        peak_height = peaks.heights(i);
        peak_width = peaks.widths(i);

        % Estimar início e fim do estágio
        % Usar largura do pico para estimar os limites
        half_width = peak_width / 2;
        start_temp = peak_temp - half_width;
        end_temp = peak_temp + half_width;

        % Ajustar limites para estarem dentro do intervalo de temperatura
        start_temp = max(start_temp, min(temperature));
        end_temp = min(end_temp, max(temperature));

        % Encontrar índices correspondentes
        start_idx = find(temperature >= start_temp, 1, 'first');
        peak_idx = find(temperature >= peak_temp, 1, 'first');
        end_idx = find(temperature >= end_temp, 1, 'first');

        % Se não encontrar índices válidos, usar aproximações
        if isempty(start_idx)
            start_idx = 1;
        end
        if isempty(peak_idx)
            [~, peak_idx] = min(abs(temperature - peak_temp));
        end
        if isempty(end_idx)
            end_idx = length(temperature);
        end

        % Calcular perda de massa no estágio
        weight_start = weight(start_idx);
        weight_end = weight(end_idx);
        weight_loss = weight_start - weight_end;
        mass_loss = (weight_loss / weight(1)) * 100;

        % Criar estrutura para o estágio
        stage = struct(...
            'start_temp', temperature(start_idx), ...
            'peak_temp', peak_temp, ...
            'end_temp', temperature(end_idx), ...
            'weight_start', weight_start, ...
            'weight_end', weight_end, ...
            'mass_loss', mass_loss, ...
            'peak_dtg', peak_height ...
        );

        % Adicionar classificação baseada na temperatura
        if peak_temp < 150
            stage.type = 'Umidade';
        elseif peak_temp < 250
            stage.type = 'Grupos laterais não-reticulados';
        elseif peak_temp < 400
            stage.type = 'Descarboxilação/Despolimerização';
        else
            stage.type = 'Carbonização';
        end

        % Adicionar estágio ao array
        stages{i} = stage;
    end

    % Converter cell array para array de estruturas
    if ~isempty(stages)
        stages = [stages{:}];
    else
        stages = struct([]);
    end
end
         %   n o s   p i c o s   d e t e c t a d o s   n a   c u r v a   D T G .   P a r a   c a d a   e s t Ã ¡ g i o ,   d e t e r m i n a : 
 
         %   -   T e m p e r a t u r a   i n i c i a l   e   f i n a l   d o   e s t Ã ¡ g i o 
 
         %   -   T e m p e r a t u r a   d o   p i c o   ( t a x a   m Ã ¡ x i m a   d e   d e c o m p o s i Ã § Ã £ o ) 
 
         %   -   P e r d a   d e   m a s s a   n o   e s t Ã ¡ g i o 
 
         %   -   P o s s Ã ­ v e l   a t r i b u i Ã § Ã £ o   ( u m i d a d e ,   v o l Ã ¡ t e i s ,   e t c . ) 
 
         
 
         %   I n i c i a l i z a r   a r r a y   d e   e s t Ã ¡ g i o s 
 
         n _ p e a k s   =   l e n g t h ( p e a k s . p o s i t i o n s ) ; 
 
         s t a g e s   =   c e l l ( 1 ,   n _ p e a k s ) ; 
 
         
 
         %   P a r a   c a d a   p i c o   D T G ,   i d e n t i f i c a r   o   e s t Ã ¡ g i o   d e   d e c o m p o s i Ã § Ã £ o   c o r r e s p o n d e n t e 
 
         f o r   i   =   1 : n _ p e a k s 
 
                 p e a k _ t e m p   =   p e a k s . p o s i t i o n s ( i ) ; 
 
                 p e a k _ h e i g h t   =   p e a k s . h e i g h t s ( i ) ; 
 
                 p e a k _ w i d t h   =   p e a k s . w i d t h s ( i ) ; 
 
                 
 
                 %   E s t i m a r   i n Ã ­ c i o   e   f i m   d o   e s t Ã ¡ g i o 
 
                 %   U s a r   l a r g u r a   d o   p i c o   p a r a   e s t i m a r   o s   l i m i t e s 
 
                 h a l f _ w i d t h   =   p e a k _ w i d t h   /   2 ; 
 
                 s t a r t _ t e m p   =   p e a k _ t e m p   -   h a l f _ w i d t h ; 
 
                 e n d _ t e m p   =   p e a k _ t e m p   +   h a l f _ w i d t h ; 
 
                 
 
                 %   A j u s t a r   l i m i t e s   p a r a   e s t a r e m   d e n t r o   d o   i n t e r v a l o   d e   t e m p e r a t u r a 
 
                 s t a r t _ t e m p   =   m a x ( s t a r t _ t e m p ,   m i n ( t e m p e r a t u r e ) ) ; 
 
                 e n d _ t e m p   =   m i n ( e n d _ t e m p ,   m a x ( t e m p e r a t u r e ) ) ; 
 
                 
 
                 %   E n c o n t r a r   Ã ­ n d i c e s   c o r r e s p o n d e n t e s 
 
                 s t a r t _ i d x   =   f i n d ( t e m p e r a t u r e   > =   s t a r t _ t e m p ,   1 ,   ' f i r s t ' ) ; 
 
                 p e a k _ i d x   =   f i n d ( t e m p e r a t u r e   > =   p e a k _ t e m p ,   1 ,   ' f i r s t ' ) ; 
 
                 e n d _ i d x   =   f i n d ( t e m p e r a t u r e   > =   e n d _ t e m p ,   1 ,   ' f i r s t ' ) ; 
 
                 
 
                 %   S e   n Ã £ o   e n c o n t r a r   Ã ­ n d i c e s   v Ã ¡ l i d o s ,   u s a r   a p r o x i m a Ã § Ã µ e s 
 
                 i f   i s e m p t y ( s t a r t _ i d x ) 
 
                         s t a r t _ i d x   =   1 ; 
 
                 e n d 
 
                 i f   i s e m p t y ( p e a k _ i d x ) 
 
                         [ ~ ,   p e a k _ i d x ]   =   m i n ( a b s ( t e m p e r a t u r e   -   p e a k _ t e m p ) ) ; 
 
                 e n d 
 
                 i f   i s e m p t y ( e n d _ i d x ) 
 
                         e n d _ i d x   =   l e n g t h ( t e m p e r a t u r e ) ; 
 
                 e n d 
 
                 
 
                 %   C a l c u l a r   p e r d a   d e   m a s s a   n o   e s t Ã ¡ g i o 
 
                 w e i g h t _ s t a r t   =   w e i g h t ( s t a r t _ i d x ) ; 
 
                 w e i g h t _ e n d   =   w e i g h t ( e n d _ i d x ) ; 
 
                 w e i g h t _ l o s s   =   w e i g h t _ s t a r t   -   w e i g h t _ e n d ; 
 
                 m a s s _ l o s s   =   ( w e i g h t _ l o s s   /   w e i g h t ( 1 ) )   *   1 0 0 ; 
 
                 
 
                 %   C r i a r   e s t r u t u r a   p a r a   o   e s t Ã ¡ g i o 
 
                 s t a g e   =   s t r u c t ( . . . 
 
                         ' s t a r t _ t e m p ' ,   t e m p e r a t u r e ( s t a r t _ i d x ) ,   . . . 
 
                         ' p e a k _ t e m p ' ,   p e a k _ t e m p ,   . . . 
 
                         ' e n d _ t e m p ' ,   t e m p e r a t u r e ( e n d _ i d x ) ,   . . . 
 
                         ' w e i g h t _ s t a r t ' ,   w e i g h t _ s t a r t ,   . . . 
 
                         ' w e i g h t _ e n d ' ,   w e i g h t _ e n d ,   . . . 
 
                         ' m a s s _ l o s s ' ,   m a s s _ l o s s ,   . . . 
 
                         ' p e a k _ d t g ' ,   p e a k _ h e i g h t   . . . 
 
                 ) ; 
 
                 
 
                 %   A d i c i o n a r   c l a s s i f i c a Ã § Ã £ o   b a s e a d a   n a   t e m p e r a t u r a 
 
                 i f   p e a k _ t e m p   <   1 5 0 
 
                         s t a g e . t y p e   =   ' U m i d a d e ' ; 
 
                 e l s e i f   p e a k _ t e m p   <   2 5 0 
 
                         s t a g e . t y p e   =   ' G r u p o s   l a t e r a i s   n Ã £ o - r e t i c u l a d o s ' ; 
 
                 e l s e i f   p e a k _ t e m p   <   4 0 0 
 
                         s t a g e . t y p e   =   ' D e s c a r b o x i l a Ã § Ã £ o / D e s p o l i m e r i z a Ã § Ã £ o ' ; 
 
                 e l s e 
 
                         s t a g e . t y p e   =   ' C a r b o n i z a Ã § Ã £ o ' ; 
 
                 e n d 
 
                 
 
                 s t a g e s { i }   =   s t a g e ; 
 
         e n d 
 
         
 
         %   C o n v e r t e r   c e l l   a r r a y   p a r a   a r r a y   d e   e s t r u t u r a s 
 
         i f   ~ i s e m p t y ( s t a g e s ) 
 
                 s t a g e s   =   [ s t a g e s { : } ] ; 
 
         e l s e 
 
                 s t a g e s   =   s t r u c t ( [ ] ) ; 
 
         e n d 
 
 e n d 
 
 
 
 % %   F u n Ã § Ã £ o   p a r a   c a l c u l a r   t e m p e r a t u r a s   c a r a c t e r Ã ­ s t i c a s   d a   c u r v a   T G A 
 
 f u n c t i o n   t e m p s   =   c a l c u l a t e C h a r a c t e r i s t i c T e m p e r a t u r e s ( t e m p e r a t u r e ,   w e i g h t _ p e r c e n t ) 
 
         % %   C A L C U L A T E C H A R A C T E R I S T I C T E M P E R A T U R E S   -   C a l c u l a   t e m p e r a t u r a s   c a r a c t e r Ã ­ s t i c a s   d a   c u r v a   T G A 
 
         % 
 
         %   E s t a   f u n Ã § Ã £ o   d e t e r m i n a   t e m p e r a t u r a s   c a r a c t e r Ã ­ s t i c a s   i m p o r t a n t e s   d a   c u r v a   T G A ,   i n c l u i n d o : 
 
         %   -   T _ o n s e t :   T e m p e r a t u r a   d e   i n Ã ­ c i o   d a   d e c o m p o s i Ã § Ã £ o   p r i n c i p a l 
 
         %   -   T _ e n d s e t :   T e m p e r a t u r a   d e   t Ã © r m i n o   d a   d e c o m p o s i Ã § Ã £ o   p r i n c i p a l 
 
         %   -   T 5 ,   T 1 0 ,   T 5 0 ,   T 9 0 :   T e m p e r a t u r a s   n a s   q u a i s   o c o r r e   5 % ,   1 0 % ,   5 0 % ,   9 0 %   d e   p e r d a   d e   m a s s a 
 
         % 
 
         %   A s   t e m p e r a t u r a s   s Ã £ o   c a l c u l a d a s   c o m   b a s e   n a   c u r v a   d e   p e r d a   d e   m a s s a   s u a v i z a d a 
 
         
 
         %   I n i c i a l i z a r   e s t r u t u r a   d e   s a Ã ­ d a 
 
         t e m p s   =   s t r u c t ( ) ; 
 
         
 
         %   N o r m a l i z a r   p e r d a   d e   m a s s a   ( 1 0 0 %   n o   i n Ã ­ c i o ) 
 
         w e i g h t _ n o r m   =   w e i g h t _ p e r c e n t   /   w e i g h t _ p e r c e n t ( 1 )   *   1 0 0 ; 
 
         
 
         %   C a l c u l a r   T 5 ,   T 1 0 ,   T 5 0 ,   T 9 0   ( t e m p e r a t u r a s   d e   p e r d a   d e   m a s s a   r e l a t i v a ) 
 
         %   E s t e s   r e p r e s e n t a m   t e m p e r a t u r a s   o n d e   5 % ,   1 0 % ,   5 0 %   e   9 0 %   d a   m a s s a   f o i   p e r d i d a 
 
         %   ( o u   s e j a ,   9 5 % ,   9 0 % ,   5 0 % ,   1 0 %   d a   m a s s a   o r i g i n a l   p e r m a n e c e ) 
 
         t a r g e t _ w e i g h t s   =   [ 9 5 ,   9 0 ,   5 0 ,   1 0 ] ; 
 
         f i e l d _ n a m e s   =   { ' T 5 ' ,   ' T 1 0 ' ,   ' T 5 0 ' ,   ' T 9 0 ' } ; 
 
         
 
         f o r   i   =   1 : l e n g t h ( t a r g e t _ w e i g h t s ) 
 
                 t a r g e t   =   t a r g e t _ w e i g h t s ( i ) ; 
 
                 f i e l d   =   f i e l d _ n a m e s { i } ; 
 
                 
 
                 %   E n c o n t r a r   o   p o n t o   o n d e   o   p e s o   Ã ©   m e n o r   o u   i g u a l   a o   a l v o 
 
                 i d x   =   f i n d ( w e i g h t _ n o r m   < =   t a r g e t ,   1 ,   ' f i r s t ' ) ; 
 
                 
 
                 i f   ~ i s e m p t y ( i d x )   & &   i d x   >   1 
 
                         %   I n t e r p o l a Ã § Ã £ o   l i n e a r   p a r a   o b t e r   u m a   e s t i m a t i v a   m a i s   p r e c i s a 
 
                         w 1   =   w e i g h t _ n o r m ( i d x - 1 ) ; 
 
                         w 2   =   w e i g h t _ n o r m ( i d x ) ; 
 
                         t 1   =   t e m p e r a t u r e ( i d x - 1 ) ; 
 
                         t 2   =   t e m p e r a t u r e ( i d x ) ; 
 
                         
 
                         %   P o n t o   n a   c u r v a   o n d e   o   p e s o   =   t a r g e t 
 
                         t e m p s . ( f i e l d )   =   t 1   +   ( t a r g e t   -   w 1 )   *   ( t 2   -   t 1 )   /   ( w 2   -   w 1 ) ; 
 
                 e l s e i f   i s e m p t y ( i d x ) 
 
                         %   C a s o   e m   q u e   o   m a t e r i a l   n Ã £ o   a t i n g e   a   p e r d a   d e   m a s s a   a l v o 
 
                         t e m p s . ( f i e l d )   =   N a N ; 
 
                 e l s e 
 
                         %   C a s o   e m   q u e   o   p r i m e i r o   p o n t o   j Ã ¡   e s t Ã ¡   a b a i x o   d o   a l v o 
 
                         t e m p s . ( f i e l d )   =   t e m p e r a t u r e ( 1 ) ; 
 
                 e n d 
 
         e n d 
 
         
 
         %   C a l c u l a r   d e r i v a d a   p a r a   e n c o n t r a r   T _ o n s e t   e   T _ e n d s e t 
 
         %   I s s o   n o r m a l m e n t e   r e q u e r   a n Ã ¡ l i s e   m a i s   c o m p l e x a   c o m   i d e n t i f i c a Ã § Ã £ o   d e   l i n h a s   d e   b a s e 
 
         %   A q u i   u s a m o s   u m a   a b o r d a g e m   s i m p l i f i c a d a 
 
         
 
         %   C a l c u l a r   p r i m e i r a   d e r i v a d a 
 
         d w _ d t   =   g r a d i e n t ( w e i g h t _ n o r m ,   t e m p e r a t u r e ) ; 
 
         
 
         %   I d e n t i f i c a r   r e g i Ã £ o   d e   d e c o m p o s i Ã § Ã £ o   p r i n c i p a l   ( o n d e   a   t a x a   d e   p e r d a   Ã ©   m Ã ¡ x i m a ) 
 
         [ ~ ,   m a x _ r a t e _ i d x ]   =   m i n ( d w _ d t ) ;   %   T a x a   m Ã ¡ x i m a   d e   p e r d a   ( v a l o r   n e g a t i v o   m Ã ­ n i m o ) 
 
         
 
         %   D e f i n i r   l i m i t e   p a r a   c o n s i d e r a r   i n Ã ­ c i o / f i m   d a   d e c o m p o s i Ã § Ã £ o   ( 1 0 %   d a   t a x a   m Ã ¡ x i m a ) 
 
         t h r e s h o l d   =   0 . 1   *   d w _ d t ( m a x _ r a t e _ i d x ) ; 
 
         
 
         %   T _ o n s e t :   P r i m e i r o   p o n t o   a n t e s   d o   p i c o   o n d e   a   d e r i v a d a   a t i n g e   o   l i m i t e 
 
         o n s e t _ i d x   =   f i n d ( d w _ d t ( 1 : m a x _ r a t e _ i d x )   < =   t h r e s h o l d ,   1 ,   ' l a s t ' ) ; 
 
         i f   ~ i s e m p t y ( o n s e t _ i d x ) 
 
                 t e m p s . T _ o n s e t   =   t e m p e r a t u r e ( o n s e t _ i d x ) ; 
 
         e l s e 
 
                 t e m p s . T _ o n s e t   =   t e m p e r a t u r e ( 1 ) ; 
 
         e n d 
 
         
 
         %   T _ e n d s e t :   P r i m e i r o   p o n t o   a p Ã ³ s   o   p i c o   o n d e   a   d e r i v a d a   v o l t a   a c i m a   d o   l i m i t e 
 
         e n d s e t _ i d x   =   f i n d ( d w _ d t ( m a x _ r a t e _ i d x : e n d )   > =   t h r e s h o l d ,   1 ,   ' f i r s t ' ) ; 
 
         i f   ~ i s e m p t y ( e n d s e t _ i d x ) 
 
                 t e m p s . T _ e n d s e t   =   t e m p e r a t u r e ( m a x _ r a t e _ i d x   +   e n d s e t _ i d x   -   1 ) ; 
 
         e l s e 
 
                 t e m p s . T _ e n d s e t   =   t e m p e r a t u r e ( e n d ) ; 
 
         e n d 
 
 e n d 
 
 
 
 % %   F u n Ã § Ã £ o   p a r a   c o m p a r a r   c o m   b i b l i o t e c a   d e   r e f e r Ã ª n c i a 
 
 f u n c t i o n   r e f _ r e s u l t s   =   c o m p a r e W i t h R e f e r e n c e L i b r a r y ( t e m p e r a t u r e ,   w e i g h t ,   d t g ,   l i b r a r y _ p a t h ) 
 
         % %   C O M P A R E W I T H R E F E R E N C E L I B R A R Y   -   C o m p a r a   d a d o s   T G A   c o m   b i b l i o t e c a   d e   r e f e r Ã ª n c i a 
 
         % 
 
         %   E s t a   f u n Ã § Ã £ o   c o m p a r a   a   c u r v a   T G A   c o m   u m a   b i b l i o t e c a   d e   c u r v a s   d e   r e f e r Ã ª n c i a 
 
         %   p a r a   i d e n t i f i c a r   s i m i l a r i d a d e s   c o m   m a t e r i a i s   c o n h e c i d o s .   P a r t i c u l a r m e n t e 
 
         %   Ã º t i l   p a r a   i d e n t i f i c a r   p a d r Ã µ e s   d e   d e c o m p o s i Ã § Ã £ o   c a r a c t e r Ã ­ s t i c o s . 
 
         
 
         %   I n i c i a l i z a r   e s t r u t u r a   d e   r e s u l t a d o s 
 
         r e f _ r e s u l t s   =   s t r u c t ( ' m a t c h e s ' ,   s t r u c t ( [ ] ) ,   ' s i m i l a r i t y _ s c o r e s ' ,   [ ] ) ; 
 
         
 
         %   V e r i f i c a r   s e   o   c a m i n h o   d a   b i b l i o t e c a   f o i   f o r n e c i d o 
 
         i f   i s e m p t y ( l i b r a r y _ p a t h ) 
 
                 %   U s a r   c a m i n h o   p a d r Ã £ o   s e   n Ã £ o   f o i   e s p e c i f i c a d o 
 
                 %   I s s o   a s s u m e   q u e   a   b i b l i o t e c a   e s t Ã ¡   e m   u m   s u b d i r e t Ã ³ r i o   ' r e f e r e n c e _ d a t a ' 
 
                 r o o t _ d i r   =   f i l e p a r t s ( m f i l e n a m e ( ' f u l l p a t h ' ) ) ; 
 
                 l i b r a r y _ p a t h   =   f u l l f i l e ( r o o t _ d i r ,   ' . . ' ,   ' . . ' ,   ' r e f e r e n c e _ d a t a ' ,   ' t g a _ l i b r a r y . m a t ' ) ; 
 
         e n d 
 
         
 
         %   V e r i f i c a r   s e   o   a r q u i v o   d a   b i b l i o t e c a   e x i s t e 
 
         i f   ~ e x i s t ( l i b r a r y _ p a t h ,   ' f i l e ' ) 
 
                 w a r n i n g ( ' B i b l i o t e c a   d e   r e f e r Ã ª n c i a   n Ã £ o   e n c o n t r a d a   e m :   % s ' ,   l i b r a r y _ p a t h ) ; 
 
                 r e t u r n ; 
 
         e n d 
 
         
 
         %   C a r r e g a r   b i b l i o t e c a   d e   r e f e r Ã ª n c i a 
 
         t r y 
 
                 r e f _ l i b   =   l o a d ( l i b r a r y _ p a t h ) ; 
 
                 i f   ~ i s f i e l d ( r e f _ l i b ,   ' t g a _ r e f e r e n c e s ' ) 
 
                         w a r n i n g ( ' F o r m a t o   d e   b i b l i o t e c a   i n v Ã ¡ l i d o .   O   c a m p o   ' ' t g a _ r e f e r e n c e s ' '   n Ã £ o   f o i   e n c o n t r a d o . ' ) ; 
 
                         r e t u r n ; 
 
                 e n d 
 
                 r e f e r e n c e s   =   r e f _ l i b . t g a _ r e f e r e n c e s ; 
 
         c a t c h   e r r 
 
                 w a r n i n g ( ' E r r o   a o   c a r r e g a r   b i b l i o t e c a   d e   r e f e r Ã ª n c i a :   % s ' ,   e r r . m e s s a g e ) ; 
 
                 r e t u r n ; 
 
         e n d 
 
         
 
         %   I n t e r p o l a r   d a d o s   p a r a   u m a   f a i x a   d e   t e m p e r a t u r a   c o m u m   p a r a   c o m p a r a Ã § Ã £ o 
 
         t e m p _ r a n g e   =   l i n s p a c e ( m i n ( t e m p e r a t u r e ) ,   m a x ( t e m p e r a t u r e ) ,   1 0 0 ) ; 
 
         w e i g h t _ i n t e r p   =   i n t e r p 1 ( t e m p e r a t u r e ,   w e i g h t ,   t e m p _ r a n g e ) ; 
 
         
 
         %   N o r m a l i z a r   p a r a   c o m p a r a Ã § Ã £ o   ( 0 - 1 0 0 % ) 
 
         w e i g h t _ n o r m   =   ( w e i g h t _ i n t e r p   -   m i n ( w e i g h t _ i n t e r p ) )   /   ( m a x ( w e i g h t _ i n t e r p )   -   m i n ( w e i g h t _ i n t e r p ) )   *   1 0 0 ; 
 
         
 
         %   C o m p a r a r   c o m   c a d a   r e f e r Ã ª n c i a 
 
         n _ r e f s   =   l e n g t h ( r e f e r e n c e s ) ; 
 
         s i m i l a r i t i e s   =   z e r o s ( 1 ,   n _ r e f s ) ; 
 
         
 
         f o r   i   =   1 : n _ r e f s 
 
                 r e f   =   r e f e r e n c e s ( i ) ; 
 
                 
 
                 %   I n t e r p o l a r   r e f e r Ã ª n c i a   p a r a   m e s m a   f a i x a   d e   t e m p e r a t u r a 
 
                 r e f _ w e i g h t _ i n t e r p   =   i n t e r p 1 ( r e f . t e m p e r a t u r e ,   r e f . w e i g h t ,   t e m p _ r a n g e ,   ' l i n e a r ' ,   ' e x t r a p ' ) ; 
 
                 
 
                 %   N o r m a l i z a r 
 
                 r e f _ w e i g h t _ n o r m   =   ( r e f _ w e i g h t _ i n t e r p   -   m i n ( r e f _ w e i g h t _ i n t e r p ) )   /   ( m a x ( r e f _ w e i g h t _ i n t e r p )   -   m i n ( r e f _ w e i g h t _ i n t e r p ) )   *   1 0 0 ; 
 
                 
 
                 %   C a l c u l a r   e r r o   q u a d r Ã ¡ t i c o   m Ã © d i o   ( M S E )   c o m o   m e d i d a   d e   s i m i l a r i d a d e 
 
                 m s e   =   m e a n ( ( w e i g h t _ n o r m   -   r e f _ w e i g h t _ n o r m ) . ^ 2 ) ; 
 
                 
 
                 %   C o n v e r t e r   M S E   p a r a   s i m i l a r i d a d e   ( 0 - 1 0 0 % ) ,   o n d e   1 0 0 %   Ã ©   i d e n t i d a d e   p e r f e i t a 
 
                 s i m i l a r i t i e s ( i )   =   1 0 0   *   e x p ( - m s e / 1 0 0 ) ; 
 
         e n d 
 
         
 
         %   O r d e n a r   s i m i l a r i d a d e s   e m   o r d e m   d e c r e s c e n t e 
 
         [ s o r t e d _ s i m i l a r i t i e s ,   i n d i c e s ]   =   s o r t ( s i m i l a r i t i e s ,   ' d e s c e n d ' ) ; 
 
         
 
         %   S e l e c i o n a r   a s   3   p r i n c i p a i s   c o r r e s p o n d Ã ª n c i a s   ( o u   m e n o s   s e   n Ã £ o   h o u v e r   s u f i c i e n t e s ) 
 
         n _ m a t c h e s   =   m i n ( 3 ,   n _ r e f s ) ; 
 
         t o p _ m a t c h e s   =   c e l l ( 1 ,   n _ m a t c h e s ) ; 
 
         t o p _ s c o r e s   =   s o r t e d _ s i m i l a r i t i e s ( 1 : n _ m a t c h e s ) ; 
 
         
 
         f o r   i   =   1 : n _ m a t c h e s 
 
                 i d x   =   i n d i c e s ( i ) ; 
 
                 m a t c h   =   s t r u c t ( . . . 
 
                         ' n a m e ' ,   r e f e r e n c e s ( i d x ) . n a m e ,   . . . 
 
                         ' t y p e ' ,   r e f e r e n c e s ( i d x ) . t y p e ,   . . . 
 
                         ' s i m i l a r i t y ' ,   s o r t e d _ s i m i l a r i t i e s ( i ) ,   . . . 
 
                         ' r e f e r e n c e _ i d ' ,   i d x   . . . 
 
                 ) ; 
 
                 t o p _ m a t c h e s { i }   =   m a t c h ; 
 
         e n d 
 
         
 
         %   C o n v e r t e r   c e l l   a r r a y   p a r a   a r r a y   d e   e s t r u t u r a s 
 
         i f   ~ i s e m p t y ( t o p _ m a t c h e s ) 
 
                 r e f _ r e s u l t s . m a t c h e s   =   [ t o p _ m a t c h e s { : } ] ; 
 
                 r e f _ r e s u l t s . s i m i l a r i t y _ s c o r e s   =   t o p _ s c o r e s ; 
 
         e n d 
 
 e n d 
 
 
 
 % %   F u n Ã § Ã £ o   p a r a   c a l c u l a r   p a r Ã ¢ m e t r o s   a d i c i o n a i s   d e   T G A 
 
 f u n c t i o n   p a r a m s   =   c a l c u l a t e T G A P a r a m e t e r s ( t e m p e r a t u r e ,   w e i g h t ,   d t g ,   d e c o m p o s i t i o n _ s t a g e s ) 
 
         % %   C A L C U L A T E T G A P A R A M E T E R S   -   C a l c u l a   p a r Ã ¢ m e t r o s   a d i c i o n a i s   d a   a n Ã ¡ l i s e   T G A 
 
         % 
 
         %   E s t a   f u n Ã § Ã £ o   c a l c u l a   p a r Ã ¢ m e t r o s   a d i c i o n a i s   d e r i v a d o s   d a   c u r v a   T G A ,   i n c l u i n d o : 
 
         %   -   C o n t e Ã º d o   d e   u m i d a d e 
 
         %   -   C o n t e Ã º d o   d e   v o l Ã ¡ t e i s 
 
         %   -   C a r b o n o   f i x o 
 
         %   -   C o n t e Ã º d o   d e   r e s Ã ­ d u o 
 
         
 
         %   I n i c i a l i z a r   e s t r u t u r a   d e   p a r Ã ¢ m e t r o s 
 
         p a r a m s   =   s t r u c t ( ) ; 
 
         
 
         %   C a l c u l a r   r e s Ã ­ d u o   f i n a l   ( %   d e   m a s s a   r e s t a n t e   n o   f i n a l   d o   e x p e r i m e n t o ) 
 
         p a r a m s . r e s i d u e _ c o n t e n t   =   w e i g h t ( e n d ) ; 
 
         
 
         %   A n a l i s a r   e s t Ã ¡ g i o s   d e   d e c o m p o s i Ã § Ã £ o   p a r a   d e t e r m i n a r   o u t r o s   p a r Ã ¢ m e t r o s 
 
         i f   i s e m p t y ( d e c o m p o s i t i o n _ s t a g e s ) 
 
                 %   C a s o   n Ã £ o   h a j a   e s t Ã ¡ g i o s   i d e n t i f i c a d o s ,   u s a r   e s t i m a t i v a s   b Ã ¡ s i c a s 
 
                 
 
                 %   T e m p e r a t u r a   a m b i e n t e   ( c o n s i d e r a r   ~ 3 0 Â ° C ) 
 
                 a m b i e n t _ i d x   =   f i n d ( t e m p e r a t u r e   > =   3 0 ,   1 ,   ' f i r s t ' ) ; 
 
                 i f   i s e m p t y ( a m b i e n t _ i d x ) 
 
                         a m b i e n t _ i d x   =   1 ; 
 
                 e n d 
 
                 
 
                 %   P e r d a   d e   u m i d a d e   ( a t Ã ©   ~ 1 2 0 Â ° C ) 
 
                 m o i s t u r e _ i d x   =   f i n d ( t e m p e r a t u r e   > =   1 2 0 ,   1 ,   ' f i r s t ' ) ; 
 
                 i f   i s e m p t y ( m o i s t u r e _ i d x ) 
 
                         m o i s t u r e _ i d x   =   l e n g t h ( t e m p e r a t u r e ) ; 
 
                 e n d 
 
                 p a r a m s . m o i s t u r e _ c o n t e n t   =   w e i g h t ( a m b i e n t _ i d x )   -   w e i g h t ( m o i s t u r e _ i d x ) ; 
 
                 
 
                 %   V o l Ã ¡ t e i s   ( d e   ~ 1 2 0 Â ° C   a t Ã ©   ~ 6 0 0 Â ° C ) 
 
                 v o l a t i l e s _ i d x   =   f i n d ( t e m p e r a t u r e   > =   6 0 0 ,   1 ,   ' f i r s t ' ) ; 
 
                 i f   i s e m p t y ( v o l a t i l e s _ i d x ) 
 
                         v o l a t i l e s _ i d x   =   l e n g t h ( t e m p e r a t u r e ) ; 
 
                 e n d 
 
                 p a r a m s . v o l a t i l e _ c o n t e n t   =   w e i g h t ( m o i s t u r e _ i d x )   -   w e i g h t ( v o l a t i l e s _ i d x ) ; 
 
                 
 
                 %   C a r b o n o   f i x o   ( d e   ~ 6 0 0 Â ° C   a t Ã ©   o   f i n a l ) 
 
                 p a r a m s . f i x e d _ c a r b o n   =   w e i g h t ( v o l a t i l e s _ i d x )   -   w e i g h t ( e n d ) ; 
 
                 
 
                 r e t u r n ; 
 
         e n d 
 
         
 
         %   A n Ã ¡ l i s e   b a s e a d a   n o s   e s t Ã ¡ g i o s   i d e n t i f i c a d o s 
 
         %   C l a s s i f i c a r   e s t Ã ¡ g i o s   p o r   f a i x a   d e   t e m p e r a t u r a 
 
         m o i s t u r e _ s t a g e s   =   [ ] ; 
 
         v o l a t i l e s _ s t a g e s   =   [ ] ; 
 
         c a r b o n i z a t i o n _ s t a g e s   =   [ ] ; 
 
         
 
         f o r   i   =   1 : l e n g t h ( d e c o m p o s i t i o n _ s t a g e s ) 
 
                 s t a g e   =   d e c o m p o s i t i o n _ s t a g e s ( i ) ; 
 
                 
 
                 %   E s t Ã ¡ g i o s   p o r   f a i x a   d e   t e m p e r a t u r a 
 
                 i f   s t a g e . p e a k _ t e m p   <   1 5 0 
 
                         m o i s t u r e _ s t a g e s   =   [ m o i s t u r e _ s t a g e s ,   i ] ; 
 
                 e l s e i f   s t a g e . p e a k _ t e m p   <   6 0 0 
 
                         v o l a t i l e s _ s t a g e s   =   [ v o l a t i l e s _ s t a g e s ,   i ] ; 
 
                 e l s e 
 
                         c a r b o n i z a t i o n _ s t a g e s   =   [ c a r b o n i z a t i o n _ s t a g e s ,   i ] ; 
 
                 e n d 
 
         e n d 
 
         
 
         %   C a l c u l a r   c o n t e Ã º d o   d e   u m i d a d e   ( s o m a   d a s   p e r d a s   e m   e s t Ã ¡ g i o s   d e   u m i d a d e ) 
 
         p a r a m s . m o i s t u r e _ c o n t e n t   =   0 ; 
 
         f o r   i   =   m o i s t u r e _ s t a g e s 
 
                 p a r a m s . m o i s t u r e _ c o n t e n t   =   p a r a m s . m o i s t u r e _ c o n t e n t   +   d e c o m p o s i t i o n _ s t a g e s ( i ) . m a s s _ l o s s ; 
 
         e n d 
 
         
 
         %   C a l c u l a r   c o n t e Ã º d o   d e   v o l Ã ¡ t e i s   ( s o m a   d a s   p e r d a s   e m   e s t Ã ¡ g i o s   d e   v o l Ã ¡ t e i s ) 
 
         p a r a m s . v o l a t i l e _ c o n t e n t   =   0 ; 
 
         f o r   i   =   v o l a t i l e s _ s t a g e s 
 
                 p a r a m s . v o l a t i l e _ c o n t e n t   =   p a r a m s . v o l a t i l e _ c o n t e n t   +   d e c o m p o s i t i o n _ s t a g e s ( i ) . m a s s _ l o s s ; 
 
         e n d 
 
         
 
         %   C a l c u l a r   c o n t e Ã º d o   d e   c a r b o n o   f i x o   ( s o m a   d a s   p e r d a s   e m   e s t Ã ¡ g i o s   d e   c a r b o n i z a Ã § Ã £ o ) 
 
         p a r a m s . f i x e d _ c a r b o n   =   0 ; 
 
         f o r   i   =   c a r b o n i z a t i o n _ s t a g e s 
 
                 p a r a m s . f i x e d _ c a r b o n   =   p a r a m s . f i x e d _ c a r b o n   +   d e c o m p o s i t i o n _ s t a g e s ( i ) . m a s s _ l o s s ; 
 
         e n d 
 
         
 
         %   A j u s t a r   v a l o r e s   p a r a   p o r c e n t a g e m   d o   t o t a l 
 
         t o t a l _ m a s s   =   p a r a m s . m o i s t u r e _ c o n t e n t   +   p a r a m s . v o l a t i l e _ c o n t e n t   +   p a r a m s . f i x e d _ c a r b o n   +   p a r a m s . r e s i d u e _ c o n t e n t ; 
 
         i f   t o t a l _ m a s s   >   0 
 
                 p a r a m s . m o i s t u r e _ c o n t e n t   =   ( p a r a m s . m o i s t u r e _ c o n t e n t   /   t o t a l _ m a s s )   *   1 0 0 ; 
 
                 p a r a m s . v o l a t i l e _ c o n t e n t   =   ( p a r a m s . v o l a t i l e _ c o n t e n t   /   t o t a l _ m a s s )   *   1 0 0 ; 
 
                 p a r a m s . f i x e d _ c a r b o n   =   ( p a r a m s . f i x e d _ c a r b o n   /   t o t a l _ m a s s )   *   1 0 0 ; 
 
                 p a r a m s . r e s i d u e _ c o n t e n t   =   ( p a r a m s . r e s i d u e _ c o n t e n t   /   t o t a l _ m a s s )   *   1 0 0 ; 
 
         e n d 
 
 e n d 
 
 
 
 % %   F u n Ã § Ã £ o   p a r a   c a l c u l a r   Ã ­ n d i c e   d e   e s t a b i l i d a d e   t Ã © r m i c a 
 
 f u n c t i o n   s t a b i l i t y _ i n d e x   =   c a l c u l a t e T h e r m a l S t a b i l i t y I n d e x ( t e m p s ,   p a r a m s ) 
 
         % %   C A L C U L A T E T H E R M A L S T A B I L I T Y I N D E X   -   C a l c u l a   u m   Ã ­ n d i c e   d e   e s t a b i l i d a d e   t Ã © r m i c a 
 
         % 
 
         %   E s t a   f u n Ã § Ã £ o   c a l c u l a   u m   Ã ­ n d i c e   d e   e s t a b i l i d a d e   t Ã © r m i c a   n o r m a l i z a d o   ( 0 - 1 0 ) 
 
         %   c o m   b a s e   e m   p a r Ã ¢ m e t r o s   c h a v e   d a   a n Ã ¡ l i s e   T G A .   V a l o r e s   m a i s   a l t o s   i n d i c a m 
 
         %   m a i o r   e s t a b i l i d a d e   t Ã © r m i c a . 
 
         
 
         %   I n i c i a l i z a r   Ã ­ n d i c e   d e   e s t a b i l i d a d e 
 
         s t a b i l i t y _ i n d e x   =   0 ; 
 
         
 
         %   P e s o s   p a r a   c a d a   p a r Ã ¢ m e t r o 
 
         w e i g h t s   =   s t r u c t ( . . . 
 
                 ' T 5 ' ,   0 . 1 5 ,   . . .             %   T e m p e r a t u r a   d e   5 %   d e   p e r d a   d e   m a s s a 
 
                 ' T _ o n s e t ' ,   0 . 2 0 ,   . . .   %   T e m p e r a t u r a   d e   i n Ã ­ c i o   d a   d e c o m p o s i Ã § Ã £ o 
 
                 ' T 5 0 ' ,   0 . 3 0 ,   . . .           %   T e m p e r a t u r a   d e   5 0 %   d e   p e r d a   d e   m a s s a 
 
                 ' r e s i d u e ' ,   0 . 2 5 ,   . . .   %   C o n t e Ã º d o   d e   r e s Ã ­ d u o 
 
                 ' r a t e ' ,   0 . 1 0   . . .           %   T a x a   m Ã ¡ x i m a   d e   d e c o m p o s i Ã § Ã £ o 
 
         ) ; 
 
         
 
         %   V e r i f i c a r   d i s p o n i b i l i d a d e   d e   c a d a   p a r Ã ¢ m e t r o   e   c a l c u l a r   c o m p o n e n t e s   d o   Ã ­ n d i c e 
 
         
 
         %   C o m p o n e n t e   b a s e a d o   e m   T 5   ( p o n t u a Ã § Ã £ o   m Ã ¡ x i m a   e m   3 0 0 Â ° C ) 
 
         i f   i s f i e l d ( t e m p s ,   ' T 5 ' )   & &   ~ i s n a n ( t e m p s . T 5 ) 
 
                 %   N o r m a l i z a r   T 5   p a r a   e s c a l a   0 - 1   ( 0   =   1 0 0 Â ° C ,   1   =   3 5 0 Â ° C ) 
 
                 s c o r e _ T 5   =   m i n ( 1 ,   m a x ( 0 ,   ( t e m p s . T 5   -   1 0 0 )   /   2 5 0 ) ) ; 
 
                 s t a b i l i t y _ i n d e x   =   s t a b i l i t y _ i n d e x   +   w e i g h t s . T 5   *   1 0   *   s c o r e _ T 5 ; 
 
         e n d 
 
         
 
         %   C o m p o n e n t e   b a s e a d o   e m   T _ o n s e t   ( p o n t u a Ã § Ã £ o   m Ã ¡ x i m a   e m   3 5 0 Â ° C ) 
 
         i f   i s f i e l d ( t e m p s ,   ' T _ o n s e t ' )   & &   ~ i s n a n ( t e m p s . T _ o n s e t ) 
 
                 %   N o r m a l i z a r   T _ o n s e t   p a r a   e s c a l a   0 - 1   ( 0   =   1 5 0 Â ° C ,   1   =   4 0 0 Â ° C ) 
 
                 s c o r e _ o n s e t   =   m i n ( 1 ,   m a x ( 0 ,   ( t e m p s . T _ o n s e t   -   1 5 0 )   /   2 5 0 ) ) ; 
 
                 s t a b i l i t y _ i n d e x   =   s t a b i l i t y _ i n d e x   +   w e i g h t s . T _ o n s e t   *   1 0   *   s c o r e _ o n s e t ; 
 
         e n d 
 
         
 
         %   C o m p o n e n t e   b a s e a d o   e m   T 5 0   ( p o n t u a Ã § Ã £ o   m Ã ¡ x i m a   e m   4 5 0 Â ° C ) 
 
         i f   i s f i e l d ( t e m p s ,   ' T 5 0 ' )   & &   ~ i s n a n ( t e m p s . T 5 0 ) 
 
                 %   N o r m a l i z a r   T 5 0   p a r a   e s c a l a   0 - 1   ( 0   =   2 0 0 Â ° C ,   1   =   5 0 0 Â ° C ) 
 
                 s c o r e _ T 5 0   =   m i n ( 1 ,   m a x ( 0 ,   ( t e m p s . T 5 0   -   2 0 0 )   /   3 0 0 ) ) ; 
 
                 s t a b i l i t y _ i n d e x   =   s t a b i l i t y _ i n d e x   +   w e i g h t s . T 5 0   *   1 0   *   s c o r e _ T 5 0 ; 
 
         e n d 
 
         
 
         %   C o m p o n e n t e   b a s e a d o   n o   c o n t e Ã º d o   d e   r e s Ã ­ d u o   ( p o n t u a Ã § Ã £ o   m Ã ¡ x i m a   e m   3 0 % ) 
 
         i f   i s f i e l d ( p a r a m s ,   ' r e s i d u e _ c o n t e n t ' ) 
 
                 %   N o r m a l i z a r   r e s Ã ­ d u o   p a r a   e s c a l a   0 - 1   ( 0   =   0 % ,   1   =   4 0 % ) 
 
                 s c o r e _ r e s i d u e   =   m i n ( 1 ,   m a x ( 0 ,   p a r a m s . r e s i d u e _ c o n t e n t   /   4 0 ) ) ; 
 
                 s t a b i l i t y _ i n d e x   =   s t a b i l i t y _ i n d e x   +   w e i g h t s . r e s i d u e   *   1 0   *   s c o r e _ r e s i d u e ; 
 
         e n d 
 
         
 
         %   C o m p o n e n t e   b a s e a d o   n a   t a x a   d e   d e c o m p o s i Ã § Ã £ o 
 
         %   N e s t e   c a s o ,   u s a m o s   u m   v a l o r   f i x o   c o m o   n Ã £ o   t e m o s   a   t a x a   d e   d e c o m p o s i Ã § Ã £ o   d i r e t a m e n t e 
 
         %   E m   u m a   i m p l e m e n t a Ã § Ã £ o   c o m p l e t a ,   i s s o   s e r i a   c a l c u l a d o   a   p a r t i r   d a   c u r v a   D T G 
 
         s t a b i l i t y _ i n d e x   =   s t a b i l i t y _ i n d e x   +   w e i g h t s . r a t e   *   5 ;   %   V a l o r   m Ã © d i o 
 
         
 
         %   A r r e d o n d a r   p a r a   d u a s   c a s a s   d e c i m a i s 
 
         s t a b i l i t y _ i n d e x   =   r o u n d ( s t a b i l i t y _ i n d e x   *   1 0 0 )   /   1 0 0 ; 
 
 e n d 
 
 
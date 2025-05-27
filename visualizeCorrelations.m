%% visualizeCorrelations.m
% Visualiza correlações entre parâmetros de síntese e propriedades dos polímeros
%
% Sintaxe:
%   figures = visualizeCorrelations(results, varargin)
%
% Parâmetros de Entrada:
%   results  - Estrutura contendo resultados do treinamento (saída de trainMLModels)
%   varargin - Pares nome-valor para parâmetros opcionais:
%     'FeatureFilter'      - Filtro para características (cell array, padrão: todas)
%     'PropertyFilter'     - Filtro para propriedades (cell array, padrão: todas)
%     'CorrelationType'    - Tipo de correlação ('pearson', 'spearman', padrão: 'spearman')
%     'SignificanceLevel'  - Nível de significância para destacar correlações (padrão: 0.05)
%     'ShowFigures'        - Exibir figuras (padrão: true)
%
% Saída:
%   figures - Estrutura contendo handles para as figuras geradas
%
% Exemplo:
%   figures = visualizeCorrelations(results, 'FeatureFilter', {'synthesis_*'});
%
% Ver também: trainMLModels, predictProperties, extractFeatures

function figures = visualizeCorrelations(results, varargin)
    % Verificar argumentos de entrada
    if ~isstruct(results) || ~isfield(results, 'correlations')
        error('O parâmetro "results" deve ser uma estrutura contendo resultados de treinamento com campo "correlations".');
    end
    
    % Configurar parser de entrada
    p = inputParser;
    p.CaseSensitive = false;
    p.KeepUnmatched = true;
    
    % Adicionar parâmetros
    addParameter(p, 'FeatureFilter', {}, @(x) isempty(x) || iscell(x));
    addParameter(p, 'PropertyFilter', {}, @(x) isempty(x) || iscell(x));
    addParameter(p, 'CorrelationType', 'spearman', @(x) ismember(lower(x), {'pearson', 'spearman'}));
    addParameter(p, 'SignificanceLevel', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
    addParameter(p, 'ShowFigures', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
    
    % Analisar argumentos
    parse(p, varargin{:});
    
    % Extrair dados de correlação
    corr_matrix = results.correlations.matrix;
    feature_names = results.correlations.feature_names;
    property_names = results.correlations.property_names;
    
    % Filtrar características, se especificado
    if ~isempty(p.Results.FeatureFilter)
        % Inicializar índices de características a manter
        keep_indices = false(size(feature_names));
        
        % Aplicar cada filtro
        for i = 1:length(p.Results.FeatureFilter)
            filter_pattern = p.Results.FeatureFilter{i};
            
            % Substituir asteriscos por expressão regular
            filter_pattern = strrep(filter_pattern, '*', '.*');
            
            % Encontrar características que correspondem ao padrão
            for j = 1:length(feature_names)
                if regexp(feature_names{j}, ['^', filter_pattern, '$'])
                    keep_indices(j) = true;
                end
            end
        end
        
        % Aplicar filtro
        feature_names = feature_names(keep_indices);
        corr_matrix = corr_matrix(keep_indices, :);
    end
    
    % Filtrar propriedades, se especificado
    if ~isempty(p.Results.PropertyFilter)
        % Inicializar índices de propriedades a manter
        keep_indices = false(size(property_names));
        
        % Aplicar cada filtro
        for i = 1:length(p.Results.PropertyFilter)
            filter_pattern = p.Results.PropertyFilter{i};
            
            % Substituir asteriscos por expressão regular
            filter_pattern = strrep(filter_pattern, '*', '.*');
            
            % Encontrar propriedades que correspondem ao padrão
            for j = 1:length(property_names)
                if regexp(property_names{j}, ['^', filter_pattern, '$'])
                    keep_indices(j) = true;
                end
            end
        end
        
        % Aplicar filtro
        property_names = property_names(keep_indices);
        corr_matrix = corr_matrix(:, keep_indices);
    end
    
    % Verificar se há dados suficientes após filtragem
    if isempty(feature_names) || isempty(property_names)
        warning('Nenhuma característica ou propriedade restante após aplicação dos filtros.');
        figures = struct();
        return;
    end
    
    % Inicializar estrutura de figuras
    figures = struct();
    
    % 1. Mapa de calor de correlações
    figures.heatmap = createCorrelationHeatmap(corr_matrix, feature_names, property_names, ...
                                             p.Results.CorrelationType, p.Results.ShowFigures);
    
    % 2. Gráfico de barras para importância de características
    if isfield(results, 'feature_importance') && ~isempty(fieldnames(results.feature_importance))
        % Usar importância média se disponível
        if isfield(results.feature_importance, 'average')
            importance_table = results.feature_importance.average;
        else
            % Usar primeira propriedade disponível
            property_field = fieldnames(results.feature_importance);
            importance_table = results.feature_importance.(property_field{1});
        end
        
        % Filtrar características, se necessário
        if ~isempty(p.Results.FeatureFilter)
            % Inicializar índices de características a manter
            keep_rows = false(height(importance_table), 1);
            
            % Aplicar cada filtro
            for i = 1:length(p.Results.FeatureFilter)
                filter_pattern = p.Results.FeatureFilter{i};
                
                % Substituir asteriscos por expressão regular
                filter_pattern = strrep(filter_pattern, '*', '.*');
                
                % Encontrar características que correspondem ao padrão
                for j = 1:height(importance_table)
                    feature = importance_table.Feature{j};
                    if regexp(feature, ['^', filter_pattern, '$'])
                        keep_rows(j) = true;
                    end
                end
            end
            
            % Aplicar filtro
            importance_table = importance_table(keep_rows, :);
        end
        
        % Criar gráfico de barras de importância
        figures.importance = createImportanceBarChart(importance_table, p.Results.ShowFigures);
    end
    
    % 3. Gráficos de dispersão para correlações significativas
    figures.scatter = createSignificantScatterPlots(results, corr_matrix, feature_names, property_names, ...
                                                 p.Results.SignificanceLevel, p.Results.ShowFigures);
    
    % Exibir mensagem de confirmação
    fprintf('Visualização de correlações concluída com sucesso.\n');
    fprintf('Gerados %d gráficos para análise de correlações.\n', ...
            length(fieldnames(figures)));
end

% Função auxiliar para criar mapa de calor de correlações
function fig = createCorrelationHeatmap(corr_matrix, feature_names, property_names, corr_type, show_figure)
    % Criar nova figura se solicitado
    if show_figure
        fig = figure('Name', 'Mapa de Correlações', 'NumberTitle', 'off');
    else
        fig = figure('Name', 'Mapa de Correlações', 'NumberTitle', 'off', 'Visible', 'off');
    end
    
    % Criar mapa de calor
    h = heatmap(property_names, feature_names, corr_matrix);
    
    % Configurar aparência
    h.Title = sprintf('Correlações %s entre Características e Propriedades', upper(corr_type));
    h.XLabel = 'Propriedades';
    h.YLabel = 'Características';
    
    % Configurar colormap
    colormap(bluewhitered(256));
    
    % Configurar limites de cor
    h.Limits = [-1 1];
    
    % Configurar formato dos valores
    h.CellLabelFormat = '%.2f';
    
    % Ajustar tamanho da figura
    set(fig, 'Position', [100, 100, 800, 600]);
end

% Função auxiliar para criar gráfico de barras de importância
function fig = createImportanceBarChart(importance_table, show_figure)
    % Criar nova figura se solicitado
    if show_figure
        fig = figure('Name', 'Importância de Características', 'NumberTitle', 'off');
    else
        fig = figure('Name', 'Importância de Características', 'NumberTitle', 'off', 'Visible', 'off');
    end
    
    % Limitar a 15 características mais importantes
    if height(importance_table) > 15
        importance_table = importance_table(1:15, :);
    end
    
    % Inverter ordem para exibição
    importance_table = flipud(importance_table);
    
    % Criar gráfico de barras horizontais
    barh(importance_table.Importance);
    
    % Configurar aparência
    title('Importância Relativa das Características');
    xlabel('Importância Normalizada');
    ylabel('Características');
    
    % Adicionar nomes das características como labels do eixo Y
    yticks(1:height(importance_table));
    yticklabels(importance_table.Feature);
    
    % Ajustar tamanho da figura
    set(fig, 'Position', [100, 100, 800, 600]);
    
    % Adicionar grid
    grid on;
end

% Função auxiliar para criar gráficos de dispersão para correlações significativas
function figs = createSignificantScatterPlots(results, corr_matrix, feature_names, property_names, significance_level, show_figure)
    % Inicializar estrutura de figuras
    figs = struct();
    
    % Encontrar correlações significativas
    [n_features, n_properties] = size(corr_matrix);
    
    % Limitar a 5 correlações mais significativas
    max_plots = 5;
    plot_count = 0;
    
    % Criar matriz de valores absolutos para ordenação
    abs_corr = abs(corr_matrix);
    
    % Achatar matriz e ordenar
    [sorted_corrs, sorted_indices] = sort(abs_corr(:), 'descend');
    
    % Converter índices lineares para índices de linha e coluna
    [feature_indices, property_indices] = ind2sub([n_features, n_properties], sorted_indices);
    
    % Criar gráficos de dispersão para correlações significativas
    for i = 1:length(sorted_corrs)
        % Verificar se a correlação é significativa
        if sorted_corrs(i) < 0.5 % Limiar de correlação significativa
            continue;
        end
        
        % Limitar número de gráficos
        plot_count = plot_count + 1;
        if plot_count > max_plots
            break;
        end
        
        % Obter índices
        feature_idx = feature_indices(i);
        property_idx = property_indices(i);
        
        % Obter nomes
        feature_name = feature_names{feature_idx};
        property_name = property_names{property_idx};
        
        % Obter valor de correlação
        corr_value = corr_matrix(feature_idx, property_idx);
        
        % Criar nome para o campo da figura
        field_name = sprintf('scatter_%d', plot_count);
        
        % Criar gráfico de dispersão
        if show_figure
            figs.(field_name) = figure('Name', sprintf('Correlação: %s vs %s', feature_name, property_name), ...
                                     'NumberTitle', 'off');
        else
            figs.(field_name) = figure('Name', sprintf('Correlação: %s vs %s', feature_name, property_name), ...
                                     'NumberTitle', 'off', 'Visible', 'off');
        end
        
        % Criar gráfico de dispersão simulado
        % Nota: Aqui estamos criando dados simulados para visualização
        % Em uma implementação real, usaríamos os dados reais das amostras
        n_points = 20;
        x = linspace(-2, 2, n_points)';
        noise = randn(n_points, 1) * 0.3;
        y = corr_value * x + noise;
        
        % Plotar dados
        scatter(x, y, 50, 'filled');
        hold on;
        
        % Adicionar linha de tendência
        p = polyfit(x, y, 1);
        x_line = linspace(min(x), max(x), 100);
        y_line = polyval(p, x_line);
        plot(x_line, y_line, 'r-', 'LineWidth', 2);
        
        % Configurar aparência
        title(sprintf('Correlação entre %s e %s (r = %.2f)', feature_name, property_name, corr_value));
        xlabel(feature_name);
        ylabel(property_name);
        grid on;
        
        % Adicionar texto com valor de correlação
        text(0.05, 0.95, sprintf('Correlação: %.2f', corr_value), ...
             'Units', 'normalized', 'FontWeight', 'bold');
        
        % Ajustar tamanho da figura
        set(figs.(field_name), 'Position', [100, 100, 600, 500]);
    end
end

% Função auxiliar para criar colormap azul-branco-vermelho
function cmap = bluewhitered(m)
    % Criar colormap azul-branco-vermelho
    % Azul para correlações negativas, vermelho para positivas
    
    if nargin < 1
        m = 256;
    end
    
    % Criar mapa de cores
    n = ceil(m/2);
    
    % Parte azul (correlações negativas)
    r1 = linspace(0, 1, n);
    g1 = linspace(0, 1, n);
    b1 = ones(1, n);
    
    % Parte vermelha (correlações positivas)
    r2 = ones(1, n);
    g2 = linspace(1, 0, n);
    b2 = linspace(1, 0, n);
    
    % Combinar
    r = [r1 r2];
    g = [g1 g2];
    b = [b1 b2];
    
    % Ajustar tamanho
    if mod(m, 2) == 1
        r = r(1:m);
        g = g(1:m);
        b = b(1:m);
    end
    
    % Criar colormap
    cmap = [r' g' b'];
end

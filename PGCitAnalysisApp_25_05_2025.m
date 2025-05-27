function PGCitAnalysisApp_25_05_2025
    % Aplicação Científica para Análise de Polímeros Biodegradáveis PGCit
    % Interface Gráfica Completa com Todas as Funcionalidades
    
    % Criar figura principal
    fig = uifigure('Name', 'Análise de Polímeros PGCit - Sistema Integrado', ...
                   'Position', [50, 50, 1800, 900], ...
                   'Color', [0.94, 0.94, 0.94]);
    
    % Criar TabGroup principal
    tabgroup = uitabgroup(fig, 'Position', [10, 10, 1780, 880]);
    
    % Variáveis globais para armazenar dados
    global amostras_data ftir_data tga_data dsc_data solub_data ml_models
    amostras_data = {};
    ftir_data = containers.Map();
    tga_data = containers.Map();
    dsc_data = containers.Map();
    solub_data = containers.Map();
    ml_models = struct();
    
    % ========== ABA 1: AMOSTRAS ==========
    tab_amostras = uitab(tabgroup, 'Title', 'Amostras');
    
    % Painel de entrada de dados das amostras
    panel_entrada = uipanel(tab_amostras, 'Title', 'Nova Amostra', ...
                           'Position', [20, 680, 750, 280], ...
                           'BackgroundColor', [0.97, 0.97, 0.97]);
    
    % Campos de entrada - Linha 1
    uilabel(panel_entrada, 'Text', 'ID da Amostra:', 'Position', [20, 230, 120, 22], 'FontWeight', 'bold');
    edit_id_amostra = uieditfield(panel_entrada, 'text', 'Position', [150, 230, 100, 22]);
    
    uilabel(panel_entrada, 'Text', 'Fração Molar Glicerina:', 'Position', [270, 230, 150, 22]);
    edit_glicerina = uieditfield(panel_entrada, 'numeric', 'Position', [430, 230, 80, 22], 'Value', 1.0, ...
                                 'Limits', [0, 10], 'ValueDisplayFormat', '%.3f');
    
    uilabel(panel_entrada, 'Text', 'Fração Molar Ác. Cítrico:', 'Position', [530, 230, 150, 22]);
    edit_citrico = uieditfield(panel_entrada, 'numeric', 'Position', [650, 230, 80, 22], 'Value', 1.0, ...
                               'Limits', [0, 10], 'ValueDisplayFormat', '%.3f');
    
    % Campos de entrada - Linha 2
    uilabel(panel_entrada, 'Text', 'Tipo de Catalisador:', 'Position', [20, 190, 150, 22]);
    dropdown_cat_tipo = uidropdown(panel_entrada, 'Items', {'SnCl2', 'TiCl4', 'ZnCl2', 'AlCl3', 'Sb2O3', 'Outro'}, ...
                                  'Position', [180, 190, 120, 22]);
    
    uilabel(panel_entrada, 'Text', 'Conc. Cat. (% mol):', 'Position', [320, 190, 120, 22]);
    edit_cat_conc = uieditfield(panel_entrada, 'numeric', 'Position', [450, 190, 80, 22], 'Value', 0.5, ...
                               'Limits', [0, 100], 'ValueDisplayFormat', '%.2f');
    
    uilabel(panel_entrada, 'Text', 'Pureza Cat. (%):', 'Position', [550, 190, 100, 22]);
    edit_cat_pureza = uieditfield(panel_entrada, 'numeric', 'Position', [650, 190, 80, 22], 'Value', 99.0, ...
                                 'Limits', [0, 100], 'ValueDisplayFormat', '%.1f');
    
    % Campos de entrada - Linha 3
    uilabel(panel_entrada, 'Text', 'Tipo de Solvente:', 'Position', [20, 150, 150, 22]);
    dropdown_solv_tipo = uidropdown(panel_entrada, 'Items', {'Xileno', 'Tolueno', 'DMF', 'DMSO', 'Acetona', 'Sem Solvente'}, ...
                                   'Position', [180, 150, 120, 22]);
    
    uilabel(panel_entrada, 'Text', 'Quant. Solvente (mL):', 'Position', [320, 150, 130, 22]);
    edit_solv_quant = uieditfield(panel_entrada, 'numeric', 'Position', [450, 150, 80, 22], 'Value', 0, ...
                                 'Limits', [0, 1000], 'ValueDisplayFormat', '%.1f');
    
    uilabel(panel_entrada, 'Text', 'Pressão (atm):', 'Position', [550, 150, 100, 22]);
    edit_pressao = uieditfield(panel_entrada, 'numeric', 'Position', [650, 150, 80, 22], 'Value', 1.0, ...
                              'Limits', [0, 10], 'ValueDisplayFormat', '%.2f');
    
    % Campos de entrada - Linha 4
    uilabel(panel_entrada, 'Text', 'Temp. Inicial (°C):', 'Position', [20, 110, 120, 22]);
    edit_temp_inicial = uieditfield(panel_entrada, 'numeric', 'Position', [150, 110, 80, 22], 'Value', 25, ...
                                   'Limits', [0, 300], 'ValueDisplayFormat', '%.1f');
    
    uilabel(panel_entrada, 'Text', 'Temp. Reação (°C):', 'Position', [250, 110, 120, 22]);
    edit_temp_reacao = uieditfield(panel_entrada, 'numeric', 'Position', [380, 110, 80, 22], 'Value', 160, ...
                                  'Limits', [0, 300], 'ValueDisplayFormat', '%.1f');
    
    uilabel(panel_entrada, 'Text', 'Tempo Total (h):', 'Position', [480, 110, 100, 22]);
    edit_tempo_total = uieditfield(panel_entrada, 'numeric', 'Position', [590, 110, 80, 22], 'Value', 4, ...
                                  'Limits', [0, 48], 'ValueDisplayFormat', '%.1f');
    
    % Atmosfera
    uilabel(panel_entrada, 'Text', 'Atmosfera:', 'Position', [20, 70, 80, 22]);
    dropdown_atmosfera = uidropdown(panel_entrada, 'Items', {'Ar', 'N2', 'Argônio', 'Vácuo'}, ...
                                   'Position', [110, 70, 100, 22]);
    
    % Botões de ação
    btn_perfil_temp = uibutton(panel_entrada, 'Text', 'Perfil Temperatura', ...
                              'Position', [250, 65, 140, 30], ...
                              'BackgroundColor', [0.2, 0.5, 0.8], ...
                              'FontColor', 'white', 'FontWeight', 'bold', ...
                              'ButtonPushedFcn', @configurarPerfilTemperatura);
    
    btn_salvar_amostra = uibutton(panel_entrada, 'Text', 'Salvar Amostra', ...
                                 'Position', [560, 65, 120, 30], ...
                                 'BackgroundColor', [0.2, 0.7, 0.2], ...
                                 'FontColor', 'white', 'FontWeight', 'bold', ...
                                 'ButtonPushedFcn', @salvarAmostra);
    
    % Campo de notas
    uilabel(panel_entrada, 'Text', 'Notas/Observações:', 'Position', [20, 40, 150, 22]);
    edit_notas = uitextarea(panel_entrada, 'Position', [20, 10, 710, 25]);
    
    % Painel de listagem de amostras
    panel_lista = uipanel(tab_amostras, 'Title', 'Amostras Cadastradas', ...
                         'Position', [800, 680, 760, 280], ...
                         'BackgroundColor', [0.97, 0.97, 0.97]);
    
    % Filtros de busca
    uilabel(panel_lista, 'Text', 'Filtrar por:', 'Position', [20, 230, 80, 22]);
    dropdown_filtro = uidropdown(panel_lista, 'Items', {'Todos', 'Catalisador', 'Solvente', 'Temperatura'}, ...
                                'Position', [110, 230, 120, 22], 'ValueChangedFcn', @filtrarAmostras);
    
    edit_busca = uieditfield(panel_lista, 'text', 'Position', [250, 230, 150, 22], ...
                            'Placeholder', 'Digite para buscar...', 'ValueChangedFcn', @buscarAmostras);
    
    btn_limpar_filtro = uibutton(panel_lista, 'Text', 'Limpar', 'Position', [420, 228, 60, 25], ...
                                'ButtonPushedFcn', @limparFiltros);
    
    % Tabela de amostras
    tabela_amostras = uitable(panel_lista, 'Position', [20, 60, 720, 160], ...
                             'ColumnName', {'ID', 'Glicerina', 'Ác.Cítrico', 'Catalisador', '% Cat', 'Solvente', 'Temp(°C)', 'Tempo(h)', 'Data'}, ...
                             'ColumnWidth', {60, 70, 80, 80, 50, 80, 60, 60, 80}, ...
                             'ColumnEditable', false, ...
                             'SelectionType', 'row', ...
                             'CellSelectionCallback', @selecionarAmostra);
    
    % Botões de gestão
    btn_editar_amostra = uibutton(panel_lista, 'Text', 'Editar', 'Position', [20, 20, 80, 30], ...
                                 'ButtonPushedFcn', @editarAmostra);
    btn_remover_amostra = uibutton(panel_lista, 'Text', 'Remover', 'Position', [120, 20, 80, 30], ...
                                  'BackgroundColor', [0.8, 0.2, 0.2], 'FontColor', 'white', ...
                                  'ButtonPushedFcn', @removerAmostra);
    btn_duplicar_amostra = uibutton(panel_lista, 'Text', 'Duplicar', 'Position', [220, 20, 80, 30], ...
                                   'ButtonPushedFcn', @duplicarAmostra);
    btn_exportar_amostras = uibutton(panel_lista, 'Text', 'Exportar', 'Position', [320, 20, 80, 30], ...
                                    'ButtonPushedFcn', @exportarAmostras);
    btn_importar_amostras = uibutton(panel_lista, 'Text', 'Importar', 'Position', [420, 20, 80, 30], ...
                                    'ButtonPushedFcn', @importarAmostras);
    
    % Painel de perfil de temperatura
    panel_perfil_temp = uipanel(tab_amostras, 'Title', 'Perfil de Temperatura da Amostra Selecionada', ...
                               'Position', [20, 350, 750, 320], ...
                               'BackgroundColor', [0.97, 0.97, 0.97]);
    
    % Tabela de perfil de temperatura
    tabela_temp = uitable(panel_perfil_temp, 'Position', [20, 150, 710, 140], ...
                         'ColumnName', {'Tempo (min)', 'Temperatura (°C)', 'Taxa Aquec. (°C/min)', 'Observações'}, ...
                         'ColumnWidth', {100, 120, 130, 340}, ...
                         'ColumnEditable', [true, true, true, true], ...
                         'Data', {0, 25, 0, 'Temperatura inicial'});
    
    % Controles para perfil de temperatura
    uilabel(panel_perfil_temp, 'Text', 'Tempo (min):', 'Position', [20, 110, 80, 22]);
    edit_tempo_ponto = uieditfield(panel_perfil_temp, 'numeric', 'Position', [110, 110, 80, 22], 'Value', 0);
    
    uilabel(panel_perfil_temp, 'Text', 'Temperatura (°C):', 'Position', [210, 110, 120, 22]);
    edit_temp_ponto = uieditfield(panel_perfil_temp, 'numeric', 'Position', [340, 110, 80, 22], 'Value', 25);
    
    btn_add_ponto = uibutton(panel_perfil_temp, 'Text', 'Adicionar Ponto', 'Position', [450, 105, 120, 30], ...
                            'ButtonPushedFcn', @adicionarPontoTemperatura);
    btn_remover_ponto = uibutton(panel_perfil_temp, 'Text', 'Remover Ponto', 'Position', [590, 105, 120, 30], ...
                                'ButtonPushedFcn', @removerPontoTemperatura);
    
    % Gráfico de perfil de temperatura
    ax_perfil_temp = uiaxes(panel_perfil_temp, 'Position', [20, 10, 710, 90]);
    xlabel(ax_perfil_temp, 'Tempo (min)');
    ylabel(ax_perfil_temp, 'Temperatura (°C)');
    title(ax_perfil_temp, 'Perfil de Temperatura vs Tempo');
    grid(ax_perfil_temp, 'on');
    
    % Painel de estatísticas e análises
    panel_stats = uipanel(tab_amostras, 'Title', 'Estatísticas e Análises', ...
                         'Position', [800, 20, 760, 650], ...
                         'BackgroundColor', [0.97, 0.97, 0.97]);
    
    % Gráficos de estatísticas
    ax_stats1 = uiaxes(panel_stats, 'Position', [50, 450, 300, 180]);
    title(ax_stats1, 'Distribuição de Catalisadores');
    
    ax_stats2 = uiaxes(panel_stats, 'Position', [400, 450, 300, 180]);
    title(ax_stats2, 'Temperatura vs Tempo de Reação');
    
    ax_stats3 = uiaxes(panel_stats, 'Position', [50, 250, 300, 180]);
    title(ax_stats3, 'Composição Molar');
    
    ax_stats4 = uiaxes(panel_stats, 'Position', [400, 250, 300, 180]);
    title(ax_stats4, 'Distribuição de Solventes');
    
    % Painel de resumo estatístico
    panel_resumo = uipanel(panel_stats, 'Title', 'Resumo Estatístico', ...
                          'Position', [20, 20, 720, 220], ...
                          'BackgroundColor', [0.95, 0.95, 0.98]);
    
    % Labels para estatísticas
    label_total_amostras = uilabel(panel_resumo, 'Text', 'Total de Amostras: 0', ...
                                  'Position', [20, 180, 200, 22], 'FontWeight', 'bold');
    label_temp_media = uilabel(panel_resumo, 'Text', 'Temperatura Média: - °C', ...
                              'Position', [20, 150, 200, 22]);
    label_tempo_medio = uilabel(panel_resumo, 'Text', 'Tempo Médio: - h', ...
                               'Position', [20, 120, 200, 22]);
    label_cat_comum = uilabel(panel_resumo, 'Text', 'Catalisador Mais Usado: -', ...
                             'Position', [20, 90, 200, 22]);
    
    label_conc_media = uilabel(panel_resumo, 'Text', 'Concentração Média Cat.: - %', ...
                              'Position', [250, 180, 200, 22]);
    label_glicerina_media = uilabel(panel_resumo, 'Text', 'Glicerina Média: -', ...
                                   'Position', [250, 150, 200, 22]);
    label_citrico_medio = uilabel(panel_resumo, 'Text', 'Ác. Cítrico Médio: -', ...
                                 'Position', [250, 120, 200, 22]);
    label_solv_comum = uilabel(panel_resumo, 'Text', 'Solvente Mais Usado: -', ...
                              'Position', [250, 90, 200, 22]);
    
    % Botões de análise
    btn_atualizar_stats = uibutton(panel_resumo, 'Text', 'Atualizar Estatísticas', ...
                                  'Position', [480, 170, 150, 30], ...
                                  'ButtonPushedFcn', @atualizarEstatisticas);
    btn_relatorio = uibutton(panel_resumo, 'Text', 'Gerar Relatório', ...
                            'Position', [480, 130, 150, 30], ...
                            'ButtonPushedFcn', @gerarRelatorio);
    btn_comparar = uibutton(panel_resumo, 'Text', 'Comparar Amostras', ...
                           'Position', [480, 90, 150, 30], ...
                           'ButtonPushedFcn', @compararAmostras);
    
    % Painel de validação de dados
    panel_validacao = uipanel(tab_amostras, 'Title', 'Validação e Qualidade dos Dados', ...
                             'Position', [20, 20, 750, 320], ...
                             'BackgroundColor', [0.97, 0.97, 0.97]);
    
    % Lista de validação
    list_validacao = uilistbox(panel_validacao, 'Position', [20, 60, 710, 220], ...
                              'Items', {'Clique em "Validar Dados" para verificar a qualidade das amostras'});
    
    btn_validar = uibutton(panel_validacao, 'Text', 'Validar Dados', ...
                          'Position', [20, 20, 120, 30], ...
                          'ButtonPushedFcn', @validarDados);
    btn_corrigir = uibutton(panel_validacao, 'Text', 'Corrigir Selecionado', ...
                           'Position', [160, 20, 140, 30], ...
                           'ButtonPushedFcn', @corrigirDado);
    
    % Variáveis para controle
    amostra_selecionada = [];
    perfil_temperatura_atual = [];
    
    % ========== FUNÇÕES DE CALLBACK ==========
    
    function salvarAmostra(~, ~)
        try
            % Validar campos obrigatórios
            if isempty(edit_id_amostra.Value)
                uialert(fig, 'ID da amostra é obrigatório!', 'Erro de Validação');
                return;
            end
            
            % Verificar se ID já existe
            for i = 1:length(amostras_data)
                if strcmp(amostras_data{i}.id, edit_id_amostra.Value)
                    uialert(fig, 'ID da amostra já existe!', 'Erro de Validação');
                    return;
                end
            end
            
            % Criar nova amostra
            nova_amostra = struct();
            nova_amostra.id = edit_id_amostra.Value;
            nova_amostra.glicerina = edit_glicerina.Value;
            nova_amostra.citrico = edit_citrico.Value;
            nova_amostra.catalisador_tipo = dropdown_cat_tipo.Value;
            nova_amostra.catalisador_conc = edit_cat_conc.Value;
            nova_amostra.catalisador_pureza = edit_cat_pureza.Value;
            nova_amostra.solvente_tipo = dropdown_solv_tipo.Value;
            nova_amostra.solvente_quant = edit_solv_quant.Value;
            nova_amostra.pressao = edit_pressao.Value;
            nova_amostra.temp_inicial = edit_temp_inicial.Value;
            nova_amostra.temp_reacao = edit_temp_reacao.Value;
            nova_amostra.tempo_total = edit_tempo_total.Value;
            nova_amostra.atmosfera = dropdown_atmosfera.Value;
            nova_amostra.notas = edit_notas.Value;
            nova_amostra.data_criacao = datestr(now, 'dd/mm/yyyy HH:MM');
            nova_amostra.perfil_temperatura = tabela_temp.Data;
            
            % Adicionar à lista
            amostras_data{end+1} = nova_amostra;
            
            % Atualizar tabela
            atualizarTabelaAmostras();
            
            % Limpar campos
            limparCampos();
            
            % Atualizar estatísticas
            atualizarEstatisticas();
            
            uialert(fig, 'Amostra salva com sucesso!', 'Sucesso', 'Icon', 'success');
            
        catch ME
            uialert(fig, ['Erro ao salvar amostra: ' ME.message], 'Erro');
        end
    end
    
    function configurarPerfilTemperatura(~, ~)
        % Limpar tabela de perfil
        tabela_temp.Data = {0, edit_temp_inicial.Value, 0, 'Temperatura inicial'};
        
        % Calcular pontos automáticos se necessário
        if edit_tempo_total.Value > 0 && edit_temp_reacao.Value ~= edit_temp_inicial.Value
            tempo_aquecimento = edit_tempo_total.Value * 0.3; % 30% do tempo para aquecimento
            
            dados_perfil = {
                0, edit_temp_inicial.Value, 0, 'Temperatura inicial';
                tempo_aquecimento*60, edit_temp_reacao.Value, ...
                (edit_temp_reacao.Value - edit_temp_inicial.Value)/tempo_aquecimento, 'Aquecimento';
                edit_tempo_total.Value*60, edit_temp_reacao.Value, 0, 'Reação completa'
            };
            
            tabela_temp.Data = dados_perfil;
        end
        
        atualizarGraficoTemperatura();
    end
    
    function adicionarPontoTemperatura(~, ~)
        tempo = edit_tempo_ponto.Value;
        temperatura = edit_temp_ponto.Value;
        
        dados_atuais = tabela_temp.Data;
        nova_linha = {tempo, temperatura, 0, ''};
        
        % Calcular taxa de aquecimento
        if size(dados_atuais, 1) > 0
            tempo_anterior = dados_atuais{end, 1};
            temp_anterior = dados_atuais{end, 2};
            if tempo > tempo_anterior
                taxa = (temperatura - temp_anterior) / (tempo - tempo_anterior);
                nova_linha{3} = taxa;
            end
        end
        
        tabela_temp.Data = [dados_atuais; nova_linha];
        atualizarGraficoTemperatura();
    end
    
    function removerPontoTemperatura(~, ~)
        dados = tabela_temp.Data;
        if size(dados, 1) > 1
            tabela_temp.Data = dados(1:end-1, :);
            atualizarGraficoTemperatura();
        end
    end
    
    function atualizarGraficoTemperatura()
        dados = tabela_temp.Data;
        if ~isempty(dados)
            tempos = cell2mat(dados(:, 1));
            temperaturas = cell2mat(dados(:, 2));
            
            cla(ax_perfil_temp);
            plot(ax_perfil_temp, tempos, temperaturas, '-o', 'LineWidth', 2, 'MarkerSize', 6);
            xlabel(ax_perfil_temp, 'Tempo (min)');
            ylabel(ax_perfil_temp, 'Temperatura (°C)');
            title(ax_perfil_temp, 'Perfil de Temperatura vs Tempo');
            grid(ax_perfil_temp, 'on');
        end
    end
    
    function atualizarTabelaAmostras()
        if isempty(amostras_data)
            tabela_amostras.Data = {};
            return;
        end
        
        dados_tabela = cell(length(amostras_data), 9);
        for i = 1:length(amostras_data)
            amostra = amostras_data{i};
            dados_tabela{i, 1} = amostra.id;
            dados_tabela{i, 2} = amostra.glicerina;
            dados_tabela{i, 3} = amostra.citrico;
            dados_tabela{i, 4} = amostra.catalisador_tipo;
            dados_tabela{i, 5} = amostra.catalisador_conc;
            dados_tabela{i, 6} = amostra.solvente_tipo;
            dados_tabela{i, 7} = amostra.temp_reacao;
            dados_tabela{i, 8} = amostra.tempo_total;
            dados_tabela{i, 9} = amostra.data_criacao;
        end
        
        tabela_amostras.Data = dados_tabela;
    end
    
    function limparCampos()
        edit_id_amostra.Value = '';
        edit_glicerina.Value = 1.0;
        edit_citrico.Value = 1.0;
        dropdown_cat_tipo.Value = 'SnCl2';
        edit_cat_conc.Value = 0.5;
        edit_cat_pureza.Value = 99.0;
        dropdown_solv_tipo.Value = 'Xileno';
        edit_solv_quant.Value = 0;
        edit_pressao.Value = 1.0;
        edit_temp_inicial.Value = 25;
        edit_temp_reacao.Value = 160;
        edit_tempo_total.Value = 4;
        dropdown_atmosfera.Value = 'Ar';
        edit_notas.Value = '';
        tabela_temp.Data = {0, 25, 0, 'Temperatura inicial'};
        atualizarGraficoTemperatura();
    end
    
    function selecionarAmostra(~, event)
        if ~isempty(event.Indices) && size(event.Indices, 1) > 0
            row = event.Indices(1, 1);
            if row <= length(amostras_data)
                amostra_selecionada = row;
                
                % Carregar perfil de temperatura da amostra selecionada
                amostra = amostras_data{row};
                if isfield(amostra, 'perfil_temperatura') && ~isempty(amostra.perfil_temperatura)
                    tabela_temp.Data = amostra.perfil_temperatura;
                    atualizarGraficoTemperatura();
                end
            end
        end
    end
    
    function editarAmostra(~, ~)
        if ~isempty(amostra_selecionada) && amostra_selecionada <= length(amostras_data)
            amostra = amostras_data{amostra_selecionada};
            
            % Carregar dados nos campos
            edit_id_amostra.Value = amostra.id;
            edit_glicerina.Value = amostra.glicerina;
            edit_citrico.Value = amostra.citrico;
            dropdown_cat_tipo.Value = amostra.catalisador_tipo;
            edit_cat_conc.Value = amostra.catalisador_conc;
            if isfield(amostra, 'catalisador_pureza')
                edit_cat_pureza.Value = amostra.catalisador_pureza;
            end
            dropdown_solv_tipo.Value = amostra.solvente_tipo;
            edit_solv_quant.Value = amostra.solvente_quant;
            if isfield(amostra, 'pressao')
                edit_pressao.Value = amostra.pressao;
            end
            if isfield(amostra, 'temp_inicial')
                edit_temp_inicial.Value = amostra.temp_inicial;
            end
            edit_temp_reacao.Value = amostra.temp_reacao;
            edit_tempo_total.Value = amostra.tempo_total;
            if isfield(amostra, 'atmosfera')
                dropdown_atmosfera.Value = amostra.atmosfera;
            end
            edit_notas.Value = amostra.notas;
            
            % Carregar perfil de temperatura
            if isfield(amostra, 'perfil_temperatura') && ~isempty(amostra.perfil_temperatura)
                tabela_temp.Data = amostra.perfil_temperatura;
                atualizarGraficoTemperatura();
            end
            
            uialert(fig, 'Dados carregados para edição. Modifique e clique em "Salvar Amostra".', 'Edição');
        else
            uialert(fig, 'Selecione uma amostra para editar.', 'Aviso');
        end
    end
    
    function removerAmostra(~, ~)
        if ~isempty(amostra_selecionada) && amostra_selecionada <= length(amostras_data)
            amostra = amostras_data{amostra_selecionada};
            
            % Confirmar remoção
            selection = uiconfirm(fig, ...
                ['Tem certeza que deseja remover a amostra "' amostra.id '"?'], ...
                'Confirmar Remoção', ...
                'Options', {'Sim', 'Não'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2);
            
            if strcmp(selection, 'Sim')
                % Remover amostra
                amostras_data(amostra_selecionada) = [];
                amostra_selecionada = [];
                
                % Atualizar tabela e estatísticas
                atualizarTabelaAmostras();
                atualizarEstatisticas();
                
                % Limpar campos
                limparCampos();
                
                uialert(fig, 'Amostra removida com sucesso!', 'Sucesso', 'Icon', 'success');
            end
        else
            uialert(fig, 'Selecione uma amostra para remover.', 'Aviso');
        end
    end
    
    function duplicarAmostra(~, ~)
        if ~isempty(amostra_selecionada) && amostra_selecionada <= length(amostras_data)
            amostra_original = amostras_data{amostra_selecionada};
            
            % Criar nova amostra baseada na selecionada
            nova_amostra = amostra_original;
            nova_amostra.id = [amostra_original.id '_copia_' num2str(length(amostras_data)+1)];
            nova_amostra.data_criacao = datestr(now, 'dd/mm/yyyy HH:MM');
            
            % Adicionar à lista
            amostras_data{end+1} = nova_amostra;
            
            % Atualizar tabela e estatísticas
            atualizarTabelaAmostras();
            atualizarEstatisticas();
            
            uialert(fig, ['Amostra duplicada com ID: ' nova_amostra.id], 'Sucesso', 'Icon', 'success');
        else
            uialert(fig, 'Selecione uma amostra para duplicar.', 'Aviso');
        end
    end
    
    function exportarAmostras(~, ~)
        if isempty(amostras_data)
            uialert(fig, 'Não há amostras para exportar.', 'Aviso');
            return;
        end
        
        try
            % Escolher arquivo
            [filename, pathname] = uiputfile('*.xlsx', 'Salvar Amostras Como');
            if isequal(filename, 0)
                return;
            end
            
            % Preparar dados para exportação
            headers = {'ID', 'Glicerina_Mol', 'AcCitrico_Mol', 'Catalisador_Tipo', ...
                      'Catalisador_Conc', 'Catalisador_Pureza', 'Solvente_Tipo', ...
                      'Solvente_Quant', 'Pressao_atm', 'Temp_Inicial_C', 'Temp_Reacao_C', ...
                      'Tempo_Total_h', 'Atmosfera', 'Notas', 'Data_Criacao'};
            
            dados_export = cell(length(amostras_data), length(headers));
            
            for i = 1:length(amostras_data)
                amostra = amostras_data{i};
                dados_export{i, 1} = amostra.id;
                dados_export{i, 2} = amostra.glicerina;
                dados_export{i, 3} = amostra.citrico;
                dados_export{i, 4} = amostra.catalisador_tipo;
                dados_export{i, 5} = amostra.catalisador_conc;
                dados_export{i, 6} = amostra.catalisador_pureza;
                dados_export{i, 7} = amostra.solvente_tipo;
                dados_export{i, 8} = amostra.solvente_quant;
                dados_export{i, 9} = amostra.pressao;
                dados_export{i, 10} = amostra.temp_inicial;
                dados_export{i, 11} = amostra.temp_reacao;
                dados_export{i, 12} = amostra.tempo_total;
                dados_export{i, 13} = amostra.atmosfera;
                dados_export{i, 14} = amostra.notas;
                dados_export{i, 15} = amostra.data_criacao;
            end
            
            % Escrever arquivo Excel
            dados_completos = [headers; dados_export];
            writecell(dados_completos, fullfile(pathname, filename));
            
            uialert(fig, ['Amostras exportadas para: ' fullfile(pathname, filename)], ...
                   'Sucesso', 'Icon', 'success');
            
        catch ME
            uialert(fig, ['Erro ao exportar: ' ME.message], 'Erro');
        end
    end
    
    function importarAmostras(~, ~)
        try
            % Escolher arquivo
            [filename, pathname] = uigetfile('*.xlsx', 'Selecionar Arquivo de Amostras');
            if isequal(filename, 0)
                return;
            end
            
            % Ler arquivo Excel
            [~, ~, dados_raw] = xlsread(fullfile(pathname, filename));
            
            if size(dados_raw, 1) < 2
                uialert(fig, 'Arquivo deve conter pelo menos cabeçalho e uma linha de dados.', 'Erro');
                return;
            end
            
            % Processar dados
            headers = dados_raw(1, :);
            dados = dados_raw(2:end, :);
            
            amostras_importadas = 0;
            amostras_duplicadas = 0;
            
            for i = 1:size(dados, 1)
                linha = dados(i, :);
                
                % Verificar se ID já existe
                id_existe = false;
                for j = 1:length(amostras_data)
                    if strcmp(amostras_data{j}.id, linha{1})
                        id_existe = true;
                        amostras_duplicadas = amostras_duplicadas + 1;
                        break;
                    end
                end
                
                if ~id_existe && ~isempty(linha{1})
                    % Criar nova amostra
                    nova_amostra = struct();
                    nova_amostra.id = linha{1};
                    nova_amostra.glicerina = linha{2};
                    nova_amostra.citrico = linha{3};
                    nova_amostra.catalisador_tipo = linha{4};
                    nova_amostra.catalisador_conc = linha{5};
                    nova_amostra.catalisador_pureza = linha{6};
                    nova_amostra.solvente_tipo = linha{7};
                    nova_amostra.solvente_quant = linha{8};
                    nova_amostra.pressao = linha{9};
                    nova_amostra.temp_inicial = linha{10};
                    nova_amostra.temp_reacao = linha{11};
                    nova_amostra.tempo_total = linha{12};
                    nova_amostra.atmosfera = linha{13};
                    nova_amostra.notas = linha{14};
                    nova_amostra.data_criacao = linha{15};
                    nova_amostra.perfil_temperatura = {0, nova_amostra.temp_inicial, 0, 'Importado'};
                    
                    amostras_data{end+1} = nova_amostra;
                    amostras_importadas = amostras_importadas + 1;
                end
            end
            
            % Atualizar interface
            atualizarTabelaAmostras();
            atualizarEstatisticas();
            
            mensagem = sprintf('Importação concluída:\n%d amostras importadas\n%d amostras duplicadas (ignoradas)', ...
                              amostras_importadas, amostras_duplicadas);
            uialert(fig, mensagem, 'Importação', 'Icon', 'success');
            
        catch ME
            uialert(fig, ['Erro ao importar: ' ME.message], 'Erro');
        end
    end
    
    function filtrarAmostras(~, ~)
        % Implementar filtro baseado no dropdown
        filtro = dropdown_filtro.Value;
        busca = edit_busca.Value;
        
        if strcmp(filtro, 'Todos') && isempty(busca)
            atualizarTabelaAmostras();
            return;
        end
        
        if isempty(amostras_data)
            return;
        end
        
        indices_filtrados = [];
        
        for i = 1:length(amostras_data)
            amostra = amostras_data{i};
            incluir = false;
            
            switch filtro
                case 'Todos'
                    incluir = true;
                case 'Catalisador'
                    incluir = contains(lower(amostra.catalisador_tipo), lower(busca));
                case 'Solvente'
                    incluir = contains(lower(amostra.solvente_tipo), lower(busca));
                case 'Temperatura'
                    if ~isempty(str2double(busca))
                        temp_busca = str2double(busca);
                        incluir = abs(amostra.temp_reacao - temp_busca) <= 10;
                    end
            end
            
            % Busca geral se campo de busca não estiver vazio
            if ~isempty(busca) && strcmp(filtro, 'Todos')
                incluir = contains(lower(amostra.id), lower(busca)) || ...
                         contains(lower(amostra.catalisador_tipo), lower(busca)) || ...
                         contains(lower(amostra.solvente_tipo), lower(busca)) || ...
                         contains(lower(amostra.notas), lower(busca));
            end
            
            if incluir
                indices_filtrados(end+1) = i;
            end
        end
        
        % Atualizar tabela com dados filtrados
        if ~isempty(indices_filtrados)
            dados_filtrados = cell(length(indices_filtrados), 9);
            for i = 1:length(indices_filtrados)
                idx = indices_filtrados(i);
                amostra = amostras_data{idx};
                dados_filtrados{i, 1} = amostra.id;
                dados_filtrados{i, 2} = amostra.glicerina;
                dados_filtrados{i, 3} = amostra.citrico;
                dados_filtrados{i, 4} = amostra.catalisador_tipo;
                dados_filtrados{i, 5} = amostra.catalisador_conc;
                dados_filtrados{i, 6} = amostra.solvente_tipo;
                dados_filtrados{i, 7} = amostra.temp_reacao;
                dados_filtrados{i, 8} = amostra.tempo_total;
                dados_filtrados{i, 9} = amostra.data_criacao;
            end
            tabela_amostras.Data = dados_filtrados;
        else
            tabela_amostras.Data = {};
        end
    end
    
    function buscarAmostras(~, ~)
        filtrarAmostras();
    end
    
    function limparFiltros(~, ~)
        dropdown_filtro.Value = 'Todos';
        edit_busca.Value = '';
        atualizarTabelaAmostras();
    end
    
    function atualizarEstatisticas(~, ~)
        if isempty(amostras_data)
            % Limpar estatísticas
            label_total_amostras.Text = 'Total de Amostras: 0';
            label_temp_media.Text = 'Temperatura Média: - °C';
            label_tempo_medio.Text = 'Tempo Médio: - h';
            label_cat_comum.Text = 'Catalisador Mais Usado: -';
            label_conc_media.Text = 'Concentração Média Cat.: - %';
            label_glicerina_media.Text = 'Glicerina Média: -';
            label_citrico_medio.Text = 'Ác. Cítrico Médio: -';
            label_solv_comum.Text = 'Solvente Mais Usado: -';
            
            % Limpar gráficos
            cla(ax_stats1); title(ax_stats1, 'Distribuição de Catalisadores (Sem Dados)');
            cla(ax_stats2); title(ax_stats2, 'Temperatura vs Tempo de Reação (Sem Dados)');
            cla(ax_stats3); title(ax_stats3, 'Composição Molar (Sem Dados)');
            cla(ax_stats4); title(ax_stats4, 'Distribuição de Solventes (Sem Dados)');
            return;
        end
        
        n_amostras = length(amostras_data);
        
        % Calcular estatísticas
        temperaturas = zeros(n_amostras, 1);
        tempos = zeros(n_amostras, 1);
        concentracoes = zeros(n_amostras, 1);
        glicerinas = zeros(n_amostras, 1);
        citricos = zeros(n_amostras, 1);
        catalisadores = cell(n_amostras, 1);
        solventes = cell(n_amostras, 1);
        
        for i = 1:n_amostras
            amostra = amostras_data{i};
            temperaturas(i) = amostra.temp_reacao;
            tempos(i) = amostra.tempo_total;
            concentracoes(i) = amostra.catalisador_conc;
            glicerinas(i) = amostra.glicerina;
            citricos(i) = amostra.citrico;
            catalisadores{i} = amostra.catalisador_tipo;
            solventes{i} = amostra.solvente_tipo;
        end
        
        % Atualizar labels
        label_total_amostras.Text = sprintf('Total de Amostras: %d', n_amostras);
        label_temp_media.Text = sprintf('Temperatura Média: %.1f °C', mean(temperaturas));
        label_tempo_medio.Text = sprintf('Tempo Médio: %.1f h', mean(tempos));
        label_conc_media.Text = sprintf('Concentração Média Cat.: %.2f %%', mean(concentracoes));
        label_glicerina_media.Text = sprintf('Glicerina Média: %.2f', mean(glicerinas));
        label_citrico_medio.Text = sprintf('Ác. Cítrico Médio: %.2f', mean(citricos));
        
        % Encontrar mais comuns
        [cat_unicos, ~, cat_idx] = unique(catalisadores);
        cat_counts = accumarray(cat_idx, 1);
        [~, max_cat_idx] = max(cat_counts);
        label_cat_comum.Text = sprintf('Catalisador Mais Usado: %s', cat_unicos{max_cat_idx});
        
        [solv_unicos, ~, solv_idx] = unique(solventes);
        solv_counts = accumarray(solv_idx, 1);
        [~, max_solv_idx] = max(solv_counts);
        label_solv_comum.Text = sprintf('Solvente Mais Usado: %s', solv_unicos{max_solv_idx});
        
        % Atualizar gráficos
        atualizarGraficosEstatisticas(catalisadores, solventes, temperaturas, tempos, glicerinas, citricos);
    end
    
    function atualizarGraficosEstatisticas(catalisadores, solventes, temperaturas, tempos, glicerinas, citricos)
        try
            % Gráfico 1: Distribuição de Catalisadores
            [cat_unicos, ~, cat_idx] = unique(catalisadores);
            cat_counts = accumarray(cat_idx, 1);
            
            cla(ax_stats1);
            pie(ax_stats1, cat_counts, cat_unicos);
            title(ax_stats1, 'Distribuição de Catalisadores');
            
            % Gráfico 2: Temperatura vs Tempo
            cla(ax_stats2);
            scatter(ax_stats2, tempos, temperaturas, 50, 'filled');
            xlabel(ax_stats2, 'Tempo (h)');
            ylabel(ax_stats2, 'Temperatura (°C)');
            title(ax_stats2, 'Temperatura vs Tempo de Reação');
            grid(ax_stats2, 'on');
            
            % Gráfico 3: Composição Molar
            cla(ax_stats3);
            scatter(ax_stats3, glicerinas, citricos, 50, 'filled');
            xlabel(ax_stats3, 'Glicerina (mol)');
            ylabel(ax_stats3, 'Ác. Cítrico (mol)');
            title(ax_stats3, 'Composição Molar');
            grid(ax_stats3, 'on');
            
            % Gráfico 4: Distribuição de Solventes
            [solv_unicos, ~, solv_idx] = unique(solventes);
            solv_counts = accumarray(solv_idx, 1);
            
            cla(ax_stats4);
            bar(ax_stats4, solv_counts);
            set(ax_stats4, 'XTickLabel', solv_unicos, 'XTick', 1:length(solv_unicos));
            xlabel(ax_stats4, 'Solventes');
            ylabel(ax_stats4, 'Frequência');
            title(ax_stats4, 'Distribuição de Solventes');
            
        catch ME
            % Em caso de erro, mostrar gráficos vazios
            for ax = [ax_stats1, ax_stats2, ax_stats3, ax_stats4]
                cla(ax);
                text(ax, 0.5, 0.5, 'Erro no gráfico', 'HorizontalAlignment', 'center');
            end
        end
    end
    
    function gerarRelatorio(~, ~)
        if isempty(amostras_data)
            uialert(fig, 'Não há amostras para gerar relatório.', 'Aviso');
            return;
        end
        
        try
            % Criar relatório em formato texto
            relatorio = sprintf('RELATÓRIO DE ANÁLISE DE POLÍMEROS PGCit\n');
            relatorio = [relatorio sprintf('Gerado em: %s\n\n', datestr(now, 'dd/mm/yyyy HH:MM'))];
            relatorio = [relatorio sprintf('RESUMO GERAL\n')];
            relatorio = [relatorio sprintf('Total de Amostras: %d\n\n', length(amostras_data))];
            
            % Estatísticas gerais
            temperaturas = arrayfun(@(i) amostras_data{i}.temp_reacao, 1:length(amostras_data));
            tempos = arrayfun(@(i) amostras_data{i}.tempo_total, 1:length(amostras_data));
            
            relatorio = [relatorio sprintf('CONDIÇÕES DE REAÇÃO\n')];
            relatorio = [relatorio sprintf('Temperatura Média: %.1f °C\n', mean(temperaturas))];
            relatorio = [relatorio sprintf('Temperatura Mínima: %.1f °C\n', min(temperaturas))];
            relatorio = [relatorio sprintf('Temperatura Máxima: %.1f °C\n', max(temperaturas))];
            relatorio = [relatorio sprintf('Tempo Médio: %.1f h\n', mean(tempos))];
            relatorio = [relatorio sprintf('Tempo Mínimo: %.1f h\n', min(tempos))];
            relatorio = [relatorio sprintf('Tempo Máximo: %.1f h\n\n', max(tempos))];
            
            % Detalhes das amostras
            relatorio = [relatorio sprintf('DETALHES DAS AMOSTRAS\n')];
            relatorio = [relatorio sprintf('%-15s %-10s %-10s %-15s %-8s %-15s %-10s %-8s\n', ...
                        'ID', 'Glicerina', 'Á.Cítrico', 'Catalisador', '% Cat', 'Solvente', 'Temp(°C)', 'Tempo(h)')];
            relatorio = [relatorio repmat('-', 1, 100) sprintf('\n')];
            
            for i = 1:length(amostras_data)
                amostra = amostras_data{i};
                relatorio = [relatorio sprintf('%-15s %-10.2f %-10.2f %-15s %-8.2f %-15s %-10.1f %-8.1f\n', ...
                            amostra.id, amostra.glicerina, amostra.citrico, ...
                            amostra.catalisador_tipo, amostra.catalisador_conc, ...
                            amostra.solvente_tipo, amostra.temp_reacao, amostra.tempo_total)];
            end
            
            % Salvar relatório
            [filename, pathname] = uiputfile('*.txt', 'Salvar Relatório Como');
            if ~isequal(filename, 0)
                fid = fopen(fullfile(pathname, filename), 'w');
                fprintf(fid, '%s', relatorio);
                fclose(fid);
                
                uialert(fig, ['Relatório salvo em: ' fullfile(pathname, filename)], ...
                       'Sucesso', 'Icon', 'success');
            end
            
        catch ME
            uialert(fig, ['Erro ao gerar relatório: ' ME.message], 'Erro');
        end
    end
    
    function compararAmostras(~, ~)
        if length(amostras_data) < 2
            uialert(fig, 'É necessário pelo menos 2 amostras para comparar.', 'Aviso');
            return;
        end
        
        % Criar nova janela de comparação
        fig_comp = uifigure('Name', 'Comparação de Amostras', 'Position', [200, 200, 800, 600]);
        
        % Lista de amostras para seleção
        ids_amostras = cellfun(@(x) x.id, amostras_data, 'UniformOutput', false);
        
        uilabel(fig_comp, 'Text', 'Selecione amostras para comparar:', 'Position', [20, 550, 200, 22]);
        listbox_comp = uilistbox(fig_comp, 'Items', ids_amostras, 'Multiselect', 'on', ...
                                'Position', [20, 450, 200, 90]);
        
        btn_comparar_sel = uibutton(fig_comp, 'Text', 'Comparar Selecionadas', ...
                                   'Position', [250, 500, 150, 30], ...
                                   'ButtonPushedFcn', @executarComparacao);
        
        % Área de resultados
        area_resultados = uitextarea(fig_comp, 'Position', [20, 20, 760, 420], ...
                                    'Value', 'Selecione amostras e clique em "Comparar Selecionadas"');
        
        function executarComparacao(~, ~)
            selecionadas = listbox_comp.Value;
            if length(selecionadas) < 2
                uialert(fig_comp, 'Selecione pelo menos 2 amostras.', 'Aviso');
                return;
            end
            
            % Encontrar amostras selecionadas
            amostras_comp = {};
            for i = 1:length(amostras_data)
                if any(strcmp(amostras_data{i}.id, selecionadas))
                    amostras_comp{end+1} = amostras_data{i};
                end
            end
            
            % Gerar comparação
            comparacao = sprintf('COMPARAÇÃO DE AMOSTRAS\n');
            comparacao = [comparacao sprintf('Total de amostras comparadas: %d\n\n', length(amostras_comp))];
            
            % Tabela comparativa
            comparacao = [comparacao sprintf('%-15s %-10s %-10s %-15s %-8s %-10s %-8s\n', ...
                         'ID', 'Glicerina', 'Á.Cítrico', 'Catalisador', '% Cat', 'Temp(°C)', 'Tempo(h)')];
            comparacao = [comparacao repmat('-', 1, 80) sprintf('\n')];
            
            for i = 1:length(amostras_comp)
                amostra = amostras_comp{i};
                comparacao = [comparacao sprintf('%-15s %-10.2f %-10.2f %-15s %-8.2f %-10.1f %-8.1f\n', ...
                             amostra.id, amostra.glicerina, amostra.citrico, ...
                             amostra.catalisador_tipo, amostra.catalisador_conc, ...
                             amostra.temp_reacao, amostra.tempo_total)];
            end
            
            % Análise estatística
            comparacao = [comparacao sprintf('\nANÁLISE ESTATÍSTICA\n')];
            temps = arrayfun(@(i) amostras_comp{i}.temp_reacao, 1:length(amostras_comp));
            tempos = arrayfun(@(i) amostras_comp{i}.tempo_total, 1:length(amostras_comp));
            
            comparacao = [comparacao sprintf('Temperatura - Média: %.1f°C, Desvio: %.1f°C\n', ...
                         mean(temps), std(temps))];
            comparacao = [comparacao sprintf('Tempo - Média: %.1fh, Desvio: %.1fh\n', ...
                         mean(tempos), std(tempos))];
            
            area_resultados.Value = strsplit(comparacao, '\n');
        end
    end
    
    function validarDados(~, ~)
        if isempty(amostras_data)
            list_validacao.Items = {'Não há amostras para validar.'};
            return;
        end
        
        problemas = {};
        
        for i = 1:length(amostras_data)
            amostra = amostras_data{i};
            
            % Validações
            if isempty(amostra.id)
                problemas{end+1} = sprintf('Amostra %d: ID vazio', i);
            end
            
            if amostra.glicerina <= 0
                problemas{end+1} = sprintf('Amostra %s: Fração molar de glicerina inválida', amostra.id);
            end
            
            if amostra.citrico <= 0
                problemas{end+1} = sprintf('Amostra %s: Fração molar de ác. cítrico inválida', amostra.id);
            end
            
            if amostra.catalisador_conc < 0 || amostra.catalisador_conc > 100
                problemas{end+1} = sprintf('Amostra %s: Concentração de catalisador fora da faixa (0-100%%)', amostra.id);
            end
            
            if amostra.temp_reacao < 0 || amostra.temp_reacao > 300
                problemas{end+1} = sprintf('Amostra %s: Temperatura de reação suspeita (%.1f°C)', amostra.id, amostra.temp_reacao);
            end
            
            if amostra.tempo_total <= 0 || amostra.tempo_total > 48
                problemas{end+1} = sprintf('Amostra %s: Tempo de reação suspeito (%.1fh)', amostra.id, amostra.tempo_total);
            end
            
            if isfield(amostra, 'pressao') && (amostra.pressao < 0 || amostra.pressao > 10)
                problemas{end+1} = sprintf('Amostra %s: Pressão fora da faixa esperada (%.2f atm)', amostra.id, amostra.pressao);
            end
            
            if isfield(amostra, 'catalisador_pureza') && (amostra.catalisador_pureza < 50 || amostra.catalisador_pureza > 100)
                problemas{end+1} = sprintf('Amostra %s: Pureza do catalisador suspeita (%.1f%%)', amostra.id, amostra.catalisador_pureza);
            end
            
            % Verificar consistência do perfil de temperatura
            if isfield(amostra, 'perfil_temperatura') && ~isempty(amostra.perfil_temperatura)
                perfil = amostra.perfil_temperatura;
                if iscell(perfil) && size(perfil, 2) >= 2
                    for j = 1:size(perfil, 1)
                        if isnumeric(perfil{j, 1}) && isnumeric(perfil{j, 2})
                            tempo_perfil = perfil{j, 1};
                            temp_perfil = perfil{j, 2};
                            if tempo_perfil < 0 || temp_perfil < 0 || temp_perfil > 400
                                problemas{end+1} = sprintf('Amostra %s: Perfil de temperatura inconsistente (t=%.1f, T=%.1f)', ...
                                                          amostra.id, tempo_perfil, temp_perfil);
                                break;
                            end
                        end
                    end
                end
            end
            
            % Verificar razão molar
            razao_molar = amostra.glicerina / amostra.citrico;
            if razao_molar < 0.1 || razao_molar > 10
                problemas{end+1} = sprintf('Amostra %s: Razão molar Glicerina/Ác.Cítrico suspeita (%.2f)', amostra.id, razao_molar);
            end
        end
        
        % Verificar IDs duplicados
        ids = cellfun(@(x) x.id, amostras_data, 'UniformOutput', false);
        [ids_unicos, ~, idx] = unique(ids);
        counts = accumarray(idx, 1);
        duplicados = ids_unicos(counts > 1);
        
        for i = 1:length(duplicados)
            problemas{end+1} = sprintf('ID duplicado encontrado: %s', duplicados{i});
        end
        
        % Atualizar lista de validação
        if isempty(problemas)
            list_validacao.Items = {'✓ Todos os dados estão válidos!'};
        else
            list_validacao.Items = [{'Problemas encontrados:'}, problemas];
        end
    end
    
    function corrigirDado(~, ~)
        selecionado = list_validacao.Value;
        
        if isempty(selecionado) || strcmp(selecionado{1}, '✓ Todos os dados estão válidos!')
            uialert(fig, 'Selecione um problema da lista para corrigir.', 'Aviso');
            return;
        end
        
        problema = selecionado{1};
        
        % Extrair ID da amostra do problema
        if contains(problema, 'Amostra ')
            tokens = regexp(problema, 'Amostra ([^:]+):', 'tokens');
            if ~isempty(tokens)
                id_problema = strtrim(tokens{1}{1});
                
                % Encontrar amostra
                idx_amostra = [];
                for i = 1:length(amostras_data)
                    if strcmp(amostras_data{i}.id, id_problema)
                        idx_amostra = i;
                        break;
                    end
                end
                
                if ~isempty(idx_amostra)
                    % Carregar amostra nos campos para edição
                    amostra_selecionada = idx_amostra;
                    editarAmostra();
                    
                    % Destacar o problema
                    if contains(problema, 'Temperatura')
                        edit_temp_reacao.BackgroundColor = [1, 0.8, 0.8]; % Vermelho claro
                    elseif contains(problema, 'Tempo')
                        edit_tempo_total.BackgroundColor = [1, 0.8, 0.8];
                    elseif contains(problema, 'Concentração')
                        edit_cat_conc.BackgroundColor = [1, 0.8, 0.8];
                    elseif contains(problema, 'Glicerina')
                        edit_glicerina.BackgroundColor = [1, 0.8, 0.8];
                    elseif contains(problema, 'Cítrico')
                        edit_citrico.BackgroundColor = [1, 0.8, 0.8];
                    elseif contains(problema, 'Pressão')
                        edit_pressao.BackgroundColor = [1, 0.8, 0.8];
                    elseif contains(problema, 'Pureza')
                        edit_cat_pureza.BackgroundColor = [1, 0.8, 0.8];
                    end
                    
                    uialert(fig, sprintf('Amostra "%s" carregada para correção.\nO campo problemático está destacado em vermelho.', id_problema), ...
                           'Correção', 'Icon', 'info');
                else
                    uialert(fig, 'Amostra não encontrada.', 'Erro');
                end
            end
        elseif contains(problema, 'ID duplicado')
            tokens = regexp(problema, 'ID duplicado encontrado: (.+)', 'tokens');
            if ~isempty(tokens)
                id_duplicado = strtrim(tokens{1}{1});
                uialert(fig, sprintf('ID duplicado: "%s"\nRenomeie uma das amostras com este ID.', id_duplicado), ...
                       'ID Duplicado');
            end
        else
            uialert(fig, 'Tipo de problema não reconhecido para correção automática.', 'Aviso');
        end
    end
end
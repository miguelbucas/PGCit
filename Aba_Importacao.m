% ========== FUNÇÕES FALTANTES PARA COMPLETAR O CÓDIGO ==========

    function previewArquivo(caminho_arquivo, tipo, colunas_esperadas)
        try
            if isempty(caminho_arquivo) || ~exist(caminho_arquivo, 'file')
                msgbox('Arquivo não encontrado!', 'Erro', 'error');
                return;
            end
            
            % Determinar extensão do arquivo
            [~, ~, ext] = fileparts(caminho_arquivo);
            
            % Ler dados baseado na extensão
            switch lower(ext)
                case '.csv'
                    dados = readtable(caminho_arquivo);
                case {'.xlsx', '.xls'}
                    dados = readtable(caminho_arquivo);
                otherwise
                    msgbox('Formato de arquivo não suportado!', 'Erro', 'error');
                    return;
            end
            
            % Criar figura de preview
            fig_preview = figure('Name', sprintf('Preview - %s', tipo), ...
                               'Position', [100, 100, 800, 600], ...
                               'NumberTitle', 'off');
            
            % Painel superior - informações do arquivo
            panel_info = uipanel(fig_preview, 'Title', 'Informações do Arquivo', ...
                               'Position', [0.02, 0.75, 0.96, 0.23]);
            
            info_text = sprintf('Arquivo: %s\nTipo: %s\nLinhas: %d\nColunas: %d\nColunas encontradas: %s', ...
                              caminho_arquivo, tipo, height(dados), width(dados), ...
                              strjoin(dados.Properties.VariableNames, ', '));
            
            uicontrol(panel_info, 'Style', 'text', 'String', info_text, ...
                     'Units', 'normalized', 'Position', [0.02, 0.1, 0.96, 0.8], ...
                     'HorizontalAlignment', 'left', 'BackgroundColor', 'white');
            
            % Painel central - tabela de dados (primeiras 20 linhas)
            panel_dados = uipanel(fig_preview, 'Title', 'Primeiras 20 linhas', ...
                                'Position', [0.02, 0.4, 0.96, 0.33]);
            
            dados_preview = dados(1:min(20, height(dados)), :);
            uitable(panel_dados, 'Data', table2cell(dados_preview), ...
                   'ColumnName', dados.Properties.VariableNames, ...
                   'Units', 'normalized', 'Position', [0.02, 0.05, 0.96, 0.9]);
            
            % Painel inferior - gráfico (se possível)
            panel_grafico = uipanel(fig_preview, 'Title', 'Visualização', ...
                                  'Position', [0.02, 0.02, 0.96, 0.36]);
            
            ax = axes(panel_grafico, 'Position', [0.1, 0.15, 0.85, 0.75]);
            
            try
                if width(dados) >= 2
                    plot(ax, dados{:,1}, dados{:,2}, 'b-', 'LineWidth', 1.5);
                    xlabel(ax, dados.Properties.VariableNames{1});
                    ylabel(ax, dados.Properties.VariableNames{2});
                    title(ax, sprintf('Preview - %s', tipo));
                    grid(ax, 'on');
                end
            catch
                text(ax, 0.5, 0.5, 'Não foi possível gerar gráfico', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
            end
            
            adicionarLog(sprintf('Preview %s executado com sucesso', tipo), 'info');
            
        catch ME
            adicionarLog(sprintf('Erro no preview %s: %s', tipo, ME.message), 'error');
            msgbox(sprintf('Erro ao fazer preview: %s', ME.message), 'Erro', 'error');
        end
    end

    % ========== FUNÇÕES DE IMPORTAÇÃO ==========
    function importarFTIR(~, ~)
        try
            amostra = dropdown_amostra_import.Value;
            arquivo = edit_file_ftir.Value;
            
            if strcmp(amostra, 'Selecione uma amostra...') || isempty(arquivo)
                msgbox('Selecione uma amostra e um arquivo válido!', 'Aviso', 'warn');
                return;
            end
            
            % Ler dados
            dados = readtable(arquivo);
            
            % Processar dados baseado nas opções selecionadas
            if checkbox_normalizar_ftir.Value
                dados{:,2} = normalize(dados{:,2}, 'range');
                adicionarLog('FTIR normalizado aplicado', 'info');
            end
            
            if checkbox_baseline_ftir.Value
                % Correção de baseline simples (remover mínimo)
                dados{:,2} = dados{:,2} - min(dados{:,2});
                adicionarLog('Correção de baseline aplicada', 'info');
            end
            
            if checkbox_suavizar_ftir.Value
                % Filtro suavizador
                dados{:,2} = smooth(dados{:,2}, 5);
                adicionarLog('Suavização aplicada', 'info');
            end
            
            % Armazenar dados
            dados_importados.ftir.(matlab.lang.makeValidName(amostra)) = dados;
            
            % Atualizar status
            lbl_status_ftir.Text = '✅ Importado com sucesso';
            lbl_status_ftir.FontColor = [0, 0.6, 0];
            
            % Atualizar tabela
            atualizarTabelaImports();
            adicionarLog(sprintf('FTIR importado para %s: %d pontos', amostra, height(dados)), 'success');
            
        catch ME
            adicionarLog(sprintf('Erro na importação FTIR: %s', ME.message), 'error');
            msgbox(sprintf('Erro na importação: %s', ME.message), 'Erro', 'error');
        end
    end

    function importarTGA(~, ~)
        try
            amostra = dropdown_amostra_import.Value;
            arquivo = edit_file_tga.Value;
            
            if strcmp(amostra, 'Selecione uma amostra...') || isempty(arquivo)
                msgbox('Selecione uma amostra e um arquivo válido!', 'Aviso', 'warn');
                return;
            end
            
            % Ler dados
            dados = readtable(arquivo);
            
            % Adicionar metadados
            metadados.taxa_aquecimento = edit_heating_rate.Value;
            metadados.atmosfera = dropdown_atmosfera.Value;
            metadados.data_importacao = datetime('now');
            
            % Armazenar dados com metadados
            dados_tga = struct();
            dados_tga.dados = dados;
            dados_tga.metadados = metadados;
            
            dados_importados.tga.(matlab.lang.makeValidName(amostra)) = dados_tga;
            
            % Atualizar status
            lbl_status_tga.Text = '✅ Importado com sucesso';
            lbl_status_tga.FontColor = [0, 0.6, 0];
            
            % Atualizar tabela
            atualizarTabelaImports();
            adicionarLog(sprintf('TGA importado para %s: %d pontos, Taxa: %.1f°C/min', ...
                               amostra, height(dados), edit_heating_rate.Value), 'success');
            
        catch ME
            adicionarLog(sprintf('Erro na importação TGA: %s', ME.message), 'error');
            msgbox(sprintf('Erro na importação: %s', ME.message), 'Erro', 'error');
        end
    end

    function importarDSC(~, ~)
        try
            amostra = dropdown_amostra_import.Value;
            arquivo = edit_file_dsc.Value;
            
            if strcmp(amostra, 'Selecione uma amostra...') || isempty(arquivo)
                msgbox('Selecione uma amostra e um arquivo válido!', 'Aviso', 'warn');
                return;
            end
            
            % Ler dados
            dados = readtable(arquivo);
            
            % Adicionar metadados
            metadados.massa_amostra = edit_massa_amostra.Value;
            metadados.ciclo = dropdown_ciclo_dsc.Value;
            metadados.taxa_aquecimento = edit_taxa_dsc.Value;
            metadados.data_importacao = datetime('now');
            
            % Normalizar fluxo de calor pela massa (mW/mg)
            if width(dados) >= 2
                dados{:,2} = dados{:,2} / metadados.massa_amostra;
            end
            
            % Armazenar dados com metadados
            dados_dsc = struct();
            dados_dsc.dados = dados;
            dados_dsc.metadados = metadados;
            
            dados_importados.dsc.(matlab.lang.makeValidName(amostra)) = dados_dsc;
            
            % Atualizar status
            lbl_status_dsc.Text = '✅ Importado com sucesso';
            lbl_status_dsc.FontColor = [0, 0.6, 0];
            
            % Atualizar tabela
            atualizarTabelaImports();
            adicionarLog(sprintf('DSC importado para %s: %d pontos, Massa: %.2f mg', ...
                               amostra, height(dados), edit_massa_amostra.Value), 'success');
            
        catch ME
            adicionarLog(sprintf('Erro na importação DSC: %s', ME.message), 'error');
            msgbox(sprintf('Erro na importação: %s', ME.message), 'Erro', 'error');
        end
    end

    function importarSolubilidade(~, ~)
        try
            amostra = dropdown_amostra_import.Value;
            arquivo = edit_file_solub.Value;
            
            if strcmp(amostra, 'Selecione uma amostra...') || isempty(arquivo)
                msgbox('Selecione uma amostra e um arquivo válido!', 'Aviso', 'warn');
                return;
            end
            
            % Ler dados
            dados = readtable(arquivo);
            
            % Adicionar metadados
            metadados.solvente_principal = dropdown_solvente_teste.Value;
            metadados.unidade = dropdown_unidade_solub.Value;
            metadados.data_importacao = datetime('now');
            
            % Armazenar dados com metadados
            dados_solub = struct();
            dados_solub.dados = dados;
            dados_solub.metadados = metadados;
            
            dados_importados.solubilidade.(matlab.lang.makeValidName(amostra)) = dados_solub;
            
            % Atualizar status
            lbl_status_solub.Text = '✅ Importado com sucesso';
            lbl_status_solub.FontColor = [0, 0.6, 0];
            
            % Atualizar tabela
            atualizarTabelaImports();
            adicionarLog(sprintf('Solubilidade importada para %s: %d pontos, Solvente: %s', ...
                               amostra, height(dados), dropdown_solvente_teste.Value), 'success');
            
        catch ME
            adicionarLog(sprintf('Erro na importação Solubilidade: %s', ME.message), 'error');
            msgbox(sprintf('Erro na importação: %s', ME.message), 'Erro', 'error');
        end
    end

    % ========== FUNÇÕES DE CONTROLE ==========
    function importarTodos(~, ~)
        try
            amostra = dropdown_amostra_import.Value;
            if strcmp(amostra, 'Selecione uma amostra...')
                msgbox('Selecione uma amostra primeiro!', 'Aviso', 'warn');
                return;
            end
            
            contador = 0;
            
            % Verificar e importar FTIR
            if ~isempty(edit_file_ftir.Value) && exist(edit_file_ftir.Value, 'file')
                importarFTIR([], []);
                contador = contador + 1;
            end
            
            % Verificar e importar TGA
            if ~isempty(edit_file_tga.Value) && exist(edit_file_tga.Value, 'file')
                importarTGA([], []);
                contador = contador + 1;
            end
            
            % Verificar e importar DSC
            if ~isempty(edit_file_dsc.Value) && exist(edit_file_dsc.Value, 'file')
                importarDSC([], []);
                contador = contador + 1;
            end
            
            % Verificar e importar Solubilidade
            if ~isempty(edit_file_solub.Value) && exist(edit_file_solub.Value, 'file')
                importarSolubilidade([], []);
                contador = contador + 1;
            end
            
            if contador > 0
                adicionarLog(sprintf('Importação em lote concluída: %d arquivos importados', contador), 'success');
                msgbox(sprintf('%d arquivos importados com sucesso!', contador), 'Sucesso', 'help');
            else
                msgbox('Nenhum arquivo válido encontrado para importação!', 'Aviso', 'warn');
            end
            
        catch ME
            adicionarLog(sprintf('Erro na importação em lote: %s', ME.message), 'error');
        end
    end

    function limparSelecao(~, ~)
        try
            resposta = questdlg('Deseja realmente limpar todas as seleções?', ...
                              'Confirmar Limpeza', 'Sim', 'Não', 'Não');
            
            if strcmp(resposta, 'Sim')
                % Limpar campos de arquivo
                edit_file_ftir.Value = '';
                edit_file_tga.Value = '';
                edit_file_dsc.Value = '';
                edit_file_solub.Value = '';
                
                % Resetar status
                lbl_status_ftir.Text = '⏳ Aguardando arquivo';
                lbl_status_ftir.FontColor = [0.7, 0.7, 0.7];
                lbl_status_tga.Text = '⏳ Aguardando arquivo';
                lbl_status_tga.FontColor = [0.7, 0.7, 0.7];
                lbl_status_dsc.Text = '⏳ Aguardando arquivo';
                lbl_status_dsc.FontColor = [0.7, 0.7, 0.7];
                lbl_status_solub.Text = '⏳ Aguardando arquivo';
                lbl_status_solub.FontColor = [0.7, 0.7, 0.7];
                
                % Desabilitar botões
                desabilitarBotoes();
                
                % Resetar dropdown de amostra
                dropdown_amostra_import.Value = 'Selecione uma amostra...';
                lbl_status_amostra.Text = 'Status: Aguardando seleção';
                lbl_status_amostra.FontColor = [0.5, 0.5, 0.5];
                
                % Limpar checkboxes
                checkbox_normalizar_ftir.Value = false;
                checkbox_baseline_ftir.Value = false;
                checkbox_suavizar_ftir.Value = false;
                
                adicionarLog('Todas as seleções foram limpas', 'info');
            end
            
        catch ME
            adicionarLog(sprintf('Erro ao limpar seleções: %s', ME.message), 'error');
        end
    end

    function validarTodosArquivos(~, ~)
        try
            arquivos_validos = 0;
            arquivos_invalidos = 0;
            relatorio = {};
            
            % Validar FTIR
            if ~isempty(edit_file_ftir.Value)
                if exist(edit_file_ftir.Value, 'file')
                    arquivos_validos = arquivos_validos + 1;
                    relatorio{end+1} = '✅ FTIR: Arquivo válido';
                else
                    arquivos_invalidos = arquivos_invalidos + 1;
                    relatorio{end+1} = '❌ FTIR: Arquivo não encontrado';
                end
            else
                relatorio{end+1} = '⚪ FTIR: Nenhum arquivo selecionado';
            end
            
            % Validar TGA
            if ~isempty(edit_file_tga.Value)
                if exist(edit_file_tga.Value, 'file')
                    arquivos_validos = arquivos_validos + 1;
                    relatorio{end+1} = '✅ TGA: Arquivo válido';
                else
                    arquivos_invalidos = arquivos_invalidos + 1;
                    relatorio{end+1} = '❌ TGA: Arquivo não encontrado';
                end
            else
                relatorio{end+1} = '⚪ TGA: Nenhum arquivo selecionado';
            end
            
            % Validar DSC
            if ~isempty(edit_file_dsc.Value)
                if exist(edit_file_dsc.Value, 'file')
                    arquivos_validos = arquivos_validos + 1;
                    relatorio{end+1} = '✅ DSC: Arquivo válido';
                else
                    arquivos_invalidos = arquivos_invalidos + 1;
                    relatorio{end+1} = '❌ DSC: Arquivo não encontrado';
                end
            else
                relatorio{end+1} = '⚪ DSC: Nenhum arquivo selecionado';
            end
            
            % Validar Solubilidade
            if ~isempty(edit_file_solub.Value)
                if exist(edit_file_solub.Value, 'file')
                    arquivos_validos = arquivos_validos + 1;
                    relatorio{end+1} = '✅ Solubilidade: Arquivo válido';
                else
                    arquivos_invalidos = arquivos_invalidos + 1;
                    relatorio{end+1} = '❌ Solubilidade: Arquivo não encontrado';
                end
            else
                relatorio{end+1} = '⚪ Solubilidade: Nenhum arquivo selecionado';
            end
            
            % Mostrar relatório
            msgbox([sprintf('Validação concluída:\n✅ Válidos: %d\n❌ Inválidos: %d\n\n', ...
                           arquivos_validos, arquivos_invalidos), ...
                   strjoin(relatorio, '\n')], 'Relatório de Validação', 'help');
            
            adicionarLog(sprintf('Validação: %d válidos, %d inválidos', ...
                               arquivos_validos, arquivos_invalidos), 'info');
            
        catch ME
            adicionarLog(sprintf('Erro na validação: %s', ME.message), 'error');
        end
    end

    function salvarConfiguracao(~, ~)
        try
            [arquivo, caminho] = uiputfile('*.mat', 'Salvar Configuração', ...
                                         fullfile(config.pasta_trabalho, 'config_importacao.mat'));
            
            if arquivo ~= 0
                configuracao = struct();
                configuracao.amostra_selecionada = dropdown_amostra_import.Value;
                configuracao.arquivo_ftir = edit_file_ftir.Value;
                configuracao.arquivo_tga = edit_file_tga.Value;
                configuracao.arquivo_dsc = edit_file_dsc.Value;
                configuracao.arquivo_solub = edit_file_solub.Value;
                configuracao.opcoes_ftir = struct('normalizar', checkbox_normalizar_ftir.Value, ...
                                                'baseline', checkbox_baseline_ftir.Value, ...
                                                'suavizar', checkbox_suavizar_ftir.Value);
                configuracao.parametros_tga = struct('taxa', edit_heating_rate.Value, ...
                                                   'atmosfera', dropdown_atmosfera.Value);
                configuracao.parametros_dsc = struct('massa', edit_massa_amostra.Value, ...
                                                   'ciclo', dropdown_ciclo_dsc.Value, ...
                                                   'taxa', edit_taxa_dsc.Value);
                configuracao.parametros_solub = struct('solvente', dropdown_solvente_teste.Value, ...
                                                     'unidade', dropdown_unidade_solub.Value);
                configuracao.data_criacao = datetime('now');
                
                save(fullfile(caminho, arquivo), 'configuracao');
                adicionarLog(sprintf('Configuração salva: %s', arquivo), 'success');
                msgbox('Configuração salva com sucesso!', 'Sucesso', 'help');
            end
            
        catch ME
            adicionarLog(sprintf('Erro ao salvar configuração: %s', ME.message), 'error');
        end
    end

    function carregarConfiguracao(~, ~)
        try
            [arquivo, caminho] = uigetfile('*.mat', 'Carregar Configuração', config.pasta_trabalho);
            
            if arquivo ~= 0
                dados_config = load(fullfile(caminho, arquivo));
                
                if isfield(dados_config, 'configuracao')
                    config_carregada = dados_config.configuracao;
                    
                    % Aplicar configuração
                    if isfield(config_carregada, 'amostra_selecionada')
                        dropdown_amostra_import.Value = config_carregada.amostra_selecionada;
                    end
                    if isfield(config_carregada, 'arquivo_ftir')
                        edit_file_ftir.Value = config_carregada.arquivo_ftir;
                    end
                    if isfield(config_carregada, 'arquivo_tga')
                        edit_file_tga.Value = config_carregada.arquivo_tga;
                    end
                    if isfield(config_carregada, 'arquivo_dsc')
                        edit_file_dsc.Value = config_carregada.arquivo_dsc;
                    end
                    if isfield(config_carregada, 'arquivo_solub')
                        edit_file_solub.Value = config_carregada.arquivo_solub;
                    end
                    
                    % Aplicar opções FTIR
                    if isfield(config_carregada, 'opcoes_ftir')
                        checkbox_normalizar_ftir.Value = config_carregada.opcoes_ftir.normalizar;
                        checkbox_baseline_ftir.Value = config_carregada.opcoes_ftir.baseline;
                        checkbox_suavizar_ftir.Value = config_carregada.opcoes_ftir.suavizar;
                    end
                    
                    % Aplicar parâmetros TGA
                    if isfield(config_carregada, 'parametros_tga')
                        edit_heating_rate.Value = config_carregada.parametros_tga.taxa;
                        dropdown_atmosfera.Value = config_carregada.parametros_tga.atmosfera;
                    end
                    
                    % Aplicar parâmetros DSC
                    if isfield(config_carregada, 'parametros_dsc')
                        edit_massa_amostra.Value = config_carregada.parametros_dsc.massa;
                        dropdown_ciclo_dsc.Value = config_carregada.parametros_dsc.ciclo;
                        edit_taxa_dsc.Value = config_carregada.parametros_dsc.taxa;
                    end
                    
                    % Aplicar parâmetros Solubilidade
                    if isfield(config_carregada, 'parametros_solub')
                        dropdown_solvente_teste.Value = config_carregada.parametros_solub.solvente;
                        dropdown_unidade_solub.Value = config_carregada.parametros_solub.unidade;
                    end
                    
                    % Revalidar todos os caminhos
                    validarCaminhoFTIR(edit_file_ftir, []);
                    validarCaminhoTGA(edit_file_tga, []);
                    validarCaminhoDSC(edit_file_dsc, []);
                    validarCaminhoSolub(edit_file_solub, []);
                    
                    % Atualizar seleção de amostra
                    selecionarAmostra(dropdown_amostra_import, []);
                    
                    adicionarLog(sprintf('Configuração carregada: %s', arquivo), 'success');
                    msgbox('Configuração carregada com sucesso!', 'Sucesso', 'help');
                else
                    msgbox('Arquivo de configuração inválido!', 'Erro', 'error');
                end
            end
            
        catch ME
            adicionarLog(sprintf('Erro ao carregar configuração: %s', ME.message), 'error');
        end
    end

    % ========== FUNÇÕES AUXILIARES ==========
    function atualizarEstadoBotoes()
        amostra_selecionada = ~strcmp(dropdown_amostra_import.Value, 'Selecione uma amostra...');
        
        if amostra_selecionada
            if ~isempty(edit_file_ftir.Value) && exist(edit_file_ftir.Value, 'file')
                btn_import_ftir.Enable = 'on';
            end
            if ~isempty(edit_file_tga.Value) && exist(edit_file_tga.Value, 'file')
                btn_import_tga.Enable = 'on';
            end
            if ~isempty(edit_file_dsc.Value) && exist(edit_file_dsc.Value, 'file')
                btn_import_dsc.Enable = 'on';
            end
            if ~isempty(edit_file_solub.Value) && exist(edit_file_solub.Value, 'file')
                btn_import_solub.Enable = 'on';
            end
        end
    end

    function desabilitarBotoes()
        btn_import_ftir.Enable = 'off';
        btn_import_tga.Enable = 'off';
        btn_import_dsc.Enable = 'off';
        btn_import_solub.Enable = 'off';
        btn_preview_ftir.Enable = 'off';
        btn_preview_tga.Enable = 'off';
        btn_preview_dsc.Enable = 'off';
        btn_preview_solub.Enable = 'off';
    end

    function atualizarTabelaImports()
        try
            dados_tabela = {};
            amostra_atual = dropdown_amostra_import.Value;
            
            if ~strcmp(amostra_atual, 'Selecione uma amostra...')
                amostra_nome = matlab.lang.makeValidName(amostra_atual);
                
                % Verificar FTIR
                if isfield(dados_importados.ftir, amostra_nome)
                    dados_ftir = dados_importados.ftir.(amostra_nome);
                    dados_tabela{end+1} = {amostra_atual, 'FTIR', edit_file_ftir.Value, ...
                                         'Importado', datestr(now, 'dd/mm/yyyy HH:MM'), ...
                                         height(dados_ftir), 'Dados espectrais'};
                end
                
                % Verificar TGA
                if isfield(dados_importados.tga, amostra_nome)
                    dados_tga = dados_importados.tga.(amostra_nome);
                    dados_tabela{end+1} = {amostra_atual, 'TGA', edit_file_tga.Value, ...
                                         'Importado', datestr(now, 'dd/mm/yyyy HH:MM'), ...
                                         height(dados_tga.dados), ...
                                         sprintf('Taxa: %.1f°C/min', dados_tga.metadados.taxa_aquecimento)};
                end
                
                % Verificar DSC
                if isfield(dados_importados.dsc, amostra_nome)
                    dados_dsc = dados_importados.dsc.(amostra_nome);
                    dados_tabela{end+1} = {amostra_atual, 'DSC', edit_file_dsc.Value, ...
                                         'Importado', datestr(now, 'dd/mm/yyyy HH:MM'), ...
                                         height(dados_dsc.dados), ...
                                         sprintf('Massa: %.2f mg', dados_dsc.metadados.massa_amostra)};
                end
                
                % Verificar Solubilidade
                if isfield(dados_importados.solubilidade, amostra_nome)
                    dados_solub = dados_importados.solubilidade.(amostra_nome);
                    dados_tabela{end+1} = {amostra_atual, 'Solubilidade', edit_file_solub.Value, ...
                                         'Importado', datestr(now, 'dd/mm/yyyy HH:MM'), ...
                                         height(dados_solub.dados), ...
                                         sprintf('Solvente: %s', dados_solub.metadados.solvente_principal)};
                end
            end
            
         
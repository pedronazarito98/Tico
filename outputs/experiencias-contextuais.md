# Experiências contextuais do Tico

## Fazer com conteúdo

Abra **Atalhos → Fazer com conteúdo**, o menu de status ou o rodapé do painel
contextual. Escolha Texto, Link ou Arquivos. O catálogo mostra as regras habilitadas
compatíveis com o contexto e com a entrada. “Criar ação de conteúdo” abre o criador
com a ação preparada; o acionamento ainda precisa ser escolhido e o salvamento é explícito.

No editor da ação, escolha a origem **Conteúdo do painel** ou **Texto selecionado**
e o destino **Pesquisa** ou **Atalho do macOS**. Pesquisas usam um endereço HTTPS e
um parâmetro de query; a entrada é codificada como dado. O Atalho do macOS deve
existir com o nome configurado. O Tico não trata a entrada como shell ou AppleScript.

Para seleção, escolha entre fixar o texto no início da sequência e consultá-lo
na própria etapa. Acessibilidade precisa estar concedida e o aplicativo precisa
expor uma seleção de texto não protegida. Não há simulação de copiar nem leitura
automática do clipboard. Ao usar o painel, o aplicativo de origem é fixado; trocar
o foco impede uma captura ambígua. Etapas que enviam teclas são recusadas nesse
painel para não atingir o campo de entrada.

Texto tem limite de 64 KB; links e termos de pesquisa, 8 KB. Até 20 arquivos
regulares de 100 MB cada podem ser enviados ao app Atalhos. Diretórios e links
simbólicos são recusados pelo executor. O conteúdo é removido ao concluir,
limpar, cancelar, fechar ou após cinco minutos sem uso. Uma transferência ao app
Atalhos usa arquivos temporários privados durante a execução, com limpeza ao
encerrar o processo. Conteúdo não integra a configuração salva ou os relatórios.
Ações já entregues a um aplicativo externo não são desfeitas pelo cancelamento.

## Aprender durante o uso

No **Mapa**, selecione **Aprender** em um atalho habilitado. Há somente um objetivo
ativo: cinco execuções reais bem-sucedidas concluem o aprendizado. Prática e replay
não contam. Depois de usar a ação pelo painel contextual, uma dica pode lembrar o
acionamento; o intervalo inicial é de vinte minutos e cresce com o progresso.

É possível praticar, adiar por um dia, dispensar a dica, marcar como aprendido,
reiniciar ou desligar lembretes. Editar, pausar ou excluir o atalho invalida o
objetivo ativo para que o Tico não ensine uma configuração antiga. O armazenamento
local contém identificadores, revisão, datas e contagens agregadas.

Gestos contínuos contam após uma atualização bem-sucedida e a conclusão da sessão.
Uma regra que mistura gesto contínuo com outras etapas ou layout não pode iniciar
um objetivo: o fluxo contínuo atual executa somente a ação contínua.

## Cenas e recuperação

Em **Cenas → Nova cena**, adicione ações e, opcionalmente, capture a disposição
atual. Ajuste quais janelas fazem parte dela, posição, tamanho e monitor de destino.
O layout usa proporções da área útil e papéis de tela — principal, interna ou
externa — sem persistir identificadores físicos. O fallback para a tela principal
precisa ser escolhido explicitamente.

A execução prepara os aplicativos e ações da sequência e depois revisa as janelas
atuais antes de aplicar o layout. Na revisão **Agora / Depois**, resolva ambiguidades
e identifique uma janela por **Mostrar no aplicativo**. O prazo da sequência também
cobre a revisão; se expirar ou for cancelada, o layout não é aplicado. Ações anteriores
já concluídas permanecem executadas e aparecem no relatório.

A recuperação guarda referências exatas apenas em memória. Ela continua disponível
se a aplicação falhar parcialmente ou a cena for excluída. Antes de outra aplicação,
restaure ou descarte explicitamente a recuperação. Janelas fechadas, processos
reiniciados, telas indisponíveis e alterações manuais posteriores são tratados como
pendências; o Tico não tenta adivinhar substitutas. Encerrar o Tico descarta essa
recuperação, sem mover as janelas.

Limites: até 20 janelas padrão redimensionáveis e quatro monitores externos.
Aplicativos podem impor tamanhos mínimos ou recusar controle por Acessibilidade.
Não há restauração de abas, documentos, Spaces ou aplicativos encerrados.
A condição “Única janela” é conferida na preparação e novamente antes da aplicação.
As consultas e escritas de Acessibilidade não são uma transação atômica do macOS.

## Rotinas de telas

Na mesma página **Cenas**, habilite rotinas e crie uma ligação entre uma mudança
de telas e uma cena salva. Escolha conexão, desconexão ou reorganização e a condição
de telas. O padrão é oferecer uma sugestão. Se várias rotinas coincidirem, o Tico
pede a escolha de uma delas.

O modo automático exige configuração explícita e ações elegíveis. Scripts,
conteúdo contextual e layouts com escolha manual de janela continuam exigindo
interação. A topologia precisa estabilizar por 2,5 segundos; ofertas repetidas
respeitam intervalo de 30 segundos, e sugestões expiram após dois minutos.
Inicialização, desbloqueio e retomada após sleep estabelecem uma nova referência
sem executar retroativamente uma mudança. Gravação, prática, replay e pausa
explícita suspendem as rotinas.
Bloqueio, repouso, nova mudança de telas ou alteração da configuração invalidam
também a rotina em andamento. Seu cancelamento impede as próximas etapas; ações
já concluídas e a recuperação de janelas permanecem preservadas.

## Persistência e validação

O documento principal passa à versão 7 e aceita formatos anteriores pelo codec
existente. Aprendizado e rotinas usam arquivos próprios no mesmo diretório de dados,
com escrita atômica e validação; eles não são incluídos na exportação de atalhos.
Um arquivo inválido gera erro sem sobrescrever silenciosamente o original.

A sessão `--ui-testing` mantém dados isolados e não executa ações reais, captura
seleção ou movimenta janelas. Build e suítes automatizadas não comprovam TCC,
trackpad, apps de terceiros, monitores físicos, VoiceOver ou sleep/wake. Consulte
[a evidência da integração](../.specs/features/contextual-experiences/validation.md)
para distinguir verificações executadas e cenários ainda manuais.

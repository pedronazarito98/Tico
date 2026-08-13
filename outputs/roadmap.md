# Roadmap do Tico

## O que já está pronto

- Captura global de teclado, mouse e trackpad com fallback público.
- Motor de sessões, replay, calibração e diagnóstico de gestos.
- Tap, hold, TipTap, swipes, pinça, rotação, acordes e sequências.
- Gestos personalizados treinados localmente.
- Regras por aplicativo, perfis, prioridades e análise de conflitos.
- Workflows, automações locais, ações de aplicativos e janelas.
- Métricas locais, importação segura e persistência versionada.
- Identidade Tico aplicada ao produto, executável, dados e permissões técnicas.
- Gate local de build, testes, segurança e empacotamento ad hoc.
- Documentação para publicação como preview técnico open source.

## Atualizações concluídas

1. **Licença MIT:** adicionada em [`LICENSE`](../LICENSE). O código pode ser
   reutilizado nos termos dessa licença.
2. **Validação interna:** concluída manualmente no trackpad interno. Não há
   gate separado de relatório: build, testes, regressões de segurança, replay
   e pacote ad hoc são verificados automaticamente pelo CI. O relatório
   sanitizado permanece opcional para diagnosticar regressões físicas.
3. **CI remoto:** confirmado no commit de consolidação `87f65ef`. A execução
   de push [#30209304727](https://github.com/pedronazarito98/Tico/actions/runs/30209304727)
   concluiu com sucesso no workflow `macOS verification`.

## O que fica para depois

1. **Validar hardware externo:** Magic Trackpad permanece sem garantia até
   existir um dispositivo para executar a matriz.
2. **Preparar uma release binária assinada:** somente quando fizer sentido
   pagar pelo Apple Developer Program, instalar Developer ID, notarizar,
   validar o ticket, passar pelo Gatekeeper e testar o mesmo artefato em um
   Mac ou usuário limpo.

## Backlog não bloqueante

Estes itens apareceram em planos antigos, mas não fazem parte do produto atual:

- desfazer parcialmente um workflow após falha;
- controlar volume e brilho com ações contínuas;
- oferecer uma grade de janelas totalmente configurável;
- exportar seletivamente pacotes de presets;
- criar um assistente após atualizações do macOS;
- investigar supressão segura de eventos de teclado e mouse.

A supressão de gestos do trackpad não é prometida: a captura atual é
observacional.

## Critério de evolução

O código pode continuar público como **preview técnico open source**. A
distribuição recomendada neste estágio é build local a partir do repositório.
Uma release binária para usuários só deve ser chamada de pronta depois dos
gates de Developer ID, notarização, Gatekeeper e máquina limpa.

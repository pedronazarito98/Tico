# Changelog

## Unreleased — technical preview open source

Baseline desta iniciativa: `27e0650`. Consolidação integrada em `87f65ef`.

### Incluído

- identidade pública Tico com ícone, wordmark, menu bar e compatibilidade
  preservada para executável, bundle identifier, dados e permissões do
  Tico;
- gate macOS compartilhado para build, 111 testes Swift, 8 regressões de
  segurança e verificação do package ad hoc;
- licença MIT adicionada e CI remoto confirmado no commit de consolidação;
- documentação pública de status, segurança, captura privada, fallback
  público e replay isolado;
- pacote sanitizado para evidência física e validador de relatório;
- preflight que extrai o ZIP em diretório temporário e executa
  `codesign --verify --deep --strict`;
- templates e checklists de evidência para uma futura distribuição Developer
  ID.

### Estado verificado

- Build/test/package local: PASS.
- Replay 0.5×, 1× e 2× sem execução de ações: PASS automatizado.
- Trackpad interno: validação manual concluída pelo responsável pelo produto;
  o relatório sanitizado é opcional.
- Magic Trackpad e reconexão de hardware externo: NOT-RUN por falta de
  dispositivo.
- Pressão/Force Touch: suporte condicional à capacidade observada no hardware.
- Assinatura do ZIP local: ad hoc/development.
- Developer ID, Hardened Runtime de distribuição, notarização, staple,
  Gatekeeper e máquina limpa: BLOCKED/NOT-RUN.
- Licença open source: MIT.

### Limitações

- A captura avançada usa o framework privado `MultitouchSupport` e deve ser
  revalidada por versão do macOS e classe de dispositivo.
- O fallback público tem capacidades diferentes da captura privada.
- O ZIP ad hoc é apenas um dry-run local e não deve ser distribuído como
  release para usuários.
- A publicação do código como technical preview open source não representa
  suporte físico nem aprovação de distribuição binária.

### Como verificar

```bash
./script/ci_verify.sh --package
./script/release_preflight.sh dist/Tico.zip
./script/validate_hardware_report.sh outputs/hardware-validation/report-AAAA-MM-DD.md
```

Consulte `outputs/roadmap.md` para o estado atual e `outputs/distribuicao.md`
para a estratégia de preview atual e os gates de uma release binária futura.

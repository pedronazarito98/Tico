# Distribuição do Tico

## Estado atual

O projeto está no modo **preview técnico open source**. A distribuição
recomendada neste estágio é publicar o código e orientar pessoas técnicas a
buildarem localmente.

O projeto gera `dist/Tico.app`, `dist/Tico.zip` e `dist/Tico.dmg`. Sem uma
identidade Developer ID configurada, o app recebe assinatura ad hoc e os dois
arquivos de distribuição servem somente para desenvolvimento e QA local. O
DMG facilita a instalação por arrastar para Aplicativos, mas não remove os
alertas do Gatekeeper nem equivale a notarização.

A assinatura ad hoc usa a identidade padrão específica do build. Isso evita
que outro binário ad hoc seja tratado como o Tico apenas por declarar o mesmo
bundle identifier, mas pode fazer o macOS solicitar novamente permissões após
uma recompilação. Continuidade de TCC no desenvolvimento exige uma identidade
local estável configurada explicitamente em `TICO_CODESIGN_IDENTITY`.

Se no futuro houver uma release binária pública, o caminho previsto continua
sendo distribuição direta fora da Mac App Store, porque a captura avançada usa
um framework privado da Apple.

## O que já está automatizado

- build otimizado com `./script/build_and_run.sh --release-package`;
- versão e build centralizados em `version.env` e conferidos pelo gate;
- geração reutilizável do DMG por `script/create_dmg.sh`;
- geração do ZIP e do DMG com verificação estrutural, de versão e de assinatura;
- Hardened Runtime e timestamp quando uma identidade real é informada;
- notarização e stapling do app, recriação dos containers e notarização separada
  do DMG final em `script/notarize_release.sh`;
- verificação local do ZIP ou DMG com `script/release_preflight.sh`.

## Se houver release binária pública

Estes passos dependem do proprietário e podem ser adiados enquanto o projeto
for publicado apenas como código aberto:

1. Participar do Apple Developer Program.
2. Instalar um certificado **Developer ID Application** no Keychain.
3. Criar um perfil do `notarytool` no Keychain.
4. Atualizar `MARKETING_VERSION` e incrementar `BUILD_NUMBER` em `version.env`.
5. Gerar e assinar o release candidate com a identidade real.
6. Notarizar e aplicar o ticket ao app, recriar ZIP e DMG a partir desse app,
   assinar/notarizar o DMG e validar o ticket do container final.
7. Confirmar `spctl` como aceito e abrir o mesmo artefato em ambiente limpo.

Certificados, senhas, perfis e logs sensíveis nunca devem entrar no
repositório.

## Comandos para uma release futura

```sh
export TICO_CODESIGN_IDENTITY="Developer ID Application: NOME (TEAMID)"
./script/build_and_run.sh --release-package

export TICO_NOTARYTOOL_PROFILE="TicoNotary"
./script/notarize_release.sh
```

Depois:

```sh
codesign --verify --deep --strict --verbose=2 dist/Tico.app
xcrun stapler validate dist/Tico.app
xcrun stapler validate dist/Tico.dmg
spctl -a -vv --type execute dist/Tico.app
spctl -a -vv --type open --context context:primary-signature dist/Tico.dmg
```

Uma assinatura ad hoc aprovada por `codesign` não substitui Developer ID,
notarização, Gatekeeper ou teste em máquina limpa.

O script de notarização exige artefatos já assinados com Developer ID. Ele não
procura certificados nem cria credenciais; usa o perfil do Keychain informado
explicitamente em `TICO_NOTARYTOOL_PROFILE`.

## Comandos para o preview atual

```sh
./script/build_and_run.sh
./script/ci_verify.sh --package
```

O pacote ad hoc pode ser inspecionado com:

```sh
./script/release_preflight.sh dist/Tico.zip
./script/release_preflight.sh dist/Tico.dmg
```

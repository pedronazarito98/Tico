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

Se no futuro houver uma release binária pública, o caminho previsto continua
sendo distribuição direta fora da Mac App Store, porque a captura avançada usa
um framework privado da Apple.

## O que já está automatizado

- build otimizado com `./script/build_and_run.sh --release-package`;
- geração do ZIP e do DMG com verificação estrutural e de assinatura;
- Hardened Runtime e timestamp quando uma identidade real é informada;
- envio, espera, stapling e validações em `script/notarize_release.sh`;
- verificação local do ZIP ou DMG com `script/release_preflight.sh`.

## Se houver release binária pública

Estes passos dependem do proprietário e podem ser adiados enquanto o projeto
for publicado apenas como código aberto:

1. Participar do Apple Developer Program.
2. Instalar um certificado **Developer ID Application** no Keychain.
3. Criar um perfil do `notarytool` no Keychain.
4. Gerar e assinar o release candidate com a identidade real.
5. Notarizar, aplicar e validar o ticket.
6. Confirmar `spctl` como aceito e abrir o mesmo artefato em ambiente limpo.

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
spctl -a -vv --type execute dist/Tico.app
```

Uma assinatura ad hoc aprovada por `codesign` não substitui Developer ID,
notarização, Gatekeeper ou teste em máquina limpa.

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

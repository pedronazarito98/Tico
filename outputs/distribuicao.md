# Distribuição do Tico

## Estado atual

O projeto está no modo **preview técnico open source**. A [release 0.1.0
(build 2)](https://github.com/pedronazarito98/Tico/releases/tag/v0.1.0-preview.2)
oferece um DMG assinado e notarizado para macOS 26 ou posterior. A abertura
desse pacote em outro Mac permanece pendente de validação.

O projeto gera `dist/Tico.app`, `dist/Tico.zip` e `dist/Tico.dmg` assinados com
o Developer ID de Pedro. O DMG facilita a instalação por arrastar para
Aplicativos. A assinatura, por si só, não equivale a notarização.

O scheme compartilhado `Tico` também suporta Run, Profile e Archive no Xcode.
Seu target `TicoApp` reaproveita o package local e gera o mesmo produto público
`Tico.app`. Archive organiza o fluxo de entrega no Xcode, mas não fornece
automaticamente certificado, Team, Developer ID ou notarização; esses gates
continuam obrigatórios para distribuição pública.

Os builds usam uma identidade de assinatura estável. A continuidade de
permissões TCC precisa ser verificada no Mac em uso.

## Assinatura local estável

Os scripts e o Xcode usam o Developer ID Application de Pedro; a chave privada
precisa estar disponível no ambiente de build e não deve entrar no repositório.
O gate de pacote também requer essa identidade. A execução pelo script usa o
caminho estável `dist/.run/Tico.app`; o Xcode mantém seu próprio local de build.

A assinatura estável permite ao macOS reconhecer versões relacionadas, mas não
garante a preservação das permissões em todos os cenários. Ao trocar de
identidade, pode ser necessário concedê-las novamente. A
notarização é separada e não é necessária para testar localmente essa continuidade.

A distribuição é direta, fora da Mac App Store; a captura avançada usa um
framework privado da Apple.

## O que já está automatizado

- build otimizado com `./script/build_and_run.sh --release-package`;
- build e inspeção do App Target Xcode com `./script/verify_xcode_app.sh`;
- versão e build centralizados em `version.env` e conferidos pelo gate;
- geração reutilizável do DMG por `script/create_dmg.sh`;
- geração do ZIP e do DMG com verificação estrutural, de versão e de assinatura;
- Hardened Runtime e timestamp quando uma identidade real é informada;
- notarização e stapling do app, recriação dos containers e notarização separada
  do DMG final em `script/notarize_release.sh`;
- verificação local do ZIP ou DMG com `script/release_preflight.sh`.

## Para uma nova release binária

Estes passos dependem do proprietário da assinatura:

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

Uma assinatura aprovada por `codesign` não substitui notarização, Gatekeeper ou
teste em máquina limpa.

O script de notarização exige artefatos já assinados com Developer ID. Ele não
procura certificados nem cria credenciais; usa o perfil do Keychain informado
explicitamente em `TICO_NOTARYTOOL_PROFILE`.

## Comandos para o preview atual

```sh
./script/build_and_run.sh
./script/ci_verify.sh --package
```

O pacote assinado pode ser inspecionado com:

```sh
./script/release_preflight.sh dist/Tico.zip
./script/release_preflight.sh dist/Tico.dmg
```

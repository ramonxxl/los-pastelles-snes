# Los Pastelles: O Império do Pastel — ROM de Super Nintendo

Desenvolvido por **Ramon de Oliveira** — loja: [www.lospastelles.com.br](https://www.lospastelles.com.br)

**`LosPastelles.sfc`** é uma ROM real de SNES (LoROM, 1 MB, 2 KB de SRAM com bateria), com vozes e música gravadas.
Funciona em emuladores (Mesen, bsnes, Snes9x) e em cartucho flash (EverDrive, FXPAK etc.).

## Como jogar
1. Abra `LosPastelles.sfc` num emulador (há um Mesen em `tools/mesen/Mesen.exe`).
2. **Cruz**: move o cursor · **A**: fritar / tirar do óleo / entregar · **B**: jogar fora o pastel da mão · **X**: pegar refrigerante (nível 7+) · **START**: pausa.
3. Na mesa, escolha o sabor e aperte A, depois repita os botões que aparecem no topo (cruz direcional e A vermelho, B amarelo, X azul, Y verde; ✓ = acertado; barra embaixo = tempo) para **fechar o pastel** (errou ou demorou, o pastel abre).
4. Tire com A quando a barra ficar **verde** (ponto perfeito). Cru ou queimado o cliente reclama.
5. O cursor vai sozinho até quem pediu aquele sabor: aperte A. Balão com latinha = **combo**: pegue o refri (X) antes de entregar (+R$ 7).
6. No fim do dia: resultado (vendas, gorjetas, aluguel, salários, lucro). Depois, a loja:
   ingredientes, fritadeira, balcão, promoção, atendente, publicidade, novas lojas, franquias e mapa.
   "Abrir a loja" salva o jogo e começa o próximo dia; "Voltar ao menu" salva e volta à tela inicial (CONTINUAR retoma de onde parou).

## Conteúdo
- Tela de título com a logo oficial e cores da marca no jogo todo; mascote (pastelzinho piscando) nas cartas, na loja e comemorando cada pastel perfeito.
- Abertura na rua à noite (o letreiro acende).
- Tutorial guiado no dia 1: a cada passo (cliente chegou, fechar o pastel, fritadeira, ponto certo, entregar) o jogo para e mostra o que fazer; **A** continua.
- Minijogo de fechar o pastel (2 a 4 botões conforme o nível) e combos com refrigerante.
- Cestos da fritadeira podem quebrar: aperte A no cesto com X e repita 5 botões para consertar.
- "+R$" flutuando a cada venda, óleo animado, barra de paciência piscando no vermelho.
- Preço do pastel ajustável na loja (-R$1 até +R$2) e gráfico de lucro dos últimos 7 dias no fim do dia.
- Opções: dificuldade (Fácil/Normal/Difícil), música e falas (liga/desliga as vozes gravadas); escolha do bairro onde trabalhar (5 cenários).
- Demonstração: com o título parado 30 s, a CPU joga um expediente num estágio sorteado (qualquer botão volta ao menu).
- Sabores e ícones do expediente com emojis (Twemoji): carne, queijo, frango, bacon, cadeado, coração, moeda, estrela, telefone, computador, moto e efeitos.
- Menus modernos: título com a logo sobre o xadrez animado e um cartão com o menu, ícones emoji em cada item, pílula no item escolhido e botões coloridos do controle nas dicas.
- Eventos: feira, concorrente, chuva e jogo do Brasil na TV.
- Pedido duplo (nível 4+): balão com "2" = entregue dois pastéis.
- Duelo semanal com o Concorrente (dias 7, 14, 21...): bata a meta de clientes satisfeitos e ganhe R$ 100.
- 3 jogos salvos (NOVO JOGO / CONTINUAR abrem a escolha do espaço).
- Tipos de cliente: criança (boné, tem pressa e paga meia), idoso (óculos, espera mais e dá gorjeta boa) e turista (chapéu de palha, pede o mais caro e paga R$ 3 a mais).
- 16 troféus salvos no cartucho (loja: VER TROFÉUS).
- Reforma do salão em 2 etapas (vitrine com pastéis no balcão; depois loja premium com bandeirinhas, flores e letreiro dourado) e novos itens: freezer, ar-condicionado, música ambiente e uniforme. A lista da loja rola (setas ↑↓).
- Entregas (nível 6+): o telefone toca, aperte **Y** para anotar a comanda; com o pastel na mão, **Y** de novo para pôr no saco do motoboy (pastel + taxa de R$ 4). Na loja: **Computador (app)** no nível 13 (pedidos entram sozinhos, alguns com 2-3 pastéis) e **Motoboy extra** (prazo maior e taxa de R$ 6).
- Animações: bolhas no óleo, moeda voando até o caixa, Fundador comemorando e clientes andando.
- 6 sabores (carne, queijo, frango + calabresa, catupiry, bacon desbloqueáveis).
- Personagens: Fundador, Mestre da Massa, Gerente, Concorrente e Cliente Misterioso.
- 5 capítulos e 4 desafios: Hora do Almoço, Desafio do Sabor, Cozinha em Crise, Expansão Nacional.
- 15 missões, níveis/XP, reputação, eventos (feira, promoção do concorrente).
- Mapa da expansão; final ao chegar a 10 unidades (lojas + franquias).
- Música-tema gravada na tela de título (com a narração "Los Pastelles, o império do pastel") e durante o expediente; música chiptune nas outras telas (abertura, resultado, vitória, derrota) e efeitos sonoros.
- Vozes gravadas: o pastel fechou, abriu, cru, queimou, "olha o pastel!", "top demais", sabor errado, combo com refri, cliente desistindo, telefone, cesto quebrado, "bom dia, freguesia!", "por hoje é só", missão cumprida, troféu, desafio, vitória, derrota e o final. Chiado da fritura gravado.

## Recompilar
Requer Node.js e Python com Pillow. `node build.js` gera a arte, a fonte, os textos, a música e
monta a ROM com o cc65 (em `tools/cc65`).
- `gerador/` — arte em pixel art (código), fonte, textos, músicas, conversão da logo.
- `src/` — código 65816 (`main.s`, `game.s`, `telas.s`, `audio.s`).
- `teste/` — robô em Lua que joga sozinho num Mesen de testes separado (`teste/mesen/Mesen.exe --testrunner LosPastelles.sfc teste/bot.lua`), sem mexer nos seus saves.

## Gravar no cartucho
- **Arquivo:** `LosPastelles.sfc` — 1 MB (8 Mbit), mapa **LoROM**, cabeçalho e checksum válidos, região NTSC.
- **Placa:** LoROM **com SRAM e bateria** (o jogo usa 2 KB; placas com 8 KB de SRAM também servem). Sem SRAM o jogo roda, mas não salva.
- **Memória:** ROM/flash de pelo menos 8 Mbit; não precisa de memória rápida (funciona como SlowROM).
- **Teste antes:** se possível rode primeiro num flashcart (FXPAK/EverDrive) ou numa flash regravável.
- **Etiqueta e manual:** pasta `cartucho/` — `etiqueta_formato_classico.png` (mesmo formato e proporção do modelo de etiqueta frontal), `etiqueta_frente_70x50mm_600dpi.png` (alternativa) e o manual em PDF (A5, 6 páginas). Imprima a etiqueta na medida do modelo do seu cartucho. Para regerar: `python gerador/cartucho.py`.

## Qualidade
- 60 quadros por segundo sem lentidão (medido no emulador com o máximo de clientes e cestos).
- Testado com memória aleatória ao ligar, como num console real.

## Segredos (não estão no manual)
- **Menu secreto:** na tela de título, aperte ↑ ↑ ↓ ↓ ← → ← → B A. Escolha um jogo salvo e use: +R$ 1.000, +1 nível, estoque cheio, liberar tudo e Pastel de Vento (frita sem gastar estoque). O jogo salvo fica marcado como ★FESTA e não ganha mais troféus.
- **Mascote dançando:** aperte SELECT 10 vezes na abertura "LOS PASTELLES APRESENTA".
- No final do jogo, depois dos créditos, aparece uma dica sobre o código.

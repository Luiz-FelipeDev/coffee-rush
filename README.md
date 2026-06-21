# Coffee Rush

O projeto é um protótipo de FPS centrado em movimentação avançada e controle de momento físico. O núcleo da jogabilidade envolve navegar por um ambiente gerado proceduralmente utilizando habilidades de parkour e um gancho mecânico. O objetivo principal é coletar itens de café pelo cenário que ativam um estado de câmera lenta, mecânica essencial para permitir que o jogador sobreviva a ondas massivas de inimigos.

## 1. Estrutura de Diretórios

A arquitetura do projeto foi dividida para isolar os dados da lógica de estado, facilitando a escalabilidade.

* `world/`: Contém os scripts de gerenciamento global. O `game_manager.gd` orquestra a cena e o `island_generator.gd` constrói a malha do terreno. Os arquivos de configuração de bioma também ficam nesta pasta.
* `nature/`: Diretório de modelos 3D brutos e cenas pré configuradas com colisão, abrigando a flora, minérios e as plataformas flutuantes.
* `player/`: Estrutura do controlador em primeira pessoa. O nó principal processa a física terrestre e a entrada do usuário. O gancho possui seu próprio script de cálculo vetorial. Sensores espaciais de parede e a câmera operam em nós independentes para garantir que os cálculos direcionais sejam precisos, ignorando animações locais do modelo.

## 2. Como Testar Novos Níveis

A parte visual da ilha é modular e estruturada em Custom Resources da Godot. Isso permite alterar o clima e a flora da fase inteira sem manipular código.

1. No painel FileSystem, abra a pasta `world/biomes/`. Lá estão os arquivos de dados com a extensão `.tres`.
2. Na árvore da cena principal, selecione o nó `GameManager`.
3. Olhe para o painel Inspector à direita. Na seção Biome Configuration, há o campo `Current Biome`.
4. Clique e arraste um arquivo do FileSystem (como o `biome_lava.tres`) diretamente para esse campo vazio no Inspector.
5. Ao executar o projeto, o script lerá esse arquivo e injetará as novas cores no shader de terreno, modificará a iluminação do céu e carregará os modelos específicos de árvore daquele ecossistema.

## 3. Geração de Mundo Procedural

O mapa de colisão e o cenário são construídos matematicamente na memória durante a inicialização. 

* **Terreno e Ruído:** A topografia é definida pela subdivisão de um plano primitivo afetado por um algoritmo FastNoiseLite operando em modo Simplex. Uma fórmula de atenuação circular é sobreposta aos vértices para forçar as bordas da malha a descerem até a coordenada da água, garantindo o formato de ilha.
* **Instanciamento Seguro:** As árvores e pedras de superfície são espalhadas via raycasting disparado do limite superior do mapa. O algoritmo possui um sistema de registro espacial que salva a coordenada de cada objeto instanciado. Antes de plantar um novo modelo, ele calcula a distância bidimensional; caso o raio colida muito próximo de uma árvore existente, a coordenada é descartada, prevenindo a sobreposição de malhas.
* **Agrupamentos Flutuantes:** Os blocos para parkour aéreo não seguem a área terrestre plana. A rotina gera clusters utilizando coordenadas polares ancoradas no centro da ilha (raio máximo e ângulo). Isso confina as plataformas de pulo em torno do pico da montanha central.

## 4. Próximas Etapas e Core Loop

O controlador base e o algoritmo geográfico estão estruturados. As tarefas seguintes documentam os requisitos para estabelecer a malha principal de jogabilidade.

* Polir as variáveis de atrito e inércia da movimentação, além de confirmar a viabilidade técnica do salto duplo no design vertical do mapa.
* Desenvolver a mecânica de tiro. É necessário incorporar a malha do blaster (referência Kenney) no HUD do jogador. O modelo precisará de dois canos: um operando como emissor contínuo de projéteis básicos e o outro servindo como o novo nó de ancoragem visual para a corda do gancho.
* Criar a rotina de instanciamento para inimigos. A densidade de oponentes deve ser elevada para criar pressão mecânica contínua.
* Configurar o sistema de saúde do jogador no GameManager. A integridade estrutural deve ser limitada para punir aproximações estáticas e favorecer a mobilidade.
* Distribuir os consumíveis pelo mapa. O jogador precisará localizar o café (que pode utilizar sprites em billboard para otimização). 
* Atrelar a coleta do café à manipulação da escala de tempo da engine, ativando a câmera lenta vitalícia para lidar com o combate de alta velocidade. A arquitetura futura poderá suportar múltiplos grãos com modificadores de status diferentes.

## 5. Histórico de Versões (Changelog)

O projeto segue o padrão de Versionamento Semântico (SemVer). 

---

### [1.2.0]

**Features**
* Adição da randomização do bioma ao iniciar uma partida: Existem 5 biomas possíveis e, a cada novo jogo, um deles será escolhido.

### [1.1.0]

**Features**
* Adição de um novo tipo de inimigo (`EnemyAstronaut`), reutilizando a IA e estrutura de cena já existentes.
* Refatoração do sistema de spawn de inimigos em `game_manager.gd`: substituição do campo único `enemy_scene` por `enemy_scenes: Array[PackedScene]`, permitindo múltiplos tipos de inimigo sorteados aleatoriamente a cada spawn.

**Fixes**
* Substituição de raycasts verticais redundantes pelo sistema nativo de colisão da Godot para otimização de performance.
* Aplicação do parâmetro `floor_snap_length` para estabilizar o movimento de entidades em declives acentuados no terreno procedural.
* Descomentada a função de spawn das rochas no céu.

---

### [1.0.0]

**Features**
* Estruturação da arquitetura base do projeto e diretórios (`world/`, `nature/`, `player/`).
* Geração procedural de terreno utilizando `FastNoiseLite`.
* Instanciamento seguro de objetos (flora e pedras) via raycasting e registro espacial.
* Criação do controlador em primeira pessoa com física de parkour aéreo e gancho.
* Implementação do sistema de física nativa para a movimentação dos inimigos utilizando `CharacterBody3D`.
* Adição da rotina de inteligência artificial básica para detecção e perseguição do jogador.
* Integração de lógica de alteração de cores dinâmicas nos materiais dos modelos inimigos instanciados.

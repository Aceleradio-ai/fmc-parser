**TeltonikaTcpParserServer**
**Objetivo**
O objetivo deste projeto é desenvolver um servidor TCP capaz de analisar (parsing) dados de qualquer dispositivo Teltonika. O servidor aceita conexões, recebe dados e os processa conforme as especificações do dispositivo.

**Pré-requisitos**
Antes de iniciar, certifique-se de que um dispositivo FMC003 esteja configurado e operando corretamente. É necessário:

* Firmware atualizado no FMC003 (versão mínima recomendada: 6.150).
* Configuração de APN válida para comunicação GPRS/3G/4G.
* Endereço IP do servidor e porta (por exemplo, `IP_DO_SERVIDOR:2202`) configurados no FMC003.
* Modo de envio TCP habilitado no perfil de célula do FMC003.
* Conectividade de rede (GPRS/3G/4G) verificada e estável.
* IMEI do FMC003 anotado para mapeamento e identificação no servidor.

**Funcionalidades**

* **Análise de IMEI**: identifica o dispositivo com base no IMEI.
* **Extração e Processamento de Campos de Dados**:

  * **Preamble**: sincroniza os dados recebidos.
  * **Data Size**: determina o tamanho dos dados subsequentes.
  * **Codec ID**: identifica o tipo de dado codificado.
  * **Number of Data**: conta o número de conjuntos de dados presentes.
  * **CRC16**: verifica a integridade dos dados.
  * **Timestamp**: extrai o momento em que os dados foram gerados.
  * **Priority**: determina a prioridade dos dados.
  * **GPS Element**: analisa informações de localização como latitude, longitude, altitude, velocidade e ângulo.
  * **IO Elements**: processa elementos de entrada/saída com base em mapeamentos predefinidos.
* Código modular e extensível.

**Instalação**

1. Clone o repositório:

   ```bash
   git clone https://github.com/Aceleradio-ai/fmc-parser.git
   cd fmc-parser
   ```
2. Instale o Zig (caso ainda não tenha): siga as instruções no site oficial do Zig.

**Como Executar**
Para iniciar o servidor, utilize:

```bash
zig build run
```

O servidor iniciará e ficará escutando na porta **2202**.

**Estrutura do Projeto**

* `src/main.zig`: arquivo principal que inicializa e executa o servidor TCP.
* `src/server.zig`: implementação do servidor TCP.
* `src/parser.zig`: módulo principal que importa diversas funções de parsing.
* `src/teltonika/imei_handler.zig`: trata e analisa o IMEI.
* `src/teltonika/validate_checksum.zig`: valida o checksum dos pacotes recebidos.
* `src/teltonika/parser/`: diretório com funções específicas de parsing:

  * `preamble.zig`: parsing do preâmbulo.
  * `data_field.zig`: parsing do tamanho dos dados.
  * `codec.zig`: parsing do Codec ID.
  * `number_data.zig`: parsing do número de conjuntos de dados.
  * `crc16.zig`: parsing e verificação do CRC16.
* `src/teltonika/parser/avl/`: funções relacionadas ao AVL (Automatic Vehicle Location):

  * `timestamp.zig`: parsing do timestamp.
  * `priority.zig`: parsing da prioridade.
  * `gps_element.zig`: parsing dos elementos de GPS.
* `src/teltonika/parser/io_elements/`: parsing de elementos de E/S:

  * `io_element.zig`: parsing de elementos de entrada/saída.
  * `mapping_io.zig`: mapeia IDs de eventos para propriedades.

**Uso**
Com o servidor em execução, ele aceitará conexões de dispositivos Teltonika e processará os dados recebidos. Os dados analisados serão exibidos no console para fins de depuração.

**Detalhamento das Funcionalidades**

* **Análise de IMEI**: o `imei_handler` analisa o IMEI dos dispositivos Teltonika, identificando a fonte dos dados.
* **Preamble**: o `parsePreamble` sincroniza os dados recebidos.
* **Data Size**: o `parseDataField` determina o tamanho dos dados seguintes.
* **Codec ID**: o `parseCodecId` identifica o tipo de codificação dos dados.
* **Number of Data**: o `parseNumberData` conta quantos conjuntos de dados existem.
* **CRC16**: o `parseCrc16` verifica a integridade dos dados.
* **Timestamp**: o `parseTimestamp` extrai quando os dados foram gerados.
* **Priority**: o `parsePriority` define a importância dos dados.
* **GPS Element**: o `parseGpsElement` extrai informações de localização (latitude, longitude, altitude, velocidade, ângulo).
* **IO Elements**: o `parseIoElements` processa os elementos de E/S conforme os mapeamentos em `mapping_io.zig`.

**Contribuições**
Contribuições são bem-vindas! Sinta-se à vontade para abrir issues e pull requests.

**Licença**
Este projeto está licenciado sob a **MIT License**.

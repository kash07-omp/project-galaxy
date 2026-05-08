# Nexus: Downfall

MMORTS de navegador (sucesor espiritual de OGame) orientado a un desarrollo iterativo, testeable y escalable.

## Objetivo inmediato
Construir un **MVP funcional** que permita:

- Registro/inicio de sesión y entrada a un universo.
- Gestión básica de 1 planeta (edificios y producción de recursos).
- Creación y envío de flotas en una misión inicial (transporte/ataque simplificado).
- Notificaciones en tiempo real y base del bucle de progreso.

Consulta el plan de trabajo en `ROADMAP.md` y las directrices para agentes en `AGENTS.md`.

---

## Guía general de diseño y funcionalidad (fuente de verdad)

Este documento contiene la **definición general de Nexus: Downfall**. Si un agente de IA o desarrollador tiene dudas funcionales, de alcance o reglas del juego, debe acudir primero a este README.

> **Regla explícita:** en caso de duda sobre el diseño, revisar el **README.md** antes de implementar.

---

## INTRODUCCIÓN

Nexus: Downfall es un videojuego del género MMORTS basado en navegador y heredero espiritual de Ogame, enriqueciéndolo con gráficos modernos y mayor complejidad. Este sitúa a los jugadores en un universo amplio en el que podrán hacer prosperar su imperio, comerciar y luchar contra otros jugadores o npcs.

El equipo de Nexus: Downfall está concienciado en evitar prácticas “Pay-to-win”, por lo que la forma de monetización de juego no permitirá nunca que unos jugadores saquen ventajas abusivas por compras y microtransacciones. En otras palabras: No podrán ser comprados recursos, cartas, flotas o cualquier otro recurso, sino que estos deberán ser ganados mediante el propio juego.

Como es lógico el juego tendrá un sistema de monetización, pero esta estará basada en el pago por contenido extra (como DLCs o expansiones), sobres de cartas, skins del juego y ayudas para la gestión del juego (como pantallas con resúmenes y datos estadísticos), de forma que nunca haya una diferencia insondable entre jugadores que decidan pagar por contenido y aquellos que no lo hagan.

Nexus: Downfall es un videojuego Free-to-play.

### Objetivo del juego

En Nexus cada jugador toma el papel de líder de un grupo de supervivientes que deberán fundar una próspera colonia. Esta colonia prosperará mediante la construcción de edificios, la investigación de tecnología y la conquista de otros planetas hasta convertirse en un poderoso imperio galáctico. Eso hará que interactúen inevitablemente entre si los jugadores, aliándose, comerciando y luchando entre sí.

Inicialmente el jugador controlará un planeta de un sistema solar. El objetivo inmediato de todo nuevo jugador es hacer prosperar su planeta antes de poder lanzarse a la conquista del espacio y colonizar otros planetas.

### PvP, flotas y conquista

Llegado un punto el jugador se lanzará a la conquista del universo, lo que le hará enfrentarse a otros jugadores. Para ello deberá construir una flota. Usando su flota el jugador puede colonizar planetas que no estén controlados por otros jugadores o interferir en planetas bajo el control de otros jugadores, pudiendo saquearlos para robar recursos, bombardearlos para destruir sus estructuras o bloquearlo para evitar el movimiento de flotas. Además de eso el jugador podrá conquistar el planeta de otro jugador.

### Ser conquistado por otro jugador

En caso de que esto ocurra, el jugador conquistado deberá elegir otro planeta donde asentar a sus refugiados y volver a comenzar a edificar su imperio, pero no empezará de 0, sino que tendrá desbloqueadas todas las investigaciones que ya había investigado y contará con un paquete de ayuda. Este paquete de ayuda constará de recursos, tropas y cartas en función de los logros adquiridos en la partida. En caso de que el jugador no quiera volver a comenzar en ese servidor de juego, ganará puntos que se asignarán a su cuenta para su uso en otros universos.

### Distintos servidores de juego

Nexus: Downfall contará con distintos servidores de juego que irán siendo abiertos al público conforme aumente la demanda de servidores. Aunque inicialmente los servidores serán iguales, se planea en que en un futuro se abrirán servidores con modificadores que permitan a los jugadores una jugabilidad distinta. Algunos ejemplos de esto serían servidores acelerados en los que ganar recursos es más rápido o el tiempo de viaje de flotas menor, servidores con un mapa de juego más reducido (y por tanto para menos jugadores) o masivos. También serán abiertos en el futuro servidores especiales en los que esté activa una versión del juego con expansiones activas y contenido extra desbloqueado.

### Ganar o perder: El fin del universo

Cada universo de juego está destinado a acabar con la victoria de un jugador o grupo de jugadores. Para alcanzar esta victoria los jugadores deberán desencadenar una serie de eventos que conducirán al late-game del servidor. Cada universo tendrá un tiempo de vida determinado por las acciones de sus jugadores, pudiendo teorícamente alcanzarse un punto en el que un universo nunca llegue al late-game por decisión de los jugadores. El late-game del juego permanecerá oculto e indocumentado hasta que un jugador descubra como alcanzarlo y se finalice con éxito.

---

## Capítulo 2: MECÁNICAS Y JUGABILIDAD

> “La Tierra es la cuna de la humanidad, pero uno no puede vivir en la cuna para siempre.” — Konstantín Tsiolkovski

### MECÁNICAS DETALLADAS

A continuación expondremos todas las mecánicas de Nexus: Downfall, explicándolas de forma detallada.

### La división del espacio y el mapa del juego

Cada universo de juego se compone de un número determinado de galaxias, cada galaxia tiene a su vez varios sistemas solares y cada sistema solar un número variable de planetas y distintos elementos (como campos de asteroides). Dentro de cada planeta es donde se desarrollan las ciudades de los jugadores, pues cada ciudad ocupa una de las tres regiones disponibles en un planeta. Los universos están aislados entre si y actúan a modo de “servidor” de juego. Un jugador puede estar en múltiples universos entre si, pero no habrá interacción entre estos universos/servidores de juegos mas allá de que cada usuario tendrá una cuenta global de Nexus, con la que se registrará en los distintos universos disponibles.

### Las galaxias

En un universo promedio de Nexus: Downfall hay 10 galaxias. Cada galaxia se compone de un número variable de sistemas solares interconectados entre sí por hipervías. En el mapa de galaxia se pueden ver estos sistemas solares unidos entre sí.

### Sistemas solares

Dentro de ellos se desarrolla el núcleo de interacción entre jugadores. Cada galaxia puede tener entre 200 y 500 sistemas solares (según configuración del propio universo), y cada sistema solar puede estar conectado a un número variable de otros sistemas solares, teniendo en cuenta siempre un mínimo de una conexión y un máximo de cuatro.

Cada sistema solar está poblado por distintos elementos, como planetas o anillos de asteroides. Cada elemento ocupa un lugar en la órbita del sistema solar.

### Planetas

Cada planeta ocupa una posición en el sistema solar (siendo la posición 1 la más cercana a la estrella del sistema). En el planeta se desarrolla toda la actividad de microgestión de cada jugador. Es en estos planetas donde construyen edificios que les permiten generar recursos, investigar tecnologías o desbloquear funcionalidades. Cada planeta está gobernado por un gobernador que da ciertas ventajas y desventajas a ese planeta, además de poderse elegir leyes específicas para ese planeta. Es aquí donde se construyen flotas y donde viven los habitantes del imperio del jugador.

### Construcción de estructuras

Cuando un jugador coloniza o conquista un planeta puede construir en ella una serie de estructuras. Cada una de ellas tiene una función definida, un coste y un nivel. Además, hay ciertas estructuras que solo pueden ser construidas tras haber cumplido con unos requisitos específicos, los cuales pueden ser haber investigado una tecnología en particular o haber llegado a construir otra estructura a un nivel determinado.

En un planeta no hay límite de estructuras ni de nivel de estas. Cada estructura podrá tener una especialización, por ejemplo el área residencial puede tener la especialización “zona de ocio” que aumenta la felicidad a cambio de reducir el espacio habitable ganado por nivel. Para poder especializar una estructura se deberá haber investigado una tecnología particular, si por ejemplo una estructura tiene 3 especializaciones cada una de estas estará asociada a una tecnología.

### El ayuntamiento

Como centro de control y principal estructura del planeta, el centro de mando tiene por objetivo administrar el planeta. Gracias al ayuntamiento se pueden promulgar leyes en el planeta y asignar un gobernador. Todos los planetas comienzan con un centro de mando a nivel 1. Para asignar un gobernador en un planeta el ayuntamiento debe estar a nivel 2 y para promulgar leyes debe haberse subido el ayuntamiento a nivel 3 e investigado una tecnología llamada “Leyes planetarias”.

### Estructuras de recursos y soporte

- **Mina de materia prima**: recurso Materia Prima.
- **Fábrica de microchips**: recurso Microchips.
- **Mina de hidrógeno**: recurso Hidrógeno.
- **Generador de energía**: recurso Energía.
- **Reactor nuclear**: recurso Energía con mayor eficiencia.
- **Granjas de cultivo**: recurso Comida.
- **Área residencial**: espacio habitable para población.
- **Espaciopuerto**: ensamblaje de naves para flotas.
- **Centro de defensa**: construcción de defensas planetarias.
- **Laboratorio de investigación**: investigación tecnológica.
- **Fábrica de componentes**: producción activa de componentes mid-game.

### Investigar tecnologías

Después de la construcción de estructuras un jugador querrá investigar tecnologías, para ello usa los laboratorios de investigación. Cada laboratorio de investigación proporciona una serie de Puntos de Ciencia (PC) diarios en base a su nivel. Estos PC son usados para investigar tecnologías, pues cada tecnología tiene un coste en PC específico además de un tiempo necesario de investigación.

Las tecnologías se presentan al jugador en cuatro distintos árboles. Cada tecnología tendrá sus propios requisitos y puede que una tecnología de un árbol necesite que se haya investigado la tecnología de otro árbol para ser investigada. También pueden requerir cierto nivel de en una estructura particular. Los árboles tecnológicos son el de estructuras, el de flotas, el de defensa y el de leyes.

### Flotas y combate

Los jugadores pueden crear un número infinito de flotas, pero solo pueden estar activas (es decir, en una misión como pueda ser un ataque, saqueo, defensa de otro planeta, etc) un número determinado de flotas. El número de flotas que pueden estar en misión a la vez debe ser igual a 3 inicialmente. Este número aumentará de la siguiente forma:

- La estructura Espaciopuerto con mayor nivel de entre todas los planetas del jugador sumará su nivel al total de flotas.
- En el futuro se planea incrementar la cantidad de flotas gracias a investigación de tecnologías.

Para crear una flota el jugador podrá hacerlo desde la página de gestión de flota (`/Fleet`) usando para ello el botón “Nueva Flota”.
También podrá hacerlo dentro de la vista de un planeta (`/Planets/Detail/{Id}`), desde el modal del Espaciopuerto en la pestaña “Recruit”.

### Viajes de flota

Las flotas pueden ser enviadas de un planeta a otro en distintas misiones. Para ello la flota calculará la ruta más corta hasta el planeta de destino. Esta ruta se determina teniendo en cuenta que los sistemas solares están unidos por hipervías (Hyperlink), por lo tanto para ir de un sistema solar A a un sistema solar B se deberán recorrer X sistemas solares (algoritmo A*). Además de eso se agrega un cierto tiempo de viaje por despegar del planeta, por cada órbita del sistema de origen y destino que se recorra y por aterrizar en el planeta de destino.

Para hacer este viaje la flota consumirá el recurso Hidrógeno. El cálculo de combustible consumido se realizará usando el valor de `FuelPerSecond` del conjunto de naves de la flota.

### Misiones disponibles

- **Misión de colonización**: una flota con al menos una nave Colonizer puede viajar a un planeta libre. El primero que llega inicia la colonización; durante ese tiempo el planeta deja de aceptar nuevas colonizaciones. Si la colonia se completa, se consume una nave colonizadora, el planeta pasa al jugador con estructuras y recursos iniciales configurables y las naves restantes regresan a la base. Si otro jugador llegó antes, la flota retorna automáticamente.
- **Misión de transporte**: una flota puede llevar Materia Prima, Microchips, Hidrógeno, Comida y Créditos a un planeta habitado del mismo universo. El despacho valida capacidad total de bodega y disponibilidad real del planeta origen, reservando primero el hidrógeno de ida y vuelta; al llegar entrega la carga en backend y programa el retorno automático.
- **Misión de ataque**: combate contra flotas/defensas del objetivo, con resultado de victoria, empate o derrota y notificación de reporte.
- Futuro: bombardeo orbital y bloqueo planetario.

### Defensas planetarias

Las defensas se construyen desde el Centro de Defensa y quedan fijas en el planeta. No pueden moverse, atacar ni saquear, por lo que sus valores de combate son más eficientes que los de una nave equivalente. El MVP incluye Plataforma de Misiles, Láser Ligero, Láser Pesado, Gauss, Iónico, Plasma, Cúpula de Escudo Planetario, Matriz Antiasedio, Plataforma de Interdicción Orbital y Bastión de Defensa Planetaria. Las infraestructuras críticas tienen límites por planeta para evitar una defensa universal: por ejemplo, la Cúpula y el Bastión son únicos y la Matriz Antiasedio está limitada.

La construcción usa una cola persistente por planeta con Oban. El backend descuenta recursos y completa cada unidad de forma transaccional; LiveView solo muestra el estado y no participa en la resolución lógica.

La vista del Centro de Defensa valida también en UX los límites de infraestructuras críticas contando defensas construidas, defensas en cola y defensas preparadas en el resumen. Los catálogos de naves y defensas muestran una vista resumida de dos líneas y un modal de detalle con imagen, descripción completa y estadísticas.

### Configuración parametrizable

Los valores de gameplay de alto impacto para el MVP se cargan desde `priv/settings/gameplay.json` y se cachean en memoria al arrancar la aplicación para reducir overhead en runtime.

Actualmente incluye:

- Tiempo base y mínimo de colonización.
- Recursos iniciales de un planeta recién fundado.
- Estructuras iniciales de un planeta recién fundado.
- Constantes base de tiempo de viaje de flotas.

Esto permite ajustar balance sin tocar la lógica de dominio ni recompilar fórmulas de misión.

### Ganancia de recursos

#### Recursos estándar

Cada tipo de recurso tiene una estructura asociada:

- Materia Prima: multiplicador base 200.
- Microchips: multiplicador base 170.
- Hidrógeno: multiplicador base 140.
- Comida: multiplicador base 150.

#### Fórmula de producción

`Ganancia por hora = MultiplicadorBase * Nivel * (1.1 ^ Nivel)`

Además:

- Se aplica bono de gobernador si existe.
- La producción depende de trabajadores asignados (0% a 100%).
- Si una estructura sube de nivel durante inactividad, el cálculo se divide por tramos para precisión.

### Componentes (mid-game)

Los componentes se producen activamente en la Fábrica de Componentes:

- **Módulo Estructural Avanzado** (mucha materia prima + algo de microchips + créditos).
- **Núcleo de Sistemas Integrados** (muchos microchips + créditos).
- **Gel de eficiencia de combustible** (mucho hidrógeno + algo de microchips + créditos).

### Ganancia de energía

La energía es dinámica (no almacenable como reserva). Se calcula por generación total menos consumo total.

Efectos por energía baja en producción:

- Energía < 5 → Producción al 20%.
- Energía < 10 → Producción al 50%.
- Energía < 15 → Producción al 80%.
- Energía < 20 → Producción detenida.

### Población

La población pertenece al planeta y no puede comerciarse en misiones de transporte.

#### Muerte de ciudadanos

En ataque se elige:

- **¡Sin Piedad!**: maximiza bajas civiles tras victoria.
- **Ignorar civiles**: mismas reglas con impacto reducido (aprox. /10).

#### Generación de población

`Nueva población/hora = FreePopulation * 0.05`, modificada por `HappynessBonus`:

- 0-30% felicidad: -20%
- 31-50%: 0%
- 51-75%: +20%
- 76-99%: +30%
- 100%: +50%

La tabla debe ser parametrizable.

### Créditos y comercio

Los créditos representan salud económica y se almacenan por planeta.

- Generación pasiva: impuestos + comercio/rutas.
- Impuestos más altos reducen felicidad.
- Futuro: sistema detallado de rutas comerciales con bienes y leyes.

### Diplomacia

Acuerdos entre jugadores/clanes desde página Diplomacia:

- Pacto de libre comercio.
- Pacto de no agresión.
- Acuerdo de investigación.

Con duración configurable, posibles requisitos adicionales (inicialmente créditos), aceptación/rechazo/contraoferta y penalización de karma por ruptura unilateral.

### Sistema de Karma

`UniverseUser` tendrá puntuación de karma (positiva o negativa), con ventajas/desventajas según rango.

- Acciones que dan karma: ayuda humanitaria, atacar karma negativo, PvE piratas, ciertas leyes/gobiernos/edictos.
- Acciones que quitan karma: saquear con ¡Sin Piedad!, atacar jugadores de menor clasificación, romper pactos.

### Sociedades secretas

Al alcanzar cierto karma, se desbloquea acceso a sociedades secretas, con leyes/edictos/formas de gobierno particulares y cadena de misiones hacia endgame.

### Sistema de leyes

Tres pilares:

- **Forma de gobierno** (ventajas/desventajas y desbloqueos).
- **Leyes** (efectos permanentes en el tiempo).
- **Edictos** (efectos temporales inmediatos con coste de créditos).

### Sistema de espionaje

Se basa en cartas Espía y Centro de inteligencia:

- Reclutamiento con créditos.
- Contraespionaje asignando espías en defensa.
- Infiltración por tirada comparando Infiltración vs Percepción (con riesgo mínimo incluso sin defensor).
- Misiones: actualizar datos, sabotear minas, incitar revueltas.
- Herramienta defensiva: redada (ley activa con coste en felicidad).

### Sistema de Clanes

Un clan tiene:

- Nombre único (máx. 25).
- Siglas únicas (máx. 7).
- Puntuación agregada.
- Página pública editable.
- Página de administración.
- Rangos y permisos.

Fundar clan consume puntos diplomáticos configurables (`DiplomaticPoints` en `UniverseUser`).
Debe existir ranking de clanes en la página Ranking.

---

## CAPÍTULO 3: STACK TECNOLÓGICO Y ARQUITECTURA

Para garantizar persistencia, reactividad y concurrencia masiva:

1. **Backend y lógica**: Elixir + OTP/GenServers + ETS para estado de alta velocidad.
2. **Capa web y real-time**: Phoenix + LiveView + Channels + PubSub.
3. **Persistencia y tareas**: PostgreSQL + Oban (misiones, colas, investigación).
4. **Caché y presencia**: Redis + Presence + rate limiting.
5. **Frontend visual**: PixiJS + Tailwind CSS.
6. **Infraestructura**: Docker + Fly.io/Gigalixir + CI/CD automatizado.

---

## Nota operativa para agentes IA

- Si hay conflicto entre una implementación y esta guía, priorizar esta guía y documentar la discrepancia.
- Si hay ambigüedad funcional o de UX, revisar primero este README y luego `ROADMAP.md`/`AGENTS.md` para resolver prioridades.

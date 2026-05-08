# ROADMAP — Nexus: Downfall (MVP-first)

Este roadmap está ordenado por prioridad para entregar valor rápido sin comprometer escalabilidad.

## Principios de ejecución

1. **Vertical slices**: cada bloque deja funcionalidad usable end-to-end.
2. **Test-first donde aplique**: motor de reglas con pruebas unitarias desde el día 1.
3. **No romper lo anterior**: regresión obligatoria en cada iteración.
4. **MVP realista**: primero jugable, después profundidad.

---

## Fase 0 — Fundación del proyecto (Prioridad crítica)

### Objetivo
Tener un monorepo operativo con CI, entorno local reproducible y estándares de calidad.

### Tareas
- [x] Inicializar proyecto base con Elixir + Phoenix + LiveView.
- [x] Configurar PostgreSQL, Oban y Redis en `docker-compose` para entorno local.
- [x] Definir estructura modular de dominios (`Accounts`, `Universe`, `Planets`, `Fleets`, `Combat`, `Diplomacy`).
- [x] Configurar lint/format/checks (`mix format`, `credo`, `dialyzer` opcional inicial).
- [x] Configurar pipeline CI (test + lint + build).
- [x] Preparar sistema de seeds para universo de desarrollo.

### Tests obligatorios
- [x] Smoke tests de arranque de app.
- [x] Test de conexión a BD + migraciones.
- [x] Test de encolado/ejecución de job en Oban.

---

## Fase 1 — Cuentas y entrada al universo (Prioridad crítica)

### Objetivo
Que un usuario pueda crear cuenta, entrar y tener su primer planeta inicial.

### Tareas
- [x] Implementar autenticación (registro/login/logout).
- [x] Modelo de usuario global + relación con usuarios por universo.
- [x] Flujo "unirse a universo" y creación de planeta inicial.
- [x] Endurecer onboarding: wizard de unión (especie + galaxia recomendada) y bloqueo de menú/rutas de juego hasta pertenecer a un universo.
- [x] UI base sci-fi (Tailwind) para dashboard inicial.
- [x] Telemetría básica de eventos clave (alta, login, creación planeta).

### Tests obligatorios
- [x] Tests de autenticación y autorización.
- [x] Tests de creación de usuario/universe-user/planeta inicial.
- [x] Tests de permisos de acceso por universo.

---

## Fase 2 — Economía planetaria base (Prioridad crítica)

### Objetivo
Bucle principal: construir/mejorar edificios y generar recursos con reglas energéticas.

### Tareas
- [x] Modelar recursos base: Materia Prima, Microchips, Hidrógeno, Comida, Energía, Créditos, Población.
- [x] Implementar edificios MVP: Centro de mando, minas base, generador, granjas, residencial, laboratorio, espaciopuerto.
- [x] Añadir edificios de fase media: Reactor Nuclear, Centro de Defensa, Fábrica de Componentes.
- [x] Motor de producción por hora (fórmula OGame: `base * nivel * 1.1^nivel`).
- [x] Sistema de consumo/penalización por energía insuficiente (balance estático, no flujo).
- [x] Cola de construcción de edificios con finalización por tiempo (Oban).
- [x] Vista planetaria LiveView con actualización en tiempo real.
- [x] Sistema i18n: Gettext con locales ES/EN/FR, campo `locale` en User, página de ajustes, submenú de avatar.

### Tests obligatorios
- [x] Property tests/fuzz sobre fórmulas de producción.
- [x] Tests de borde de energía (umbrales y penalizaciones).
- [x] Tests de cola de construcción (inicio, cancelación, finalización).
- [x] Tests de regresión de economía (snapshot fixtures).

---

## Fase 3 — Flotas y navegación inicial (Prioridad alta)

### Objetivo
Permitir creación de flotas y viajes entre sistemas conectados.

### Tareas
- [x] Modelo de galaxia/sistemas/hipervías y planetas.
- [x] Pathfinding A* para rutas de flota.
- [x] Creación de flota desde `/Fleet` y desde detalle de planeta.
- [x] Misión de colonización (selección de planeta válido, tiempo que tarda en colonizarse, eliminación de la nave tras la colonización, asignación del nuevo planeta al jugador con la estructura del ayuntamiento a nivel 1 y recursos iniciales, consumo de hidrógeno).
- [x] Misión de transporte (ida, entrega, retorno, consumo de hidrógeno. Fijarse en como está implementada la UX de la misión de colonización respecto a la progress bar.).
- [x] Programación temporal de misiones con Oban.
- [x] Límite de flotas activas (base + mejor espaciopuerto).

### Tests obligatorios
- [x] Tests de A* (ruta mínima, sin ruta, empates).
- [x] Tests de consumo de combustible por segundo.
- [x] Tests E2E de misión de transporte completa.

---

## Fase 4 — Combate MVP y reportes (Prioridad alta)

### Objetivo
Introducir PvP base con misión de ataque simplificada y reportes.

### Tareas
- [x] Creación de defensas (funcionará de forma similar a la creación de naves desde el espaciopuerto pero creando defensas desde el centro de defensa. Hay que procurar reutilizar todo el código posible.).
- [ ] Resolver combate por rondas (atacante/defensor).
- [ ] Resultado de combate: victoria/empate/derrota.
- [ ] Saqueo según capacidad de carga restante.
- [ ] Opciones sobre población enemiga (`Sin piedad` / `Ignorar civiles`) en versión simplificada.
- [ ] Sistema de reportes y notificaciones a ambos jugadores.

### Tests obligatorios
- [ ] Tests deterministas del motor de combate con seeds fijas.
- [ ] Tests de integración ataque + resolución + notificaciones.
- [ ] Tests de invariantes (nunca recursos negativos, nunca naves < 0).

---

## Fase 5 — Diplomacia y clanes base (Prioridad media)

### Objetivo
Añadir capa social mínima para retención.

### Tareas
- [ ] Propuestas de pacto básicas (no agresión y libre comercio).
- [ ] Flujo aceptar/rechazar/contraoferta simple.
- [ ] Creación de clanes + solicitudes + aceptación.
- [ ] Ranking básico de clanes por puntuación agregada.
- [ ] Chat de clan mediante Phoenix Channels.

### Tests obligatorios
- [ ] Tests de permisos y estados de pactos.
- [ ] Tests de ciclo de vida de clan (crear, unirse, gestionar).
- [ ] Tests de canales/chat (conexión y broadcast).

---

## Fase 6 — Producto, UX y operación (Prioridad media)

### Objetivo
Pulido para lanzamiento MVP cerrado.

### Tareas
- [ ] Diseño sci-fi consistente (design tokens + componentes UI reutilizables).
- [ ] Tutorial inicial (onboarding de primeros 15 minutos).
- [ ] Sistema de métricas de retención y embudos.
- [ ] Endurecimiento anti-abuso (rate limits críticos).
- [ ] Preparación de despliegue en Fly.io/Gigalixir.

### Tests obligatorios
- [ ] Tests de humo E2E del onboarding.
- [ ] Pruebas de carga inicial sobre ticks de producción y jobs.
- [ ] Test de rollback de despliegue en staging.

---

## Definición de Done por tarea

Una tarea solo se considera terminada cuando cumple:

- [ ] Código implementado y revisado.
- [ ] Tests unitarios/integración actualizados y en verde.
- [ ] Sin regresiones en suites existentes.
- [ ] Telemetría/logs mínimos para observar comportamiento.
- [ ] Documentación funcional y técnica mínima actualizada.

---

## Orden de ejecución recomendado inmediato

1. Fase 0 completa.
2. Fase 1 completa.
3. Fase 2 hasta tener bucle económico jugable.
4. Revisión de métricas y then Fase 3.

Con esto se obtiene un MVP temprano sobre el que iterar sin deuda estructural crítica.

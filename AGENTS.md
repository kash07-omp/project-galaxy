# AGENTS — Nexus: Downfall

Lee este documento antes de implementar nuevas tareas.

## Visión del producto

- **Nexus: Downfall** es un MMORTS de navegador, sucesor espiritual de OGame, con estética sci-fi moderna.
- Debe ser **free-to-play** y evitar prácticas **pay-to-win**.
- Monetización permitida: expansiones/DLC, cosméticos, sobres de cartas y utilidades de gestión; nunca venta directa de poder.

## Objetivo de desarrollo

Entregar un MVP práctico y rápido, iterando por prioridad y manteniendo estabilidad continua:

1. Hacer primero el núcleo jugable (economía planetaria + flotas básicas).
2. Añadir complejidad por capas (combate, diplomacia, clanes, karma, endgame).
3. Mantener compatibilidad hacia atrás en cada incremento.

## Reglas de ejecución para agentes

1. **Trabajar por roadmap**: ejecutar tareas en el orden definido en `ROADMAP.md`.
2. **No romper lo previo**: antes de cerrar una tarea, ejecutar tests de regresión relevantes.
3. **Test-centric**:
   - Añadir tests unitarios para reglas de dominio.
   - Añadir tests de integración para flujos críticos.
   - Añadir tests E2E para journeys de jugador del MVP.
4. **Arquitectura objetivo**:
   - Backend: Elixir + Phoenix + LiveView.
   - Procesos y concurrencia: OTP/GenServer.
   - Persistencia: PostgreSQL.
   - Jobs temporales: Oban.
   - Tiempo real/chat/notificaciones: Channels/PubSub.
   - Frontend visual: Tailwind + PixiJS (cuando aplique).
5. **Diseño y UX**:
   - Interfaz moderna sci-fi, clara y responsive.
   - Priorizar legibilidad de estado, timers, recursos y alertas.
6. **Observabilidad mínima**:
   - Registrar eventos de dominio críticos.
   - Añadir métricas básicas por funcionalidades nuevas.

## Resumen jugable (alto nivel)

- Universo con galaxias, sistemas solares conectados por hipervías y planetas.
- Progresión por edificios, tecnologías, recursos, flotas y expansión.
- Interacción multijugador con comercio, combate, diplomacia y clanes.
- Servidores/universos independientes con posible final de universo en late-game.

## Restricciones de diseño de juego

- Nada de compra directa de recursos, flotas o ventaja militar.
- Sistemas premium deben ser cosméticos o de comodidad, no de poder injusto.
- Balance y fórmulas deben ser parametrizables para ajustes rápidos.

## Entregables mínimos por tarea

- Código funcional.
- Tests pasando.
- Documentación breve de lo implementado.
- Checklist de regresión ejecutado.

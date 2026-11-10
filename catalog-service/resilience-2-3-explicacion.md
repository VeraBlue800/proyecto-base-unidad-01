# Explicación de la bitácora: `resilience-2-3.txt`

**Laboratorio 1.2, Paso 2.3: `@Timeout` + `@Retry` + `@Fallback`**

## Cambios aplicados

Respecto a la etapa 2.2 se agregó:

- `@Fallback(fallbackMethod = "getCatalogFallback")` en `getProducts()`.
- El método `getCatalogFallback()`, que responde HTTP 200 con `{"status":"DEGRADED_CACHE", ...}` y datos simulados de caché.
- El reseteo de los contadores `ThreadLocal` se movió al método de fallback, para que pueda registrar cuántos intentos se agotaron.

El modelo de fallas es el mismo de la etapa 2.2: 60% de las solicitudes fallan en todos sus intentos.

## Resultados

| Métrica | Valor |
|---|---|
| Solicitudes totales | 200 |
| `SUCCESS` (HTTP 200) | 76 (38%) |
| `DEGRADED_CACHE` (HTTP 200) | 124 (62%) |
| Respuestas distintas de 200 | **0** |
| Disponibilidad observada | **1.0** |

## Comportamiento observado

**Desaparecieron todos los errores HTTP 500.** Las 124 solicitudes que en la etapa anterior habrían terminado en error ahora reciben una respuesta degradada con HTTP 200. En los logs aparece `Fallback activado: Se agotaron todos los 3 intentos...` en cada una.

**La proporción coincide con el modelo de fallas.** El 62% de respuestas `DEGRADED_CACHE` corresponde al 60% de solicitudes configuradas para fallar, y el 38% de `SUCCESS` al 40% que responde bien a la primera.

**Disponible no es lo mismo que correcto.** La disponibilidad sube a 1.0 porque toda respuesta con HTTP 200 se cuenta como disponible, pero el 62% de los clientes recibió datos de caché, posiblemente desactualizados. El servicio prioriza la **disponibilidad sobre la consistencia**: es preferible mostrar un catálogo antiguo que una página de error. Por eso conviene reportar también la tasa de `SUCCESS` (38%) junto con la disponibilidad.

**La latencia de las solicitudes fallidas no cambia.** El fallback se ejecuta después de agotar los reintentos, así que una solicitud degradada sigue tardando alrededor de 1.1 s. `@Fallback` mejora el resultado de la respuesta, no su velocidad.

**El cliente debe distinguir los estados.** Como ambas respuestas usan HTTP 200, quien consume el servicio debe revisar el campo `status` para saber si los datos son actuales o de caché.

## Conclusión

`@Fallback` es el patrón que más impacto tuvo en la disponibilidad (0.405 → 1.0): transforma errores totales en respuestas degradadas pero útiles. Sin embargo, el servicio sigue reintentando contra una dependencia que falla de forma persistente, lo que mantiene la carga y la latencia altas. Ese problema lo resuelve `@CircuitBreaker`.

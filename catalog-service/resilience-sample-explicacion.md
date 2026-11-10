# Explicación de la bitácora: `resilience-sample.txt`

**Laboratorio 1.2, Paso 2.4: configuración completa (`@Timeout` + `@Retry` + `@CircuitBreaker` + `@Fallback`)**

## Cambios aplicados

Respecto a la etapa 2.3 se agregó:

```java
@CircuitBreaker(requestVolumeThreshold = 10, failureRatio = 0.7, delay = 5000)
```

- `requestVolumeThreshold = 10`: el circuito evalúa las últimas 10 solicitudes.
- `failureRatio = 0.7`: se abre si al menos 7 de esas 10 fallaron.
- `delay = 5000`: permanece abierto 5 segundos antes de pasar a HALF_OPEN y probar si la dependencia se recuperó.

El modelo de fallas es el mismo de las etapas anteriores: 60% de las solicitudes fallan en todos sus intentos.

## Resultados

| Métrica | Valor |
|---|---|
| Solicitudes totales | 200 |
| `SUCCESS` (HTTP 200) | 27 (13.5%) |
| `DEGRADED_CACHE` (HTTP 200) | 173 (86.5%) |
| Errores HTTP 500 | **0** |
| Disponibilidad observada | **1.0** |
| Latencia máxima | 2.594 s |
| Latencia promedio | 0.377 s |

## Comportamiento observado

**Bajaron las respuestas `SUCCESS` aunque el modelo de fallas no cambió (76 → 27).** Es la señal de que el circuito se abrió. Mientras está en estado OPEN, el circuito rechaza *todas* las solicitudes sin ejecutar `getProducts()`, incluidas las que habrían respondido con éxito, y las manda directo al fallback. Con un 60% de solicitudes fallando, es frecuente que una ventana de 10 alcance el 70% de fallas, así que el circuito se abre varias veces durante la prueba.

**El estado OPEN es visible en los logs.** Aparecen secuencias de `Fallback activado: Se agotaron todos los 0 intentos...` sin líneas `[Intento ...]` previas. El contador en 0 indica que la solicitud fue interceptada antes de entrar al método.

> Completar con lo observado en los logs:
>
> - Momento aproximado en que se abrió el circuito por primera vez:
> - Cantidad de líneas consecutivas con "0 intentos":
> - Duración aproximada de la fase OPEN (esperado: ~5 s):
> - ¿Volvieron a aparecer reintentos completos (`Intento 1/3`, `2/3`, `3/3`) después de la recuperación?:

**La latencia promedio bajó a la mitad respecto a la línea base (0.745 s → 0.377 s).** Las solicitudes rechazadas con el circuito abierto se responden de inmediato, sin reintentos ni timeouts, y ninguna solicitud queda bloqueada 3 segundos.

**Latencia máxima de 2.594 s.** Es mayor que el ~1.1 s esperado para una solicitud que agota sus reintentos. La causa más probable es que la primera solicitud después de guardar el código provocó la recompilación automática de Quarkus en modo dev. _(Verificar qué solicitud tuvo este tiempo; si es la 001, se trata de la recompilación y no del comportamiento de los patrones.)_

**El circuito protege a la dependencia.** Mientras está abierto, la "base de datos" no recibe llamadas, lo que le da tiempo de recuperarse en lugar de recibir hasta 3 llamadas por solicitud como en las etapas 2.2 y 2.3.

## Comparación de todas las etapas

| Etapa | SUCCESS | DEGRADED_CACHE | Errores | Disponibilidad |
|---|---|---|---|---|
| Línea base (Lab 1.1) | 126 | 0 | 74 | 0.63 |
| 2.2: Timeout + Retry | 81 | 0 | 119 | 0.405 |
| 2.3: + Fallback | 76 | 124 | 0 | 1.0 |
| 2.4: + CircuitBreaker | 27 | 173 | 0 | 1.0 |

## Conclusión

La combinación de los cuatro patrones logra una disponibilidad de 1.0 sin errores HTTP 500 y con menor latencia que la línea base. El costo es que la mayoría de las respuestas son degradadas: el `@CircuitBreaker` sacrifica respuestas exitosas a cambio de proteger a la dependencia y responder rápido. En un sistema real, los parámetros del circuito (`failureRatio`, `delay`) deben ajustarse para equilibrar esa protección con la proporción de datos actualizados que reciben los clientes.

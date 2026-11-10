# Explicación de la bitácora: `resilience-2-2.txt`

**Laboratorio 1.2, Paso 2.2: `@Timeout` + `@Retry`**

## Cambios aplicados

Sobre el código de la línea base se agregaron:

- Dos campos `ThreadLocal` (`ATTEMPT_COUNT` y `SHOULD_FAIL_FIRST_ATTEMPTS`) para rastrear el número de intento de cada solicitud.
- `@Timeout(800)`: cancela cualquier ejecución que tarde más de 800 ms.
- `@Retry(maxRetries = 2, delay = 150)`: reintenta hasta 2 veces, con 150 ms de espera entre intentos.

**El modelo de fallas también cambió.** En esta versión, el 60% de las solicitudes se marca para fallar en los tres intentos (intento 1: excepción de conexión; intento 2: latencia de 3000 ms cortada por el timeout; intento 3: excepción). El 40% restante responde con éxito en el primer intento. Por eso los resultados no se comparan directamente con la línea base, cuya tasa de fallas era del ~30%.

## Resultados

| Métrica | Valor |
|---|---|
| Solicitudes totales | 200 |
| Respuestas HTTP 200 (`SUCCESS`) | 81 (40.5%) |
| Respuestas distintas de 200 | 119 (59.5%) |
| Disponibilidad observada | **0.405** |
| Latencia máxima | _completar_ |
| Latencia promedio | _completar_ |

> Para obtener la latencia:
> `Get-Content resilience-2-2.txt | ForEach-Object { [double](($_ -split ' ')[2]) } | Measure-Object -Maximum -Average`

## Comportamiento observado

**La disponibilidad bajó respecto a la línea base (0.63 → 0.405), y es el resultado esperado.** No es que los patrones empeoren el servicio: el nuevo modelo hace fallar al 60% de las solicitudes en todos sus intentos, y sin un `@Fallback` el error se propaga al cliente como HTTP 500 cuando se agotan los reintentos. El 40.5% observado coincide casi exacto con el 40% teórico.

**`@Timeout` eliminó las esperas de 3 segundos.** El `Thread.sleep(3000)` del segundo intento se interrumpe a los 800 ms. Una solicitud que falla en los tres intentos tarda aproximadamente: falla inmediata + 150 ms + 800 ms de timeout + 150 ms + falla inmediata ≈ 1.1 s, en lugar de quedar bloqueada.

**`@Retry` funciona, pero no puede rescatar fallas persistentes.** En los logs se observa la secuencia completa `[Intento 1/3]`, `[Intento 2/3]`, `[Intento 3/3]` para cada solicitud fallida. Los reintentos son útiles cuando la falla es transitoria; cuando la dependencia sigue caída, solo retrasan el error.

**Costo de los reintentos.** Cada solicitud fallida generó 3 llamadas a la "base de datos" en lugar de una. Si la dependencia ya está saturada, triplicar la carga puede empeorar la falla. Este costo justifica agregar un `@CircuitBreaker` más adelante.

## Conclusión

`@Timeout` mejora la latencia y `@Retry` da más oportunidades de éxito, pero ninguno de los dos evita que el cliente reciba errores cuando la falla persiste. Hace falta un mecanismo que convierta el error final en una respuesta útil: `@Fallback`.

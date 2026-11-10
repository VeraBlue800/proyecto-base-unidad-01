# Script para analizar y comparar resultados de resiliencia
# Uso: .\analyze-resilience.ps1

if (-not (Test-Path "availability-baseline.txt") -or -not (Test-Path "resilience-sample.txt")) {
    Write-Host "Error: Archivos no encontrados." -ForegroundColor Red
    Write-Host "Asegurate de que existen: availability-baseline.txt y resilience-sample.txt"
    exit 1
}

function Get-Latency($lines) {
    $times = $lines | ForEach-Object { [double](($_ -split ' ')[2]) }
    return ($times | Measure-Object -Maximum -Average)
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "        ANALISIS DE RESILIENCIA: Lab 1.1 vs Lab 1.2" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# --- Linea base (Lab 1.1) ---
$baseline = @(Get-Content availability-baseline.txt)
$total_1_1 = $baseline.Count
$success_1_1 = ($baseline | Where-Object { $_ -like '*"status":"SUCCESS"*' }).Count
$errors_1_1 = $total_1_1 - $success_1_1
$avail_1_1 = [math]::Round($success_1_1 / $total_1_1, 4)
$lat_1_1 = Get-Latency $baseline

Write-Host ""
Write-Host "LINEA BASE (Lab 1.1 - SIN patrones)" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Total solicitudes:         $total_1_1"
Write-Host "SUCCESS (HTTP 200):        $success_1_1 (~$([math]::Round($success_1_1 * 100 / $total_1_1))%)"
Write-Host "Errores/No disponibles:    $errors_1_1 (~$([math]::Round($errors_1_1 * 100 / $total_1_1))%)"
Write-Host "Disponibilidad:            $avail_1_1"
Write-Host "Latencia maxima (s):       $([math]::Round($lat_1_1.Maximum, 3))"
Write-Host "Latencia promedio (s):     $([math]::Round($lat_1_1.Average, 3))"

# --- Con patrones (Lab 1.2) ---
$resilience = @(Get-Content resilience-sample.txt)
$total_1_2 = $resilience.Count
$success_1_2 = ($resilience | Where-Object { $_ -like '*"status":"SUCCESS"*' }).Count
$degraded_1_2 = ($resilience | Where-Object { $_ -like '*"status":"DEGRADED_CACHE"*' }).Count
$http500_1_2 = ($resilience | Where-Object { $_ -match '^\d+\s+500\s+' }).Count
$total_respuestas = $success_1_2 + $degraded_1_2
$avail_1_2 = [math]::Round($total_respuestas / $total_1_2, 4)
$lat_1_2 = Get-Latency $resilience

Write-Host ""
Write-Host "CON PATRONES (Lab 1.2 - Timeout + Retry + Fallback + CircuitBreaker)" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Total solicitudes:         $total_1_2"
Write-Host "SUCCESS (HTTP 200):        $success_1_2 (~$([math]::Round($success_1_2 * 100 / $total_1_2))%)"
Write-Host "DEGRADED_CACHE (HTTP 200): $degraded_1_2 (~$([math]::Round($degraded_1_2 * 100 / $total_1_2))%)"
Write-Host "Errores HTTP 500:          $http500_1_2"
Write-Host "Disponibilidad:            $avail_1_2"
Write-Host "Latencia maxima (s):       $([math]::Round($lat_1_2.Maximum, 3))"
Write-Host "Latencia promedio (s):     $([math]::Round($lat_1_2.Average, 3))"

# --- Comparacion ---
$mejora_avail = [math]::Round($avail_1_2 - $avail_1_1, 4)
$mejora_porcentaje = [math]::Round(($avail_1_2 - $avail_1_1) * 100, 2)

Write-Host ""
Write-Host "COMPARACION - MEJORA OBTENIDA" -ForegroundColor Green
Write-Host "------------------------------------------------------------------" -ForegroundColor Green
Write-Host "Disponibilidad mejorada:   $mejora_avail ($mejora_porcentaje puntos porcentuales)"
Write-Host "Errores HTTP:              de $errors_1_1 a $http500_1_2"
Write-Host "Respuestas degradadas:     $degraded_1_2 solicitudes salvadas por @Fallback"
Write-Host "Latencia maxima:           de $([math]::Round($lat_1_1.Maximum, 3)) s a $([math]::Round($lat_1_2.Maximum, 3)) s"

Write-Host ""
Write-Host "CONCLUSION" -ForegroundColor Green
Write-Host "------------------------------------------------------------------" -ForegroundColor Green
if ($avail_1_2 -gt 0.99) {
    Write-Host "La implementacion de patrones de resiliencia fue EXITOSA." -ForegroundColor Green
} else {
    Write-Host "La implementacion funciona, pero revisa si el @CircuitBreaker se activo correctamente." -ForegroundColor Yellow
}
Write-Host ""
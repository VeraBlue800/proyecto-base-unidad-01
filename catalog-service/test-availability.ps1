# Script reutilizable para medir disponibilidad
# Uso: .\test-availability.ps1 -OutputFile <nombre_archivo>
# Ejemplo para Lab 1.1: .\test-availability.ps1 -OutputFile "availability-baseline.txt"
# Ejemplo para Lab 1.2: .\test-availability.ps1 -OutputFile "resilience-sample.txt"

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

$EndpointUrl = "http://localhost:8081/v1/products"
$NumRequests = 200

# 1. Validar parametro
if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    Write-Host "Error: Debes proporcionar el nombre del archivo de salida" -ForegroundColor Red
    Write-Host "Uso: .\test-availability.ps1 -OutputFile <nombre_archivo>" -ForegroundColor Yellow
    exit 1
}

# 2. Limpiar archivo de salida
if (Test-Path $OutputFile) { Remove-Item $OutputFile }

Write-Host "Ejecutando $NumRequests solicitudes a $EndpointUrl" -ForegroundColor Cyan
Write-Host "Guardando en: $OutputFile" -ForegroundColor Cyan

# 3. Loop de solicitudes
for ($i = 1; $i -le $NumRequests; $i++) {
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        # Importante: usar curl.exe explicitamente en Windows
        $output = curl.exe -sS -o $tempFile -w "%{http_code} %{time_total}" $EndpointUrl 2>$null

        $body = Get-Content -Raw -Path $tempFile 2>$null | ForEach-Object { $_ -replace "`r?`n", ' ' }

        $line = "{0:D3} {1} {2}" -f $i, $output, $body
        Add-Content -Path $OutputFile -Value $line
        Write-Host $line
    }
    finally {
        Remove-Item -Force $tempFile -ErrorAction SilentlyContinue
    }
}

Write-Host "`nResultados guardados en: $OutputFile`n" -ForegroundColor Green

# 4. Procesar metricas
$lines = Get-Content $OutputFile

$total = $lines.Count
$success = ($lines | Where-Object { $_ -like '*"status":"SUCCESS"*' }).Count
$http200 = ($lines | Where-Object { $_ -match '^\d+\s+200\s+' }).Count
$httpErrors = $total - $http200

# 5. Mostrar resultados
Write-Host "Respuestas SUCCESS: $success"
Write-Host "Respuestas HTTP 200: $http200"
Write-Host "Respuestas HTTP distintas de 200: $httpErrors"
Write-Host "Solicitudes totales: $total"

if ($total -gt 0) {
    $availability = [math]::Round($http200 / $total, 4)
    Write-Host "Disponibilidad observada: $availability" -ForegroundColor Yellow
}
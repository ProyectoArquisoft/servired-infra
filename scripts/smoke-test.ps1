# Comprueba que todo responde. Uso: .\scripts\smoke-test.ps1
# (con el perfil app arriba y el override dev, que publica 8081-8083).
$fallos = 0
function Probar($nombre, $url, $esperado = 200) {
  try { $codigo = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).StatusCode }
  catch { $codigo = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 } }
  if ($codigo -eq $esperado) { Write-Host "OK    $nombre ($codigo)" }
  else { Write-Host "FALLA $nombre`: $codigo (esperaba $esperado)"; $script:fallos = 1 }
}
Probar "gateway /actuator/health"    "http://localhost:8080/actuator/health"
Probar "gateway /internal bloqueado" "http://localhost:8080/internal/reportes/1" 404
Probar "reportes /actuator/health"   "http://localhost:8081/actuator/health"
Probar "moderacion /actuator/health" "http://localhost:8082/actuator/health"
Probar "indicadores /health"         "http://localhost:8083/health"
Probar "rabbitmq consola"            "http://localhost:15672/"
exit $fallos

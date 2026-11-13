#!/bin/sh
# Comprueba que todo responde. Uso: sh scripts/smoke-test.sh   (con el perfil app arriba y el override dev,
# que publica 8081-8083; sin el override solo se prueban gateway y RabbitMQ).
fallos=0
probar() {
  nombre=$1; url=$2; esperado=${3:-200}
  codigo=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" || true)
  if [ "$codigo" = "$esperado" ]; then echo "OK    $nombre ($codigo)"; else echo "FALLA $nombre: $codigo (esperaba $esperado)"; fallos=1; fi
}
probar "gateway /actuator/health"      http://localhost:8080/actuator/health
probar "gateway /internal bloqueado"   http://localhost:8080/internal/reportes/1 404
probar "reportes /actuator/health"     http://localhost:8081/actuator/health
probar "moderacion /actuator/health"   http://localhost:8082/actuator/health
probar "indicadores /health"           http://localhost:8083/health
probar "rabbitmq consola"              http://localhost:15672/
exit $fallos

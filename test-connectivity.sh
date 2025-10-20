#!/bin/bash
set -e

cd /microservices

FRONTEND=$(kubectl get pod -l app=frontend -n frontend-ns -o jsonpath='{.items[0].metadata.name}')
BACKEND=$(kubectl get pod -l app=backend -n backend-ns -o jsonpath='{.items[0].metadata.name}')
DATABASE=$(kubectl get pod -l app=database -n database-ns -o jsonpath='{.items[0].metadata.name}')

echo "=========================================="
echo "🧪 TESTS DE CONECTIVIDAD COMPLETOS"
echo "=========================================="
echo ""
echo "Pods:"
echo "  Frontend: $FRONTEND"
echo "  Backend: $BACKEND"
echo "  Database: $DATABASE"
echo ""

echo "Test 1️⃣  Backend responde en puerto 3000"
kubectl exec -n backend-ns $BACKEND -- wget -qO- --timeout=3 http://localhost:3000 && echo "✅ OK" || echo "❌ FAIL"
echo ""

echo "Test 2️⃣  Backend → Database (puerto 5432)"
kubectl exec -n backend-ns $BACKEND -- nc -zv -w 2 database-service.database-ns.svc.cluster.local 5432 && echo "✅ OK" || echo "❌ FAIL"
echo ""

echo "Test 3️⃣  Frontend → Backend (puerto 3000)"
kubectl exec -n frontend-ns $FRONTEND -- wget -qO- --timeout=3 http://backend-service.backend-ns.svc.cluster.local:3000 && echo "✅ OK" || echo "❌ FAIL"
echo ""

echo "Test 4️⃣  Frontend → Database (debe fallar por Network Policy)"
if kubectl exec -n frontend-ns $FRONTEND -- nc -zv -w 2 database-service.database-ns.svc.cluster.local 5432 2>&1 | grep -q "succeeded"; then
  echo "❌ FAIL - Frontend NO debería conectar a DB"
else
  echo "✅ OK - Bloqueado correctamente"
fi
echo ""

echo "=========================================="
echo "✅ Tests completados"
echo "=========================================="

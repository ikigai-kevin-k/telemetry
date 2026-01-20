#!/bin/bash
# Check Error Event metrics in Prometheus
# This script helps diagnose missing metrics in the Error Event panel

set -e

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

echo "=========================================="
echo "Error Event Metrics Diagnostic Script"
echo "=========================================="
echo ""

echo "1. Checking roulette_error_event metrics..."
echo "-------------------------------------------"
ROULETTE_INSTANCES=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=roulette_error_event" | jq -r '.data.result[] | .metric.instance' | sort -u)
if [ -z "$ROULETTE_INSTANCES" ]; then
    echo "❌ No roulette_error_event metrics found"
else
    echo "✅ Found roulette_error_event instances:"
    echo "$ROULETTE_INSTANCES" | while read instance; do
        if [ -n "$instance" ]; then
            VALUE=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=roulette_error_event{instance=\"${instance}\"}" | jq -r '.data.result[0].value[1] // "N/A"')
            echo "   - ${instance}: ${VALUE}"
        fi
    done
fi
echo ""

echo "2. Checking sicbo_error_event metrics..."
echo "-------------------------------------------"
SICBO_INSTANCES=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=sicbo_error_event" | jq -r '.data.result[] | .metric.instance' | sort -u)
if [ -z "$SICBO_INSTANCES" ]; then
    echo "❌ No sicbo_error_event metrics found"
else
    echo "✅ Found sicbo_error_event instances:"
    echo "$SICBO_INSTANCES" | while read instance; do
        if [ -n "$instance" ]; then
            COUNT=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=count(sicbo_error_event{instance=\"${instance}\"})" | jq -r '.data.result[0].value[1] // "0"')
            echo "   - ${instance}: ${COUNT} series"
        fi
    done
fi
echo ""

echo "3. Dashboard Query vs Actual Data Comparison..."
echo "-------------------------------------------"
echo "Dashboard Query B: roulette_error_event{instance=\"speed_roulette\"}"
if echo "$ROULETTE_INSTANCES" | grep -q "speed_roulette"; then
    echo "   ✅ Match found"
else
    echo "   ❌ No match - speed_roulette not found in Prometheus"
    echo "   Available instances: $(echo $ROULETTE_INSTANCES | tr '\n' ' ')"
fi
echo ""

echo "Dashboard Query D: sicbo_error_event{instance=\"sicbo\"}"
if echo "$SICBO_INSTANCES" | grep -q "sicbo"; then
    echo "   ✅ Match found"
else
    echo "   ❌ No match - sicbo not found in Prometheus"
    echo "   Available instances: $(echo $SICBO_INSTANCES | tr '\n' ' ')"
fi
echo ""

echo "4. All available instance labels..."
echo "-------------------------------------------"
ALL_INSTANCES=$(curl -s "${PROMETHEUS_URL}/api/v1/label/instance/values" | jq -r '.data[]' | grep -E '(speed|vip|sicbo|roulette)' | sort -u)
if [ -z "$ALL_INSTANCES" ]; then
    echo "❌ No relevant instance labels found"
else
    echo "✅ Relevant instance labels:"
    echo "$ALL_INSTANCES" | while read instance; do
        echo "   - ${instance}"
    done
fi
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="






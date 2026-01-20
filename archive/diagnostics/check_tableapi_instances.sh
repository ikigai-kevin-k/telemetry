#!/bin/bash

# Check actual instance labels for TableAPI game duration metrics in Prometheus
# This script helps verify if the instance labels match what's configured in Grafana

echo "🔍 Checking TableAPI game duration metrics instance labels in Prometheus"
echo "========================================================================"
echo ""

echo "📋 Checking available instance labels for finish_to_start_time:"
echo "--------------------------------------------------------------"
echo "Run this query in Prometheus/Grafana Explore:"
echo ""
echo "  label_values(finish_to_start_time{job=\"time_intervals_metrics\"}, instance)"
echo ""

echo "📋 Checking available instance labels for start_to_launch_time:"
echo "--------------------------------------------------------------"
echo "Run this query in Prometheus/Grafana Explore:"
echo ""
echo "  label_values(start_to_launch_time{job=\"time_intervals_metrics\"}, instance)"
echo ""

echo "📋 Checking available instance labels for launch_to_deal_time:"
echo "--------------------------------------------------------------"
echo "Run this query in Prometheus/Grafana Explore:"
echo ""
echo "  label_values(launch_to_deal_time{job=\"time_intervals_metrics\"}, instance)"
echo ""

echo "📋 Checking available instance labels for deal_to_finish_time:"
echo "--------------------------------------------------------------"
echo "Run this query in Prometheus/Grafana Explore:"
echo ""
echo "  label_values(deal_to_finish_time{job=\"time_intervals_metrics\"}, instance)"
echo ""

echo "📊 Checking data availability for both instances:"
echo "------------------------------------------------"
echo "Run these queries to check if data exists for both instances:"
echo ""
echo "  # ARO11 (api-instance):"
echo "  finish_to_start_time{job=\"time_intervals_metrics\", instance=\"api-instance\"}"
echo ""
echo "  # ARO22:"
echo "  finish_to_start_time{job=\"time_intervals_metrics\", instance=\"aro22\"}"
echo ""

echo "🔍 Checking if both instances have data at the same time:"
echo "---------------------------------------------------------"
echo "Run this query to see all instances with data:"
echo ""
echo "  finish_to_start_time{job=\"time_intervals_metrics\"}"
echo ""

echo "📝 Current Grafana Configuration:"
echo "--------------------------------"
echo "  ARO11: instance=\"api-instance\""
echo "  ARO22: instance=\"aro22\""
echo ""

echo "💡 If the actual instance labels don't match, update the queries in Grafana accordingly."
echo ""

















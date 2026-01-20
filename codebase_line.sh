#!/bin/bash

# Codebase Line Count Script
# This script counts the total lines of code in the codebase, excluding common non-code files

echo "==============================================="
echo "Codebase Line Count Analysis"
echo "==============================================="
echo "Timestamp: $(date)"
echo "Working Directory: $(pwd)"
echo ""

# Define directories and files to exclude
EXCLUDE_DIRS="node_modules|.git|backups|__pycache__|\.pytest_cache|\.venv|venv|env|\.idea|\.vscode|dist|build|\.next|out"
EXCLUDE_FILES="\.log$|\.lock$|package-lock\.json|yarn\.lock|\.min\.js$|\.min\.css$|\.map$"

# Common code file extensions
CODE_EXTENSIONS="\.(py|js|ts|jsx|tsx|java|go|rs|cpp|c|h|hpp|cc|cs|php|rb|swift|kt|scala|sh|bash|zsh|fish|ps1|psm1|sql|r|m|mm|pl|pm|lua|vim|el|clj|hs|ml|fs|vb|asm|s|S)$"

# Configuration and data files (optional - can be included or excluded)
CONFIG_EXTENSIONS="\.(yml|yaml|json|xml|toml|ini|cfg|conf|properties|env|dockerfile|makefile|cmake|gradle|maven|pom|sbt|build|mk)$"

# Documentation files
DOC_EXTENSIONS="\.(md|txt|rst|adoc|org)$"

# Get total line count for code files
echo "📊 Code Files Analysis"
echo "---------------------"

# Count lines in code files
CODE_LINES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -regextype posix-extended \
    -regex ".*${CODE_EXTENSIONS}" \
    2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

if [ -z "$CODE_LINES" ] || [ "$CODE_LINES" = "0" ]; then
    CODE_LINES=0
fi

CODE_FILES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -regextype posix-extended \
    -regex ".*${CODE_EXTENSIONS}" \
    2>/dev/null | wc -l)

echo "Code files: ${CODE_FILES}"
echo "Total code lines: ${CODE_LINES}"
echo ""

# Get line count for configuration files
echo "📊 Configuration Files Analysis"
echo "-------------------------------"

CONFIG_LINES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -regextype posix-extended \
    -regex ".*${CONFIG_EXTENSIONS}" \
    2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

if [ -z "$CONFIG_LINES" ] || [ "$CONFIG_LINES" = "0" ]; then
    CONFIG_LINES=0
fi

CONFIG_FILES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -regextype posix-extended \
    -regex ".*${CONFIG_EXTENSIONS}" \
    2>/dev/null | wc -l)

echo "Config files: ${CONFIG_FILES}"
echo "Total config lines: ${CONFIG_LINES}"
echo ""

# Get line count for documentation files
echo "📊 Documentation Files Analysis"
echo "--------------------------------"

DOC_LINES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -regextype posix-extended \
    -regex ".*${DOC_EXTENSIONS}" \
    2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

if [ -z "$DOC_LINES" ] || [ "$DOC_LINES" = "0" ]; then
    DOC_LINES=0
fi

DOC_FILES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -regextype posix-extended \
    -regex ".*${DOC_EXTENSIONS}" \
    2>/dev/null | wc -l)

echo "Documentation files: ${DOC_FILES}"
echo "Total documentation lines: ${DOC_LINES}"
echo ""

# Get total line count (all files excluding common excludes)
echo "📊 Total Lines Analysis"
echo "-----------------------"

TOTAL_LINES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -not -name "*.log" \
    -not -name "*.lock" \
    -not -name "package-lock.json" \
    -not -name "yarn.lock" \
    -not -name "*.min.js" \
    -not -name "*.min.css" \
    -not -name "*.map" \
    2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

if [ -z "$TOTAL_LINES" ] || [ "$TOTAL_LINES" = "0" ]; then
    TOTAL_LINES=0
fi

TOTAL_FILES=$(find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    -not -name "*.log" \
    -not -name "*.lock" \
    -not -name "package-lock.json" \
    -not -name "yarn.lock" \
    -not -name "*.min.js" \
    -not -name "*.min.css" \
    -not -name "*.map" \
    2>/dev/null | wc -l)

echo "Total files: ${TOTAL_FILES}"
echo "Total lines (all files): ${TOTAL_LINES}"
echo ""

# Language breakdown (top languages)
echo "📊 Language Breakdown (Top 10)"
echo "------------------------------"

# Count by file extension
echo "Code files by extension:"
find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/backups/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.pytest_cache/*" \
    -not -path "*/venv/*" \
    -not -path "*/\.venv/*" \
    -not -path "*/env/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/out/*" \
    2>/dev/null | \
    grep -E "\.(py|sh|js|yml|yaml|json|md|txt)$" | \
    sed 's/.*\.//' | \
    sort | \
    uniq -c | \
    sort -rn | \
    head -10 | \
    awk '{printf "  %-10s %6d files\n", $2, $1}'

echo ""

# Summary
echo "📈 Summary"
echo "----------"
echo "Code lines: ${CODE_LINES} (${CODE_FILES} files)"
echo "Config lines: ${CONFIG_LINES} (${CONFIG_FILES} files)"
echo "Documentation lines: ${DOC_LINES} (${DOC_FILES} files)"
echo "Total lines: ${TOTAL_LINES} (${TOTAL_FILES} files)"
echo ""

# Calculate percentages
if [ "$TOTAL_LINES" -gt 0 ]; then
    CODE_PERCENT=$(echo "scale=1; $CODE_LINES * 100 / $TOTAL_LINES" | bc)
    CONFIG_PERCENT=$(echo "scale=1; $CONFIG_LINES * 100 / $TOTAL_LINES" | bc)
    DOC_PERCENT=$(echo "scale=1; $DOC_LINES * 100 / $TOTAL_LINES" | bc)
    
    echo "📊 Distribution:"
    echo "  Code: ${CODE_PERCENT}%"
    echo "  Config: ${CONFIG_PERCENT}%"
    echo "  Documentation: ${DOC_PERCENT}%"
fi

echo ""
echo "==============================================="









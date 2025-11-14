#!/bin/bash
# Rapiba Python3 Requirements Check
# Überprüft ob Python3 mit allen erforderlichen Modulen installiert ist

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Rapiba - Python3 Requirements Check${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# 1. Python3 Verfügbarkeit
echo -e "${BLUE}[1] Python3 Verfügbarkeit${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")')
    PYTHON_PATH=$(which python3)
    echo -e "${GREEN}✓${NC} Python3 gefunden"
    echo "  Path: $PYTHON_PATH"
    echo "  Version: $PYTHON_VERSION"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Python3 nicht gefunden!"
    echo ""
    echo "Installation (Raspberry Pi/Debian/Ubuntu):"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y python3 python3-pip"
    ((CHECKS_FAILED++))
fi
echo ""

# 2. Minimum Python Version
echo -e "${BLUE}[2] Minimum Python Version (3.6+)${NC}"
if command -v python3 &> /dev/null; then
    MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
    MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')
    
    if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 6 ]; then
        echo -e "${GREEN}✓${NC} Python $MAJOR.$MINOR (erforderlich: 3.6+)"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} Python $MAJOR.$MINOR ist zu alt (erforderlich: 3.6+)"
        ((CHECKS_FAILED++))
    fi
else
    echo -e "${RED}✗${NC} Python3 nicht verfügbar"
    ((CHECKS_FAILED++))
fi
echo ""

# 3. Standard Library Module (erforderlich)
echo -e "${BLUE}[3] Standard Library Module (erforderlich)${NC}"

REQUIRED_MODULES=(
    "sys"
    "os"
    "time"
    "logging"
    "configparser"
    "subprocess"
    "shutil"
    "pathlib"
    "datetime"
    "hashlib"
    "sqlite3"
    "json"
    "argparse"
    "concurrent.futures"
    "threading"
)

for module in "${REQUIRED_MODULES[@]}"; do
    if python3 -c "import $module" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $module"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $module (ERFORDERLICH)"
        ((CHECKS_FAILED++))
    fi
done
echo ""

# 4. Optional Module
echo -e "${BLUE}[4] Optional Module${NC}"

OPTIONAL_MODULES=(
    "tabulate"
)

for module in "${OPTIONAL_MODULES[@]}"; do
    if python3 -c "import $module" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $module (optional, gefunden)"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} $module (optional, nicht gefunden)"
        ((CHECKS_WARNING++))
    fi
done
echo ""

# 5. Encoding Support
echo -e "${BLUE}[5] Encoding Support${NC}"
if python3 -c "import sys; sys.stdout.encoding and sys.stderr.encoding" 2>/dev/null; then
    ENCODING=$(python3 -c "import sys; print(sys.stdout.encoding)")
    echo -e "${GREEN}✓${NC} Encoding: $ENCODING"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Encoding-Problem erkannt"
    ((CHECKS_WARNING++))
fi
echo ""

# 6. Paths & Executable
echo -e "${BLUE}[6] Paths & Executable${NC}"

# Prüfe /usr/bin/python3
if [ -x /usr/bin/python3 ]; then
    echo -e "${GREEN}✓${NC} /usr/bin/python3 existiert und ist ausführbar"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} /usr/bin/python3 könnte nicht existieren"
    ((CHECKS_WARNING++))
fi

# Prüfe python3 Symlink
if command -v python3 &> /dev/null; then
    PYTHON_BIN=$(which python3)
    if [ -L "$PYTHON_BIN" ]; then
        TARGET=$(readlink -f "$PYTHON_BIN")
        echo -e "${GREEN}✓${NC} python3 symlink: $PYTHON_BIN -> $TARGET"
    else
        echo -e "${GREEN}✓${NC} python3 binary: $PYTHON_BIN"
    fi
    ((CHECKS_PASSED++))
fi
echo ""

# 7. PIP (optional aber empfohlen)
echo -e "${BLUE}[7] PIP Package Manager (optional)${NC}"
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version)
    echo -e "${GREEN}✓${NC} pip3 gefunden: $PIP_VERSION"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} pip3 nicht gefunden (optional)"
    echo "  Installation: sudo apt-get install -y python3-pip"
    ((CHECKS_WARNING++))
fi
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "Ergebnisse:"
echo -e "  ${GREEN}✓ Bestanden: $CHECKS_PASSED${NC}"
if [ $CHECKS_WARNING -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Warnungen: $CHECKS_WARNING${NC}"
fi
if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "  ${RED}✗ Fehler: $CHECKS_FAILED${NC}"
fi
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Python3 ist vollständig und einsatzbereit!${NC}"
    echo ""
    echo "Du kannst jetzt Rapiba installieren:"
    echo "  sudo bash install.sh"
    exit 0
else
    echo -e "${RED}✗ Python3 Anforderungen nicht erfüllt!${NC}"
    echo ""
    echo "Behebung:"
    if [ $CHECKS_FAILED -gt 0 ]; then
        echo "  1. Installiere Python3:"
        echo "     sudo apt-get update"
        echo "     sudo apt-get install -y python3"
        echo ""
        echo "  2. Führe dieses Script erneut aus:"
        echo "     bash check_python_requirements.sh"
    fi
    exit 1
fi

#!/bin/bash
# Regenerate D2 diagrams to SVG
# Requires: d2 CLI (https://d2lang.com)
#
# Usage: ./scripts/regenerate-diagrams.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
D2_DIR="$PROJECT_ROOT/diagrams/d2"
SVG_DIR="$PROJECT_ROOT/diagrams/svg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check D2 installation
check_d2() {
    if ! command -v d2 &> /dev/null; then
        echo -e "${YELLOW}WARNING: D2 CLI not installed.${NC}"
        echo "  Install: brew install d2 (macOS) or curl -fsSL https://d2lang.com/install.sh | sh"
        echo "  Using committed SVGs instead."
        exit 0
    fi

    D2_VERSION=$(d2 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    echo "D2 version: $D2_VERSION"
}

# Add accessibility attributes to SVG
add_accessibility() {
    local svg_file="$1"
    local name="$2"

    # Create human-readable title from filename
    local title=$(echo "$name" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')

    # Add role="img" if not present
    if ! grep -q 'role="img"' "$svg_file"; then
        sed -i 's/<svg /<svg role="img" aria-labelledby="title-'"$name"'" /' "$svg_file"
    fi

    # Add title element after opening svg tag if not present
    if ! grep -q '<title' "$svg_file"; then
        sed -i 's|\(<svg[^>]*>\)|\1\n  <title id="title-'"$name"'">'"$title"'</title>\n  <desc>Diagram showing '"$title"' for Omnibus Review</desc>|' "$svg_file"
    fi
}

# Generate SVGs from D2 files
generate_diagrams() {
    mkdir -p "$SVG_DIR"

    local count=0
    local errors=0

    for d2_file in "$D2_DIR"/*.d2; do
        [[ -e "$d2_file" ]] || continue

        local basename=$(basename "$d2_file" .d2)
        local svg_file="$SVG_DIR/$basename.svg"

        echo -n "Generating: $basename.svg ... "

        # Generate SVG with ELK layout and neutral theme
        if d2 --layout=elk --theme=0 --pad=20 "$d2_file" "$svg_file" 2>/dev/null; then
            add_accessibility "$svg_file" "$basename"
            echo -e "${GREEN}OK${NC}"
            ((count++))
        else
            echo -e "${RED}FAILED${NC}"
            echo "  Keeping existing SVG if present."
            ((errors++))
        fi
    done

    echo ""
    echo "Generated: $count SVGs"
    if [[ $errors -gt 0 ]]; then
        echo -e "${YELLOW}Errors: $errors${NC}"
    fi
}

# Validate generated SVGs
validate_svgs() {
    echo ""
    echo "Validating SVGs..."

    local valid=0
    local invalid=0

    for svg_file in "$SVG_DIR"/*.svg; do
        [[ -e "$svg_file" ]] || continue

        local basename=$(basename "$svg_file")

        # Check if xmllint is available
        if command -v xmllint &> /dev/null; then
            if xmllint --noout "$svg_file" 2>/dev/null; then
                # Check for accessibility
                if grep -q 'role="img"' "$svg_file" && grep -q '<title' "$svg_file"; then
                    echo -e "  ${GREEN}OK${NC}: $basename (valid XML, accessible)"
                    ((valid++))
                else
                    echo -e "  ${YELLOW}WARN${NC}: $basename (valid XML, missing accessibility)"
                    ((valid++))
                fi
            else
                echo -e "  ${RED}FAIL${NC}: $basename (invalid XML)"
                ((invalid++))
            fi
        else
            # No xmllint, just check file exists and has content
            if [[ -s "$svg_file" ]]; then
                echo -e "  ${GREEN}OK${NC}: $basename (file exists)"
                ((valid++))
            else
                echo -e "  ${RED}FAIL${NC}: $basename (empty file)"
                ((invalid++))
            fi
        fi
    done

    echo ""
    echo "Valid: $valid, Invalid: $invalid"

    if [[ $invalid -gt 0 ]]; then
        exit 1
    fi
}

# Main
echo "=== Omnibus Review Diagram Generator ==="
echo ""

check_d2
generate_diagrams
validate_svgs

echo ""
echo -e "${GREEN}Done!${NC} SVGs generated in diagrams/svg/"
echo "Remember to commit the updated SVGs."

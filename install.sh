#!/bin/sh
# RealBrowser by Ceki — installation script
# Installs ceki-sdk CLI and verifies environment.

set -e

echo "→ Installing ceki-sdk (Python CLI + SDK)..."
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --upgrade ceki-sdk --break-system-packages 2>/dev/null \
        || pip3 install --upgrade --user ceki-sdk
elif command -v pip >/dev/null 2>&1; then
    pip install --upgrade ceki-sdk --break-system-packages 2>/dev/null \
        || pip install --upgrade --user ceki-sdk
else
    echo "❌ pip not found. Install Python 3.10+ first."
    exit 1
fi

echo "→ Verifying ceki CLI in PATH..."
if ! command -v ceki >/dev/null 2>&1; then
    echo "⚠️  'ceki' command not found in PATH. Try adding ~/.local/bin to PATH:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    exit 1
fi

echo "→ ceki CLI version: $(ceki --version 2>/dev/null || echo unknown)"

# Check for API key
if [ -z "$CEKI_API_KEY" ]; then
    echo ""
    echo "→ No CEKI_API_KEY env var set."
    echo "  1. Sign up at https://ceki.me (email only, no KYC)"
    echo "  2. Dashboard → API keys → create one"
    echo "  3. Export in your shell:"
    echo "       export CEKI_API_KEY=\"your_key_here\""
else
    echo "→ CEKI_API_KEY is set."
    if command -v curl >/dev/null 2>&1; then
        INFO=$(curl -s -m 5 -H "Authorization: Bearer $CEKI_API_KEY" \
            https://api.ceki.me/api/auth/introspect 2>/dev/null || echo "")
        if [ -n "$INFO" ]; then
            echo "→ Token valid. Account: $(echo "$INFO" | grep -o '"name":"[^"]*"' | head -1)"
        fi
    fi
fi

echo ""
echo "✓ Installation complete."
echo ""
echo "Next steps:"
echo ""
echo "  USE marketplace browsers (paid \$0.01/min, USDC):"
echo "    ceki search --limit 5      # find available browsers"
echo "    ceki rent --schedule N     # rent one"
echo ""
echo "  USE your OWN Chrome for free (Self mode):"
echo "    Install the Ceki Chrome extension from:"
echo "      https://browser.ceki.me/install"
echo "    Your browser then appears in the marketplace as your own host,"
echo "    and YOUR agents can rent it for \$0 (host_user == renter_user)."
echo ""
echo "  See SKILL.md for full usage reference."
echo "  See examples/ for integration configs (Claude Desktop, Cursor, Cline)."

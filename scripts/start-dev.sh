#!/bin/bash
# =============================================================================
# Roboshare Local Development Environment
# =============================================================================
# This script starts all services needed for local development using tmux.
# Run this script in Ghostty (or any terminal) to spin up the full stack.
#
# Prerequisites:
#   - tmux (brew install tmux)
#   - Docker (for The Graph node)
#   - Node.js >= 20.18.3
#   - Foundry (anvil, forge)
#
# Usage:
#   ./scripts/start-dev.sh         # Start all services
#   ./scripts/start-dev.sh --reset # Clean graph node data and fresh deploy
#   ./scripts/start-dev.sh --kill  # Kill the dev session
# =============================================================================

set -e

SESSION="roboshare-dev"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESET_MODE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --reset)
            RESET_MODE=true
            shift
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              🚗 Roboshare Dev Environment 🚗                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

detect_lan_ip() {
    local interface=""
    local lan_ip=""

    interface=$(route -n get default 2>/dev/null | awk '/interface: / {print $2; exit}')
    if [ -n "$interface" ]; then
        lan_ip=$(ipconfig getifaddr "$interface" 2>/dev/null || true)
    fi

    if [ -z "$lan_ip" ]; then
        lan_ip=$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')
    fi

    echo "$lan_ip"
}

# Handle --kill flag
if [[ " $@ " =~ " --kill " ]]; then
    print_header
    if tmux has-session -t $SESSION 2>/dev/null; then
        # Gracefully stop Anvil (Pane 0) to ensure state saves
        tmux send-keys -t $SESSION:main.0 C-c 2>/dev/null
        echo "Stopping services..."
        sleep 2
        tmux kill-session -t $SESSION
        print_status "Killed session: $SESSION"
    else
        print_warning "No session found: $SESSION"
    fi
    exit 0
fi

# Check prerequisites
check_prerequisites() {
    local missing=0
    
    if ! command -v tmux &> /dev/null; then
        print_error "tmux is not installed. Run: brew install tmux"
        missing=1
    fi
    
    if ! command -v anvil &> /dev/null; then
        print_error "Foundry (anvil) is not installed. Run: curl -L https://foundry.paradigm.xyz | bash"
        missing=1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed (needed for Graph node)"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        exit 1
    fi
}

print_header
check_prerequisites

LAN_IP="$(detect_lan_ip)"

# Handle --reset mode: clean up graph node data and chain state
if [ "$RESET_MODE" = true ]; then
    print_warning "Reset mode enabled - cleaning graph node data and chain state..."
    cd "$ROOT_DIR"
    yarn subgraph:stop-node 2>/dev/null || true
    yarn subgraph:clean-node 2>/dev/null || true
    rm -rf protocols/evm/subgraph/graph-node/data 2>/dev/null || true
    rm -f protocols/evm/anvil-state.json 2>/dev/null || true
    rm -rf protocols/evm/broadcast/Deploy.s.sol/31337 2>/dev/null || true
    print_status "Graph node data and chain state cleaned"
fi

# Kill existing session if it exists
if tmux has-session -t $SESSION 2>/dev/null; then
    print_warning "Killing existing session: $SESSION"
    tmux kill-session -t $SESSION
fi

print_status "Creating new tmux session: $SESSION"

# =============================================================================
# LAYOUT:
# ┌───────────────────────────┬───────────────────────────┬───────────────────┐
# │                           │                           │                   │
# │   0: Anvil (Chain Logs)   │   1: Web App (Next.js)    │   2: Deploy       │
# │                           │                           │                   │
# ├───────────────────────────┼───────────────────────────┼───────────────────┤
# │                           │                           │                   │
# │   3: Graph Node (Docker)  │   4: Subgraph Deploy      │   5: Shell        │
# │                           │                           │                   │
# └───────────────────────────┴───────────────────────────┴───────────────────┘
# =============================================================================

# Determine deploy command based on reset mode and existing state
DEPLOY_CMD="yarn deploy"
if [ "$RESET_MODE" = true ]; then
    DEPLOY_CMD="yarn deploy --reset"
elif [ -f "protocols/evm/anvil-state.json" ]; then
    echo "Found existing chain state. Skipping fresh deployment."
    DEPLOY_CMD="echo '🔄 Found existing chain state. Skipping deployment.' && cd protocols/evm && make generate-abis"
fi

# Create session with first window named 'main'
tmux new-session -d -s $SESSION -n 'main' -c "$ROOT_DIR"

# Create a 2x3 grid layout
# First split into left and right (creates pane 1)
tmux split-window -h -t $SESSION:main -c "$ROOT_DIR"

# Split right side into 3 rows (creates panes 2, 3)
tmux split-window -v -t $SESSION:main.1 -c "$ROOT_DIR"
tmux split-window -v -t $SESSION:main.1 -c "$ROOT_DIR"

# Split left side into 3 rows (creates panes 4, 5 - but after balancing it's different)
tmux split-window -v -t $SESSION:main.0 -c "$ROOT_DIR"
tmux split-window -v -t $SESSION:main.0 -c "$ROOT_DIR"

# Balance all panes
tmux select-layout -t $SESSION:main tiled

# Now send commands to each pane (pane numbers after tiled layout: 0-5)
# Pane 0: Anvil (Local Blockchain)
tmux send-keys -t $SESSION:main.0 "echo '🔗 Starting Anvil (Local Blockchain)...'" Enter
tmux send-keys -t $SESSION:main.0 "yarn chain" Enter

# Pane 1: Next.js Web App
tmux send-keys -t $SESSION:main.1 "echo '🌐 Starting Next.js Web App...'" Enter
tmux send-keys -t $SESSION:main.1 "sleep 10 && yarn start" Enter

# Pane 2: Deploy contracts
tmux send-keys -t $SESSION:main.2 "echo '⏳ Waiting for chain to start...'" Enter
tmux send-keys -t $SESSION:main.2 "sleep 3 && echo '📦 Deploying contracts...' && $DEPLOY_CMD" Enter

# Pane 3: Graph Node (Docker)
tmux send-keys -t $SESSION:main.3 "echo '📊 Graph Node - waiting for contracts to deploy...'" Enter
tmux send-keys -t $SESSION:main.3 "echo 'Starting Graph node in 5 seconds...'" Enter
tmux send-keys -t $SESSION:main.3 "sleep 5 && yarn subgraph:run-node" Enter

# Pane 4: Subgraph deployment
if [ "$RESET_MODE" = true ]; then
    tmux send-keys -t $SESSION:main.4 "echo '📡 Subgraph Deploy (reset mode)...'" Enter
    tmux send-keys -t $SESSION:main.4 "echo 'Waiting for Graph node (60s)...'" Enter
    tmux send-keys -t $SESSION:main.4 "sleep 60 && yarn subgraph:create-local && yarn subgraph:local-ship-auto" Enter
else
    tmux send-keys -t $SESSION:main.4 "echo '📡 Subgraph Deploy...'" Enter
    tmux send-keys -t $SESSION:main.4 "echo 'Waiting for Graph node (60s)...'" Enter
    tmux send-keys -t $SESSION:main.4 "sleep 60 && yarn subgraph:local-ship-auto" Enter
fi

# Pane 5: Shell for commands - show quick reference
tmux send-keys -t $SESSION:main.5 "./scripts/quick-commands.sh" Enter

# Balance panes in a 3x2 grid
tmux select-layout -t $SESSION:main tiled

print_status "Services starting in tmux session"
echo ""
echo -e "${BLUE}Services:${NC}"
echo "  • Pane 0: Anvil - Local blockchain logs"
echo "  • Pane 1: Next.js - Web app (http://localhost:3000)"
echo "  • Pane 2: Contract deployment"
echo "  • Pane 3: Graph Node (Docker)"
echo "  • Pane 4: Subgraph deployment"
echo "  • Pane 5: Shell - Quick commands"
if [ -n "$LAN_IP" ]; then
    echo ""
    echo -e "${BLUE}LAN Endpoints:${NC}"
    echo "  • Web app:    http://$LAN_IP:3000"
    echo "  • Chain RPC:  http://$LAN_IP:8545"
    echo "  • GraphQL:    http://$LAN_IP:8000/subgraphs/name/roboshare/protocol"
    echo "  • Graph admin:http://$LAN_IP:8020"
    echo "  • IPFS API:   http://$LAN_IP:5001"
    echo "  • IPFS GW:    http://$LAN_IP:8080"
fi
echo ""
echo -e "${GREEN}Attaching to session...${NC}"
echo ""

# Attach to session
tmux attach -t $SESSION

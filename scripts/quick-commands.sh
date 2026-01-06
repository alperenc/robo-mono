#!/bin/bash
# Quick Commands Reference - displayed in pane 5

cat << 'EOF'

═══════════════════════════════════════════════════════════════
                      📋 Quick Commands
═══════════════════════════════════════════════════════════════

  🧪 TESTING
  ─────────────────────────────────────────────────────────────
  yarn test                                   Run all tests
  yarn test --match-contract Treasury         Test specific contract
  yarn test --match-test testFunctionName     Test specific function
  yarn coverage --ir-minimum                  Check code coverage

  📦 CONTRACTS
  ─────────────────────────────────────────────────────────────
  yarn deploy                                 Deploy contracts
  yarn deploy --reset                         Fresh deploy (reset state)
  yarn compile                                Compile contracts
  yarn verify                                 Verify on explorer

  📊 SUBGRAPH
  ─────────────────────────────────────────────────────────────
  yarn subgraph:local-ship                    Build & deploy subgraph
  yarn subgraph:stop-node                     Stop Graph node
  yarn subgraph:test                          Run subgraph tests

  🔧 UTILITIES
  ─────────────────────────────────────────────────────────────
  yarn format                                 Format all code
  yarn lint                                   Lint all code
  yarn graphclient:build                      Rebuild GraphQL client

  🖥️  TMUX SHORTCUTS
  ─────────────────────────────────────────────────────────────
  Ctrl+b arrow keys    Navigate panes
  Ctrl+b [             Scroll mode (q to exit)
  Ctrl+b z             Zoom current pane
  Ctrl+b d             Detach session

  yarn dev:kill        Kill this dev session

═══════════════════════════════════════════════════════════════

EOF

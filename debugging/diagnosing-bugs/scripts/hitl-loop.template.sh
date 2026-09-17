#!/usr/bin/env bash
# Human-in-the-loop reproduction loop.
# Copy this file, edit the steps below, and run it.
# The agent runs the script; the user follows prompts in their terminal.
#
# Usage:
#   bash hitl-loop.template.sh
#
# Two helpers:
#   step "<instruction>"          -> show instruction, wait for Enter
#   capture VAR "<question>"      -> show question, read response into VAR
#
# At the end, captured values are printed as KEY=VALUE for the agent to parse.

set -euo pipefail

function step() {
    local instruction="${1}"

    printf '\n>>> %s\n' "${instruction}"
    read -r -p "    [Enter when done] " _
}

function capture() {
    local var="${1}"
    local question="${2}"
    local answer

    printf '\n>>> %s\n' "${question}"
    read -r -p "    > " answer
    printf -v "${var}" '%s' "${answer}"
}

# --- edit below ---------------------------------------------------------

declare FAILED=""
declare LAST_LINE=""

step "Power-cycle the device and wait for the boot prompt."

capture FAILED "Did the unit reach a login prompt? (y/n)"

capture LAST_LINE "Paste the last line printed on the console (or 'none'):"

printf '\n--- Captured ---\n'
printf 'FAILED=%s\n' "${FAILED}"
printf 'LAST_LINE=%s\n' "${LAST_LINE}"

# --- edit above ---------------------------------------------------------

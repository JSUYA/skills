#!/usr/bin/env bash
# Plugin regression test runner for flutter-tizen plugins.
# Companion to ../SKILL.md.

set -eu

# Configuration
PLUGINS_REPO="${PLUGINS_REPO:-$HOME/workspace/plugins}"
TV_EMULATOR_ID="${TV_EMULATOR_ID:-T-samsung-9.0-x86}"
DEVICE_ID="${DEVICE_ID:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.config/flutter-tizen-regression-test}"
APP_PID=""

# Testable plugins — read from the plugins repo's .github/recipe.yaml at run
# time (see ../SKILL.md "Testable Plugins"); a hardcoded list goes stale as
# plugins are added or excluded upstream.
load_testable_plugins() {
    local recipe_file="$PLUGINS_REPO/.github/recipe.yaml"
    if [[ ! -f "$recipe_file" ]]; then
        log_error "Could not find recipe.yaml at: $recipe_file"
        log_error "Please verify your PLUGINS_REPO env variable or the --plugins-repo argument."
        return 1
    fi
    # mapfile requires Bash 4+; macOS ships Bash 3.2, so build the array with
    # a portable read loop instead.
    TESTABLE_PLUGINS=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && TESTABLE_PLUGINS+=("$line")
    done < <(grep -E '\[[^]]*"tv-9.0"[^]]*\]' "$recipe_file" | tr -d ' ' | cut -d: -f1)
    if [[ ${#TESTABLE_PLUGINS[@]} -eq 0 ]]; then
        log_error "No tv-9.0 plugins found in $recipe_file"
        return 1
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

stop_app() {
    if [[ -n "$APP_PID" ]]; then
        kill "$APP_PID" 2>/dev/null || true
        wait "$APP_PID" 2>/dev/null || true
        APP_PID=""
    fi
}
trap stop_app EXIT

# Verify environment prerequisites
verify_environment() {
    log_info "Verifying environment..."
    
    # Check flutter-tizen
    if ! command -v flutter-tizen &> /dev/null; then
        log_error "flutter-tizen not found on PATH"
        return 1
    fi
    log_info "flutter-tizen: $(flutter-tizen --version)"
    
    # Check Tizen SDK
    if ! command -v sdb &> /dev/null; then
        log_error "sdb not found on PATH"
        return 1
    fi
    log_info "sdb: $(sdb version)"
    
    if ! command -v tizen &> /dev/null; then
        log_error "tizen CLI not found on PATH"
        return 1
    fi
    log_info "tizen: $(tizen version)"
    
    # Check certificate profile
    if ! tizen security-profiles list | grep -q "Active"; then
        log_error "No active certificate profile found"
        return 1
    fi
    log_info "Certificate profile: active"
    
    # Check plugins repository
    if [[ ! -d "$PLUGINS_REPO" ]]; then
        log_error "Plugins repository not found: $PLUGINS_REPO"
        return 1
    fi
    log_info "Plugins repository: $PLUGINS_REPO"
    
    return 0
}

find_tv_emulator() {
    local id status rest
    while read -r id status rest; do
        [[ "$id" == emulator-* && "$status" == device ]] || continue
        if sdb -s "$id" capability 2>/dev/null | grep -q '^profile_name:tv'; then
            printf '%s\n' "$id"
            return 0
        fi
    done < <(sdb devices)
    return 1
}

# Launch TV emulator if not running. TV_EMULATOR_ID names an emulator config;
# DEVICE_ID names the connected sdb target created from that config.
launch_emulator() {
    log_info "Checking TV emulator status..."

    if [[ -n "$DEVICE_ID" ]]; then
        sdb devices | awk -v id="$DEVICE_ID" '$1 == id && $2 == "device" { found = 1 } END { exit !found }' || {
            log_error "Device is not connected: $DEVICE_ID"
            return 1
        }
        return 0
    fi

    DEVICE_ID="$(find_tv_emulator || true)"
    if [[ -n "$DEVICE_ID" ]]; then
        log_info "TV emulator already running: $DEVICE_ID"
        return 0
    fi

    log_info "Launching TV emulator: $TV_EMULATOR_ID"
    flutter-tizen emulators --launch "$TV_EMULATOR_ID" || {
        log_error "Failed to launch emulator"
        return 1
    }

    local retries=60
    while [[ $retries -gt 0 ]]; do
        DEVICE_ID="$(find_tv_emulator || true)"
        if [[ -n "$DEVICE_ID" ]]; then
            log_info "Emulator ready: $DEVICE_ID"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done

    log_error "Emulator did not become ready in time"
    return 1
}

# Run example app for a plugin
run_example_app() {
    local plugin_name="$1"
    local example_dir="$PLUGINS_REPO/packages/$plugin_name/example"
    local log_file="$OUTPUT_DIR/logs/${plugin_name}_example_run.log"
    
    if [[ ! -d "$example_dir" ]]; then
        log_warn "Example directory not found: $example_dir"
        return 1
    fi
    
    log_info "Running example app for: $plugin_name"
    cd "$example_dir"

    # NOTE: `sdb dlog` does NOT work on the Samsung TV emulator
    # (secure_protocol:enabled, intershell_support:disabled) — it returns no
    # output, so it must not be used as a log source here. The foreground
    # `flutter-tizen run` session is the only log channel that works on TV; it
    # streams Dart print/debugPrint and engine messages, which we capture below.
    mkdir -p "$OUTPUT_DIR/logs"
    : > "$log_file"
    flutter-tizen -d "$DEVICE_ID" run --debug > "$log_file" 2>&1 &
    APP_PID=$!

    local retries=300
    while [[ $retries -gt 0 ]]; do
        grep -qE 'http://127\.0\.0\.1:[0-9]+/' "$log_file" && break
        if ! kill -0 "$APP_PID" 2>/dev/null; then
            wait "$APP_PID" 2>/dev/null || true
            APP_PID=""
            log_error "App exited before publishing a VM Service URL"
            return 1
        fi
        sleep 1
        retries=$((retries - 1))
    done
    if [[ $retries -eq 0 ]]; then
        stop_app
        log_error "Timed out waiting for the VM Service URL"
        return 1
    fi

    # Let the launched app run briefly after startup.
    sleep 15
    stop_app

    log_info "Example app run completed for: $plugin_name"
    return 0
}

# Check and run integration tests
run_integration_tests() {
    local plugin_name="$1"
    local example_dir="$PLUGINS_REPO/packages/$plugin_name/example"
    local test_output="$OUTPUT_DIR/logs/${plugin_name}_test_output.log"
    
    if [[ ! -d "$example_dir/test_driver" || ! -d "$example_dir/integration_test" ]]; then
        log_warn "No integration tests for: $plugin_name"
        return 0
    fi
    
    log_info "Running integration tests for: $plugin_name"
    cd "$example_dir"
    : > "$test_output"
    local failed=false
    
    # Run each test file
    for test_file in "$example_dir/integration_test"/*.dart; do
        if [[ -f "$test_file" ]]; then
            local test_name=$(basename "$test_file" .dart)
            log_info "Running test: $test_name"
            
            flutter-tizen drive \
                --driver=test_driver/integration_test.dart \
                --target="integration_test/$test_name.dart" \
                -d "$DEVICE_ID" \
                --debug >> "$test_output" 2>&1 || {
                log_error "Test failed: $test_name"
                failed=true
            }
        fi
    done
    
    [[ "$failed" == false ]]
}

# Analyze logs for issues
analyze_logs() {
    local plugin_name="$1"
    local log_file="$OUTPUT_DIR/logs/${plugin_name}_example_run.log"
    local issues_file="$OUTPUT_DIR/logs/${plugin_name}_issues.txt"
    
    if [[ ! -f "$log_file" ]]; then
        log_warn "Log file not found: $log_file"
        return 1
    fi
    
    log_info "Analyzing logs for: $plugin_name"

    # Run-console patterns only; dlog/logcat prefixes never appear here.
    local pattern='Unhandled Exception|EXCEPTION CAUGHT BY|PlatformException|SIGSEGV|SIGABRT|Failed to|Error:'
    local issue_count
    issue_count=$(grep -Eci "$pattern" "$log_file" 2>/dev/null || true)
    rm -f "$issues_file"
    if [[ $issue_count -gt 0 ]]; then
        echo "Failure indicators: $issue_count" > "$issues_file"
        grep -Ei "$pattern" "$log_file" >> "$issues_file" || true
        log_warn "Issues found for $plugin_name - see $issues_file"
        return 1
    fi

    log_info "No critical issues found for: $plugin_name"
    return 0
}

# Generate summary report
generate_report() {
    local plugin_name="$1"
    local result="$2"
    local report_file="$OUTPUT_DIR/reports/$(date +%Y%m%d_%H%M%S)_${plugin_name}_report.md"
    
    mkdir -p "$OUTPUT_DIR/reports"
    
    cat > "$report_file" << EOF
# Flutter-Tizen Plugin Regression Test Report

**Date:** $(date -Iseconds)
**Plugin:** $plugin_name
**Device:** TV 9.0 Emulator ($DEVICE_ID)
**flutter-tizen version:** $(flutter-tizen --version)
**Result:** $result

## Summary

Check logs in: $OUTPUT_DIR/logs/${plugin_name}_*

## Log Files

- Example run log: $OUTPUT_DIR/logs/${plugin_name}_example_run.log
- Test output: $OUTPUT_DIR/logs/${plugin_name}_test_output.log

EOF

    log_info "Report generated: $report_file"
}

# Main function
main() {
    local plugin_name=""
    local run_all=false
    local failed=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --plugin)
                plugin_name="$2"
                shift 2
                ;;
            --all)
                run_all=true
                shift
                ;;
            --plugins-repo)
                PLUGINS_REPO="$2"
                shift 2
                ;;
            --emulator-id)
                TV_EMULATOR_ID="$2"
                shift 2
                ;;
            --device-id)
                DEVICE_ID="$2"
                shift 2
                ;;
            *)
                echo "Usage: $0 [--plugin <name> | --all] [--plugins-repo <path>] [--emulator-id <id>] [--device-id <id>]"
                exit 1
                ;;
        esac
    done
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR/logs" "$OUTPUT_DIR/reports"
    
    # Verify environment
    verify_environment || exit 1
    
    # Launch emulator
    launch_emulator || exit 1
    
    if [[ "$run_all" == true ]]; then
        load_testable_plugins || exit 1
        log_info "Running regression tests for all plugins..."
        for plugin in "${TESTABLE_PLUGINS[@]}"; do
            log_info "Testing plugin: $plugin"
            local result=PASS
            run_example_app "$plugin" || result=FAIL
            run_integration_tests "$plugin" || result=FAIL
            analyze_logs "$plugin" || result=FAIL
            generate_report "$plugin" "$result"
            [[ "$result" == PASS ]] || failed=true
        done
    elif [[ -n "$plugin_name" ]]; then
        log_info "Running regression test for plugin: $plugin_name"
        local result=PASS
        run_example_app "$plugin_name" || result=FAIL
        run_integration_tests "$plugin_name" || result=FAIL
        analyze_logs "$plugin_name" || result=FAIL
        generate_report "$plugin_name" "$result"
        [[ "$result" == PASS ]] || failed=true
    else
        echo "Usage: $0 [--plugin <name> | --all]"
        exit 1
    fi
    
    if [[ "$failed" == true ]]; then
        log_error "Regression test failed"
        return 1
    fi
    log_info "Regression test completed"
}

main "$@"

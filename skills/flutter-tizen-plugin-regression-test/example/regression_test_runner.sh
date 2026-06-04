#!/usr/bin/env bash
# Plugin regression test runner for flutter-tizen plugins.
# Companion to ../SKILL.md.

set -eu

# Configuration
PLUGINS_REPO="${PLUGINS_REPO:-$HOME/workspace/plugins}"
TV_EMULATOR_ID="${TV_EMULATOR_ID:-emulator-26111}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.config/flutter-tizen-regression-test}"
CONFIG_FILE="$OUTPUT_DIR/config.json"

# Testable plugins (from .github/recipe.yaml)
TESTABLE_PLUGINS=(
    "audioplayers"
    "connectivity_plus"
    "device_info_plus"
    "flutter_secure_storage"
    "flutter_inappwebview"
    "flutter_tts"
    "integration_test"
    "keyboard_detection"
    "messageport"
    "package_info_plus"
    "path_provider"
    "shared_preferences"
    "sqflite"
    "tizen_app_manager"
    "tizen_audio_manager"
    "tizen_bundle"
    "tizen_package_manager"
    "tizen_rpc_port"
    "tizen_window_manager"
    "url_launcher"
    "wakelock_plus"
)

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

# Launch TV emulator if not running
launch_emulator() {
    log_info "Checking TV emulator status..."
    
    if sdb devices | grep -q "$TV_EMULATOR_ID"; then
        log_info "TV emulator already running: $TV_EMULATOR_ID"
        return 0
    fi
    
    log_info "Launching TV emulator..."
    flutter-tizen emulators --launch "$TV_EMULATOR_ID" || {
        log_error "Failed to launch emulator"
        return 1
    }
    
    # Wait for emulator to be ready
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if sdb devices | grep -q "$TV_EMULATOR_ID.*device"; then
            log_info "Emulator ready: $TV_EMULATOR_ID"
            return 0
        fi
        sleep 2
        ((retries--))
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
    
    # Clear log buffer
    sdb -s "$TV_EMULATOR_ID" dlog -c
    
    # Run the app in background
    mkdir -p "$OUTPUT_DIR/logs"
    flutter-tizen -d "$TV_EMULATOR_ID" run --debug > "$log_file" 2>&1 &
    local app_pid=$!
    
    # Capture logs in separate file
    local dlog_file="$OUTPUT_DIR/logs/${plugin_name}_dlog.log"
    sdb -s "$TV_EMULATOR_ID" dlog ConsoleMessage:V FlutterEngine:I *:S > "$dlog_file" 2>&1 &
    local dlog_pid=$!
    
    # Wait for app to start
    sleep 10
    
    # Check if app is running
    if ! kill -0 $app_pid 2>/dev/null; then
        log_error "App crashed during startup"
        kill $dlog_pid 2>/dev/null || true
        return 1
    fi
    
    # Let the app run for a bit
    sleep 15
    
    # Stop the app and log capture
    kill $app_pid 2>/dev/null || true
    kill $dlog_pid 2>/dev/null || true
    
    log_info "Example app run completed for: $plugin_name"
    return 0
}

# Check and run integration tests
run_integration_tests() {
    local plugin_name="$1"
    local example_dir="$PLUGINS_REPO/packages/$plugin_name/example"
    local test_output="$OUTPUT_DIR/logs/${plugin_name}_test_output.log"
    
    if [[ ! -d "$example_dir/test_driver" ]]; then
        log_warn "No test_driver directory for: $plugin_name"
        return 1
    fi
    
    if [[ ! -d "$example_dir/integration_test" ]]; then
        log_warn "No integration_test directory for: $plugin_name"
        return 1
    fi
    
    log_info "Running integration tests for: $plugin_name"
    cd "$example_dir"
    
    # Run each test file
    for test_file in "$example_dir/integration_test"/*.dart; do
        if [[ -f "$test_file" ]]; then
            local test_name=$(basename "$test_file" .dart)
            log_info "Running test: $test_name"
            
            flutter-tizen drive \
                --driver=test_driver/integration_test.dart \
                --target="integration_test/$test_name.dart" \
                -d "$TV_EMULATOR_ID" \
                --debug >> "$test_output" 2>&1 || {
                log_error "Test failed: $test_name"
            }
        fi
    done
    
    return 0
}

# Analyze logs for issues
analyze_logs() {
    local plugin_name="$1"
    local log_file="$OUTPUT_DIR/logs/${plugin_name}_dlog.log"
    local issues_file="$OUTPUT_DIR/logs/${plugin_name}_issues.txt"
    
    if [[ ! -f "$log_file" ]]; then
        log_warn "Log file not found: $log_file"
        return 1
    fi
    
    log_info "Analyzing logs for: $plugin_name"
    
    # Check for fatal errors
    local fatal_count=$(grep -c "^F/" "$log_file" 2>/dev/null || echo "0")
    if [[ $fatal_count -gt 0 ]]; then
        echo "FATAL errors: $fatal_count" >> "$issues_file"
        grep "^F/" "$log_file" >> "$issues_file"
    fi
    
    # Check for Flutter engine errors
    local engine_error_count=$(grep -c "E/FlutterEngine\|E/FlutterJNI" "$log_file" 2>/dev/null || echo "0")
    if [[ $engine_error_count -gt 0 ]]; then
        echo "Flutter engine errors: $engine_error_count" >> "$issues_file"
        grep "E/FlutterEngine\|E/FlutterJNI" "$log_file" >> "$issues_file"
    fi
    
    # Check for crashes
    local crash_count=$(grep -ci "SIGSEGV\|SIGABRT\|crash" "$log_file" 2>/dev/null || echo "0")
    if [[ $crash_count -gt 0 ]]; then
        echo "Crash indicators: $crash_count" >> "$issues_file"
        grep -i "SIGSEGV\|SIGABRT\|crash" "$log_file" >> "$issues_file"
    fi
    
    # Check for exceptions
    local exception_count=$(grep -ci "exception\|error:" "$log_file" 2>/dev/null || echo "0")
    if [[ $exception_count -gt 0 ]]; then
        echo "Exceptions/Errors: $exception_count" >> "$issues_file"
    fi
    
    if [[ -f "$issues_file" ]]; then
        log_warn "Issues found for $plugin_name - see $issues_file"
        return 1
    else
        log_info "No critical issues found for: $plugin_name"
        return 0
    fi
}

# Generate summary report
generate_report() {
    local plugin_name="$1"
    local report_file="$OUTPUT_DIR/reports/$(date +%Y%m%d_%H%M%S)_${plugin_name}_report.md"
    
    mkdir -p "$OUTPUT_DIR/reports"
    
    cat > "$report_file" << EOF
# Flutter-Tizen Plugin Regression Test Report

**Date:** $(date -Iseconds)
**Plugin:** $plugin_name
**Device:** TV 9.0 Emulator ($TV_EMULATOR_ID)
**flutter-tizen version:** $(flutter-tizen --version)

## Summary

Test completed. Check logs in: $OUTPUT_DIR/logs/${plugin_name}_*

## Log Files

- Example run log: $OUTPUT_DIR/logs/${plugin_name}_example_run.log
- Dlog output: $OUTPUT_DIR/logs/${plugin_name}_dlog.log
- Test output: $OUTPUT_DIR/logs/${plugin_name}_test_output.log

EOF

    log_info "Report generated: $report_file"
}

# Main function
main() {
    local plugin_name=""
    local run_all=false
    
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
            *)
                echo "Usage: $0 [--plugin <name> | --all] [--plugins-repo <path>] [--emulator-id <id>]"
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
        log_info "Running regression tests for all plugins..."
        for plugin in "${TESTABLE_PLUGINS[@]}"; do
            log_info "Testing plugin: $plugin"
            run_example_app "$plugin" || true
            run_integration_tests "$plugin" || true
            analyze_logs "$plugin" || true
            generate_report "$plugin"
        done
    elif [[ -n "$plugin_name" ]]; then
        log_info "Running regression test for plugin: $plugin_name"
        run_example_app "$plugin_name"
        run_integration_tests "$plugin_name" || true
        analyze_logs "$plugin_name"
        generate_report "$plugin_name"
    else
        echo "Usage: $0 [--plugin <name> | --all]"
        exit 1
    fi
    
    log_info "Regression test completed!"
}

main "$@"

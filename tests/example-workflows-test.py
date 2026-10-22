#!/usr/bin/env python3
"""Exercise example scripts with controlled CLI results; no SDK or device needed."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SETUP = ROOT / "skills/flutter-tizen-setup/example/setup.sh"
REGRESSION = ROOT / "skills/flutter-tizen-plugin-regression-test/example/regression_test_runner.sh"
DEVICE = ROOT / "skills/flutter-tizen-device/example/device_session.sh"

FAKE_CLI = r'''#!/usr/bin/env bash
set -eu
tool=${0##*/}
printf '%s %s\n' "$tool" "$*" >> "$PROBE_LOG"
case "$tool $*" in
    'flutter-tizen --version')
        [[ $SCENARIO != version-error ]] || exit 23
        echo 'Flutter-Tizen fixture'
        ;;
    'flutter-tizen doctor -v')
        [[ $SCENARIO != doctor-empty ]] || exit 0
        echo '[!] Flutter (Channel [user-branch])'
        if [[ $SCENARIO == doctor-tizen-broken ]]; then
            echo '[✗] Tizen toolchain - develop for Tizen devices'
        else
            echo '[✓] Tizen toolchain - develop for Tizen devices'
        fi
        echo '[✗] Android toolchain - Unable to locate Android SDK'
        [[ $SCENARIO != doctor-command-error ]] || exit 23
        ;;
    'sdb version')
        [[ $SCENARIO != sdb-error ]] || exit 23
        echo 'Smart Development Bridge version 4.2.36'
        ;;
    'tizen security-profiles list')
        echo '[Profile Name]      [Active]'
        case $SCENARIO in
            profiles-error) echo 'fixture query failed' >&2; exit 23 ;;
            profiles-empty) ;;
            profiles-inactive) echo 'fixture profile     X' ;;
            *) echo 'fixture profile     O' ;;
        esac
        ;;
    'flutter-tizen create demo')
        [[ $SCENARIO != create-error ]] || exit 23
        mkdir demo
        ;;
    'flutter-tizen build tpk '*)
        [[ $SCENARIO != build-error ]] || exit 23
        mkdir -p build/tizen/tpk
        touch build/tizen/tpk/fixture.tpk
        ;;
    'sdb connect '*|'sdb disconnect '*) ;;
    'sdb devices')
        echo 'List of devices attached'
        state=device
        [[ $SCENARIO != device-offline ]] || state=offline
        printf '%s\t%s\tfixture-device\n' "$DEVICE_ID" "$state"
        ;;
    'flutter-tizen devices') echo "$DEVICE_ID (Tizen)" ;;
    'flutter-tizen run '*)
        [[ $SCENARIO != run-error ]] || exit 23
        echo 'A Dart VM Service on fixture is available at: http://127.0.0.1:12345/token=/'
        ;;
    *) echo "Unexpected command: $tool $*" >&2; exit 64 ;;
esac
'''


class ExampleWorkflowsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.bin = self.work / "bin"
        self.bin.mkdir()
        for tool in ("flutter-tizen", "sdb", "tizen"):
            path = self.bin / tool
            path.write_text(FAKE_CLI)
            path.chmod(0o755)
        self.trace = self.work / "calls.log"
        self.env = {
            **os.environ,
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "TMPDIR": str(self.work),
            "FLUTTER_TIZEN_HOME": "",
            "TIZEN_SDK_TOOLS": "",
            "PLUGINS_REPO": str(self.work),
            "OUTPUT_DIR": str(self.work / "output"),
            "PROBE_LOG": str(self.trace),
            "DEVICE_IP": "127.0.0.1",
            "DEVICE_ID": "127.0.0.1:26101",
        }

    def run_example(self, script, scenario="ready"):
        self.trace.write_text("")
        if script == REGRESSION:
            command = ["bash", "-c", 'source "$1"; verify_environment', "test", str(script)]
        else:
            command = ["bash", str(script)]
        return subprocess.run(
            command, cwd=self.work, env={**self.env, "SCENARIO": scenario},
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20,
        )

    def test_preflight_accepts_tizen_with_unrelated_doctor_errors(self):
        for script in (SETUP, REGRESSION):
            with self.subTest(script=script.parent.parent.name):
                result = self.run_example(script)
                self.assertEqual(result.returncode, 0, result.stdout)
                calls = self.trace.read_text().splitlines()
                self.assertIn("flutter-tizen doctor -v", calls)
                self.assertIn("tizen security-profiles list", calls)
                self.assertNotIn("tizen version", calls)

    def test_preflight_rejects_missing_evidence_and_actual_errors(self):
        for script in (SETUP, REGRESSION):
            for scenario in (
                "version-error", "sdb-error", "doctor-empty", "doctor-tizen-broken",
                "doctor-command-error", "profiles-empty", "profiles-inactive", "profiles-error",
            ):
                with self.subTest(script=script.parent.parent.name, scenario=scenario):
                    result = self.run_example(script, scenario)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertNotIn("flutter-tizen build", self.trace.read_text())

    def test_smoke_build_failures_are_not_reported_as_setup_complete(self):
        for scenario in ("create-error", "build-error"):
            with self.subTest(scenario=scenario):
                result = self.run_example(SETUP, scenario)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("Setup complete.", result.stdout)
                calls = self.trace.read_text()
                self.assertIn("flutter-tizen create demo", calls)
                if scenario == "build-error":
                    self.assertIn("flutter-tizen build tpk", calls)

    def test_device_session_keeps_host_url_and_cleans_up(self):
        result = self.run_example(DEVICE)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("http://127.0.0.1:12345/token=/", result.stdout)
        self.assertIn("sdb disconnect 127.0.0.1:26101", self.trace.read_text())

    def test_device_failure_is_not_hidden_by_cleanup(self):
        for scenario in ("device-offline", "run-error"):
            with self.subTest(scenario=scenario):
                result = self.run_example(DEVICE, scenario)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                calls = self.trace.read_text()
                self.assertIn("sdb disconnect 127.0.0.1:26101", calls)
                if scenario == "device-offline":
                    self.assertNotIn("flutter-tizen run", calls)

    def test_portable_and_cursor_rule_bodies_match(self):
        bodies = [(ROOT / "rules" / name).read_text().split("---", 2)[2].strip()
                  for name in ("flutter_tizen_cli.md", "flutter_tizen_cli.mdc")]
        self.assertEqual(*bodies)


if __name__ == "__main__":
    unittest.main(verbosity=2)

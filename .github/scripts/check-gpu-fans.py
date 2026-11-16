#!/usr/bin/env python3
"""Test fan-control behavior without NVIDIA hardware or root permission."""

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "system/imrl/usr/local/libexec/nvidia-gpu-fans-max.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("gpu_fans", SCRIPT)
fans = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = fans
spec.loader.exec_module(fans)


class FakeNvml:
    def __init__(self, count=8, fan_count=1):
        self.count = count
        self.fan_counts = [fan_count] * count
        self.states = {
            (gpu, fan): (fans.MANUAL, 100) if gpu < 6 else (fans.AUTOMATIC, 30)
            for gpu in range(count) for fan in range(fan_count)
        }
        self.writes = []
        self.fail_at = None
        self.ignore_at = None

    def uint(self, name, *args):
        if name == "nvmlDeviceGetCount_v2":
            return self.count
        if name == "nvmlDeviceGetNumFans":
            return self.fan_counts[args[0]]
        raise AssertionError(name)

    def handle(self, index):
        return index

    def uuid(self, handle):
        return f"GPU-test-{handle}"

    def policy(self, handle, fan):
        return self.states[handle, fan][0]

    def target(self, handle, fan):
        return self.states[handle, fan][1]

    def set_speed(self, handle, fan, speed):
        key = (handle, fan)
        self.writes.append((key, speed))
        if key == self.ignore_at:
            return
        self.states[key] = (fans.MANUAL, speed)
        if key == self.fail_at:
            self.fail_at = None
            raise RuntimeError("Injected error after a partial write")

    def automatic(self, handle, fan):
        self.writes.append(((handle, fan), "automatic"))
        self.states[handle, fan] = (fans.AUTOMATIC, 30)


class FanTests(unittest.TestCase):
    def setUp(self):
        self.output = io.StringIO()
        self.stdout = redirect_stdout(self.output)
        self.stderr = redirect_stderr(self.output)
        self.stdout.__enter__()
        self.stderr.__enter__()
        self.addCleanup(self.stdout.__exit__, None, None, None)
        self.addCleanup(self.stderr.__exit__, None, None, None)

    def test_read_only_check_never_writes(self):
        nvml = FakeNvml()
        self.assertEqual(len(fans.collect_fans(nvml)), 8)
        self.assertEqual(nvml.writes, [])

    def test_wrong_device_count_never_writes(self):
        for count in (7, 9):
            nvml = FakeNvml(count=count)
            with self.assertRaises(RuntimeError):
                fans.collect_fans(nvml)
            self.assertEqual(nvml.writes, [])

    def test_late_preflight_failure_never_writes(self):
        nvml = FakeNvml()
        nvml.fan_counts[7] = 0
        with self.assertRaises(RuntimeError):
            fans.collect_fans(nvml)
        self.assertEqual(nvml.writes, [])

    def test_all_fans_on_each_gpu_are_set(self):
        nvml = FakeNvml(fan_count=2)
        fans.apply_full_speed(nvml, fans.collect_fans(nvml))
        self.assertEqual(len(nvml.writes), 16)
        self.assertTrue(all(state == (fans.MANUAL, 100)
                            for state in nvml.states.values()))

    def test_partial_write_restores_original_modes_and_targets(self):
        nvml = FakeNvml()
        nvml.states[0, 0] = (fans.MANUAL, 75)
        original = dict(nvml.states)
        nvml.fail_at = (7, 0)
        with self.assertRaises(RuntimeError):
            fans.apply_full_speed(nvml, fans.collect_fans(nvml))
        self.assertEqual(nvml.states, original)

    def test_verification_failure_restores_original_state(self):
        nvml = FakeNvml()
        original = dict(nvml.states)
        nvml.ignore_at = (7, 0)
        with self.assertRaises(RuntimeError):
            fans.apply_full_speed(nvml, fans.collect_fans(nvml))
        self.assertEqual(nvml.states, original)

    def test_recovery_continues_after_one_restore_fails(self):
        nvml = FakeNvml()
        nvml.states[0, 0] = (fans.MANUAL, 75)
        nvml.fail_at = (7, 0)

        def fail_restore(_handle, _fan):
            raise RuntimeError("Injected restore failure")

        nvml.automatic = fail_restore
        with self.assertRaises(RuntimeError):
            fans.apply_full_speed(nvml, fans.collect_fans(nvml))
        self.assertIn("RESTORE FAILED", self.output.getvalue())
        self.assertEqual(nvml.states[0, 0], (fans.MANUAL, 75))


if __name__ == "__main__":
    unittest.main()

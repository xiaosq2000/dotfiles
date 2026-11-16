#!/usr/bin/python3
"""Set all fans on eight NVIDIA GPUs to 100% through NVML."""

import argparse
import ctypes as C
from dataclasses import dataclass
import os
import signal
import sys


GPU_COUNT = 8
AUTOMATIC = 0
MANUAL = 1


class Nvml:
    def __init__(self):
        self.lib = C.CDLL("libnvidia-ml.so.1")
        signatures = {
            "nvmlInit_v2": [],
            "nvmlShutdown": [],
            "nvmlDeviceGetCount_v2": [C.POINTER(C.c_uint)],
            "nvmlDeviceGetHandleByIndex_v2": [C.c_uint, C.POINTER(C.c_void_p)],
            "nvmlDeviceGetUUID": [C.c_void_p, C.c_char_p, C.c_uint],
            "nvmlDeviceGetNumFans": [C.c_void_p, C.POINTER(C.c_uint)],
            "nvmlDeviceGetFanControlPolicy_v2": [
                C.c_void_p, C.c_uint, C.POINTER(C.c_uint)
            ],
            "nvmlDeviceGetTargetFanSpeed": [
                C.c_void_p, C.c_uint, C.POINTER(C.c_uint)
            ],
            "nvmlDeviceSetFanSpeed_v2": [C.c_void_p, C.c_uint, C.c_uint],
            "nvmlDeviceSetDefaultFanSpeed_v2": [C.c_void_p, C.c_uint],
        }
        for name, arguments in signatures.items():
            function = getattr(self.lib, name)
            function.argtypes = arguments
            function.restype = C.c_int
        self.lib.nvmlErrorString.argtypes = [C.c_int]
        self.lib.nvmlErrorString.restype = C.c_char_p
        self.call("nvmlInit_v2")

    def call(self, name, *arguments):
        result = getattr(self.lib, name)(*arguments)
        if result:
            message = self.lib.nvmlErrorString(result).decode()
            raise RuntimeError(f"{name}: {message}")

    def uint(self, name, *arguments):
        value = C.c_uint()
        self.call(name, *arguments, C.byref(value))
        return value.value

    def handle(self, index):
        handle = C.c_void_p()
        self.call("nvmlDeviceGetHandleByIndex_v2", index, C.byref(handle))
        return handle

    def uuid(self, handle):
        value = C.create_string_buffer(96)
        self.call("nvmlDeviceGetUUID", handle, value, len(value))
        return value.value.decode()

    def policy(self, handle, fan):
        return self.uint("nvmlDeviceGetFanControlPolicy_v2", handle, fan)

    def target(self, handle, fan):
        return self.uint("nvmlDeviceGetTargetFanSpeed", handle, fan)

    def set_speed(self, handle, fan, speed):
        # NVML also selects manual control for this fan.
        self.call("nvmlDeviceSetFanSpeed_v2", handle, fan, speed)

    def automatic(self, handle, fan):
        self.call("nvmlDeviceSetDefaultFanSpeed_v2", handle, fan)

    def close(self):
        self.call("nvmlShutdown")


@dataclass(frozen=True)
class Fan:
    gpu: int
    uuid: str
    handle: object
    index: int
    policy: int
    target: int

    @property
    def label(self):
        return f"GPU {self.gpu} ({self.uuid}), fan {self.index}"


def collect_fans(nvml):
    """Read every fan before the first write."""
    count = nvml.uint("nvmlDeviceGetCount_v2")
    if count != GPU_COUNT:
        raise RuntimeError(f"Expected {GPU_COUNT} GPUs, found {count}. No fans changed.")
    fans = []
    for gpu in range(count):
        handle = nvml.handle(gpu)
        uuid = nvml.uuid(handle)
        count_fans = nvml.uint("nvmlDeviceGetNumFans", handle)
        if count_fans == 0:
            raise RuntimeError(f"GPU {gpu}: no fans reported. No fans changed.")
        for index in range(count_fans):
            policy = nvml.policy(handle, index)
            target = nvml.target(handle, index)
            if policy not in (AUTOMATIC, MANUAL) or not 0 <= target <= 100:
                raise RuntimeError(f"GPU {gpu}, fan {index}: invalid fan state. No fans changed.")
            fans.append(Fan(gpu, uuid, handle, index, policy, target))
    return fans


def apply_full_speed(nvml, fans):
    changed = []
    try:
        for fan in fans:
            # Include this fan if a failed call partially changes its state.
            changed.append(fan)
            nvml.set_speed(fan.handle, fan.index, 100)
        for fan in fans:
            if (nvml.policy(fan.handle, fan.index) != MANUAL
                    or nvml.target(fan.handle, fan.index) != 100):
                raise RuntimeError(f"{fan.label}: manual 100% target not confirmed")
    except BaseException:
        # Keep a second termination signal from interrupting recovery.
        previous_handlers = {}
        for signum in (signal.SIGINT, signal.SIGTERM):
            previous_handlers[signum] = signal.signal(signum, signal.SIG_IGN)
        try:
            for fan in reversed(changed):
                try:
                    if fan.policy == AUTOMATIC:
                        nvml.automatic(fan.handle, fan.index)
                    else:
                        nvml.set_speed(fan.handle, fan.index, fan.target)
                    if nvml.policy(fan.handle, fan.index) != fan.policy:
                        raise RuntimeError("original control mode not confirmed")
                    if (fan.policy == MANUAL
                            and nvml.target(fan.handle, fan.index) != fan.target):
                        raise RuntimeError("original fan target not confirmed")
                    print(f"Restored original control: {fan.label}", file=sys.stderr)
                except Exception as error:
                    print(f"RESTORE FAILED: {fan.label}: {error}", file=sys.stderr)
        finally:
            for signum, handler in previous_handlers.items():
                signal.signal(signum, handler)
        raise
    for fan in fans:
        print(f"{fan.label}: manual mode, target 100% confirmed")


def interrupted(signum, _frame):
    raise InterruptedError(f"Received signal {signum}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="read fan states without changing hardware")
    arguments = parser.parse_args()
    if not arguments.check and os.geteuid() != 0:
        parser.error("Root permission is required. Use --check for read-only checks.")
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, interrupted)
    nvml = None
    try:
        nvml = Nvml()
        fans = collect_fans(nvml)
        if arguments.check:
            for fan in fans:
                mode = "automatic" if fan.policy == AUTOMATIC else "manual"
                print(f"{fan.label}: {mode}, target {fan.target}%")
            print(f"Read-only check passed: {GPU_COUNT} GPUs, {len(fans)} fans. No fans changed.")
        else:
            apply_full_speed(nvml, fans)
            print(f"All {len(fans)} fans on {GPU_COUNT} GPUs accepted the 100% target.")
        return 0
    except (Exception, KeyboardInterrupt) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    finally:
        if nvml is not None:
            try:
                nvml.close()
            except Exception as error:
                print(f"NVML shutdown failed: {error}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())

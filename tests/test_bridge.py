#!/usr/bin/env python3
"""Unit tests for mangomarchy-bridge state snapshot and dispatch translation."""

import importlib.machinery
import importlib.util
from pathlib import Path
import unittest


_bin_dir = Path(__file__).resolve().parent.parent / "bin"
BRIDGE_PATH = _bin_dir / "mangomarchy-bridge"
if not BRIDGE_PATH.is_file():
    BRIDGE_PATH = _bin_dir / "omarchy-mango-bridge"
loader = importlib.machinery.SourceFileLoader("mangomarchy_bridge", str(BRIDGE_PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
bridge = importlib.util.module_from_spec(spec)
loader.exec_module(bridge)


class TestMangoBridge(unittest.TestCase):
    def test_build_state_snapshot_monitors_and_tags(self) -> None:
        raw_monitors = [
            {
                "name": "eDP-1",
                "description": "Built-in Display",
                "width": 2880,
                "height": 1920,
                "scale": 2.0,
                "x": 0,
                "y": 0,
                "focused": True,
                "selected_tag": 2,
                "layout_symbol": "S",
            },
            {
                "name": "DP-1",
                "description": "External 4K",
                "width": 3840,
                "height": 2160,
                "scale": 1.5,
                "x": 1440,
                "y": 0,
                "focused": False,
                "selected_tag": 1,
                "layout_symbol": "T",
            },
        ]
        raw_tags = {
            "eDP-1": [
                {"id": 1, "active": False, "clients": 1},
                {"id": 2, "active": True, "clients": 2},
            ],
            "DP-1": [
                {"id": 1, "active": True, "clients": 1},
            ],
        }
        raw_clients = [
            {
                "id": 42,
                "monitor": "eDP-1",
                "tag": 2,
                "x": 10,
                "y": 40,
                "width": 1400,
                "height": 900,
                "appid": "com.mitchellh.ghostty",
                "title": "ghostty",
                "focused": True,
                "fullscreen": False,
            }
        ]

        snap = bridge.build_state_snapshot(raw_monitors, raw_tags, raw_clients, raw_kblayout="English (US)")

        self.assertEqual(len(snap["monitors"]), 2)
        self.assertEqual(snap["monitors"][0]["name"], "eDP-1")
        self.assertEqual(snap["monitors"][0]["activeWorkspace"]["id"], 2)
        self.assertEqual(snap["monitors"][1]["name"], "DP-1")
        # Monitor 1 block is 1 -> tag 1 maps to workspace 11
        self.assertEqual(snap["monitors"][1]["activeWorkspace"]["id"], 11)

        # Focused workspace should be workspace 2 on eDP-1 with scrolling layout
        self.assertEqual(snap["activeworkspace"]["id"], 2)
        self.assertEqual(snap["activeworkspace"]["tiledLayout"], "scrolling")

        # Client address should be normalized hex and mapped to workspace 2
        self.assertEqual(len(snap["clients"]), 1)
        self.assertEqual(snap["clients"][0]["address"], "0x2a")
        self.assertEqual(snap["clients"][0]["workspace"]["id"], 2)
        self.assertEqual(snap["clients"][0]["class"], "com.mitchellh.ghostty")

        # TSV for ~/.local/state/omarchy/monitor-workspaces
        self.assertIn("0\teDP-1\tBuilt-in Display", snap["monitor_workspaces_tsv"])
        self.assertIn("1\tDP-1\tExternal 4K", snap["monitor_workspaces_tsv"])

    def test_build_state_snapshot_mango_018_embedded_tags(self) -> None:
        raw_monitors = {
            "monitors": [
                {
                    "name": "eDP-1",
                    "active": True,
                    "width": 1920,
                    "height": 1200,
                    "scale": 1.25,
                    "layout_symbol": "S",
                    "active_tags": [3],
                    "keyboardlayout": "Norwegian",
                    "tags": [
                        {"index": 1, "is_active": False, "is_urgent": False, "layout": "S", "client_count": 2},
                        {"index": 2, "is_active": False, "is_urgent": False, "layout": "S", "client_count": 0},
                        {"index": 3, "is_active": True, "is_urgent": False, "layout": "S", "client_count": 1},
                    ],
                }
            ]
        }
        snap = bridge.build_state_snapshot(raw_monitors, None, [], raw_kblayout="Norwegian")
        self.assertEqual(snap["activeworkspace"]["id"], 3)
        ws_ids = [w["id"] for w in snap["workspaces"]]
        self.assertEqual(ws_ids, [1, 3])
        self.assertEqual(snap["devices"]["keyboards"][0]["active_keymap"], "Norwegian")

    def test_translate_dispatch_to_mmsg(self) -> None:
        self.assertEqual(
            bridge.translate_dispatch_to_mmsg('o.workspaces.focus(4, "eDP-1")'),
            [["mmsg", "dispatch", "view,4"]],
        )
        self.assertEqual(
            bridge.translate_dispatch_to_mmsg('o.workspaces.move_window(5)'),
            [["mmsg", "dispatch", "tag,5"]],
        )
        self.assertEqual(
            bridge.translate_dispatch_to_mmsg('hl.dsp.focus({ workspace = "13" })'),
            [["mmsg", "dispatch", "view,3"]],
        )
        self.assertEqual(
            bridge.translate_dispatch_to_mmsg('hl.dsp.focus({ direction = "l" })'),
            [["mmsg", "dispatch", "focusdir,left"]],
        )
        self.assertEqual(
            bridge.translate_dispatch_to_mmsg('o.workspace_mode({ workspace = "1", mode = "scrolling" })'),
            [["mmsg", "dispatch", "setlayout,scroller"]],
        )
        self.assertEqual(
            bridge.translate_dispatch_to_mmsg('o.workspace_mode({ workspace = "1", mode = "dwindle" })'),
            [["mmsg", "dispatch", "setlayout,tile"]],
        )

    def test_live_unix_socket_and_hyprctl_wrapper(self) -> None:
        import asyncio
        import json
        import os
        import subprocess
        import tempfile

        async def run_socket_test() -> None:
            with tempfile.TemporaryDirectory() as tmpdir:
                os.environ["XDG_RUNTIME_DIR"] = tmpdir
                os.environ["XDG_STATE_HOME"] = tmpdir
                os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "mango_test"
                os.environ["MANGO_INSTANCE_SIGNATURE"] = "test"

                b = bridge.MangoHyprBridge("mango_test")
                req_srv = await asyncio.start_unix_server(b.on_req_client, path=str(b.req_sock_path))
                evt_srv = await asyncio.start_unix_server(b.on_evt_client, path=str(b.evt_sock_path))

                hyprctl_bin = str(Path(__file__).resolve().parent.parent / "lib" / "bin" / "hyprctl")

                # Connect an event listener on .socket2.sock
                evt_reader, evt_writer = await asyncio.open_unix_connection(str(b.evt_sock_path))

                # Query `hyprctl -j monitors` via subprocess
                proc = await asyncio.create_subprocess_exec(
                    "bash",
                    hyprctl_bin,
                    "-j",
                    "monitors",
                    stdout=asyncio.subprocess.PIPE,
                )
                out, _ = await proc.communicate()
                monitors = json.loads(out.decode("utf-8"))
                self.assertEqual(len(monitors), 1)
                self.assertEqual(monitors[0]["activeWorkspace"]["id"], 1)

                # Query `hyprctl -j getoption general:gaps_out`
                proc2 = await asyncio.create_subprocess_exec(
                    "bash",
                    hyprctl_bin,
                    "-j",
                    "getoption",
                    "general:gaps_out",
                    stdout=asyncio.subprocess.PIPE,
                )
                out2, _ = await proc2.communicate()
                opt = json.loads(out2.decode("utf-8"))
                self.assertEqual(opt["option"], "general:gaps_out")
                self.assertIn("int", opt)

                # Trigger `hyprctl reload` and verify `configreloaded>>` event arrives on .socket2.sock
                proc3 = await asyncio.create_subprocess_exec(
                    "bash",
                    hyprctl_bin,
                    "reload",
                    stdout=asyncio.subprocess.PIPE,
                )
                await proc3.communicate()
                evt_line = await asyncio.wait_for(evt_reader.readline(), timeout=1.0)
                self.assertEqual(evt_line.decode("utf-8").strip(), "configreloaded>>")

                evt_writer.close()
                await evt_writer.wait_closed()
                req_srv.close()
                evt_srv.close()

        asyncio.run(run_socket_test())

    def test_theme_template_tokens(self) -> None:
        tpl_path = Path(__file__).resolve().parent.parent / "share" / "themed" / "mango-theme.conf.tpl"
        content = tpl_path.read_text(encoding="utf-8")
        self.assertIn("root_color=0x{{ background_strip }}ff", content)
        self.assertIn("border_color=0x{{ foreground_strip }}59", content)
        self.assertIn("focus_color=0x{{ accent_strip }}ff", content)
        self.assertIn("urgent_color=0x{{ color1_strip }}ff", content)


if __name__ == "__main__":
    unittest.main()

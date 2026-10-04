"""Read-only deployment-check fixtures; no SSH, network, or live VPS needed."""

import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "validate-deployment.sh"


class DeploymentChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="3xui-validation-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.db = self.work / "x-ui.db"
        with sqlite3.connect(self.db) as conn:
            conn.executescript("""
                CREATE TABLE settings (key TEXT, value TEXT);
                INSERT INTO settings VALUES ('subClashEnable','true'),
                    ('subClashPath','/clash/'),('timeLocation','Asia/Shanghai');
                CREATE TABLE clients (id INTEGER, email TEXT, sub_id TEXT,
                    enable INTEGER, total_gb INTEGER, expiry_time INTEGER,
                    traffic_reset TEXT, traffic_reset_day INTEGER, reset INTEGER,
                    reset_day INTEGER, reset_weekday INTEGER, reset_max INTEGER);
                INSERT INTO clients VALUES
                    (1,'admin','FAKE_SECRET_SUBID',1,0,0,'never',1,0,0,0,0),
                    (2,'colleague','FAKE_SECRET_SUBID2',1,53687091200,0,'monthly',17,0,0,0,0),
                    (3,'renewing','FAKE_SECRET_SUBID3',1,53687091200,1792166400000,'never',1,0,17,0,0);
                CREATE TABLE client_inbounds (client_id INTEGER, inbound_id INTEGER);
                INSERT INTO client_inbounds VALUES (1,1);
                CREATE TABLE inbounds (remark TEXT, protocol TEXT, port INTEGER,
                    enable INTEGER, settings TEXT, stream_settings TEXT);
                INSERT INTO inbounds VALUES
                    ('US-VLESS-TCP','vless',443,1,'{"decryption":"none"}',
                        '{"realitySettings":{"minClientVer":"","mldsa65Seed":""}}'),
                    ('US-VLESS-TCP-PQ','vless',23457,1,
                        '{"decryption":"mlkem768x25519plus.FAKE_SECRET_DECRYPTION"}',
                        '{"realitySettings":{"mldsa65Seed":"FAKE_SECRET_SEED"}}');
            """)
        self.install = self.work / "install.env"
        self.install.write_text(
            "XUI_USERNAME=FAKE_SECRET_USER\nXUI_PASSWORD=FAKE_SECRET_PASSWORD\n"
            "XUI_API_TOKEN=FAKE_SECRET_TOKEN\nXUI_PANEL_PORT=2053\n"
            "XUI_WEB_BASE_PATH=FAKE_SECRET_PANEL_PATH\n"
        )
        self.state = self.work / "state.env"
        self.state.write_text(
            "TCP443_PORT=443\nTCP_RANDOM_PORT=23455\nXHTTP_PORT=23456\n"
            "PQ_TCP_PORT=23457\nHY2_PORT=23458\nPRIVATE_KEY=FAKE_SECRET_STATE_KEY\n"
        )
        self.config = self.work / "config.json"
        self.config.write_text(
            '{"inbounds":[{"port":443,"settings":{"decryption":"none"}},'
            '{"port":23455},{"port":23456},{"port":23457,'
            '"settings":{"decryption":"mlkem768x25519plus.FAKE_SECRET_DECRYPTION"},'
            '"streamSettings":{"realitySettings":{"mldsa65Seed":"FAKE_SECRET_SEED"}}},'
            '{"port":23458}]}\n'
        )
        self.binaries = self.work / "bin"
        self.binaries.mkdir()
        mocks = {
            "systemctl": 'case "$1" in is-active) echo active;; is-enabled) echo enabled;; *) exit 1;; esac',
            "curl": "echo 200",
            "ss": 'printf "%s\\n" "LISTEN 0 128 0.0.0.0:23457 0.0.0.0:*"',
            "nft": "exit 0",
            "sysctl": 'case "$2" in *disable_ipv6) echo 1;; *congestion_control) echo bbr;; *default_qdisc) echo fq;; esac',
            "uname": "echo aarch64",
            "panel": '[ "$1" = -v ] || exit 1; echo v3.9.0',
        }
        for name, body in mocks.items():
            path = self.binaries / name
            path.write_text("#!/usr/bin/env bash\n" + body + "\n")
            path.chmod(0o755)
        core = self.work / "xray-linux-arm64"
        core.write_text('#!/usr/bin/env bash\n[ "$1" = version ] || exit 1\necho "Xray 26.9.30 (${0##*/})"\n')
        core.chmod(0o755)
        self.env = os.environ.copy()
        self.env.pop("XUI_XRAY_BINARY", None)
        self.env.update({
            "PATH": str(self.binaries) + os.pathsep + self.env["PATH"],
            "XUI_INSTALL_ENV": str(self.install), "XUI_DB_PATH": str(self.db),
            "XUI_CONFIG_PATH": str(self.config), "XUI_PANEL_BINARY": str(self.binaries / "panel"),
        })

    def run_check(self, email="admin", state=None):
        before = self.db.read_bytes()
        result = subprocess.run(
            ["bash", str(SCRIPT), "panel.example.com", str(state or self.state), email],
            env=self.env, text=True, capture_output=True, check=True,
        )
        self.assertEqual(before, self.db.read_bytes(), "validation must not mutate the DB")
        self.assertNotIn("FAKE_SECRET", result.stdout + result.stderr)
        return result.stdout

    def test_default_admin_stays_unlimited_and_detects_arm_core(self):
        output = self.run_check()
        self.assertIn("admin|1|0|0|never|1|0|0|0|0", output)
        self.assertNotIn("colleague|", output)
        self.assertIn("panel_version=v3.9.0", output)
        self.assertIn("xray_version=Xray 26.9.30 (xray-linux-arm64)", output)

    def test_perpetual_monthly_quota_is_separate_from_renewal(self):
        output = self.run_check("colleague")
        self.assertIn("colleague|1|53687091200|0|monthly|17|0|0|0|0", output)
        self.assertIn("panel_time_location=Asia/Shanghai", output)

    def test_calendar_renewal_keeps_first_cutoff(self):
        output = self.run_check("renewing")
        self.assertIn("renewing|1|53687091200|1792166400000|never|1|0|17|0|0", output)

    def test_pq_fields_and_compact_config_ports(self):
        output = self.run_check()
        self.assertIn("vless_mlkem_db_count=1", output)
        self.assertIn("vless_mldsa_db_count=1", output)
        self.assertIn("vless_mldsa_runtime=present", output)
        self.assertIn("config_port_23457=present", output)
        self.assertIn("0.0.0.0:23457", output)
        self.config.write_text('{"inbounds":[{"port":4430}]}\n')
        output = self.run_check()
        self.assertIn("config_port_443=missing", output)
        self.assertIn("config_port_23457=missing", output)

    def test_legacy_client_schema_is_nonblocking(self):
        with sqlite3.connect(self.db) as conn:
            conn.execute("ALTER TABLE clients RENAME COLUMN reset_weekday TO legacy_weekday")
        output = self.run_check()
        self.assertIn("client_lifecycle_begin\nunavailable\nclient_lifecycle_end", output)
        self.assertIn("config_port_23457=present", output)

    def test_missing_binaries_and_optional_state_are_nonblocking(self):
        self.env["XUI_PANEL_BINARY"] = str(self.work / "missing-panel")
        self.env["XUI_XRAY_BINARY"] = str(self.work / "missing-core")
        output = self.run_check(state=self.work / "missing-state")
        self.assertIn("panel_version=unavailable", output)
        self.assertIn("xray_version=unavailable", output)
        self.assertIn("clash_settings_begin", output)

    def test_email_quote_cannot_change_scope_or_execute_sql(self):
        output = self.run_check("' OR 1=1; DROP TABLE clients; --")
        self.assertIn("client_lifecycle_begin\nnot_found\nclient_lifecycle_end", output)
        self.assertNotIn("colleague|", output)


class SkillVersionChecks(unittest.TestCase):
    def test_documented_reader_does_not_pick_panel_or_core_version(self):
        reference = (ROOT / "references" / "version-check.md").read_text()
        reader = reference.split("```bash\n", 1)[1].split("```", 1)[0]
        with tempfile.TemporaryDirectory(prefix="3xui-version-") as work:
            readme = Path(work) / "README.md"
            for label, version in [("Skill 版本", "v1.3.0"), ("稳定版本", "v1.2.2")]:
                with self.subTest(label=label):
                    readme.write_text(f"面板 v3.9.0 / Core v26.9.30\n当前 {label}：`{version}`。\n")
                    result = subprocess.run(["bash", "-c", reader], cwd=work, text=True,
                                            capture_output=True, check=True)
                    self.assertEqual(version, result.stdout.strip())


if __name__ == "__main__":
    unittest.main()

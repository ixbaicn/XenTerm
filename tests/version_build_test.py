"""Run the real build script and resolver in an offline Unix Cargo fixture.

Windows embeds icon resources and requires winresource; this dependency-free
fixture runs on Linux/macOS. Product CI continues to cover Windows builds.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipIf(os.name == "nt", "dependency-free fixture supports Unix hosts")
class VersionBuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="xt-version-build-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        source = Path(__file__).resolve().parents[1]
        for directory in ["src", "scripts", ".git/refs"]:
            (self.root / directory).mkdir(parents=True)
        # Missing watched paths cause unconditional Cargo reruns, hiding bugs.
        (self.root / ".git/HEAD").write_text("ref: refs/heads/main\n")
        (self.root / ".git/packed-refs").write_text("")
        for path in ["build.rs", "scripts/version.sh"]:
            shutil.copy(source / path, self.root / path)
        (self.root / "Cargo.toml").write_text(
            '[package]\nname="version-fixture"\nversion="1.2.3"\nedition="2021"\n')
        (self.root / "src/main.rs").write_text(
            'fn main(){println!("{}",env!("XT_VERSION"));}')
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("XT_", "GITHUB_", "GIT_", "CARGO_TARGET_"))}
        self.env.update(GITHUB_REF_TYPE="branch", GITHUB_REF_NAME="main",
                        GITHUB_SHA="abcdef0123456789012345678901234567890123",
                        GIT_CEILING_DIRECTORIES=str(self.root.parent))
        self.env["CARGO_TARGET_DIR"] = str(self.root / "target")

    def run_version(self):
        return subprocess.check_output(
            ["cargo", "run", "--offline", "--quiet"], cwd=self.root,
            env=self.env, text=True, stderr=subprocess.PIPE, timeout=90).strip()

    def test_channel_change(self):
        self.assertTrue(self.run_version().startswith("xt-dev-abcdef0-T"))
        self.env["XT_CHANNEL"] = "alpha"
        self.assertTrue(self.run_version().startswith("xt-alpha-abcdef0-T"))

    def test_sha_change(self):
        self.run_version()
        self.env["GITHUB_SHA"] = "1234567890123456789012345678901234567890"
        self.assertTrue(self.run_version().startswith("xt-dev-1234567-T"))

    def test_ref_name_change(self):
        self.env.update(GITHUB_REF_TYPE="tag", GITHUB_REF_NAME="v1.2.3")
        self.assertEqual(self.run_version(), "xt-v1.2.3")
        self.env["GITHUB_REF_NAME"] = "v2.3.4"
        self.assertEqual(self.run_version(), "xt-v2.3.4")

    def test_ref_type_change(self):
        self.env["GITHUB_REF_NAME"] = "v1.2.3"
        self.assertTrue(self.run_version().startswith("xt-dev-abcdef0-T"))
        self.env["GITHUB_REF_TYPE"] = "tag"
        self.assertEqual(self.run_version(), "xt-v1.2.3")

    def test_override_added_removed(self):
        self.run_version()
        self.env["XT_VERSION"] = "xt-v9.8.7"
        self.assertEqual(self.run_version(), "xt-v9.8.7")
        del self.env["XT_VERSION"]
        self.assertTrue(self.run_version().startswith("xt-dev-abcdef0-T"))

    def test_unchanged_inputs_reuse_build(self):
        first = self.run_version()
        metadata = self.root / "version.json"
        before = metadata.stat().st_mtime_ns
        self.assertEqual(self.run_version(), first)
        self.assertEqual(metadata.stat().st_mtime_ns, before)


if __name__ == "__main__":
    unittest.main(verbosity=2)

"""Exercise policy decisions and the reports consumed by release reviewers."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / ".github/workflows/scripts/evaluate-trivy-report.py"
SPEC = importlib.util.spec_from_file_location("trivy_policy", SCRIPT)
policy = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = policy
SPEC.loader.exec_module(policy)


def vulnerability(identifier="CVE-TEST", **fields):
    return {"VulnerabilityID": identifier, "PkgName": "example", **fields}


class PolicyTests(unittest.TestCase):
    def test_score_boundaries(self):
        for score, expected in [(0, "NONE"), (0.1, "LOW"), (3.9, "LOW"),
                                (4, "MEDIUM"), (6.9, "MEDIUM"), (7, "HIGH"),
                                (8.9, "HIGH"), (9, "CRITICAL"), (10, "CRITICAL")]:
            with self.subTest(score=score):
                self.assertEqual(policy.score_to_band(score), expected)

    def test_nvd_precedes_other_sources_and_prefers_newest_cvss(self):
        for field, version in policy.CVSS_VERSION_FIELDS:
            with self.subTest(version=version):
                scores = {"nvd": {field: 3.0}, "vendor": {"V40Score": 10}}
                self.assertEqual(policy.select_cvss(scores), (3, f"CVSS.nvd.{version}"))
        self.assertEqual(policy.select_cvss({"nvd": {"V40Score": 0, "V3Score": 10}}),
                         (0, "CVSS.nvd.v4"))
        self.assertEqual(policy.select_cvss({"nvd": {"V40Score": 4, "V3Score": 9}}),
                         (4, "CVSS.nvd.v4"))

    def test_highest_other_source_score_is_selected(self):
        self.assertEqual(policy.select_cvss({
            "nvd": {}, "empty": None,
            "vendor": {"V40Score": 4, "V3Score": 9, "V2Score": 5},
            "other": {"V3Score": 7},
        }), (9, "CVSS.vendor.v3"))
        self.assertIsNone(policy.select_cvss({"nvd": None, "vendor": {}}))

    def test_severity_fallback_and_unknown_fail_closed(self):
        for severity, fails in [(None, True), ("unexpected", True), ("UNKNOWN", True),
                                ("low", False), ("MEDIUM", True), ("HIGH", True),
                                ("CRITICAL", True)]:
            with self.subTest(severity=severity):
                finding = policy.evaluate_finding("Python", vulnerability(Severity=severity))
                self.assertEqual(finding.is_violation, fails)
                self.assertEqual(finding.source, "Trivy.Severity")

    def test_cvss_overrides_vendor_severity_and_keeps_unfixed_findings(self):
        low = policy.evaluate_finding("Python", vulnerability(
            Severity="CRITICAL", CVSS={"nvd": {"V3Score": 3}}))
        self.assertFalse(low.is_violation)
        unfixed = policy.evaluate_finding("Python", vulnerability(
            CVSS={"nvd": {"V3Score": 7}}, InstalledVersion="1.0"))
        self.assertTrue(unfixed.is_violation)
        self.assertEqual(unfixed.installed_version, "1.0")
        self.assertEqual(unfixed.fixed_version, "")

    def test_empty_reports_and_suppressed_findings_do_not_fail(self):
        for report in ({}, {"Results": None}, {"Results": [{"Vulnerabilities": None}]}):
            self.assertFalse(policy.evaluate_report(report).violations)
        for field in policy.SUPPRESSED_FIELDS:
            report = {"Results": [{"Target": "Python", field: [
                {"Finding": vulnerability(Severity="CRITICAL"), "Statement": "Accepted"}
            ]}]}
            result = policy.evaluate_report(report)
            self.assertFalse(result.violations)
            self.assertEqual(len(result.suppressed), 1)


class SummaryTests(unittest.TestCase):
    def test_summary_shows_only_blocking_findings_with_remediation_links(self):
        result = policy.evaluate_report({"ArtifactName": "image:latest", "Results": [{
            "Target": "Python", "Vulnerabilities": [
                vulnerability("CVE-BLOCKING", Severity="HIGH", InstalledVersion="1",
                              FixedVersion="2", PrimaryURL="https://example.com/advisory"),
                vulnerability("CVE-NONBLOCKING", Severity="LOW"),
            ], "ModifiedFindings": [{"Finding": vulnerability("CVE-SUPPRESSED")}],
        }]})
        summary = policy.format_summary(result)
        for expected in ("FAILED", "image:latest", "1 non-blocking; 1 suppressed",
                         "CVE-BLOCKING", 'href="https://example.com/advisory"', "| 1 | 2 |"):
            self.assertIn(expected, summary)
        self.assertNotIn("CVE-NONBLOCKING", summary)
        self.assertNotIn("CVE-SUPPRESSED", summary)

    def test_empty_summary_passes(self):
        summary = policy.format_summary(policy.ReportResult())
        self.assertIn("PASSED", summary)
        self.assertNotIn("<details", summary)

    def test_untrusted_metadata_is_escaped_and_unsafe_links_are_not_rendered(self):
        for url in ("javascript:alert(1)", "https://[invalid", "https://example.com/\nfoo",
                    "https://example.com/|foo", "https://example.com/" + "x" * 300):
            with self.subTest(url=url):
                finding = policy.evaluate_finding("<script>|\n", vulnerability(
                    "<CVE>|", Severity="HIGH", PrimaryURL=url))
                summary = policy.format_summary(policy.ReportResult(findings=[finding]))
                self.assertNotIn('<a href=', summary)
                self.assertNotIn("<script>", summary)
                self.assertIn("&lt;CVE&gt;&#124;", summary)
                self.assertIn("Not available", summary)

    def test_large_reports_limit_rows_and_metadata_under_github_size_limit(self):
        findings = [policy.evaluate_finding("x" * 1000, vulnerability(
            f"CVE-{i:04}", Severity="CRITICAL", PkgName="p" * 1000,
            InstalledVersion="v" * 1000)) for i in range(1000)]
        summary = policy.format_summary(policy.ReportResult(findings=findings))
        self.assertEqual(summary.count("| CVE-"), 200)
        self.assertIn("Only the first 200", summary)
        self.assertIn("...", summary)
        self.assertLess(len(summary.encode()), 1024 * 1024)


class CommandTests(unittest.TestCase):
    def test_cli_aggregates_reports_and_writes_summary_before_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            passing = root / "passing.json"
            failing = root / "failing.json"
            summary = root / "summary.md"
            passing.write_text(json.dumps({"Results": [{"Vulnerabilities": [
                vulnerability("CVE-LOW", Severity="LOW")]}]}), encoding="utf-8")
            failing.write_text(json.dumps({"Results": [{
                "Target": "Python", "Vulnerabilities": [vulnerability(Severity="MEDIUM")],
                "ModifiedFindings": [{"Finding": vulnerability("CVE-EXCEPTION"),
                                      "Status": "ignored", "Statement": "Accepted"}],
            }]}), encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = policy.main(["--summary", str(summary), str(passing), str(failing)])
            self.assertEqual(code, 1)
            self.assertIn("FAILED: 1", output.getvalue())
            self.assertIn("[ok  ] CVE-LOW", output.getvalue())
            self.assertIn("[suppressed] CVE-EXCEPTION", output.getvalue())
            self.assertIn("Accepted", output.getvalue())
            self.assertIn("PASSED", summary.read_text())
            self.assertIn("FAILED", summary.read_text())
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(policy.main([str(passing)]), 0)
            passing.write_text("{}", encoding="utf-8")
            with contextlib.redirect_stdout(output):
                self.assertEqual(policy.main([str(passing)]), 0)
            self.assertIn("-- no findings --", output.getvalue())

    def test_suppression_metadata_fallbacks_are_visible(self):
        for entry, identifier in [({"ID": "CVE-ID", "Comment": "reason"}, "CVE-ID"),
                                  ({"VulnerabilityID": "CVE-TOP", "PkgName": "pkg"}, "CVE-TOP"),
                                  ({}, "UNKNOWN")]:
            self.assertIn(identifier, policy._format_suppressed("Python", entry))

    def test_script_entry_point_returns_policy_exit_status(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            report.write_text(json.dumps({"Results": [{"Vulnerabilities": [
                vulnerability(Severity="HIGH")]}]}), encoding="utf-8")
            completed = subprocess.run([sys.executable, str(SCRIPT), str(report)],
                                       capture_output=True, text=True, check=False)
            self.assertEqual(completed.returncode, 1)
            self.assertIn("FAILED: 1", completed.stdout)

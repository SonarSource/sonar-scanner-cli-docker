#!/usr/bin/env python3
"""Evaluate a Trivy JSON vulnerability report against the repository's CI policy.

Policy: a finding fails CI if its CVSS-derived severity band is Medium, High, or
Critical -- or Unknown, meaning no CVSS score and no usable Trivy severity were
available at all, so there's no data to say the finding is safe. Findings without
an upstream fix are included. Vulnerabilities suppressed by an unexpired
.trivyignore.yaml entry are absent from the report's "Vulnerabilities" list
(enforced by Trivy's --ignorefile); this script judges the remaining findings.

CVSS score selection precedence, per finding:
  1. CVSS.nvd v4   (CVSS.nvd.V40Score)
  2. CVSS.nvd v3   (CVSS.nvd.V3Score)
  3. CVSS.nvd v2   (CVSS.nvd.V2Score)
  4. The highest score reported by any other CVSS source/version
  5. Trivy's own Severity field, only when no CVSS score is available at all

Numeric CVSS scores are mapped to their band using the exact official CVSS
qualitative severity ranges (Low 0.1-3.9, Medium 4.0-6.9, High 7.0-8.9,
Critical 9.0-10.0) -- no rounding is applied, since a score already falls
in exactly one of these bands.

Not GitHub Actions-specific: run directly against any Trivy JSON report file.
"""

from __future__ import annotations

import argparse
from collections import Counter
import html
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional
from urllib.parse import urlsplit

NVD_SOURCE = "nvd"

# CVSS score field, in precedence order, together with its human-readable label.
CVSS_VERSION_FIELDS = (
    ("V40Score", "v4"),
    ("V3Score", "v3"),
    ("V2Score", "v2"),
)

TRIVY_SEVERITY_TO_BAND = {
    "UNKNOWN": "UNKNOWN",
    "LOW": "LOW",
    "MEDIUM": "MEDIUM",
    "HIGH": "HIGH",
    "CRITICAL": "CRITICAL",
}

# UNKNOWN means we have no CVSS score anywhere AND no usable Trivy severity --
# i.e. zero information, not a real "no impact" score. Fail closed on that so
# a human has to look and either fix it or add a governed .trivyignore entry,
# rather than silently trusting an absence of data. NONE (a real score of 0.0)
# is intentionally excluded -- that's an informed "no impact" verdict.
FAILING_BANDS = frozenset({"UNKNOWN", "MEDIUM", "HIGH", "CRITICAL"})

# Trivy's --show-suppressed field name has changed across releases; check both.
SUPPRESSED_FIELDS = ("ModifiedFindings", "ExperimentalModifiedFindings")


@dataclass
class Finding:
    id: str
    target: str
    package: str
    band: str
    score_display: str
    source: str
    installed_version: str = ""
    fixed_version: str = ""
    advisory_url: str = ""

    @property
    def is_violation(self) -> bool:
        return self.band in FAILING_BANDS


@dataclass
class ReportResult:
    findings: list[Finding] = field(default_factory=list)
    suppressed: list[tuple[str, dict[str, Any]]] = field(default_factory=list)
    artifact: str = ""

    @property
    def violations(self) -> list[Finding]:
        return [f for f in self.findings if f.is_violation]


def score_to_band(score: float) -> str:
    """Map a CVSS score to its qualitative band using the official v3.x/v4
    boundaries (NVD qualitative severity rating scale). These are exact float
    ranges, not integers, so no rounding is applied -- a score already sits
    in exactly one band, and comparing it directly is what "never rounds
    down" actually means here.
    """
    if score <= 0.0:
        return "NONE"
    if score <= 3.9:
        return "LOW"
    if score <= 6.9:
        return "MEDIUM"
    if score <= 8.9:
        return "HIGH"
    return "CRITICAL"


def _best_field(scores: dict[str, Any]) -> Optional[tuple[float, str]]:
    """Return (score, version_label) for the highest-precedence populated field."""
    for cvss_field, version in CVSS_VERSION_FIELDS:
        value = scores.get(cvss_field)
        if value is not None:
            return float(value), version
    return None


def select_cvss(cvss: dict[str, Any]) -> Optional[tuple[float, str]]:
    """Select (score, source_label) for a finding's CVSS map, per repo policy."""
    nvd_scores = cvss.get(NVD_SOURCE) or {}
    nvd_best = _best_field(nvd_scores)
    if nvd_best:
        score, version = nvd_best
        return score, f"CVSS.nvd.{version}"

    best: Optional[tuple[float, str, str]] = None  # (score, source, version)
    for source, scores in cvss.items():
        if source == NVD_SOURCE or not scores:
            continue
        for cvss_field, version in CVSS_VERSION_FIELDS:
            value = scores.get(cvss_field)
            if value is None:
                continue
            value = float(value)
            if best is None or value > best[0]:
                best = (value, source, version)

    if best:
        score, source, version = best
        return score, f"CVSS.{source}.{version}"

    return None


def evaluate_finding(target: str, vuln: dict[str, Any]) -> Finding:
    vuln_id = vuln.get("VulnerabilityID", "UNKNOWN")
    package = vuln.get("PkgName", "")
    cvss = vuln.get("CVSS") or {}

    selected = select_cvss(cvss)
    if selected is not None:
        score, source = selected
        band = score_to_band(score)
        score_display = f"{score:g}"
    else:
        severity = str(vuln.get("Severity") or "UNKNOWN").upper()
        band = TRIVY_SEVERITY_TO_BAND.get(severity, "UNKNOWN")
        source = "Trivy.Severity"
        score_display = severity

    return Finding(
        id=vuln_id,
        target=target,
        package=package,
        band=band,
        score_display=score_display,
        source=source,
        installed_version=vuln.get("InstalledVersion") or "",
        fixed_version=vuln.get("FixedVersion") or "",
        advisory_url=vuln.get("PrimaryURL") or "",
    )


def _iter_results(report: dict[str, Any]):
    for result in report.get("Results") or []:
        yield result.get("Target", ""), result


def evaluate_report(report: dict[str, Any]) -> ReportResult:
    findings: list[Finding] = []
    suppressed: list[tuple[str, dict[str, Any]]] = []

    for target, result in _iter_results(report):
        for vuln in result.get("Vulnerabilities") or []:
            findings.append(evaluate_finding(target, vuln))

        for suppressed_field in SUPPRESSED_FIELDS:
            for entry in result.get(suppressed_field) or []:
                suppressed.append((target, entry))

    return ReportResult(findings=findings, suppressed=suppressed, artifact=report.get("ArtifactName") or "")


def _summary_text(value: str) -> str:
    # Keep arbitrary package metadata from breaking Markdown tables/HTML.
    # Bound cells and rows to stay below GitHub's 1 MiB per-step summary limit.
    value = str(value).replace("\r", " ").replace("\n", " ")
    if len(value) > 80:
        value = value[:77] + "..."
    return html.escape(value, quote=True).replace("|", "&#124;")


def format_summary(result: ReportResult, advisory: bool = False) -> str:
    violations = result.violations
    counts = Counter(f.band for f in violations)
    status = "FAILED" if violations else "PASSED"
    if advisory and violations:
        status = "WARNING (advisory)"
    lines = [
        "## Trivy vulnerability policy: " + status,
        "",
        f"**{len(violations)} finding(s) cause policy failure.** "
        f"{len(result.findings) - len(violations)} non-blocking; {len(result.suppressed)} suppressed.",
        "",
        "| Critical | High | Medium | Unknown |",
        "| --- | --- | --- | --- |",
        "| " + " | ".join(str(counts[b]) for b in ("CRITICAL", "HIGH", "MEDIUM", "UNKNOWN")) + " |",
        "",
        "Ratings below are the CVSS policy's ratings, which can differ from Trivy's vendor severity. "
        "Low/NONE findings and suppressed exceptions do not cause policy failure. "
        "Full HTML, JSON and SARIF reports are available in the workflow artifacts.",
        "",
    ]
    if advisory:
        lines.extend([
            "> [!WARNING]" if violations else "> [!NOTE]",
            "> Advisory scan: vulnerability policy violations do not block this PR. "
            "The findings remain unresolved. Manual, scheduled, and branch scans enforce the policy.",
            "",
        ])
    if result.artifact:
        lines[2:2] = [f"**Image:** <code>{_summary_text(result.artifact)}</code>", ""]
    remaining = 200
    for band in ("CRITICAL", "HIGH", "MEDIUM", "UNKNOWN"):
        findings = sorted(
            (f for f in violations if f.band == band),
            key=lambda f: (f.target, f.package, f.id),
        )[:remaining]
        if not findings:
            continue
        lines.extend([f"<details open><summary>{band}: {counts[band]} failing finding(s)</summary>", ""])
        for target in dict.fromkeys(f.target for f in findings):
            lines.extend([
                f"**Target:** <code>{_summary_text(target)}</code>", "",
                "| Package | Advisory | Installed | Fixed | Score | Score source |",
                "| --- | --- | --- | --- | --- | --- |",
            ])
            for finding in (f for f in findings if f.target == target):
                advisory = _summary_text(finding.id)
                # Only render HTTP(S) links; never turn metadata into executable URLs.
                try:
                    url = urlsplit(finding.advisory_url)
                except ValueError:
                    url = None
                if (url and url.scheme in ("http", "https") and url.netloc
                        and len(finding.advisory_url) <= 256
                        and not any(c in finding.advisory_url for c in "\r\n|")):
                    advisory = f'<a href="{html.escape(finding.advisory_url, quote=True)}">{advisory}</a>'
                cells = [
                    _summary_text(finding.package), advisory,
                    _summary_text(finding.installed_version),
                    _summary_text(finding.fixed_version or "Not available"),
                    _summary_text(finding.score_display), _summary_text(finding.source),
                ]
                lines.append("| " + " | ".join(cells) + " |")
            lines.append("")
        lines.extend(["</details>", ""])
        remaining -= len(findings)
    if len(violations) > 200:
        lines.extend(["Only the first 200 failing findings are shown. See the artifacts for the complete report.", ""])
    return "\n".join(lines) + "\n"


def _format_finding(finding: Finding) -> str:
    marker = "FAIL" if finding.is_violation else "ok  "
    return (
        f"[{marker}] {finding.id:<18} pkg={finding.package:<28} "
        f"score={finding.score_display:<6} source={finding.source:<16} "
        f"band={finding.band}"
    )


def _format_suppressed(target: str, entry: dict[str, Any]) -> str:
    # Trivy nests the actual vulnerability under "Finding"; fall back to the
    # entry's own top level in case that shape ever changes.
    finding = entry.get("Finding") or {}
    finding_id = (
        finding.get("VulnerabilityID")
        or entry.get("VulnerabilityID")
        or entry.get("ID")
        or "UNKNOWN"
    )
    package = finding.get("PkgName") or entry.get("PkgName") or ""
    status = entry.get("Status", "?")
    statement = entry.get("Statement") or entry.get("Comment") or ""
    source = entry.get("Source", "?")
    return (
        f"[suppressed] {finding_id:<18} pkg={package:<20} target={target} "
        f"status={status} source={source} statement={statement!r}"
    )


def evaluate_path(path: Path) -> ReportResult:
    with path.open(encoding="utf-8") as fh:
        report = json.load(fh)
    return evaluate_report(report)


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--advisory",
        action="store_true",
        help="Report policy violations without a failing exit code; evaluation errors still fail.",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        help="Append a Markdown summary of policy failures to this file (e.g. GITHUB_STEP_SUMMARY).",
    )
    parser.add_argument(
        "reports",
        nargs="+",
        type=Path,
        help="Path(s) to Trivy JSON report file(s) to evaluate.",
    )
    args = parser.parse_args(argv)

    total_violations = 0

    for report_path in args.reports:
        print(f"== Evaluating {report_path} ==")
        result = evaluate_path(report_path)
        if args.summary:
            with args.summary.open("a", encoding="utf-8") as summary:
                summary.write(format_summary(result, advisory=args.advisory))

        if result.suppressed:
            print(f"-- {len(result.suppressed)} suppressed finding(s) (governed, unexpired) --")
            for target, entry in result.suppressed:
                print(f"  {_format_suppressed(target, entry)}")

        if result.findings:
            print(f"-- {len(result.findings)} finding(s) evaluated --")
            for finding in result.findings:
                print(f"  {_format_finding(finding)}")
        else:
            print("-- no findings --")

        violations = result.violations
        if violations:
            print(f"-- POLICY VIOLATION: {len(violations)} finding(s) in a failing band (Medium+ or Unknown) --")
            total_violations += len(violations)
        else:
            print("-- no policy violations --")
        print()

    if total_violations:
        if args.advisory:
            print(f"WARNING: {total_violations} finding(s) violate the policy; advisory mode does not block this run.")
            return 0
        print(f"FAILED: {total_violations} finding(s) violate the policy (CVSS >= Medium, or Unknown with no data).")
        return 1

    print("PASSED: no findings violate the policy (CVSS >= Medium, or Unknown with no data).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

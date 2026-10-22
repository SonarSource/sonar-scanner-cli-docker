#!/usr/bin/env python3
"""Offline regression check for the October 2026 eMudhra CA compromise.

Run inside the image being validated, with the sibling certificate fixtures.
An accepted compromised chain fails validation. Invalid fixtures or missing
tools are errors, never evidence that the image has been mitigated.
"""

import hashlib
import importlib
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys
import tempfile

DIRECTORY = Path(__file__).resolve().parent
UNTRUSTED = re.compile(r"error (?:18|19|20|21|23|27|28) at \d+ depth lookup")


def verify_chain(chain, bundle):
    return subprocess.run(
        [
            "openssl", "verify", "-no-CApath", "-no-CAstore",
            "-CAfile", str(bundle), "-purpose", "sslserver",
            "-verify_hostname", chain.stem, "-untrusted", str(chain), str(chain),
        ],
        capture_output=True, text=True, timeout=30, check=False,
    )


def check_bundle(name, bundle, chains):
    if not bundle or not Path(bundle).is_file():
        raise RuntimeError(f"{name}: CA bundle missing: {bundle}")
    accepted = 0
    for chain in chains:
        result = verify_chain(chain, bundle)
        if result.returncode == 0:
            print(f"[FAIL] {name}: still trusts {chain.stem}", flush=True)
            accepted += 1
        elif not UNTRUSTED.search(result.stderr):
            raise RuntimeError(f"{name}: inconclusive verification: {result.stderr}")
    print(f"{name}: accepted {accepted}/{len(chains)} compromised chains ({bundle})", flush=True)
    return accepted


def main():
    for line in (DIRECTORY / "fixtures.sha256").read_text().splitlines():
        expected, name = line.split(maxsplit=1)
        actual = hashlib.sha256((DIRECTORY / name).read_bytes()).hexdigest()
        if actual != expected:
            raise RuntimeError(f"Fixture checksum mismatch: {name}")

    chains = sorted((DIRECTORY / "chains").glob("*.pem"))
    if len(chains) != 12:
        raise RuntimeError(f"Expected 12 TLS chains, found {len(chains)}")
    # Positive controls: these same chains must validate with their original
    # roots. Expiry, malformed fixtures, and unsupported algorithms must fail
    # the check rather than making a vulnerable image appear protected.
    for chain in chains:
        control = verify_chain(chain, DIRECTORY / "roots.pem")
        if control.returncode:
            raise RuntimeError(f"Invalid/expired positive control {chain.name}: {control.stderr}")

    stores = {"System CA bundle": ssl.get_default_verify_paths().cafile}
    for module_name in ("certifi", "pip._vendor.certifi"):
        module = importlib.import_module(module_name)
        print(f"{module_name}: {getattr(module, '__version__', 'vendor-patched')}", flush=True)
        stores[module_name] = module.where()

    with tempfile.TemporaryDirectory() as tmp:
        node_bundle = Path(tmp) / "node.pem"
        environment = dict(os.environ, NODE_CA_BUNDLE=str(node_bundle))
        subprocess.run(
            ["node", "-e", 'require("fs").writeFileSync(process.env.NODE_CA_BUNDLE, '
             'require("tls").getCACertificates("default").join("\\n")); '
             'console.log("Node.js:", process.version);'],
            env=environment, check=True, timeout=30,
        )
        # Inspect Node's default CA set with OpenSSL. This is a bundle check,
        # not a live Node TLS handshake or a test of custom connection options.
        stores["Node default CA bundle (OpenSSL)"] = node_bundle
        accepted = sum(check_bundle(name, bundle, chains) for name, bundle in stores.items())

    # Java has its own verifier, trust store and certificate blocklist. Do not
    # infer its result from either the system or Python certificate bundles.
    java = subprocess.run(
        ["java", str(DIRECTORY / "CheckTrust.java"), str(DIRECTORY)],
        capture_output=True, text=True, check=False, timeout=90,
    )
    print(java.stdout, end="", flush=True)
    if java.stderr:
        print(java.stderr, end="", file=sys.stderr)
    if java.returncode not in (0, 1) or not re.search(
        r"^Java .+: accepted \d+/12 compromised chains$", java.stdout, re.MULTILINE
    ):
        raise RuntimeError(f"Java trust check could not complete (exit {java.returncode})")
    if accepted or java.returncode:
        print("FAILED: compromised eMudhra TLS chains are still trusted.", flush=True)
        return 1
    print("PASSED: all tested trust stores reject the compromised TLS chains.", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ImportError, subprocess.SubprocessError) as error:
        print(f"ERROR: certificate validation was inconclusive: {error}", file=sys.stderr)
        sys.exit(2)

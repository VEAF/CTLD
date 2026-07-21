"""The MM runtime path must not import lupa (it ships in the .exe without it).

lupa is a build-time dependency (gen-reference / gen-config / extract). The runtime
surface — Reference.from_embedded, validate, gen-user, the TUI — resolves names from
the committed bundle, so importing those modules must not pull lupa in. Checked in a
fresh subprocess so an earlier test importing lupa cannot mask a regression.
"""

import subprocess
import sys

_RUNTIME_IMPORTS = (
    "import ctld_tools.reference, ctld_tools.validate, ctld_tools.genuser; "
    "ctld_tools.reference.Reference.from_embedded(); "
    "import sys; "
    "assert 'lupa' not in sys.modules, sorted(m for m in sys.modules if 'lupa' in m)"
)


def test_runtime_does_not_import_lupa():
    result = subprocess.run(
        [sys.executable, "-c", _RUNTIME_IMPORTS],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr

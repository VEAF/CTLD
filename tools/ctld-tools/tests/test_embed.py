"""wrap() embeds a config YAML verbatim into a ctld.<var> Lua string module."""

import re

from ctld_tools.embed import wrap

YAML = 'configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\n'


def _between_brackets(module: str) -> str:
    # Capture the payload between the opening [=*[ and its matching ]=*] delimiter.
    m = re.search(r"= \[(=*)\[\n(.*)\]\1\]\n\Z", module, re.DOTALL)
    assert m, module
    return m.group(2)


def test_wraps_into_config_default_by_default():
    module = wrap(YAML)
    assert "ctld = ctld or {}" in module
    assert "ctld.configDefault = [[" in module
    assert _between_brackets(module) == YAML


def test_var_selects_the_target_global():
    module = wrap(YAML, var="configUser")
    assert "ctld.configUser = [[" in module
    assert _between_brackets(module) == YAML


def test_bracket_level_escalates_to_avoid_collision():
    # Content containing ']]' forces a higher long-bracket level so the closer is unique.
    payload = "a: 'has ]] inside'\n"
    module = wrap(payload)
    assert "[=[" in module and "]=]" in module
    assert _between_brackets(module) == payload


def test_payload_is_verbatim():
    # No escaping, no reflow — the YAML is embedded byte-for-byte.
    assert _between_brackets(wrap(YAML)) == YAML

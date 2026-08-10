"""New-empty-stub detection: which i18n keys a PR newly blanked out, vs. pre-existing debt."""

from check_i18n_diff import find_new_empty_keys


def test_new_key_added_empty_is_flagged():
    base_text = ""
    head_text = 'ctld.i18n["ko"]["Actions"] = ""\n'
    assert find_new_empty_keys(base_text, head_text) == ["Actions"]


def test_already_empty_at_base_is_not_flagged():
    base_text = 'ctld.i18n["ko"]["Actions"] = ""\n'
    head_text = 'ctld.i18n["ko"]["Actions"] = ""\n'
    assert find_new_empty_keys(base_text, head_text) == []


def test_translated_then_blanked_is_flagged():
    base_text = 'ctld.i18n["ko"]["Actions"] = "액션"\n'
    head_text = 'ctld.i18n["ko"]["Actions"] = ""\n'
    assert find_new_empty_keys(base_text, head_text) == ["Actions"]


def test_real_translation_is_not_flagged():
    base_text = 'ctld.i18n["ko"]["Actions"] = ""\n'
    head_text = 'ctld.i18n["ko"]["Actions"] = "액션"\n'
    assert find_new_empty_keys(base_text, head_text) == []


def test_multiple_keys_only_new_empties_reported():
    base_text = (
        'ctld.i18n["ko"]["Already Empty"] = ""\n'
        'ctld.i18n["ko"]["Translated"] = "번역됨"\n'
    )
    head_text = (
        'ctld.i18n["ko"]["Already Empty"] = ""\n'
        'ctld.i18n["ko"]["Translated"] = "번역됨"\n'
        'ctld.i18n["ko"]["New Key"] = ""\n'
    )
    assert find_new_empty_keys(base_text, head_text) == ["New Key"]

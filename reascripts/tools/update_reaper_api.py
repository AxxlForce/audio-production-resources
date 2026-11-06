#!/usr/bin/env python3

import argparse
import html
import re
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path


DEFAULT_URL = "https://www.reaper.fm/sdk/reascript/reascripthelp.html"


# ----------------------------------------------------------------------
# Lua keywords
# ----------------------------------------------------------------------

LUA_KEYWORDS = {
    "and",
    "break",
    "do",
    "else",
    "elseif",
    "end",
    "false",
    "for",
    "function",
    "goto",
    "if",
    "in",
    "local",
    "nil",
    "not",
    "or",
    "repeat",
    "return",
    "then",
    "true",
    "until",
    "while",
}


# ----------------------------------------------------------------------
# Type conversion
# ----------------------------------------------------------------------

TYPE_MAP = {
    "bool": "boolean",
    "boolean": "boolean",

    "int": "integer",
    "integer": "integer",

    "double": "number",
    "float": "number",
    "number": "number",

    "char*": "string",
    "const char*": "string",
    "string": "string",

    "void": "nil",
}


def lua_type(type_name):
    """
    Convert REAPER documentation types to EmmyLua types.
    """

    type_name = type_name.strip()

    if type_name in TYPE_MAP:
        return TYPE_MAP[type_name]

    # REAPER userdata pointers:
    #
    # MediaTrack* -> MediaTrack
    # ReaProject* -> ReaProject
    #
    if type_name.endswith("*"):
        return type_name[:-1].strip()

    return type_name


def safe_argument_name(name):
    """
    Lua keywords cannot be used as function argument identifiers.
    Prefix them with '_' while keeping the semantic name recognizable.
    """

    if name in LUA_KEYWORDS:
        return "_" + name

    return name


# ----------------------------------------------------------------------
# Download
# ----------------------------------------------------------------------

def fetch_url(url):

    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "REAPER-Lua-API-Updater/1.0"
        },
    )

    try:

        context = ssl.create_default_context()

        with urllib.request.urlopen(
                req,
                timeout=30,
                context=context,
        ) as response:

            return response.read().decode(
                "utf-8",
                errors="replace",
            )

    except urllib.error.URLError as exc:

        if not isinstance(
                exc.reason,
                ssl.SSLCertVerificationError,
        ):
            raise

        try:
            import certifi

        except ImportError:

            raise RuntimeError(
                "SSL certificate verification failed and "
                "certifi is not installed.\n\n"
                "Install it with:\n"
                "    python3 -m pip install certifi"
            ) from exc

        print(
            "System CA certificates unavailable; using certifi."
        )

        context = ssl.create_default_context(
            cafile=certifi.where(),
        )

        with urllib.request.urlopen(
                req,
                timeout=30,
                context=context,
        ) as response:

            return response.read().decode(
                "utf-8",
                errors="replace",
            )


# ----------------------------------------------------------------------
# HTML handling
# ----------------------------------------------------------------------

def html_to_text(source):
    """
    Convert the REAPER HTML documentation into plain text.

    Block elements are converted into newlines so that API entries
    remain separated.
    """

    # Remove scripts and styles first.
    source = re.sub(
        r"<script\b.*?</script>",
        "",
        source,
        flags=re.IGNORECASE | re.DOTALL,
    )

    source = re.sub(
        r"<style\b.*?</style>",
        "",
        source,
        flags=re.IGNORECASE | re.DOTALL,
    )

    # Preserve useful line boundaries.
    source = re.sub(
        r"<\s*(br|p|div|li|tr|h[1-6])[^>]*>",
        "\n",
        source,
        flags=re.IGNORECASE,
    )

    # Remove remaining tags.
    source = re.sub(
        r"<[^>]+>",
        "",
        source,
    )

    # Decode HTML entities.
    source = html.unescape(source)

    # Normalize lines.
    lines = []

    for line in source.splitlines():

        line = re.sub(
            r"[ \t]+",
            " ",
            line,
        ).strip()

        if line:
            lines.append(line)

    return "\n".join(lines)


# ----------------------------------------------------------------------
# Signature parsing
# ----------------------------------------------------------------------

def split_csv(text):
    """
    Split a comma-separated argument/return list.

    Handles parentheses defensively in case a future REAPER API
    signature contains nested syntax.
    """

    parts = []
    current = []
    depth = 0

    for char in text:

        if char == "(":
            depth += 1

        elif char == ")":
            depth -= 1

        if char == "," and depth == 0:

            parts.append(
                "".join(current).strip()
            )

            current = []

        else:
            current.append(char)

    if current:
        parts.append(
            "".join(current).strip()
        )

    return [
        part
        for part in parts
        if part
    ]


def parse_value_declaration(text):
    """
    Parse:

        MediaTrack track

    or:

        string name

    Returns:

        (type, name)
    """

    text = text.strip()

    match = re.match(
        r"^(.*?)\s+([A-Za-z_][A-Za-z0-9_]*)$",
        text,
    )

    if not match:
        return None

    type_name = match.group(1).strip()
    name = match.group(2).strip()

    return (
        type_name,
        name,
    )


def parse_signature(text):
    """
    Parse a REAPER Lua declaration such as:

        MediaTrack reaper.GetSelectedTrack(
            ReaProject proj,
            integer seltrackidx
        )

    or:

        number start, number end =
            reaper.GetSet_LoopTimeRange(
                boolean isSet,
                boolean isLoop,
                number start,
                number end,
                boolean allowautoseek
            )
    """

    text = text.strip()

    text = re.sub(
        r"^\s*Lua\s*:\s*",
        "",
        text,
        flags=re.IGNORECASE,
    )

    # Find the reaper function.
    match = re.search(
        r"""
        (?P<returns>.*?)
        \s*
        reaper\.
        (?P<name>[A-Za-z_][A-Za-z0-9_]*)
        \s*
        \(
        (?P<args>.*?)
        \)
        """,
        text,
        flags=re.VERBOSE,
    )

    if not match:
        return None

    function_name = match.group("name")

    returns_text = match.group("returns").strip()
    args_text = match.group("args").strip()

    # Remove '=' from return declaration.
    returns_text = re.sub(
        r"=\s*$",
        "",
        returns_text,
    ).strip()

    # --------------------------------------------------------------
    # Returns
    # --------------------------------------------------------------

    returns = []

    if returns_text:

        for item in split_csv(returns_text):

            parsed = parse_value_declaration(item)

            if parsed:

                type_name, name = parsed

                returns.append(
                    (
                        lua_type(type_name),
                        name,
                    )
                )

    # --------------------------------------------------------------
    # Arguments
    # --------------------------------------------------------------

    args = []

    if args_text:

        for item in split_csv(args_text):

            parsed = parse_value_declaration(item)

            if not parsed:
                continue

            type_name, name = parsed

            safe_name = safe_argument_name(name)

            args.append(
                (
                    safe_name,
                    lua_type(type_name),
                )
            )

    return {
        "name": function_name,
        "args": args,
        "returns": returns,
    }


# ----------------------------------------------------------------------
# Extract API signatures
# ----------------------------------------------------------------------

def extract_signatures(source):

    text = html_to_text(source)

    signatures = []

    lines = text.splitlines()

    for index, line in enumerate(lines):

        if not re.search(
                r"\bLua\s*:",
                line,
                flags=re.IGNORECASE,
        ):
            continue

        # Normally the entire declaration is on one line.
        candidates = [
            line,
            " ".join(
                lines[index:index + 2]
            ),
            " ".join(
                lines[index:index + 3]
            ),
        ]

        parsed = None

        for candidate in candidates:

            parsed = parse_signature(
                candidate
            )

            if parsed:
                break

        if parsed:
            signatures.append(parsed)

    # --------------------------------------------------------------
    # Remove duplicates
    # --------------------------------------------------------------

    unique = []
    seen = set()

    for signature in signatures:

        name = signature["name"]

        if name in seen:
            continue

        seen.add(name)
        unique.append(signature)

    return unique


# ----------------------------------------------------------------------
# Generate EmmyLua
# ----------------------------------------------------------------------

def generate_stub(signatures):

    output = []

    output.append(
        """---@meta

--- REAPER ReaScript Lua API
--- Automatically generated from the official REAPER API documentation.
--- DO NOT EDIT THIS FILE MANUALLY.
"""
    )

    # ------------------------------------------------------------------
    # Known REAPER userdata
    # ------------------------------------------------------------------

    userdata_types = [
        "ReaProject",
        "MediaTrack",
        "MediaItem",
        "MediaItem_Take",
        "TrackEnvelope",
        "PCM_source",
        "PCM_source_transfer_t",
        "TrackFX",
        "MIDI_event_t",
        "MIDI_Input",
        "MIDI_Output",
        "ProjectMarker",
        "AudioAccessor",
    ]

    output.append(
        "\n-- REAPER userdata types\n"
    )

    for type_name in userdata_types:

        output.append(
            f"---@class {type_name}"
        )

    # ------------------------------------------------------------------
    # API
    # ------------------------------------------------------------------

    output.append(
        "\n\n-- REAPER API\n"
    )

    for signature in signatures:

        name = signature["name"]
        args = signature["args"]
        returns = signature["returns"]

        output.append("")

        # --------------------------------------------------------------
        # Parameters
        # --------------------------------------------------------------

        for arg_name, arg_type in args:

            output.append(
                f"---@param {arg_name} {arg_type}"
            )

        # --------------------------------------------------------------
        # Returns
        # --------------------------------------------------------------

        for return_type, return_name in returns:

            output.append(
                f"---@return {return_type}"
                f" {return_name}"
            )

        # --------------------------------------------------------------
        # Function declaration
        # --------------------------------------------------------------

        arg_names = ", ".join(
            arg_name
            for arg_name, _ in args
        )

        output.append(
            f"function reaper.{name}"
            f"({arg_names}) end"
        )

    return "\n".join(output) + "\n"


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

def main():

    parser = argparse.ArgumentParser(
        description=(
            "Generate EmmyLua definitions from "
            "the official REAPER API documentation."
        )
    )

    parser.add_argument(
        "--url",
        default=DEFAULT_URL,
        help="REAPER API documentation URL",
    )

    parser.add_argument(
        "--input",
        type=Path,
        help=(
            "Use a local reascripthelp.html "
            "instead of downloading it"
        ),
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=Path(
            "api/reaper_api.lua"
        ),
        help="Output Lua definition file",
    )

    args = parser.parse_args()

    # ------------------------------------------------------------------
    # Load documentation
    # ------------------------------------------------------------------

    if args.input:

        print(
            f"Reading local API documentation: "
            f"{args.input}"
        )

        source = args.input.read_text(
            encoding="utf-8",
            errors="replace",
        )

    else:

        print(
            "Downloading REAPER API documentation:"
        )

        print(
            f"  {args.url}"
        )

        try:

            source = fetch_url(
                args.url
            )

        except Exception as exc:

            print(
                "\nERROR: Could not download "
                "REAPER API documentation.",
                file=sys.stderr,
            )

            print(
                exc,
                file=sys.stderr,
            )

            sys.exit(1)

    # ------------------------------------------------------------------
    # Parse
    # ------------------------------------------------------------------

    signatures = extract_signatures(
        source
    )

    if not signatures:

        print(
            "\nERROR: No Lua API signatures "
            "were found.",
            file=sys.stderr,
        )

        sys.exit(1)

    print(
        f"Found {len(signatures)} API functions."
    )

    # ------------------------------------------------------------------
    # Generate
    # ------------------------------------------------------------------

    generated = generate_stub(
        signatures
    )

    args.output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    args.output.write_text(
        generated,
        encoding="utf-8",
    )

    print(
        f"Generated: {args.output}"
    )


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""Update appcast.xml with a new release entry."""

import argparse
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")


def markdown_to_html(md: str) -> str:
    """Convert simple GitHub release markdown to styled HTML."""
    lines = md.strip().split("\n")
    html_parts = [
        "<style>",
        "body { font-family: -apple-system, sans-serif; font-size: 13px; "
        "line-height: 1.5; color: -apple-system-label; }",
        "h2 { font-size: 15px; margin: 16px 0 8px; }",
        "h3 { font-size: 14px; margin: 12px 0 6px; }",
        "ul { padding-left: 20px; margin: 4px 0; }",
        "li { margin: 2px 0; }",
        "code { background: -apple-system-quaternary-label; "
        "padding: 1px 4px; border-radius: 3px; font-size: 12px; }",
        "a { color: -apple-system-blue; text-decoration: none; }",
        "</style>",
    ]

    in_list = False
    for line in lines:
        stripped = line.strip()

        # Skip empty lines
        if not stripped:
            if in_list:
                html_parts.append("</ul>")
                in_list = False
            continue

        # Headers
        if stripped.startswith("### "):
            if in_list:
                html_parts.append("</ul>")
                in_list = False
            html_parts.append(f"<h3>{inline_format(stripped[4:])}</h3>")
            continue
        if stripped.startswith("## "):
            if in_list:
                html_parts.append("</ul>")
                in_list = False
            html_parts.append(f"<h2>{inline_format(stripped[3:])}</h2>")
            continue

        # List items
        if stripped.startswith("* ") or stripped.startswith("- "):
            if not in_list:
                html_parts.append("<ul>")
                in_list = True
            html_parts.append(f"<li>{inline_format(stripped[2:])}</li>")
            continue

        # Paragraph
        if in_list:
            html_parts.append("</ul>")
            in_list = False
        html_parts.append(f"<p>{inline_format(stripped)}</p>")

    if in_list:
        html_parts.append("</ul>")

    return "\n".join(html_parts)


def inline_format(text: str) -> str:
    """Convert inline markdown (bold, code, links) to HTML."""
    # Links: [text](url)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    # Bold: **text**
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    # Inline code: `text`
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return text


def main():
    parser = argparse.ArgumentParser(description="Update Sparkle appcast.xml")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--length", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--notes", default="", help="Markdown release notes")
    parser.add_argument("--min-os", default="14.0")
    args = parser.parse_args()

    tree = ET.parse(args.appcast)
    root = tree.getroot()
    channel = root.find("channel")

    item = ET.SubElement(channel, "item")

    title = ET.SubElement(item, "title")
    title.text = f"Version {args.version}"

    pub_date = ET.SubElement(item, "pubDate")
    pub_date.text = datetime.now(timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S %z"
    )

    version = ET.SubElement(item, f"{{{SPARKLE_NS}}}version")
    version.text = args.build

    short_version = ET.SubElement(item, f"{{{SPARKLE_NS}}}shortVersionString")
    short_version.text = args.version

    min_os = ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion")
    min_os.text = args.min_os

    if args.notes:
        desc = ET.SubElement(item, "description")
        desc.text = markdown_to_html(args.notes)

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", args.url)
    enclosure.set("length", args.length)
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{{{SPARKLE_NS}}}edSignature", args.signature)

    ET.indent(tree, space="  ")
    tree.write(args.appcast, xml_declaration=True, encoding="utf-8")


if __name__ == "__main__":
    main()

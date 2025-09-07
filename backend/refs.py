import os
from typing import List
import bibtexparser
from citeproc import CitationStylesStyle, CitationStylesBibliography
from citeproc import formatter
from citeproc.source.bibtex import BibTeX

CSL_STYLE = os.getenv("CSL_STYLE", "backend/csl_styles/nature.csl")

BIB_DB = None

def load_bibtex(bib_text: str) -> int:
    global BIB_DB
    BIB_DB = bibtexparser.loads(bib_text)
    return len(BIB_DB.entries)

def cite(keys: List[str], style_path: str = CSL_STYLE) -> str:
    if BIB_DB is None:
        return "(No bibliography loaded)"
    style = CitationStylesStyle(style_path, validate=False)
    bib_source = BibTeX(BIB_DB)
    bibliography = CitationStylesBibliography(style, bib_source, formatter.html)
    out = []
    for key in keys:
        for e in BIB_DB.entries:
            if e.get("ID") == key:
                bibliography.register(e)
                out.append(str(bibliography.bibliography()[0]))
    return "\n".join(out)

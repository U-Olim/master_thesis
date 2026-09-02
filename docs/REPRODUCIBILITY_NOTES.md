# Reproducibility notes

Empirical manifests contain SHA-256 hashes of the canonical Windows working-tree files. Git or GitHub archive/export representations may use LF line endings for tracked text files instead of the Windows working tree's CRLF line endings. Raw SHA-256 values can therefore differ even when textual content is identical.

Integrity checks performed on the canonical Windows project remain authoritative, and no result discrepancy was detected. Binary and result artifacts should be verified against their canonical manifests without line-ending normalization unless such normalization is explicitly documented.

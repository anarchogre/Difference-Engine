from dataclasses import dataclass


@dataclass(frozen=True)
class ProvenanceRecord:
    provenance_id: str
    artifact_id: str
    source_path: str
    source_sha256: str
    relationship: str = "observed_from"


def build(receipt):
    return ProvenanceRecord(
        provenance_id=f"PROV-{receipt.receipt_id}",
        artifact_id=receipt.receipt_id,
        source_path=receipt.observed_path,
        source_sha256=receipt.sha256,
    )

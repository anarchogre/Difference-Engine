from enum import Enum


class Stage(str, Enum):
    RECEIPT = "receipt"
    INTAKE = "intake"
    PARSE = "parse"
    ASSETS = "assets"
    REFERENCES = "references"
    QUEUES = "queues"
    VALIDATION = "validation"
    PROVENANCE = "provenance"
    OUTPUT = "output"
    MANIFEST = "manifest"
    INDEX = "index"

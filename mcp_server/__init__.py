"""Knowledge RAG MCP Server - Local Retrieval-Augmented Generation System"""

__version__ = "3.2.0"
__author__ = "Ailton Rocha (Lyon.)"

from .config import Config
from .ingestion import DocumentParser, Document

__all__ = ["Config", "DocumentParser", "Document"]

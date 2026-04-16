"""Knowledge RAG MCP Server - Local Retrieval-Augmented Generation System"""

__version__ = "3.4.1"
__author__ = "Ailton Rocha (Lyon.)"

from .config import Config
from .ingestion import Document, DocumentParser

__all__ = ["Config", "DocumentParser", "Document"]

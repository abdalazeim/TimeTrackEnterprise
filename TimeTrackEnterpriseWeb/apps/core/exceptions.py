"""Core exceptions."""
from __future__ import annotations


class CoreError(Exception):
    """Base exception for core app errors."""


class ConfigurationError(CoreError):
    """Raised when a required setting is missing or invalid."""


class PermissionDenied(CoreError):
    """Raised when a user lacks permission for an operation."""


class DuplicateEntryError(CoreError):
    """Raised when a unique constraint is violated."""


class RecordNotFoundError(CoreError):
    """Raised when a requested record does not exist."""
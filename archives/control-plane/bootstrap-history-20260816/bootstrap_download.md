# BOOTSTRAP.md

**Version:** 1.0.0
**Status:** Canonical

# Purpose

This document defines the standard procedure for bringing an ADE repository into a verified working state.

## Objectives

- Verify repository integrity.
- Configure the development environment.
- Establish Git identity.
- Confirm repository structure.
- Ensure reproducible engineering.

# Bootstrap Procedure

1. Clone the repository.
2. Configure Git identity.
3. Verify with `git status`.
4. Verify editing, commit, and push.
5. Read the governing documents.
6. Verify recovery assets.

## Git Identity

git config --global user.name "<username>"
git config --global user.email "<email>"
git config --global --list

## Success Criteria

- Repository cloned
- Git configured
- Repository verified
- Push confirmed
- Working tree clean

# Guiding Principle

A repository that cannot be rebuilt cannot be trusted.

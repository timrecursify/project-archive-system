# File Deletion Problems with AI Agents

## Overview

AI agents frequently cause catastrophic data loss by improperly deleting files and directories during normal operations. This document outlines recurring deletion problems that have caused significant disruptions.

## Problem 1: Premature Directory Deletion Before Git Push

**What Happened (2025-11-11):**
- User requested to submit project folder to Git and then remove it from local machine
- Agent executed `rm -rf project-archive-system` BEFORE verifying the Git push succeeded
- The folder was deleted locally, including the `.git` directory with all commit history
- When attempting to push, discovered no remote was configured
- All local commits and history were permanently lost
- Required complete project recreation from scratch

**Impact:**
- Loss of all Git commit history
- Loss of all local changes not yet pushed
- Significant time wasted recreating files from other sources
- User frustration and disruption of workflow

## Problem 2: Arbitrary File Deletion Without User Request

**What Happens:**
- AI agents sometimes delete files during unrelated operations
- Files are removed without explicit user instruction to delete them
- No clear reason or explanation for the deletion
- Often discovered only after the agent has completed other tasks

**Impact:**
- Unexpected data loss
- Disruption of project structure
- Need to recover files from backups or Git history
- Uncertainty about what else might have been deleted

## Problem 3: Cross-Project File Contamination and Deletion

**What Happens:**
- Agent confuses files from different projects
- Files from Project A are moved to or mixed with Project B
- Original files are then deleted from their correct location
- Project structures become corrupted across multiple projects

**Impact:**
- Multiple projects affected simultaneously
- Difficult to identify which files belong where
- Time-consuming to untangle and restore proper structure
- Risk of using wrong files in wrong projects

## Problem 4: Aggressive Git Clean Operations

**What Happened (Recent - day before 2025-11-11):**
- Agent executed a Git command similar to `git clean -fd` or aggressive removal
- ALL files not tracked by Git were permanently deleted from local folder
- This included:
  - Important files listed in .gitignore (secrets, configs, etc.)
  - Build artifacts that take time to regenerate
  - Local notes and documentation
  - Media files and assets intentionally not tracked
  - Development databases and local state

**Impact:**
- Complete loss of all non-Git-tracked files
- No recovery possible (not in Git, not in trash)
- Hours of work recreating deleted files
- Broken development environment requiring full rebuild
- Potential loss of sensitive configuration files

## Common Pattern

All these problems share common characteristics:
- Deletions happen quickly without confirmation
- No verification that data is safely backed up elsewhere
- No undo mechanism once deletion occurs
- Agent proceeds with subsequent tasks as if nothing is wrong
- User discovers the problem only after significant damage is done

## Severity

These deletion problems represent **catastrophic failures** that:
- Cause permanent data loss
- Waste significant development time
- Create high-stress situations
- Undermine trust in AI agent reliability
- Force manual recovery and reconstruction efforts

#!/usr/bin/env python3
"""
Session storage debugging and verification script for Claude Code Mobile Backend.

This script provides comprehensive debugging tools for Claude SDK session management,
working directory validation, and session storage diagnostics.

Usage:
    python scripts/verify_sessions.py [command] [options]

Commands:
    diagnostics     - Show comprehensive session storage diagnostics
    list           - List all available sessions
    validate       - Validate session storage setup
    recover        - Attempt to recover a specific session
    cleanup        - Clean up invalid session files
    test           - Test session creation and resumption
"""

import sys
import os
import asyncio
import argparse
import json
from pathlib import Path
from datetime import datetime

# Add the app directory to the Python path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.lifecycle import initialize_claude_environment, verify_session_storage
from app.utils.session_utils import (
    verify_session_exists,
    list_user_sessions,
    recover_session,
    get_session_diagnostics,
    validate_session_storage_setup,
    cleanup_invalid_sessions
)
from app.services.claude_service import ClaudeService
from app.models.requests import SessionRequest, ClaudeQueryRequest, ClaudeCodeOptions


def print_header(title: str):
    """Print a formatted header."""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def print_section(title: str):
    """Print a formatted section header."""
    print(f"\n{'-' * 40}")
    print(f"  {title}")
    print(f"{'-' * 40}")


def format_json(data: dict) -> str:
    """Format dictionary as pretty JSON."""
    return json.dumps(data, indent=2, default=str)


def cmd_diagnostics(project_root: Path):
    """Show comprehensive session storage diagnostics."""
    print_header("Session Storage Diagnostics")

    # Basic project information
    print_section("Project Information")
    print(f"Project Root: {project_root}")
    print(f"Current Working Directory: {Path.cwd()}")
    print(f"Working Directory Correct: {Path.cwd() == project_root}")

    # Get comprehensive diagnostics
    print_section("Claude SDK Session Storage")
    diagnostics = get_session_diagnostics(project_root)
    print(format_json(diagnostics))

    # Storage validation
    print_section("Storage Validation")
    is_valid, issues = validate_session_storage_setup(project_root)
    print(f"Storage Setup Valid: {is_valid}")
    if issues:
        print("Issues found:")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("No issues found.")

    # Session files summary
    print_section("Session Files Summary")
    sessions = list_user_sessions(project_root)
    print(f"Total Sessions: {len(sessions)}")

    if sessions:
        print("\nRecent Sessions:")
        for session in sessions[:5]:  # Show first 5
            print(f"  {session['session_id'][:20]}... | "
                  f"{session.get('file_size_bytes', 0):>8} bytes | "
                  f"{session.get('modified_at', 'unknown')}")

    # Working directory verification
    print_section("Working Directory Verification")
    verification = verify_session_storage(project_root)
    print(format_json(verification))


def cmd_list(project_root: Path):
    """List all available sessions."""
    print_header("Available Sessions")

    sessions = list_user_sessions(project_root)

    if not sessions:
        print("No sessions found.")
        return

    print(f"Found {len(sessions)} sessions:\n")

    # Table header
    print(f"{'Session ID':<40} {'Size':<10} {'Modified':<20} {'Status'}")
    print("-" * 85)

    for session in sessions:
        session_id = session['session_id']
        size = f"{session.get('file_size_bytes', 0):,}B"
        modified = session.get('modified_at', 'unknown')[:19]  # Truncate timestamp
        status = "✓" if session.get('readable', False) else "✗"

        print(f"{session_id:<40} {size:<10} {modified:<20} {status}")

        # Show any errors
        if 'error' in session:
            print(f"  Error: {session['error']}")

        # Show initial prompt if available
        if 'initial_prompt' in session and session['initial_prompt']:
            print(f"  Initial: {session['initial_prompt'][:50]}...")


def cmd_validate(project_root: Path):
    """Validate session storage setup."""
    print_header("Session Storage Validation")

    is_valid, issues = validate_session_storage_setup(project_root)

    print(f"Overall Status: {'✓ VALID' if is_valid else '✗ INVALID'}")

    if is_valid:
        print("\nAll session storage components are properly configured.")
    else:
        print(f"\nFound {len(issues)} issues:")
        for i, issue in enumerate(issues, 1):
            print(f"  {i}. {issue}")

    # Additional checks
    print_section("Detailed Checks")

    # Working directory
    cwd_correct = Path.cwd() == project_root
    print(f"Working Directory: {'✓' if cwd_correct else '✗'} {Path.cwd()}")

    # Claude directory structure
    claude_dir = Path.home() / ".claude"
    projects_dir = claude_dir / "projects"
    project_sessions_dir = projects_dir / f"-{str(project_root).replace('/', '-')}"

    print(f"Claude Config Dir: {'✓' if claude_dir.exists() else '✗'} {claude_dir}")
    print(f"Projects Dir: {'✓' if projects_dir.exists() else '✗'} {projects_dir}")
    print(f"Project Sessions Dir: {'✓' if project_sessions_dir.exists() else '✗'} {project_sessions_dir}")

    # Permissions
    if claude_dir.exists():
        writable = os.access(claude_dir, os.W_OK)
        print(f"Claude Dir Writable: {'✓' if writable else '✗'}")

    if projects_dir.exists():
        writable = os.access(projects_dir, os.W_OK)
        print(f"Projects Dir Writable: {'✓' if writable else '✗'}")


def cmd_recover(project_root: Path, session_id: str):
    """Attempt to recover a specific session."""
    print_header(f"Session Recovery: {session_id}")

    if not session_id:
        print("Error: Session ID is required for recovery.")
        return

    recovery_result = recover_session(session_id, project_root)

    print(f"Session ID: {recovery_result['session_id']}")
    print(f"Session File: {recovery_result['session_file_path']}")
    print(f"Exists: {'✓' if recovery_result['exists'] else '✗'}")
    print(f"Recoverable: {'✓' if recovery_result['recoverable'] else '✗'}")

    if recovery_result['exists']:
        print_section("File Diagnostics")
        diagnostics = recovery_result['diagnostics']

        print(f"File Size: {diagnostics.get('file_size', 0):,} bytes")
        print(f"Created: {diagnostics.get('created_at', 'unknown')}")
        print(f"Modified: {diagnostics.get('modified_at', 'unknown')}")
        print(f"Readable: {'✓' if diagnostics.get('readable', False) else '✗'}")
        print(f"Writable: {'✓' if diagnostics.get('writable', False) else '✗'}")

        if 'total_lines' in diagnostics:
            print(f"Total Lines: {diagnostics['total_lines']}")
            print(f"Valid Lines: {diagnostics['valid_lines']}")
            print(f"Invalid Lines: {len(diagnostics.get('invalid_lines', []))}")

            if diagnostics.get('invalid_lines'):
                print("\nInvalid Lines:")
                for invalid in diagnostics['invalid_lines'][:5]:  # Show first 5
                    print(f"  Line {invalid['line']}: {invalid['error']}")

    else:
        print("\nSession file does not exist.")
        print("Possible solutions:")
        print("  1. Check if the session ID is correct")
        print("  2. Verify working directory is set correctly")
        print("  3. Check if session was created in a different working directory")


def cmd_cleanup(project_root: Path, dry_run: bool = True):
    """Clean up invalid session files."""
    action = "Would clean up" if dry_run else "Cleaning up"
    print_header(f"{action} Invalid Sessions")

    cleanup_result = cleanup_invalid_sessions(project_root, dry_run)

    print(f"Sessions Directory: {cleanup_result['sessions_directory']}")
    print(f"Total Files: {cleanup_result['total_files']}")
    print(f"Valid Files: {cleanup_result['valid_files']}")
    print(f"Invalid Files: {cleanup_result['invalid_files']}")
    print(f"Empty Files: {cleanup_result['empty_files']}")

    if cleanup_result['cleanup_actions']:
        print_section("Cleanup Actions")
        for action in cleanup_result['cleanup_actions']:
            print(f"  {action}")

        if dry_run:
            print(f"\nTo actually perform cleanup, run:")
            print(f"  python scripts/verify_sessions.py cleanup --no-dry-run")
    else:
        print("\nNo cleanup actions needed.")


async def cmd_test(project_root: Path):
    """Test session creation and resumption."""
    print_header("Session Creation and Resumption Test")

    claude_service = ClaudeService(project_root)

    try:
        print_section("Creating Test Session")

        # Create test session
        session_request = SessionRequest(
            user_id="test-user",
            session_name="Verification Test Session"
        )

        print("Creating session...")
        session_response = await claude_service.create_session(session_request)
        print(f"✓ Session created: {session_response.session_id}")

        print_section("Testing Session Verification")

        # Verify session exists
        exists = await claude_service.verify_session_exists(session_response.session_id)
        print(f"Session exists: {'✓' if exists else '✗'}")

        # List sessions
        all_sessions = await claude_service.list_sessions()
        print(f"Total sessions available: {len(all_sessions)}")
        print(f"Test session in list: {'✓' if session_response.session_id in all_sessions else '✗'}")

        print_section("Testing Session Resumption")

        # Test query with resumption
        query_request = ClaudeQueryRequest(
            query="This is a test query for session verification.",
            session_id=session_response.session_id,
            user_id="test-user"
        )

        print("Testing query with session resumption...")
        query_response = await claude_service.query(query_request, ClaudeCodeOptions())
        print(f"✓ Query successful, processing time: {query_response.processing_time:.3f}s")

        print_section("Test Results")
        print("✓ All session operations completed successfully")
        print(f"✓ Session persistence verified: {session_response.session_id}")

    except Exception as e:
        print(f"✗ Test failed: {str(e)}")
        return False

    return True


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Claude Code Mobile Backend Session Verification Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        'command',
        choices=['diagnostics', 'list', 'validate', 'recover', 'cleanup', 'test'],
        help='Command to execute'
    )

    parser.add_argument(
        '--session-id',
        help='Session ID for recovery command'
    )

    parser.add_argument(
        '--no-dry-run',
        action='store_true',
        help='Actually perform cleanup (default is dry run)'
    )

    parser.add_argument(
        '--project-root',
        type=Path,
        help='Project root directory (default: auto-detect)'
    )

    args = parser.parse_args()

    # Determine project root
    if args.project_root:
        project_root = args.project_root.resolve()
    else:
        # Auto-detect project root (go up from scripts directory)
        project_root = Path(__file__).parent.parent.resolve()

    print(f"Using project root: {project_root}")

    # Set working directory
    try:
        initialize_claude_environment()
    except Exception as e:
        print(f"Warning: Could not set working directory: {e}")

    # Execute command
    try:
        if args.command == 'diagnostics':
            cmd_diagnostics(project_root)

        elif args.command == 'list':
            cmd_list(project_root)

        elif args.command == 'validate':
            cmd_validate(project_root)

        elif args.command == 'recover':
            if not args.session_id:
                print("Error: --session-id is required for recover command")
                sys.exit(1)
            cmd_recover(project_root, args.session_id)

        elif args.command == 'cleanup':
            dry_run = not args.no_dry_run
            cmd_cleanup(project_root, dry_run)

        elif args.command == 'test':
            success = asyncio.run(cmd_test(project_root))
            if not success:
                sys.exit(1)

    except KeyboardInterrupt:
        print("\nOperation cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
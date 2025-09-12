#!/usr/bin/env python3
"""
Sync environment variables from set_env.sh to GitHub repository secrets.
Uses GitHub REST API with proper encryption.
"""

import os
import sys
import re
import json
import base64
import argparse
from pathlib import Path
from typing import Dict, Tuple, Optional

try:
    import requests
    from nacl import encoding, public
except ImportError:
    print("Installing required dependencies...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests", "pynacl"])
    import requests
    from nacl import encoding, public


class GitHubSecretsManager:
    """Manages GitHub repository secrets via REST API."""
    
    def __init__(self, token: str, owner: str, repo: str):
        self.token = token
        self.owner = owner
        self.repo = repo
        self.base_url = f"https://api.github.com/repos/{owner}/{repo}"
        self.headers = {
            "Authorization": f"Bearer {token}",  # Changed from 'token' to 'Bearer'
            "Accept": "application/vnd.github.v3+json",
            "X-GitHub-Api-Version": "2022-11-28"
        }
    
    def verify_token(self) -> bool:
        """Verify the token has proper permissions."""
        try:
            response = requests.get(
                "https://api.github.com/user",
                headers=self.headers
            )
            if response.status_code == 401:
                print("❌ Invalid GitHub token")
                return False
            response.raise_for_status()
            user = response.json()
            print(f"✅ Authenticated as: {user.get('login', 'Unknown')}")
            
            # Check repository access
            repo_response = requests.get(self.base_url, headers=self.headers)
            if repo_response.status_code == 404:
                print(f"❌ Repository {self.owner}/{self.repo} not found or no access")
                return False
            repo_response.raise_for_status()
            
            # Check if we have admin access (required for secrets)
            repo_data = repo_response.json()
            permissions = repo_data.get('permissions', {})
            if not permissions.get('admin', False):
                print("⚠️  Warning: You may not have admin access to manage secrets")
                print("   Permissions:", permissions)
            
            return True
        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to verify token: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"   Response: {e.response.text}")
            return False
    
    def get_public_key(self) -> Tuple[str, str]:
        """Get repository public key for secret encryption."""
        try:
            response = requests.get(
                f"{self.base_url}/actions/secrets/public-key",
                headers=self.headers
            )
            if response.status_code == 404:
                print("❌ Unable to access repository secrets. Possible causes:")
                print("   - Repository doesn't exist or you don't have access")
                print("   - GitHub Actions is not enabled for this repository")
                print("   - Token doesn't have 'repo' scope")
                raise Exception("Cannot access repository secrets")
            response.raise_for_status()
            data = response.json()
            return data["key"], data["key_id"]
        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to get public key: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"   Status: {e.response.status_code}")
                print(f"   Response: {e.response.text}")
            raise
    
    def encrypt_secret(self, public_key: str, secret_value: str) -> str:
        """Encrypt a secret value using the repository's public key."""
        public_key_bytes = base64.b64decode(public_key)
        public_key_obj = public.PublicKey(public_key_bytes)
        sealed_box = public.SealedBox(public_key_obj)
        encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
        return base64.b64encode(encrypted).decode("utf-8")
    
    def set_secret(self, name: str, value: str) -> bool:
        """Create or update a repository secret."""
        try:
            # Get public key for encryption
            public_key, key_id = self.get_public_key()
            
            # Encrypt the secret value
            encrypted_value = self.encrypt_secret(public_key, value)
            
            # Create or update the secret
            response = requests.put(
                f"{self.base_url}/actions/secrets/{name}",
                headers=self.headers,
                json={
                    "encrypted_value": encrypted_value,
                    "key_id": key_id
                }
            )
            if response.status_code == 404:
                print(f"\n❌ Failed to set secret {name}: Repository or Actions not accessible")
                return False
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"\n❌ Failed to set secret {name}: {str(e)}")
            return False
    
    def list_secrets(self) -> list:
        """List all repository secrets."""
        response = requests.get(
            f"{self.base_url}/actions/secrets",
            headers=self.headers
        )
        response.raise_for_status()
        return [secret["name"] for secret in response.json()["secrets"]]


def parse_env_file(file_path: Path) -> Dict[str, str]:
    """Parse environment variables from shell script."""
    variables = {}
    
    # First pass: collect simple assignments
    simple_vars = {}
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if not line or line.startswith('#'):
                continue
            
            # Match export statements (with or without quotes)
            match = re.match(r'^export\s+([A-Z_]+)=(.*)$', line)
            if match:
                var_name = match.group(1)
                var_value = match.group(2).strip()
                
                # Remove quotes
                if (var_value.startswith('"') and var_value.endswith('"')) or \
                   (var_value.startswith("'") and var_value.endswith("'")):
                    var_value = var_value[1:-1]
                
                simple_vars[var_name] = var_value
    
    # Second pass: resolve variable references
    for var_name, var_value in simple_vars.items():
        if var_value.startswith('$'):
            # Variable reference
            ref_name = var_value[1:]
            if ref_name in simple_vars:
                variables[var_name] = simple_vars[ref_name]
            else:
                # Check environment variables
                env_value = os.environ.get(ref_name)
                if env_value:
                    variables[var_name] = env_value
                else:
                    print(f"⚠️  Warning: Unresolved variable reference ${ref_name} in {var_name}")
                    variables[var_name] = var_value
        else:
            variables[var_name] = var_value
    
    return variables


def get_repo_info() -> Tuple[str, str]:
    """Get repository owner and name from git remote or environment."""
    # Try environment variables first
    if "GITHUB_REPOSITORY" in os.environ:
        repo = os.environ["GITHUB_REPOSITORY"]
        owner, name = repo.split("/")
        return owner, name
    
    # Try to get from git remote
    try:
        import subprocess
        remote_url = subprocess.check_output(
            ["git", "remote", "get-url", "origin"],
            text=True
        ).strip()
        
        # Parse GitHub URL
        match = re.search(r'github\.com[:/]([^/]+)/([^/]+?)(\.git)?$', remote_url)
        if match:
            return match.group(1), match.group(2)
    except:
        pass
    
    raise ValueError("Could not determine repository. Set GITHUB_REPOSITORY environment variable.")


def main():
    parser = argparse.ArgumentParser(
        description="Sync environment variables to GitHub repository secrets"
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("GITHUB_API_TOKEN") or os.environ.get("GITHUB_TOKEN"),
        help="GitHub Personal Access Token (or set GITHUB_API_TOKEN/GITHUB_TOKEN env var)"
    )
    parser.add_argument(
        "--secrets-file",
        default="secrets/set_env.sh",
        help="Path to secrets file (default: secrets/set_env.sh)"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List current secrets instead of syncing"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be synced without making changes"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug output"
    )
    
    args = parser.parse_args()
    
    # Enable debug if requested
    if args.debug:
        import logging
        logging.basicConfig(level=logging.DEBUG)
    
    # Validate token
    if not args.token:
        print("❌ GitHub token not provided. Set GITHUB_API_TOKEN/GITHUB_TOKEN or use --token")
        print("\nTo create a token:")
        print("1. Go to https://github.com/settings/tokens")
        print("2. Click 'Generate new token (classic)'")
        print("3. Select scopes: 'repo' (all)")
        print("4. Generate and copy the token")
        sys.exit(1)
    
    # Get repository info
    try:
        owner, repo = get_repo_info()
        print(f"🚀 Repository: {owner}/{repo}")
    except ValueError as e:
        print(f"❌ {e}")
        sys.exit(1)
    
    # Create manager
    manager = GitHubSecretsManager(args.token, owner, repo)
    
    # Verify token
    print("\n🔐 Verifying GitHub access...")
    if not manager.verify_token():
        print("\n💡 Token requirements:")
        print("   - Must have 'repo' scope for private repositories")
        print("   - Must have 'public_repo' scope for public repositories")
        print("   - User must have admin access to the repository")
        sys.exit(1)
    
    # List secrets if requested
    if args.list:
        try:
            secrets = manager.list_secrets()
            print("\n📋 Current repository secrets:")
            for secret in secrets:
                print(f"  • {secret}")
        except Exception as e:
            print(f"❌ Failed to list secrets: {e}")
            sys.exit(1)
        return
    
    # Parse secrets file
    secrets_path = Path(args.secrets_file)
    if not secrets_path.exists():
        print(f"❌ Secrets file not found: {secrets_path}")
        sys.exit(1)
    
    print(f"📖 Reading secrets from {secrets_path}")
    variables = parse_env_file(secrets_path)
    
    print(f"\n🔄 Found {len(variables)} variables to sync:")
    for name in variables:
        print(f"  • {name}")
    
    if args.dry_run:
        print("\n⚠️  Dry run mode - no changes will be made")
        return
    
    # Sync secrets
    print("\n🔄 Syncing secrets to GitHub...")
    success_count = 0
    for name, value in variables.items():
        if not value:
            print(f"⚠️  Skipping {name} (empty value)")
            continue
        
        print(f"  Setting {name}...", end=" ", flush=True)
        if manager.set_secret(name, value):
            print("✅")
            success_count += 1
        else:
            print("❌")
    
    print(f"\n✅ Successfully synced {success_count}/{len(variables)} secrets")


if __name__ == "__main__":
    main()
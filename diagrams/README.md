# AWS Architecture Diagrams

Generates detailed architecture diagrams for all 5 Sagebrush AWS accounts using
the official AWS architecture icons.

## Quick Start

```bash
# Generate all diagrams
uv run generate.py

# View outputs
ls -lh outputs/
```

## Generated Diagrams

The script generates 6 PNG diagrams:

1. **00-organization-overview.png** - AWS Organization structure and
   cross-account relationships
2. **01-management-account.png** - Management account (731099197338) with ECS,
   RDS, ALB, etc.
3. **02-production-account.png** - Production account (978489150794) with
   Aurora Serverless
4. **03-staging-account.png** - Staging account (889786867297) with Aurora
   Serverless
5. **04-housekeeping-account.png** - Housekeeping account (374073887345) with
   daily billing Lambda
6. **05-neonlaw-account.png** - NeonLaw account (102186460229) with Aurora
   and CodeCommit

## Requirements

- Python 3.12+ (installed via uv)
- Graphviz (for rendering diagrams)

```bash
# Install Graphviz on macOS
brew install graphviz

# Install Graphviz on Linux
sudo apt-get install graphviz  # Debian/Ubuntu
sudo yum install graphviz      # RHEL/CentOS
```

## Dependencies

Managed via `uv`:

- **diagrams** - AWS architecture diagram generator
- **graphviz** - Python bindings for Graphviz

## Project Structure

```txt
diagrams/
├── README.md              # This file
├── generate.py            # Main diagram generation script
├── pyproject.toml         # uv project configuration
├── .gitignore             # Ignores .venv, outputs, etc.
└── outputs/               # Generated PNG files (gitignored)
```

## Updating Diagrams

The diagrams are generated from `DEPLOYED_RESOURCES.md`. When resources change:

1. Update `DEPLOYED_RESOURCES.md` first (per project guidelines)
2. Edit `generate.py` to reflect the changes
3. Regenerate diagrams: `uv run generate.py`

## Notes

- Output images are **gitignored** - diagrams are regenerated on demand
- Uses official AWS architecture icons via the `diagrams` library
- All diagrams use a consistent left-to-right or top-to-bottom flow
- Labels include resource names, types, and key configuration details

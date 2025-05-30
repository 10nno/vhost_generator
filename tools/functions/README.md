# Fresh VHost Functions Directory

This directory contains modular function files for the fresh vhost management system.

## Function Files:

- `core_functions.sh` - Core functionality (init, template, basic operations)
- `nginx_functions.sh` - Nginx management (symlinks, reload, status)
- `single_operations.sh` - Single domain operations (create, update, clone)
- `bulk_functions.sh` - Bulk operations (bulk create, delete, backup)
- `interactive_functions.sh` - Interactive menus and user interface

## Usage:

These files are automatically sourced by the main script `add_fresh_vhost.sh`.

## Adding New Functions:

1. Create or edit the appropriate function file
2. Add your function following bash best practices
3. Test the function independently
4. Update this README if adding new files

## Dependencies:

- Database file: `../database/domains_db.sh`
- Template file: `../template/fresh_template`
- Main script: `../add_fresh_vhost.sh`

## File Structure:

```
project/
├── tools/
│   ├── add_fresh_vhost.sh          # Main script
│   ├── ssl_manager.sh              # SSL management
│   ├── setup_modular.sh            # This setup script
│   └── functions/                  # Function modules
│       ├── core_functions.sh
│       ├── nginx_functions.sh
│       ├── single_operations.sh
│       ├── bulk_functions.sh
│       └── interactive_functions.sh
├── database/
│   └── domains_db.sh               # Domain database
├── template/
│   └── fresh_template              # Nginx template
├── vhost/
│   └── fresh/                      # Generated vhost files
├── backup/
│   └── vhosts/                     # Backup storage
└── logs/                           # Log files
```

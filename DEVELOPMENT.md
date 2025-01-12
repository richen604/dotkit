# Development Documentation

## User Journeys

### 1. Module Installation Journey

```mermaid
sequenceDiagram
    actor User
    participant CLI
    participant CoreManager
    participant FSManager
    participant Validator

    User->>CLI: dotkit install [source]
    CLI->>Validator: Validate command syntax
    CLI->>CoreManager: Process source
    
    CoreManager->>Validator: Validate source format
    Validator-->>CoreManager: Validation result
    
    alt Source needs fetching
        CoreManager->>Validator: Validate remote source
        Validator-->>CoreManager: Validation result
        CoreManager->>CoreManager: Fetch & cache source
    end

    CoreManager->>Validator: Validate module structure
    Validator-->>CoreManager: Validation result
    CoreManager->>FSManager: Process installation
    
    FSManager->>Validator: Validate filesystem paths
    Validator-->>FSManager: Validation result
    
    FSManager->>Validator: Validate pre-install hooks
    Validator-->>FSManager: Validation result
    FSManager->>FSManager: Run pre-install hooks
    
    FSManager->>Validator: Validate symlink targets
    Validator-->>FSManager: Validation result
    FSManager->>FSManager: Create symlinks
    
    FSManager->>Validator: Validate post-install hooks
    Validator-->>FSManager: Validation result
    FSManager->>FSManager: Run post-install hooks
    
    CLI->>User: Show success
```

### 2. Module Creation Journey

```mermaid
sequenceDiagram
    actor Developer
    participant CLI
    participant CoreManager
    participant Validator
    participant Marketplace

    Developer->>CLI: dotkit create module
    CLI->>Validator: Validate command syntax
    CLI->>CoreManager: Load template
    
    Developer->>CLI: Fill module details
    CLI->>Validator: Validate input format
    CoreManager->>Validator: Validate module structure
    Validator-->>CoreManager: Validation result
    
    Developer->>CLI: Test locally
    CLI->>Validator: Validate test environment
    
    Developer->>Marketplace: Publish module
    Marketplace->>Validator: Validate package format
    Validator-->>Marketplace: Validation result
```

### 3. Config Management Journey

```mermaid
sequenceDiagram
    actor User
    participant CLI
    participant CoreManager
    participant FSManager
    participant Validator

    User->>CLI: dotkit backup
    CLI->>Validator: Validate command syntax
    CLI->>CoreManager: Get state info
    
    CoreManager->>Validator: Validate state integrity
    Validator-->>CoreManager: Validation result
    
    CoreManager->>FSManager: Create backup
    FSManager->>Validator: Validate backup paths
    Validator-->>FSManager: Validation result
    
    User->>CLI: dotkit restore
    CLI->>Validator: Validate command syntax
    CLI->>CoreManager: Load backup
    
    CoreManager->>Validator: Validate backup integrity
    Validator-->>CoreManager: Validation result
    
    CoreManager->>FSManager: Restore files
    FSManager->>Validator: Validate restore paths
    Validator-->>FSManager: Validation result
```

## Cache Structure

```
~/.local/share/dotkit/
├── cache/
│   ├── git/                    # Cloned repositories
│   │   └── [repo-name]/
│   ├── modules/               # Cached modules
│   │   └── [namespace]/
│   │       └── [name]/
│   └── configs/               # Cached configurations
│       └── [namespace]/
│           └── [name]/
├── backup/                    # Backup storage
│   └── [timestamp]/
└── state/                    # Runtime state
    └── state.json
```
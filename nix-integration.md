# Dotkit's Nix Integration: A Pragmatic Approach

## The Problem

Current dotfile solutions in Nix:
- Force full rewrites into Nix expressions
- Use hacks like `mkOutOfStoreSymlink`
- Mix concerns between config and state
- Make sharing configs difficult

## The Solution

Dotkit provides structure without fighting Nix:

```nix
{
  dotkit.modules.nvim = {
    # 1. Static files (in nix store)
    files.static = {
      # Use existing configs directly
      "init.lua".source = ./nvim/init.lua;
      # Or pure Nix when it makes sense
      "generated.lua".text = generators.makeLuaConfig { };
    };

    # 2. State (managed outside store)
    state.files = {
      # Be explicit about mutable files
      "undo" = { type = "directory"; mode = "700"; };
      "sessions" = { type = "directory"; };
    };
  };
}
```

## Why This Works

1. **For Nix Purists**
   - No magic, just explicit patterns
   - Clear separation of concerns
   - Path toward pure Nix configs
   - No runtime complexity

2. **For Teams**
   - Keep existing configs
   - Gradual Nix adoption
   - Share modules easily
   - Clear upgrade path

3. **For Everyone**
   - Files work as expected
   - State is managed properly
   - Permissions are correct
   - No symlink hell

## Common Concerns

### "Just Use Pure Nix"
Yes, when it makes sense. But:
- Most configs mix static/dynamic content
- Teams need practical migration paths
- Community configs exist

### "State Belongs in Services"
True for daemons, but dotfiles include:
- Editor configs
- Shell scripts
- Tool preferences
- Personal customizations

### "It's Just Home-Manager++"
No - it's about being explicit:
- Clear file categorization
- Proper state management
- Better sharing
- Simpler maintenance

## Getting Started

Manage modules individually:

```nix
{
  inputs.dotkit.url = "github:richen604/dotkit";
  
  # Your existing config
  dotkit.modules.nvim = {
    enable = true;
    # Use existing files
    files.static.source = ./nvim;
    
    # Declare state needs
    state.files.undo = { type = "directory"; };
  };
}
```

Or use the `dotkit.config` module to manage your global config:

```nix
{
  dotkit.config = {
    enable = true;
    name = "my-config";
    namespace = "my-namespace";
    description = "My global config";
    backup_path = "/home/user/.backup";
    modules = {
      "nvim" = ./nvim.nix; # dotkit.modules.nvim
    };
  };
}
```

You can also use dotkit.import to attempt to load the module config automatically.

```nix
{
  dotkit.import = "github:richen604/my-module";
  dotkit.modules.my-module.enable = true;
}
```

Module maintainers can declare `state: true` to note that the files are mutable and should be managed outside the Nix store.

```yaml
files:
  - source: ./my-module/config
    target: ~/.config/my-module/config
    state: true # this file is mutable and should be managed outside the Nix store
```

It's up to module maintainers to ensure that their modules are compatible with nix. Dotkit will not enforce this allowing for gradual migration.
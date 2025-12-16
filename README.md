# Ruby Marshal Deserialization Exploit Generator

A comprehensive tool for generating Ruby Marshal deserialization payloads using multiple RubyGems gadget chains. Supports file operations and remote code execution through unsafe deserialization vulnerabilities.

## ⚠️ Disclaimer

**This tool is for authorized security testing and educational purposes only.** Unauthorized use against systems you don't own or have explicit permission to test is illegal. The authors are not responsible for any misuse of this tool.

## 📋 Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Techniques](#techniques)
- [Usage](#usage)
- [Options](#options)
- [Examples](#examples)
- [Technical Details](#technical-details)
- [Troubleshooting](#troubleshooting)

## Overview

This tool generates Ruby Marshal deserialization payloads that exploit RubyGems internal classes. The payloads are designed to execute when vulnerable applications call `Marshal.load()` or `YAML.load()` on user-controlled input.

**Key Points:**
- **File Operations**: Techniques 1 and 2 can trigger file operations via RubyGems path handling
- **Reliable RCE**: Only Technique 3 (Universal RCE) provides reliable command execution on modern Ruby (2.7+)
- **Ruby Version Compatibility**: Behavior varies significantly between Ruby versions

## Requirements

- RubyGems (included with Ruby)
- Standard libraries: `optparse`, `base64`, `yaml`

## Installation

```bash
chmod +x ruby_deser.rb
```

Or run directly:
```bash
ruby ruby_deser.rb [options]
```

## Techniques

### Technique 1: File Injection (`file-injection`)

**Capability:** File operations (file reading/deletion attempts)  
**RCE:** ❌ Not reliable on Ruby 2.7+  
**Ruby Versions:** Works on older Ruby versions for file operations

**Description:**
Abuses `Gem::StubSpecification`'s `@loaded_from` instance variable to force RubyGems to attempt opening a user-controlled file path during deserialization. On older Ruby versions, this could potentially execute commands if the path contains shell metacharacters, but this behavior is **not reliable on modern Ruby (2.7+)**.

**Use Cases:**
- File deletion attempts (if RubyGems tries to open the path)
- File reading attempts
- Testing file path injection vulnerabilities

**Gadget Chain:**
```
Gem::Requirement → Gem::DependencyList → Gem::Source::SpecificFile → Gem::StubSpecification
```

**Example:**
```bash
./ruby_deser.rb -t file-injection -p "/tmp/test.txt" -e base64
```

### Technique 2: Command Execution via Tag Replacement (`command-exec`)

**Capability:** File operations with command tag replacement  
**RCE:** ❌ Not reliable on Ruby 2.7+  
**Ruby Versions:** Works on older Ruby versions for file operations

**Description:**
Similar to Technique 1, but uses a command tag replacement technique. The payload is built with a placeholder that gets replaced with the actual command during serialization. Like Technique 1, this relies on the `@loaded_from` mechanism and is **not reliable for RCE on modern Ruby**.

**Use Cases:**
- Same as Technique 1
- Testing command injection in file paths (legacy Ruby)

**Gadget Chain:**
```
Gem::Requirement → Gem::DependencyList → Gem::Source::SpecificFile → Gem::StubSpecification
```

**Example:**
```bash
./ruby_deser.rb -t command-exec -c "rm /tmp/test" -e base64
```

### Technique 3: Universal RCE (`universal-rce`) ⭐

**Capability:** Reliable Remote Code Execution  
**RCE:** ✅ **Reliable on Ruby 2.x and 3.x**  
**Ruby Versions:** Ruby 2.x, 3.x

**Description:**
Uses a sophisticated gadget chain involving `Net::WriteAdapter`, `Gem::RequestSet`, `Gem::Package::TarReader`, and `Net::BufferedIO` to achieve direct command execution via `Kernel.system()`. This is the **only reliable method for RCE on modern Ruby versions**.

**Use Cases:**
- Remote code execution
- Command execution in vulnerable applications
- CTF challenges and bug bounty research

**Gadget Chain:**
```
Gem::SpecFetcher, Gem::Installer → Gem::Requirement → Gem::Package::TarReader → 
Net::BufferedIO → Gem::Package::TarReader::Entry → Net::WriteAdapter → 
Gem::RequestSet → Net::WriteAdapter → Kernel.system
```

**Example:**
```bash
./ruby_deser.rb -t universal-rce -c "id" -e hex -o payload
```

## Usage

### Basic Syntax

```bash
./ruby_deser.rb -t <technique> [required-options] [optional-options]
```

### Quick Reference

| Technique | Required Option | RCE Capability | Best For |
|-----------|----------------|----------------|----------|
| `file-injection` | `-p PATH` | ❌ No (file ops only) | File operations, legacy testing |
| `command-exec` | `-c COMMAND` | ❌ No (file ops only) | File operations, legacy testing |
| `universal-rce` | `-c COMMAND` | ✅ **Yes** | **Reliable RCE** |

## Options

| Option | Short | Description | Required |
|--------|-------|-------------|----------|
| `--technique` | `-t` | Technique: `file-injection`, `command-exec`, or `universal-rce` | ✅ Yes |
| `--command` | `-c` | Command to execute (for `command-exec`/`universal-rce`) | ✅ Yes* |
| `--path` | `-p` | File path to inject (for `file-injection`) | ✅ Yes* |
| `--encode` | `-e` | Output format: `hex`, `base64`, `raw`, or `all` (default: `all`) | ❌ No |
| `--output` | `-o` | Save payload to file (extension added automatically) | ❌ No |
| `--yaml` | `-y` | Generate YAML payload (only for `file-injection` and `command-exec`) | ❌ No |
| `--test` | | Test payload deserialization locally ⚠️ **WARNING: Executes payload!** | ❌ No |
| `--verbose` | `-v` | Verbose output | ❌ No |
| `--help` | `-h` | Show help message | ❌ No |

*Required based on selected technique


## Technical Details

### Marshal Deserialization Vulnerability

Ruby's `Marshal.load()` and `YAML.load()` can deserialize arbitrary objects, including those with custom `marshal_dump`/`marshal_load` methods. When these methods execute during deserialization, they can trigger code execution through carefully crafted gadget chains.

### Why File Injection Doesn't Reliably Execute Commands

On modern Ruby (2.7+), RubyGems has improved path handling that prevents command execution through `@loaded_from`. The path is sanitized and treated as a file path, not executed as a shell command. This makes Techniques 1 and 2 unreliable for RCE but still useful for file operation testing.

### Universal RCE Mechanism

Technique 3 works by:
1. Creating a `Net::WriteAdapter` that wraps `Kernel.system`
2. Chaining through `Gem::RequestSet` to trigger method calls
3. Using `Net::BufferedIO` and `Gem::Package::TarReader` to create the call chain
4. During deserialization, the chain executes `Kernel.system(command)`

This bypasses path sanitization and directly executes system commands, making it reliable across Ruby versions.


### Payload Not Executing on Target

**For Universal RCE:**
- Verify the target uses `Marshal.load()` on user input
- Check Ruby version compatibility
- Ensure the payload format matches what the application expects

**For File Injection:**
- Remember: This is for file operations, not reliable RCE
- May work on older Ruby versions (< 2.7)
- Modern Ruby will sanitize the path

### "no implicit conversion of nil into String"

Ensure RubyGems is properly installed:
```bash
gem --version
```

## Important Notes

- **RCE Reliability**: Only `universal-rce` provides reliable command execution on modern Ruby
- **File Operations**: `file-injection` and `command-exec` are primarily for file operations, not RCE
- **YAML Support**: Only available for Techniques 1 and 2
- **Payload Size**: Typically 150-350 bytes depending on technique and command/path length
- **Testing**: Use `--test` flag only in safe, isolated environments

## Ruby Version Compatibility

| Technique | Ruby 2.0-2.6 | Ruby 2.7+ | Ruby 3.x |
|-----------|--------------|-----------|----------|
| `file-injection` | File ops ⚠️ | File ops only | File ops only |
| `command-exec` | File ops ⚠️ | File ops only | File ops only |
| `universal-rce` | ✅ RCE | ✅ RCE | ✅ RCE |

⚠️ = May have worked for RCE on very old Ruby versions, but unreliable

## License

This tool is provided for educational and authorized security testing purposes only. Use responsibly and only on systems you own or have explicit permission to test.

## Acknowledgments

This tool combines multiple Ruby deserialization research techniques:
- File injection via `Gem::StubSpecification` (file operations)
- Command tag replacement (legacy technique)
- Universal RCE via `Net::WriteAdapter` chain (reliable RCE) https://devcraft.io/2021/01/07/universal-deserialisation-gadget-for-ruby-2-x-3-x.html

---

**Remember:** Always use this tool responsibly and only for authorized security testing!

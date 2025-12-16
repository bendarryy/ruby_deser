# Ruby Marshal Deserialization Exploit Generator

A comprehensive tool for generating Ruby Marshal deserialization payloads using various RubyGems gadget chains. This tool combines multiple exploitation techniques to achieve Remote Code Execution (RCE) or file operations through unsafe deserialization.

## ⚠️ Disclaimer

**This tool is for authorized security testing and educational purposes only.** Unauthorized use against systems you don't own or have explicit permission to test is illegal. The authors are not responsible for any misuse of this tool.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Techniques](#techniques)
- [Options](#options)
- [Examples](#examples)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)

## ✨ Features

- **Three Exploitation Techniques**: Multiple RubyGems gadget chains for different scenarios
- **Multiple Output Formats**: Hex, Base64, Raw bytes, or all formats
- **YAML Support**: Generate YAML payloads for techniques that support it
- **File Saving**: Save payloads to files with automatic extension
- **Testing Mode**: Test payloads locally (use with caution!)
- **Colored Output**: Beautiful terminal output with color coding
- **Comprehensive Help**: Detailed help menu with examples

## 📦 Requirements

- Ruby 2.x or 3.x
- RubyGems (usually included with Ruby)
- Standard Ruby libraries: `optparse`, `base64`, `yaml`

## 🚀 Installation

No installation required! Just ensure Ruby is installed and the script is executable:

```bash
chmod +x ruby_deser_exploit.rb
```

Or run directly with:

```bash
ruby ruby_deser_exploit.rb [options]
```

## 📖 Usage

### Basic Syntax

```bash
./ruby_deser_exploit.rb -t <technique> [options]
```

### Quick Examples

```bash
# File deletion via path injection
./ruby_deser_exploit.rb -t file-injection -p "/tmp/delete_me.txt" -e base64

# Command execution (universal technique)
./ruby_deser_exploit.rb -t universal-rce -c "id" -e hex -o payload

# Command execution (tag replacement)
./ruby_deser_exploit.rb -t command-exec -c "rm /tmp/test" -e all
```

## 🔧 Techniques

### 1. File Injection (`file-injection`)

**Best for:** File deletion/reading operations

Abuses `Gem::StubSpecification`'s `@loaded_from` instance variable to force RubyGems to open a user-controlled file path during deserialization. This can be used for file operations or command execution through shell injection in file paths.

**Gadget Chain:**
```
Gem::Requirement → Gem::DependencyList → Gem::Source::SpecificFile → Gem::StubSpecification
```

**Example:**
```bash
./ruby_deser_exploit.rb -t file-injection -p "|rm /home/carlos/morale.txt 1>&2" -e base64
```

### 2. Command Execution (`command-exec`)

**Best for:** Command execution via file operations

Uses a command tag replacement technique with `Gem::StubSpecification`. The payload is built with a placeholder command that gets replaced with the actual command during serialization.

**Gadget Chain:**
```
Gem::Requirement → Gem::DependencyList → Gem::Source::SpecificFile → Gem::StubSpecification
```

**Example:**
```bash
./ruby_deser_exploit.rb -t command-exec -c "rm /home/carlos/morale.txt" -e base64
```

### 3. Universal RCE (`universal-rce`)

**Best for:** Direct command execution (Ruby 2.x/3.x)

Uses a more complex gadget chain involving `Net::WriteAdapter`, `Gem::RequestSet`, `Gem::Package::TarReader`, and `Net::BufferedIO` to achieve direct command execution via `Kernel.system`.

**Gadget Chain:**
```
Gem::SpecFetcher, Gem::Installer → Gem::Requirement → Gem::Package::TarReader → 
Net::BufferedIO → Gem::Package::TarReader::Entry → Net::WriteAdapter → 
Gem::RequestSet → Net::WriteAdapter → Kernel.system
```

**Example:**
```bash
./ruby_deser_exploit.rb -t universal-rce -c "id" -e hex -o payload
```

## ⚙️ Options

| Option | Short | Description | Required |
|--------|-------|-------------|----------|
| `--technique` | `-t` | Technique to use: `file-injection`, `command-exec`, or `universal-rce` | ✅ Yes |
| `--command` | `-c` | Command to execute (for `command-exec`/`universal-rce`) | ✅ Yes* |
| `--path` | `-p` | File path to inject (for `file-injection`) | ✅ Yes* |
| `--encode` | `-e` | Output format: `hex`, `base64`, `raw`, or `all` (default: `all`) | ❌ No |
| `--output` | `-o` | Save payload to file (extension added automatically) | ❌ No |
| `--yaml` | `-y` | Generate YAML payload instead of Marshal (only for `file-injection` and `command-exec`) | ❌ No |
| `--test` | | Test payload deserialization locally ⚠️ **WARNING: Executes payload!** | ❌ No |
| `--verbose` | `-v` | Verbose output | ❌ No |
| `--help` | `-h` | Show help message | ❌ No |

*Required based on selected technique

## 📚 Examples

### Example 1: File Deletion

Delete a file using path injection:

```bash
./ruby_deser_exploit.rb -t file-injection -p "/home/carlos/morale.txt" -e base64
```

### Example 2: Command Execution with Universal RCE

Execute a command and save to file:

```bash
./ruby_deser_exploit.rb -t universal-rce -c "id" -e hex -o payload
```

### Example 3: YAML Payload Generation

Generate a YAML payload for file injection:

```bash
./ruby_deser_exploit.rb -t file-injection -p "/etc/passwd" -y -e base64
```

### Example 4: Multiple Output Formats

Generate payload in all formats:

```bash
./ruby_deser_exploit.rb -t command-exec -c "whoami" -e all -o exploit
```

### Example 5: Testing Payload (Use with Caution!)

Test payload deserialization locally:

```bash
./ruby_deser_exploit.rb -t universal-rce -c "echo test" --test
```

⚠️ **Warning:** The `--test` flag will execute the payload on your local machine!

## 🔬 How It Works

### Marshal Deserialization Vulnerability

Ruby's `Marshal.load()` and `YAML.load()` can deserialize arbitrary objects, including those with custom `marshal_dump`/`marshal_load` methods. When these methods are called during deserialization, they can trigger code execution through carefully crafted gadget chains.

### Technique 1: File Injection

1. Creates a `Gem::StubSpecification` with a malicious `@loaded_from` path
2. Wraps it in `Gem::Source::SpecificFile` and `Gem::DependencyList`
3. Uses `Gem::Requirement` with a custom `marshal_dump` to serialize the chain
4. During deserialization, RubyGems attempts to load the file, executing the path as a command

### Technique 2: Command Execution (Tag Replacement)

1. Similar to Technique 1, but uses a placeholder command tag
2. The tag is replaced with the actual command after serialization
3. This allows for dynamic command injection

### Technique 3: Universal RCE

1. Creates a chain: `Net::WriteAdapter(Kernel, :system)` → `Gem::RequestSet` → `Net::WriteAdapter` → `Net::BufferedIO` → `Gem::Package::TarReader`
2. When deserialized, the chain triggers `Kernel.system()` with the specified command
3. Works across Ruby 2.x and 3.x versions

## 🐛 Troubleshooting

### Error: "Technique is required"

You must specify a technique with `-t`:

```bash
./ruby_deser_exploit.rb -t file-injection -p "/path/to/file"
```

### Error: "Path is required for file-injection"

The `file-injection` technique requires a path:

```bash
./ruby_deser_exploit.rb -t file-injection -p "/tmp/test.txt"
```

### Error: "Command is required"

The `command-exec` and `universal-rce` techniques require a command:

```bash
./ruby_deser_exploit.rb -t universal-rce -c "your command here"
```

### Error: "no implicit conversion of nil into String"

This usually means RubyGems classes weren't loaded properly. The script should handle this automatically, but if it persists, ensure RubyGems is installed:

```bash
gem --version
```

### Payload Not Working on Target

- Ensure the target application uses `Marshal.load()` or `YAML.load()` on user input
- Check Ruby version compatibility (some techniques work better on specific versions)
- Verify the payload format matches what the application expects (Marshal vs YAML)
- Test with the `--test` flag locally first (in a safe environment)

## 📝 Notes

- **YAML Support**: Only `file-injection` and `command-exec` techniques support YAML payloads
- **Payload Size**: Payloads are typically 150-350 bytes depending on the technique and command/path length
- **Ruby Version**: All techniques have been tested on Ruby 2.x and 3.x
- **Safety**: The `--test` flag executes the payload locally - use only in safe testing environments

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the existing code and submit improvements.

## 📄 License

This tool is provided for educational and authorized security testing purposes only. Use responsibly and only on systems you own or have explicit permission to test.

## 🙏 Acknowledgments

This tool combines multiple Ruby deserialization techniques:
- File injection via `Gem::StubSpecification` (CVE research)
- Command execution via tag replacement
- Universal RCE via `Net::WriteAdapter` chain

## 📞 Support

For issues, questions, or contributions, please open an issue in the repository.

---

**Remember:** Always use this tool responsibly and only for authorized security testing!


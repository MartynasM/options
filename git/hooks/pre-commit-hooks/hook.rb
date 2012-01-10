class String

  #def colorize(text, color_code) "#{color_code}#{text}\e[0m" end
  def red;    "\e[1m\e[31m#{self}\e[0m"; end
  def green;  "\e[1m\e[32m#{self}\e[0m"; end
  def yellow; "\e[1m\e[33m#{self}\e[0m"; end

  # def red;    colorize(self, ""); end
  # def green;  colorize(self, "\e[1m\e[32m"); end
  # def yellow; colorize(self, "\e[1m\e[33m"); end
end

class Hook
  require File.expand_path(File.join(File.dirname(__FILE__),  "git_result"))
  require 'open3'
  include Open3

  FILES_TO_WATCH = /(.+\.(e?rb|task|rake|thor|prawn)|[Rr]akefile|[Tt]horfile)/

  RB_REGEXP     = /\.(rb|rake|task|prawn)\z/
  ERB_REGEXP   = /\.erb\z/
  JS_REGEXP   = /\.js\z/

  RB_WARNING_REGEXP  = /[0-9]+:\s+warning:/
  ERB_INVALID_REGEXP = /invalid\z/
  COLOR_REGEXP = /\e\[(\d+)m/

  def self.results(&block)
    Hook.new(&block)
  end

  # Set this to true if you want warnings to stop your commit
  def initialize(&block)
    @compiler_ruby = `which ruby`.strip

    @result = GitResult.new(false)
    @changed_ruby_files = `git diff-index --name-only --cached HEAD`.split("\n").select{ |file| file =~ FILES_TO_WATCH }.map(&:chomp)

    instance_eval(&block) if block

    if @result.errors?
      status = 1
      puts "ERRORS:".red
      puts @result.errors.join("\n")
      puts "--------\n".red
    end

    if @result.warnings?
      if @result.stop_on_warnings
        puts "WARNINGS:".yellow
      else
        puts "Warnings:".yellow
      end
      puts @result.warnings.join("\n")
      puts "--------\n".yellow
    end

    if @result.perfect_commit?
      puts "Perfect commit!".green
    end

    if @result.continue?
      # all good
      puts("COMMIT OK:".green)
      exit 0
    else
      puts("COMMIT FAILED".red)
      exit 1
    end
  end

  def stop_on_warnings
    @result.stop_on_warnings = true
  end

  def do_not_stop_on_warnings
    @result.stop_on_warnings = false
  end

  def each_changed_file(filetypes = [:all])
    if @result.continue?
      @changed_ruby_files.each do |file|
        unless filetypes.include?(:all)
          next unless (filetypes.include?(:rb) and file =~ RB_REGEXP) or (filetypes.include?(:erb) and file =~ ERB_REGEXP) or (filetypes.include?(:js) and file =~ JS_REGEXP)
        end
        yield file if File.readable?(file)
      end
    end
  end

  def check_ruby_syntax
    each_changed_file([:rb]) do |file|
      if file =~ RB_REGEXP
        popen3("#{@compiler_ruby} -wc #{file}") do |stdin, stdout, stderr|
          stderr.read.split("\n").each do |line|
            line =~ RB_WARNING_REGEXP ? @result.warnings << line : @result.errors << line
          end
        end
        end
    end
  end

  def check_erb
    each_changed_file([:erb]) do |file|
      popen3("rails-erb-check #{file}") do |stdin, stdout, stderr|
        @result.errors.concat stdout.read.split("\n").map{|line| "#{file} => invalid ERB syntax" if line.gsub(COLOR_REGEXP, '') =~ ERB_INVALID_REGEXP}.compact
      end
    end
  end

  def check_best_practices
    each_changed_file([:rb, :erb]) do |file|
      if file =~ RB_REGEXP or file =~ ERB_REGEXP
        popen3("rails_best_practices #{file}") do |stdin, stdout, stderr|
          @result.warnings.concat stdout.read.split("\n").map{|line| line.gsub(COLOR_REGEXP, '').strip if line =~ /#{file}/ }.compact
        end
      end
    end
  end

  # Maybe need options for different file types :rb :erb :js
  def warning_on(*args)
    options = (args[-1].kind_of?(Hash) ? args.pop : {})
    each_changed_file(options[:in] || [:all]) do |file|
      popen3("fgrep -nH \"#{args.join("\n")}\" #{file}") do |stdin, stdout, stderr|
        err = stdout.read
        err.split("\n").each do |msg|
          args.each do |string|
            @result.warnings << "#{msg.split(" ").first} contains #{string}" if msg =~ /#{string}/
          end
        end
      end
    end
  end

  def info(text)
    puts(text.green)
  end

  def notice(text)
    puts(text.yellow)
  end

  def warn(text)
   puts(text.red)
  end

end

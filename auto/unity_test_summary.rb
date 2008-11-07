#!/usr/bin/ruby
#
# unity_test_summary.rb
#
require 'fileutils'
require 'set'

class UnityTestSummary

  include FileUtils::Verbose

  def run

    $stderr.flush
    $stdout.flush

    # Clean up result file names
    results = @targets.map {|target| target.gsub(/\\/,'/')}

    # Dig through each result file, looking for details on pass/fail:
    total_tests = 0
    total_failures = 0
    total_ignored = 0
    
    failure_output = ""
    ignore_output = ""
    
    results.each do |result_file|
      lines = File.readlines(result_file).map { |line| line.chomp }
      if lines.length == 0
        puts "Empty test result file: #{result_file}"
      else
        summary_line = -2
        output = get_details(result_file, lines)
        failure_output += output[:failures] if !output[:failures].empty?
        ignore_output += output[:ignores] if !output[:ignores].empty?
        tests,failures,ignored = parse_test_summary(lines[summary_line])
        total_tests += tests
        total_failures += failures
        total_ignored += ignored
      end
    end
    
    if total_ignored > 0
      puts "\n"
      puts "--------------------------\n"
      puts "UNITY IGNORED TEST SUMMARY\n"
      puts "--------------------------\n"
      puts ignore_output
    end
    
    if total_failures > 0
      puts "\n"
      puts "--------------------------\n"
      puts "UNITY FAILED TEST SUMMARY\n"
      puts "--------------------------\n"
      puts failure_output
    end
  
    puts "\n"
    puts "--------------------------\n"
    puts "OVERALL UNITY TEST SUMMARY\n"
    puts "--------------------------\n"
    puts "TOTAL TESTS: #{total_tests} TOTAL FAILURES: #{total_failures} IGNORED: #{total_ignored}\n"
    puts "\n"
    
    return total_failures
  end

  def usage(err_msg=nil)
    puts err_msg if err_msg
    puts "Usage: unity_test_summary.rb"
    exit 1
  end
   
  def set_targets(target_array)
    @targets = target_array
  end
  
  def set_root_path(path)
    @root = path
  end

  protected
  
  @@targets=nil
  @@path=nil
  @@root=nil

  def get_details(result_file, lines)
    fail_lines = [] # indices of lines with failures
    ignore_lines = [] # indices of lines with ignores
    lines.each_with_index do |line,i|
      if (i < (lines.length - 2) && !(line =~ /PASS$/))
        if line =~ /(^.*\.c):(\d+)/
          if line =~ /IGNORED$/
            ignore_lines << i
          else
            fail_lines << i
          end
        elsif line =~ /IGNORED$/
          ignore_lines << i        
        end
      end
    end
    
    failures = []
    fail_lines.each do |fail_line|
      if lines[fail_line] =~ /\w:/
        src_file,src_line,test_name,msg = lines[fail_line].split(/:/)
        src_file = "#{@root}#{src_file}" unless @root == nil || @root.length == 0
        detail = "#{src_file}:#{src_line}:#{test_name}:: #{msg}"
        failures << detail.gsub(/\//, "\\")
      end
    end
    if failures.length == 0
      failure_results = ""
    else
      failure_results = failures.join("\n") + "\n"
    end
    
    ignores = []
    ignore_lines.each do |ignore_line|
      if lines[ignore_line] =~ /\w:/
        src_file,src_line,test_name,msg = lines[ignore_line].split(/:/)
        src_file = "#{@root}#{src_file}" unless @root == nil || @root.length == 0
        detail = "#{src_file}:#{src_line}:#{test_name}:: #{msg}"
        ignores << detail.gsub(/\//, "\\")
      end
    end
    if ignores.length == 0
      ignore_results = ""
    else
      ignore_results = ignores.join("\n") + "\n"
    end
    
    results = {:failures => failure_results, :ignores => ignore_results}
  end
  
  def parse_test_summary(summary)
    if summary =~ /(\d+) Tests (\d+) Failures (\d+) Ignored/
      [$1.to_i,$2.to_i,$3.to_i]
    else
      raise "Couldn't parse test results: #{summary}"
    end
  end

  def here; File.expand_path(File.dirname(__FILE__)); end
  
end

if $0 == __FILE__
  script = UnityTestSummary.new
  begin
    script.run
  rescue Exception => e
    script.usage e.message
  end
end

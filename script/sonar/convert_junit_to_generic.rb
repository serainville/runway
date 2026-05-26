#!/usr/bin/env ruby
# frozen_string_literal: true

require "rexml/document"
require "fileutils"

input_dir = ARGV[0] || "tmp/sonar/junit"
output_path = ARGV[1] || "tmp/sonar/test-execution.xml"

junit_files = Dir.glob(File.join(input_dir, "*.xml")).sort
abort("No JUnit XML files found in #{input_dir}") if junit_files.empty?

file_cases = Hash.new { |hash, key| hash[key] = [] }

junit_files.each do |path|
  xml = File.read(path)
  doc = REXML::Document.new(xml)

  REXML::XPath.each(doc, "//testcase") do |testcase|
    classname = testcase.attributes["classname"].to_s
    method_name = testcase.attributes["name"].to_s
    duration_seconds = testcase.attributes["time"].to_f
    duration_ms = (duration_seconds * 1000.0).round

    file_path = testcase.attributes["file"].to_s
    if file_path.empty?
      inferred = classname
        .gsub("::", "/")
        .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
        .downcase
      file_path = "test/#{inferred}.rb"
    end

    case_entry = {
      name: method_name.empty? ? classname : method_name,
      duration: duration_ms,
      status: :passed,
      message: nil,
      details: nil
    }

    if (failure = testcase.elements["failure"])
      case_entry[:status] = :failure
      case_entry[:message] = failure.attributes["message"].to_s
      case_entry[:details] = failure.text.to_s
    elsif (error = testcase.elements["error"])
      case_entry[:status] = :error
      case_entry[:message] = error.attributes["message"].to_s
      case_entry[:details] = error.text.to_s
    elsif testcase.elements["skipped"]
      case_entry[:status] = :skipped
      case_entry[:message] = testcase.elements["skipped"].attributes["message"].to_s
    end

    file_cases[file_path] << case_entry
  end
end

output = REXML::Document.new
output << REXML::XMLDecl.new("1.0", "UTF-8")
root = output.add_element("testExecutions", { "version" => "1" })

file_cases.each do |file_path, cases|
  file_node = root.add_element("file", { "path" => file_path })

  cases.each do |test_case|
    attrs = {
      "name" => test_case[:name],
      "duration" => test_case[:duration].to_s
    }
    test_case_node = file_node.add_element("testCase", attrs)

    case test_case[:status]
    when :failure
      failure_node = test_case_node.add_element("failure", { "message" => test_case[:message].to_s })
      failure_node.text = test_case[:details].to_s
    when :error
      error_node = test_case_node.add_element("error", { "message" => test_case[:message].to_s })
      error_node.text = test_case[:details].to_s
    when :skipped
      skipped_node = test_case_node.add_element("skipped", { "message" => test_case[:message].to_s })
      skipped_node.text = ""
    end
  end
end

FileUtils.mkdir_p(File.dirname(output_path))
File.open(output_path, "w") do |file|
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.write(output, file)
end

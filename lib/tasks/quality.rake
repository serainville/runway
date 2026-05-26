namespace :quality do
  desc "Prepare Sonar-compatible test artifacts"
  task :sonar_prepare do
    sh "mkdir -p tmp/sonar"
    sh "SONAR=1 bin/rails db:test:prepare test"
    sh "ruby script/sonar/convert_junit_to_generic.rb tmp/sonar/junit tmp/sonar/test-execution.xml"

    unless File.exist?("coverage/coverage.json")
      abort "Missing coverage/coverage.json. SONAR=1 test run did not generate coverage JSON."
    end

    unless File.exist?("tmp/sonar/test-execution.xml")
      abort "Missing tmp/sonar/test-execution.xml. Test execution conversion failed."
    end

    puts "Sonar artifacts generated: coverage/coverage.json and tmp/sonar/test-execution.xml"
  end
end

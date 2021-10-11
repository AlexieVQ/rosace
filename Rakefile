# frozen_string_literal: true

require "bundler/gem_tasks"
task default: %i[]

file "lib/rosace/parser.rb" => "lib/rosace/parser.rtlr" do |task|
	sh "rtlr #{task.prerequisites.first} -d lib/rosace --force"
end

task build: "lib/rosace/parser.rb"
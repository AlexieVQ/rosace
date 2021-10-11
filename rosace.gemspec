# frozen_string_literal: true

require_relative "lib/rosace/version"

Gem::Specification.new do |spec|
  spec.name          = "rosace"
  spec.version       = Rosace::VERSION
  spec.authors       = ["AlexieVQ"]

  spec.summary       = "Grammar-driven random text generator for Ruby."
#  spec.description   = "TODO: Write a longer description or delete this line."
  spec.homepage      = "https://github.com/AlexieVQ/rosace"
  spec.required_ruby_version = ">= 2.4.0"

#  spec.metadata["allowed_push_host"] = "TODO: Set to 'https://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/AlexieVQ/rosace"
#  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = [
    "lib/rosace.rb",
    "lib/rosace/asd.rb",
    "lib/rosace/context.rb",
    "lib/rosace/contextual_value.rb",
    "lib/rosace/data_types.rb",
    "lib/rosace/entity.rb",
    "lib/rosace/function.rb",
    "lib/rosace/messages.rb",
    "lib/rosace/parser.rb",
    "lib/rosace/refinements.rb",
    "lib/rosace/rtc_exception.rb",
    "lib/rosace/symbol_exception.rb",
    "lib/rosace/utils.rb",
    "lib/rosace/version.rb",
    "lib/rosace/data_types/enum.rb",
    "lib/rosace/data_types/identifier.rb",
    "lib/rosace/data_types/integer_type.rb",
    "lib/rosace/data_types/mult_enum.rb",
    "lib/rosace/data_types/reference.rb",
    "lib/rosace/data_types/text.rb",
    "lib/rosace/data_types/weight.rb"
  ]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_runtime_dependency 'csv', '~> 3.1'
  spec.add_runtime_dependency 'rattler', '~> 0.6'
end

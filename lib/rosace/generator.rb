require_relative "../rosace"
require_relative "entity"
require_relative "function"
require_relative "messages"
require_relative "context"

class Rosace::Generator

	# @return [String]
	attr_reader :path

	# @return [Hash{Symbol => Function}]
	attr_reader :functions

	# @return [Hash{Symbol => Class<Entity>}]
	attr_reader :rules
	
	# @param path [String]
	# @param rules [Array<Class<Entity>>]
	# @param functions [Array<Function>]
	def initialize(path:, rules: [], functions: [])
		path += path[-1] == '/' ? '' : '/'
		@path = path.freeze
		files = Dir.glob(@path + "*.csv")
		@rules = files.each_with_object({}) do |file, hash|
			rule = rules.find { |rule| rule.file == file }
			unless rule
				rule = Class.new(Rosace::Entity) do
					self.file = file
				end
			end
			hash[rule.rule_name] = rule
		end.freeze
		functions += [
			Rosace::Function::S,
			Rosace::Function::CAPITALIZE,
			Rosace::Function::RAISE
		]
		@functions = functions.each_with_object({}) do |function, hash|
			hash[function.name] = function
		end
		@functions.freeze
		# @type [Array<Message>]
		@messages = []
		@rules.values.each do |rule|
			unless rule.initialized?
				begin
					rule.send(:init_rule)
				rescue => exception
					@messages << Rosace::ErrorMessage.new(
						exception.message,
						rule.rule_name
					)
				end
			end
		end
		unless failed?
			context = Rosace::Context.new(self)
			@messages = @rules.values.reduce(@messages) do |messages, rule|
				messages + rule.send(:verify, context)
			end
		end
	end

	def failed?
		@messages.any? { |message| message.level == "ERROR" }
	end

	def print_messages(out: $stderr)
		@messages.each { |message| out.puts message }
		nil
	end

	def new_evaluation_context
		Rosace::Context.new(self)
	end

end
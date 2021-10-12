require_relative "../rosace"
require_relative "entity"
require_relative "function"
require_relative "messages"
require_relative "context"

class Rosace::Generator

	# @return [String]
	attr_reader :path

	# @return [Enumerable<Function>]
	attr_reader :functions

	# @return [Enumerable<Class<Entity>>]
	attr_reader :rules
	
	# @param path [String]
	# @param rules [Array<Class<Entity>>]
	# @param functions [Array<Function>]
	def initialize(path:, rules: [], functions: [])
		path += path[-1] == '/' ? '' : '/'
		@path = path.freeze
		files = Dir.glob(@path + "*.csv")
		@rules = files.map do |file|
			rule = rules.find { |rule| rule.file == file }
			unless rule
				Class.new(Rosace::Entity) do
					self.file = file
				end
			end
		end.freeze
		@functions = [
			Rosace::Function::S,
			Rosace::Function::CAPITALIZE,
			Rosace::Function::RAISE
		] + functions
		@functions.freeze
		# @type [Array<Message>]
		@messages = []
		rules.each do |rule|
			begin
				rule.send(:init_rule)
			rescue => exception
				@messages << Rosace::ErrorMessage.new(exception.message, rule)
			end
		end
		context = Rosace::Context.new(@functions, @rules)
		@messages = rules.reduce(@messages) do |messages, rule|
			messages + rule.send(:verify, context)
		end
	end

	def failed?
		@messages.any? { |message| message.level == "ERROR" }
	end

	def new_evaluation_context
		Rosace::Context.new(functions, rules)
	end

end
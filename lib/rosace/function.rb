require_relative '../rosace'
require_relative 'utils'
require_relative 'contextual_value'
require_relative 'refinements'

# An object storing a function called in a entity.
#
# @author AlexieVQ
class Rosace::Function

	using Rosace::Refinements

	# @return [Symbol] Name of the function
	attr_reader :name

	# @return [:sequential, :concurrent] How the argument are parsed:
	# - in sequential mode each argument is parsed sequentially from the first
	#   to the last using the same Context, which is referenced by all the
	#   arguments;
	# - in concurrent mode each argument is parsed with its own copy of the
	#   current context.
	# Sequential mode is relevant when all the arguments’ informations must be
	# kept in memory, when concurrent mode is more relevant when the function
	# picks one argument (like a rand function) and the others are not used.
	attr_reader :type

	# @ function	=> [Proc] function to execute.

	# Creates a new function of name.
	# @param [#to_sym] name name of the function
	# @param [#to_proc] body of the function, must be a lambda that takes
	#  {ContextualValue} arguments and returns a {ContextualValue}
	# @param [:sequential, :concurrent] type type of the function, see
	#  {Function#type}
	# @raise [TypeError] wrong argument types
	# @raise [ArgumentError] wrong value for +type+.
	def initialize(name, function, type = :sequential)
		@name = Rosace::Utils.sym(name)
		@function = Rosace::Utils.convert(function, :to_proc, Proc)
		unless @function.lambda?
			raise TypeError, "#{function} is not a lambda"
		end
		if @function.arity == 0
			raise ArgumentError,
				"#{function} must have at least one parametter (required or " +
				"optional)"
		end
		@type = Rosace::Utils.sym(type)
		unless [:sequential, :concurrent].include?(type)
			raise ArgumentError, "wrong value for second argument " +
				"(:sequential or :concurrent expected, #{@type} given)"
		end
	end

	# Minimum number of arguments.
	# @return [Integer] number of mandatory arguments.
	def min_arity
		arity = @function.arity
		arity < 0 ? (arity + 1) * -1 : arity
	end

	# Maximum number of arguments (can be infinite).
	# @return [Numeric] maximum number of arguments
	def max_arity
		arity = @function.arity
		if arity >= 0
			arity
		else
			Float::INFINITY
		end
	end

	# Calls the function with the given arguments.
	# @param [Array<ContextualValue<String>>] args arguments
	# @return [ContextualValue] result of the function, with the
	# eventualy-updated context
	# @raise [ArgumentError] wrong number of arguments
	# @raise [TypeError] wrong argument types
	def call(*args)
		if args.length < min_arity
			raise ArgumentError, "to few arguments for function #{name} " +
				"(#{min_arity} expected, #{args.length} given)"
		end
		if args.length > max_arity
			raise ArgumentError, "to many arguments for function #{name} " +
				"(#{max_arity} expected, #{args.length} given)"
		end
		args.each do |arg|
			Rosace::Utils.check_type(arg, Rosace::ContextualValue)
		end
		res = @function.call(*args)
		Rosace::Utils.check_type(res, Rosace::ContextualValue)
		res
	end

	# A function concatenating given arguments 
	CAT = new(:cat, ->(*args) do
		Rosace::ContextualValue.new(
			args.map { |arg| arg.value }.join(''),
			args[0].context
		)
	end, :sequential)

	# A function randomly picking one of its arguments.
	PICK = new(:pick, ->(*args) { args.pick }, :concurrent)

	# A function returning its argument.
	S = new(:s, ->(string) { string }, :sequential)

	# A function switching the first character of its argument to uppercase, but
	# without modifying the other characters unlike {String#capitalize}.
	CAPITALIZE = new(:capitalize, ->(string) do
		Rosace::ContextualValue.new(
			string.value[0].upcase + string.value[1, string.value.length],
			string.context
		)
	end, :sequential)

end
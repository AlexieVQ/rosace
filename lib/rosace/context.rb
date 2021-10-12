require_relative '../rosace.rb'
require_relative 'entity'
require_relative 'evaluation_exception'
require_relative 'refinements'
require_relative 'utils'
require_relative 'function'

# Object storing all used entities during a text generation, all defined methods
# for the generator and all rules.
#
# @author AlexieVQ
class Rosace::Context

	using Rosace::Refinements

	# @return [Generator]
	attr_reader :generator

	# Creates a new context.
	# @param generator [Generator]
	def initialize(generator)
		@generator = generator
		self.reset
	end

	# Copy constructor, used by +clone+ and +dup+.
	# @see restore_state to understand how +source+’s state is copied in an
	#  empty Context.
	def initialize_copy(source)
		reset
		restore_state(source)
		@entities.each_value do |entities|
			entities.each_value do |entity|
				entity.send(:context=, self)
			end
		end
	end

	# Restores this context’s state from given +source+ context.
	# - entities’ states are restored from the one stored in +source+,
	# - variables’ values from +source+ are cloned in this one,
	# - if several variables reference the same object in +source+, they will
	#   reference the same clone in this context,
	# - if a variable references an Entity in +source+, it will reference the
	#   corresponding Entity’s instance in this context.
	# @param source [Context] Context whose state will overwrite this one’s
	#  state
	# @return [self]
	def restore_state(source)
		unless source.equal?(self)
			Rosace::Utils.check_type(source, Rosace::Context)
			@entities.each do |rule_name, rule_entities|
				rule_entities.each do |id, entity|
					entity.send(:restore_state, source.entity(rule_name, id))
				end
			end
			variables = source.instance_variable_get(:@variables)
			@variables = variables.keys.each_with_object({}) do |var, hash|
				same_var = variables.keys.find do |var2|
					variables[var2].equal?(variables[var]) && hash.key?(var2)
				end
				if variables[var].kind_of?(Rosace::Entity)
					hash[var] = @entities[
						variables[var].rule.rule_name
					][variables[var].id]
				elsif same_var
					hash[var] = hash[same_var]
				else
					hash[var] = variables[var].clone
				end
			end
		end
		self
	end

	# Tests if variable of given name exists in the context.
	# @param [#to_sym] name name of the variable
	# @return [true, false] +true+ if variable of given name exists, +false+
	#  otherwise
	# @raise [TypeError] no implicit conversion of name into Symbol
	def variable?(name)
		@variables.key?(Rosace::Utils.sym(name))
	end

	# Returns stored value into variable of given name.
	# @param [#to_sym] name variable name
	# @return [Object, nil] value stored, or +nil+ if there is no variable of
	#  given name
	# @raise [TypeError] no implicit conversion of name into Symbol
	def variable(name)
		@variables[Rosace::Utils.sym(name)]
	end

	# Returns the number of variables stored in the context.
	# Does not count rules and functions.
	# @return [Integer] number of variables stored in the context
	def variables_number
		@variables.size
	end

	# Tests if entity of given id exists in the rule.
	# @param [#to_sym] rule name of the rule
	# @param [#to_int] id id of the entity
	# @return [true, false] +true+ if entity of given name id, +false+
	#  otherwise
	# @raise [TypeError] wrong argument types
	def entity?(rule, id)
		rule = Rosace::Utils.sym(rule)
		id = Rosace::Utils.int(id)
		@entities.key?(rule) && @entities[rule].key?(id)
	end

	# Get entity of given id
	# @param [#to_sym] rule name of the rule
	# @param [#to_int] id id of the entity
	# @return [Entity, nil] entity of the rule of given id, or +nil+ if
	#  the rule has no entity of given id
	# @raise [TypeError] wrong argument types
	def entity(rule, id)
		rule = Rosace::Utils.sym(rule)
		id = Rosace::Utils.int(id)
		@entities.fetch(rule) { |rule|	return nil }[id]
	end

	# Returns entities of given rule.
	# @param [#to_sym] rule name of the rule
	# @return [Enumerable<Entity>] entities of the rule
	# @raise [TypeError] wrong argument type
	def entities(rule)
		@entities.fetch(Rosace::Utils.sym(rule)).values
	end

	# Pick a entity of rule of given name randomly, using a weighted random
	# choice.
	# The pickable entities are definad by {Entity#pick?} using given
	# arguments.
	# @param [#to_sym] rule name of the rule
	# @param [Array<String>] args arguments (never empty when called from an
	#  expansion node, if no arguments are explecitly given, an empty string is
	#  given by default; can be empty if called from ruby code)
	# @return [Entity, nil] a randomly chosen entity, or +nil+ if no
	#  entity satisfies the arguments
	# @raise [TypeError] invalid argument types
	def pick_entity(rule, *args)
		rule = Rosace::Utils.sym(rule)
		args.each { |arg| Rosace::Utils.check_type(arg, String) }
		@entities.fetch(rule) do |rule|
			return nil
		end.values.select do |entity|
			entity.pick?(*args)
		end.pick
	end

	# Add a variable with given name that stores given value.
	# @param [#to_sym] name variable name
	# @param [Object] value value to store
	# @return [Object] value stored
	# @raise [TypeError] no implicit conversion of +name+ into Symbol
	# @raise [EvaluationException] variable of given name already
	#  exists in the context
	def store_variable!(name, value)
		name = Rosace::Utils.sym(name)
		if name == :self
			raise Rosace::EvaluationException, "symbol self is reserved"
		elsif @variables[name]
			raise Rosace::EvaluationException,
				"symbol #{name} already exists in the context"
		elsif generator.functions[name]
			raise Rosace::EvaluationException,
				"symbol #{name} is already the name of a function"
		end
		@variables[name] = value
	end

	# Clear variables and entities.
	# @return [self]
	def reset
		@variables = {}
		@entities = generator.rules.values.each_with_object({}) do |rule, hash|
			hash[rule.rule_name] = rule.entities(self)
		end
		self
	end

end
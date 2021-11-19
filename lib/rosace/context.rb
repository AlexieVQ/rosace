require "logger"
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
	# @param parent [Context, nil] Parent context
	#  parent context
	def initialize(generator, parent: nil)
		@generator = generator
		@logger = Logger.new($stdout)
		@parent = parent
		self.reset
	end

	# Tests if variable of given name exists in the context.
	# @param [#to_sym] name name of the variable
	# @return [true, false] +true+ if variable of given name exists, +false+
	#  otherwise
	# @raise [TypeError] no implicit conversion of name into Symbol
	def variable?(name)
		@variables.key?(Rosace::Utils.sym(name)) ||
				!parent.nil? && parent.variable?(name)
	end

	# Returns stored value into variable of given name.
	# @param [#to_sym] name variable name
	# @return [Object, nil] value stored, or +nil+ if there is no variable of
	#  given name
	# @raise [TypeError] no implicit conversion of name into Symbol
	def variable(name)
		name = Rosace::Utils.sym(name)
		val = @variables[name]
		if !val.nil?
			val
		elsif !parent
			nil
		else
			val = parent.variable(name)
			if !val.nil?
				if val.is_a?(Rosace::Entity)
					val = entity(val.rule.rule_name, val.id)
				else
					already_set = @variables.keys.find do |symbol|
						v = parent.variable(symbol)
						v && v.equal?(val)
					end
					if already_set
						val = @variables[already_set]
					else
						val = val.clone
					end
					@variables[name] = val
				end
			end
			val
		end
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
		@entities.key?(rule) && @entities[rule].key?(id) ||
				!parent.nil? && parent.entity?(rule, id)
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
		entity = @entities.fetch(rule) { |rule| return nil }[id]
		if !entity.nil?
			entity
		elsif !parent
			nil
		else
			entity = parent.entity(rule, id)
			if entity.nil?
				nil
			else
				entity = entity.clone
				entity.send(:context=, self)
				@entities[rule][id] = entity
				entity
			end
		end
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
		@entities.fetch(rule) { return nil }.values.select do |entity|
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
		global = name[0] == '$'
		if name == :self
			raise Rosace::EvaluationException, "symbol self is reserved"
		elsif variable?(name)
			raise Rosace::EvaluationException,
				"symbol #{name} already exists in the context"
		elsif generator.functions[name]
			raise Rosace::EvaluationException,
				"symbol #{name} is already the name of a function"
		else
			@variables[name] = value
		end
	end

	# Clear variables and entities.
	# @return [self]
	def reset
		@variables = {}
		@entities = generator.rules.values.each_with_object({}) do |rule, hash|
			hash[rule.rule_name] = parent.nil? ? rule.entities(self) : {}
		end
		self
	end

	# @param exception [EvaluationException]
	def log(exception)
		@logger.info(exception.message)
	end

	protected

	# Creates a child context to this one.
	# @return [Context] Child context
	def child
		Rosace::Context.new(generator, parent: self)
	end

	# @return [Context, nil] Parent context
	attr_reader :parent

	# @return [Context] Root of the nodes tree
	def root
		parent ? parent.root : self
	end

	# Returns entities of given rule.
	# @param [#to_sym] rule name of the rule
	# @return [Array<Entity>] entities of the rule
	# @raise [TypeError] wrong argument type
	def entities(rule)
		rule = Rosace::Utils.sym(rule)
		generator.rules[rule].ids.map { |id| entity(rule, id) }
	end

	# Writes changes to parent, even if it is read only.
	# @param local [Boolean] true to write local variable that does not exist in
	#  parent context
	# @return [void]
	def write_to_parent(local: false)
		if parent
			@entities.each do |rule, entities|
				entities.each do |id, entity|
					parent.entity(rule, id).send(:restore_state, entity)
				end
			end
			parent.instance_variable_set(:@variables,
					write_variables(@variables,
					parent.instance_variable_get(:@variables), parent, local))
		end
	end

	private

	# Returns a hash with old_vars updated from source.
	# @param source [Hash{Symbol => Object}] new variables to write
	# @param old_vars [Hash{Symbol => Object}] variables to override
	# @param dest_context [Context] context to whom the variables are updated
	# @param local [Boolean] handles local variables that does not exist in
	#  old_vars
	# @return [Hash{Symbol => Object}] new symbol table
	def write_variables(source, old_vars, dest_context, local)
		new_vars = {}
		source.each do |symbol, value|
			if symbol[0] == '$' || local || !local && old_vars.key?(symbol)
				if value.is_a?(Rosace::Entity)
					new_vars[symbol] = dest_context.entity(value.rule.rule_name,
							value.id)
				else
					# @type [Symbol, nil]
					already_set = new_vars.keys.find do |sym|
						old_vars[sym].equal?(old_vars[symbol])
					end
					if already_set
						new_vars[symbol] = new_vars[already_set]
					else
						new_vars[symbol] = value.clone
					end
				end
			end
		end
		old_vars.each do |symbol, value|
			unless new_vars.key?(symbol)
				already_set = new_vars.keys.find do |sym|
					old_vars[sym].equal?(old_vars[symbol])
				end
				if already_set
					new_vars[symbol] = new_vars[already_set]
				else
					new_vars[symbol] = value
				end
			end
		end
		new_vars
	end

end
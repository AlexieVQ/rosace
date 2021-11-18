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
	# @param read_only [Boolean] true if no modification are allowed on the
	#  parent context
	def initialize(generator, parent: nil, read_only: false)
		@generator = generator
		@logger = Logger.new($stdout)
		@parent = parent
		@read_only = read_only
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
					hash[var] = entity(variables[var].rule.rule_name,
							variables[var].id)
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
				if val.is_a(Rosace::Entity)
					val = entity(val.rule.rule_name, val.id)
				elsif read_only?
					val = val.clone
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
		elsif global && parent && !read_only?
			parent.store_variable!(name, value)
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

	# @return [Context, nil] Parent context
	attr_reader :parent

	# @return [Context] Root of the nodes tree
	def root
		parent ? parent.root : self
	end

	# @return [Context] Closest node to the root we can write on
	def writable_root
		parent && !read_only? ? parent.writable_root : self
	end

	# @return [Boolean] true if the parent context must not be modified while
	#  using this one
	def read_only?
		@read_only
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
	# @return [void]
	def write_to_parent
		if parent
			@entities.each do |rule, entities|
				entities.each do |entity|
					parent.entity(rule, entity.id).send(:restore_state, entity)
				end
			end
			parent.instance_variable_set(:@variables,
					write_variables(@variables,
					parent.instance_variable_get(:@variables), parent, false))
			root = parent.writable_root
			root.instance_variable_set(:@variables,
					write_variables(@variables,
					root.instance_variable_get(:@variables), root, true))
		end
	end

	private

	# Returns a hash with old_vars updated from source.
	# @param source [Hash{Symbol => Object}] new variables to write
	# @param old_vars [Hash{Symbol => Object}] variables to override
	# @param dest_context [Context] context to whom the variables are updated
	# @param global [Boolean] handles global variables
	# @return [Hash{Symbol => Object}] new symbol table
	def write_variables(source, old_vars, dest_context, global)
		new_vars = {}
		source.each do |symbol, value|
			if global && symbol[0] == '$' || !global && old_vars.key?(symbol)
				if value.is_a?(Rosace::Entity)
					new_vars[symbol] = dest_context.entity(value.rule.rule_name,
							value.id)
				else
					# @type [Symbol, nil]
					already_set = new_vars.keys.find do |sym|
						old_vars[sym].equal?(old_vars[value])
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
					old_vars[sym].equal?(old_vars[value])
				end
				if test
					
				end
				new_vars[symbol] = value
			end
		end
		new_vars
	end

end
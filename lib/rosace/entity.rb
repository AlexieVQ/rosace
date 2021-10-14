require 'csv'
require_relative '../rosace'
require_relative 'refinements'
require_relative 'data_types'
require_relative 'utils'
require_relative 'messages'

# A entity of a rule is a tuple from a CSV file.
#
# @author AlexieVQ
class Rosace::Entity

	using Rosace::Refinements

	###########################
	# CLASS METHOD FOR A RULE #
	###########################

	# Returns rule name, in +UpperCamelCase+, as in file name.
	# @return [Symbol] rule name, in +UpperCamelCase+, as in file name
	# @raise [RuntimeError] called on Entity, or file path not set with
	#  {Entity#file=}
	# @example
	#  class MyRule < Rosace::Entity
	#      self.file = 'rules/my_rule.csv'
	#  end
	#  
	#  MyRule.rule_name	#=> :MyRule
	def self.rule_name
		if self == Rosace::Entity
			raise "class Entity does not represent any rule"
		end
		unless @rule_name
			raise "file path not set for class #{self}"
		end
		@rule_name
	end

	# Returns rule name, in +lower_snake_case+, as in file name.
	# @return [Symbol] rule name, in +lower_snake_case+, as in file name
	# @raise [RuntimeError] called on Entity, or file path not set with
	#  {Entity#file=}
	# @example
	#  class MyRule < Rosace::Entity
	#      self.file = 'rules/my_rule.csv'
	#  end
	#  
	#  MyRule.lower_snake_case_name	#=> :my_rule
	def self.lower_snake_case_name
		if self == Rosace::Entity
			raise "class Entity does not represent any rule"
		end
		unless @lower_snake_case_name
			raise "file path not set for class #{self}"
		end
		@lower_snake_case_name
	end

	# Returns file path set with {Entity#file=}.
	# @return [String] file path (frozen)
	# @raise [RuntimeError] called on Entity, or file path not set with
	#  {Entity#file=}
	def self.file
		if self == Rosace::Entity
			raise "class Entity does not represent any rule"
		end
		unless @file
			raise "file path not set for class #{self}"
		end
		@file
	end

	# Set file path.
	# File path can only be set one time.
	# The attribute {Entity#rule_name} is inferred from the file name.
	# File name must be in the format +lower_snake_case.csv+.
	# @param [#to_str] path path to the CSV file, must end with .csv
	# @return [String] path to the CSV file (frozen)
	# @raise [TypeError] no implicit conversion of path into String
	# @raise [ArgumentError] given String does not represent a path to a CSV
	#  file
	# @raise [RuntimeError] called on Entity, or called multiple time
	def self.file=(path)
		if self == Rosace::Entity
			raise "cannot set file path for class Entity"
		end
		if @file
			raise "file path already set for class #{self}"
		end
		path = Rosace::Utils.str(path)
		unless File.exist?(path)
			raise ArgumentError, "file #{path} does not exist"
		end
		file_name = path.split('/').last
		unless file_name.valid_csv_file_name?
			raise ArgumentError, "file #{path} does not have a valid name"
		end
		@lower_snake_case_name = file_name.split('.').first.to_sym
		@rule_name = @lower_snake_case_name.id2name.camelize.to_sym
		@file = path.freeze
	end

	# Set type for given attribute.
	# @param [#to_sym] attribute name of the attribute to type
	# @param [DataType] type type of the attribute
	# @return [DataType] set type
	# @raise [TypeError] wrong argument type
	# @raise [NameError] attribute type already set
	# @raise [RuntimeError] called on Entity, or rule already initialized
	def self.data_type(attribute, type)
		if self == Rosace::Entity
			raise "cannot set data type for class Entity"
		end
		if self.initialized?
			raise "cannot set data type for already initialized rule"
		end
		attribute = Rosace::Utils.sym(attribute)
		Rosace::Utils.check_type(type, Rosace::DataTypes::DataType)
		if [:id, :weight].include?(attribute)
			raise NameError,
				"cannot set type for reserved attribute #{attribute}"
		end
		@attr_types ||= {}
		if @attr_types[attribute]
			raise NameError,
				"type already set for attribute #{attribute}"
		end
		@attr_types[attribute] = type
		type
	end

	# Declares that given attribute is a reference to rule +rule_name+'s id.
	# @param [#to_sym] attribute attribute from current rule (must only contain
	#  non-zero integers)
	# @param [#to_sym] rule_name name of the rule to reference (returned by 
	#  {Entity#rule_name})
	# @param [:required, :optional] type +:required+ for a required reference,
	#  +:optional+ for an optional one
	# @return [nil]
	# @raise [TypeError] wrong argument type
	# @raise [NameError] attribute type already set, or wrong type
	# @raise [RuntimeError] called on Entity, or rule already initialized
	def self.reference(attribute, rule_name, type = :required)
		self.data_type(attribute, Rosace::DataTypes::Reference[
			rule_name,
			type
		])
		nil
	end

	# Declares that given attribute only accepts given values.
	# The values are symbols.
	# @param [#to_sym] attribute attribute in question
	# @param [Array<#to_sym>] values accepted values
	# @return [nil]
	# @raise [TypeError] wrong argument type
	# @raise [NameError] attribute type already set
	# @raise [RuntimeError] called on Entity, or rule already initialized
	def self.enum(attribute, *values)
		self.data_type(attribute, Rosace::DataTypes::Enum[*values])
		nil
	end

	# Declares that given attribute only accepts a list of given values.
	# The values are symbols.
	# @param [#to_sym] attribute attribute in question
	# @param [Array<#to_sym>] values accepted values
	# @return [nil]
	# @raise [TypeError] wrong argument type
	# @raise [NameError] attribute type already set
	# @raise [RuntimeError] called on Entity, or rule already initialized
	def self.mult_enum(attribute, *values)
		self.data_type(attribute, Rosace::DataTypes::MultEnum[*values])
		nil
	end

	# Declares that a entity of current rule is associated with several
	# entities of a foreign rule.
	# This will creates a method +name_list+ returning an array of all the
	# associated entities, and an overridable public method +name+ picking one
	# of the entities randomly.
	# @param [#to_sym] foreign_rule name of the foreign rule
	# @param [#to_sym] foreign_attribute attribute from foreign rule
	#  referencing this rule
	# @param [#to_sym, nil] name name of the attribute to add to this rule
	# @param [:required, :optional] type +:optional+ allows for a entity to not
	#  have any associated entity in the foreign rule; in this case the
	#  dynamically defined public method will return +nil+
	# @return [nil]
	# @raise [TypeError] no implicit conversion for arguments into Symbol
	# @raise [ArgumentError] wrong value for +type+
	# @raise [RuntimeError] called on Entity, or relation of given name
	#  already set
	def self.has_many(foreign_rule,
					  foreign_attribute,
					  name,
					  type = :optional)
		if self == Rosace::Entity
			raise "cannot set assosiation with class Entity"
		end
		if self.initialized?
			raise "rule #{self.rule_name} has already been initialized"
		end
		foreign_rule = Rosace::Utils.sym(foreign_rule)
		foreign_attribute = Rosace::Utils.sym(foreign_attribute)
		name = Rosace::Utils.sym(name)
		unless [:required, :optional].include?(type)
			raise ArgumentError,
				"wrong type argument (expected :required or :optional, given " +
				type.to_s
		end
		# @type [Hash{Symbol => Hash{Symbol => Object}}]
		@relations ||= {}
		if @relations[name]
			raise "relation #{name} already set"
		end
		@relations[name] = {
			foreign_rule: foreign_rule,
			foreign_attribute: foreign_attribute,
			type: type,
			failed: false
		}
		nil
	end

	# Set attribute types from given CSV header.
	# @param [Array<Symbol>] header CSV header (names of attributes)
	# @return [nil]
	# @raise [ArgumentError] not a valid attribute name
	# @raise [RuntimeError] no +id+ attribute found
	def self.headers=(header)
		# @type [Hash{Symbol => DataType}] Attribute types
		@attr_types ||= {}
		# @type [Hash{Symbol => UnboundMethod}] User-defined methods
		@methods = {}
		if method_defined?(:weight)
			@methods[:weight] = instance_method(:weight)
		end
		header.each do |attribute|
			if attribute == :id
				@attr_types[attribute] =
					Rosace::DataTypes::Identifier.type
			else
				if attribute == :weight
					@attr_types[attribute] =
						Rosace::DataTypes::Weight.type
				else
					@attr_types[attribute] ||=
				@attr_types[attribute] ||= 
					@attr_types[attribute] ||=
						Rosace::DataTypes::Text.type
				end
				if method_defined?(attribute)
					@methods[attribute] = instance_method(attribute)
				end
				type = @attr_types[attribute]
				define_method(attribute) do
					@attributes[attribute].value(self.context)
				end
			end
		end
		unless @attr_types[:id]
			raise "no attribute id found for rule #{self.rule_name}"
		end
		unless @attr_types[:weight]
			define_method(:weight) { 1 }
		end
		nil
	end
	private_class_method :headers=

	# Returns a hash map associating attributes' names to their type.
	# @return [Hash{Symbol => DataType}] hash map associating attributes'
	#  names to their type
	# @raise [RuntimeError] called on Entity, or attributes' types not yet
	#  set
	def self.attr_types
		self.require_initialized_rule
		@attr_types
	end

	# Add a row from the file.
	# @param [CSV::Row] row row to add
	# @return [self]
	# @raise [ArgumentError] invalid row or attributes
	# @raise [RuntimeError] duplicated id
	def self.add_entity(row)
		unless row.size == @attr_types.size
			raise ArgumentError, "wrong number of arguments in tuple #{row} " +
				"(given #{row.size}, expected #{@attr_types.size})"
		end
		entity = new(row, @attr_types, @methods)
		unless @entities.add?(entity)
			raise "id #{entity.id} duplicated in rule #{self.rule_name}"
		end
		self
	end
	private_class_method :add_entity

	# Import entities from CSV file, then freeze the class.
	# The class is now considered initialized in regard of
	# {Entity#initialized?}.
	# @return [self]
	# @raise [RuntimeError] wrong number of fields in the row, or error in a row
	def self.init_rule
		# @type [Set<Entity>]
		@entities = Set[]
		# @type [Hash{Symbol => Hash{Symbol => Object}}]
		@relations ||= {}
		CSV.read(
			self.file,
			nil_value: '',
			headers: true,
			return_headers: true,
			header_converters: ->(str) do
				unless str.lower_snake_case?
					raise "invalid name for attribute \"#{str}\""
				end
				str.to_sym
			end
		).each_with_index do |row, i|
			if i == 0
				self.headers = row.headers
			else
				begin
					self.add_entity(row)
#				rescue ArgumentError => e
#					raise e.message
				end
			end
		end
		unless @attr_types[:weight]
			@attr_types[:weight] = Rosace::DataTypes::Weight.type
		end
		@relations.each do |name, relation|
			sym = "#{name}_list"
			define_method(sym) do
				self.context.entities(relation[:foreign_rule]).
					select do |entity|
					entity.send(relation[:foreign_attribute]) == self
				end
			end
			unless method_defined?(name)
				define_method(name) do
					self.send(sym).pick
				end
			end
		end
		@attr_types.freeze
		@initialized = true
		@relations.freeze
		self
	end
	private_class_method :init_rule

	# Tests whether the class is initialized or not, i.e. all its data have been
	# imported, and no more modification can be done.
	# @return [true, false] +true+ if the class has been initialized, +false+
	#  otherwise
	def self.initialized?
		@initialized || false
	end

	# Verifies the rule, i.e. searches for and lists anomalies in the entities.
	# @param [Context] context symbot context of the system
	# @return [Array<Message>] generated messages
	# @raise [RuntimeError] called on Entity, or class not initialized
	def self.verify(context)
		messages = []
		self.attr_types.each do |attribute, type|
			messages += type.verify(context, self, attribute)
		end
		@relations.each do |name, relation|
			if context.generator.rules.key?(relation[:foreign_rule])
				type = context.generator.rules[
					relation[:foreign_rule]
				].attr_types[relation[:foreign_attribute]]
				if type
					unless type.is_a?(Rosace::DataTypes::Reference) &&
						type.target == self.rule_name
						messages << Rosace::ErrorMessage.new(
							"Attribute #{relation[:foreign_attribute]} from " +
								"rule #{relation[:foreign_rule]} is not a " +
								"reference to this rule",
							self,
							nil,
							name
						)
						relation[:failed] = true
					end
				else
					messages << Rosace::ErrorMessage.new(
						"Rule #{relation[:foreign_rule]} has no " +
							"#{relation[:foreign_attribute]} attribute",
						self,
						nil,
						name
					)
					relation[:failed] = true
				end
			else
				messages << Rosace::ErrorMessage.new(
					"Rule #{relation[:foreign_rule]} does not exist",
					self,
					nil,
					name
				)
				relation[:failed] = true
			end
		end
		self.entities(context).each_value do |entity|
			messages += entity.send(:verify)
			@relations.each do |name, relation|
				if relation[:type] == :required && !relation[:failed]
					if entity.send("#{name}_list").empty?
						messages << Rosace::ErrorMessage.new(
							"No entity of rule #{relation[:foreign_rule]} " +
								"does reference this entity",
							self,
							entity,
							name
						)
					end
				end
			end
		end
		messages
	end
	private_class_method :verify

	# Returns the number of entities of the rule.
	# @return [Integer] number of entities of the rule
	# @raise [RuntimeError] called on Entity, or class not initialized
	def self.size
		self.require_initialized_rule
		return @entities.size
	end

	# Returns a map associating entities' ids to their value.
	# The Entity objects returned are newly-initalized objects.
	# @param [Context] context context where these entities are stored
	# @return [Hash{Integer => Entity}] entities stored by id
	# @raise [TypeError] wrong type of arguments
	# @raise [RuntimeError] called on Entity, or class not initialized
	def self.entities(context)
		Rosace::Utils.check_type(context, Rosace::Context)
		self.require_initialized_rule
		@entities.each_with_object({}) do |entity, hash|
			entity.instance_variable_set(:@context, context)
			hash[entity.id] = entity.dup
			entity.remove_instance_variable(:@context)
		end
	end
	
	# Raises RuntimeError if current class is Entity, or if the rule is
	# not initiaziled.
	def self.require_initialized_rule
		if self == Rosace::Entity
			raise "class Entity has no data"
		end
		unless self.initialized?
			raise "class #{self} not initialized"
		end
	end
	private_class_method :require_initialized_rule

	private_class_method :new

	class << self
		alias :length :size
	end

	################################
	# INSTANCE METHODS FOR VARIANT #
	################################

	# @return [Context] Context where the entity is stored
	attr_reader :context

	# Creates a new entity from given row.
	# @private
	# @param row [CSV::Row] row from the CSV file.
	# @param attr_types [Hash{Symbol => AttrType}] Attribute types
	# @param methods [Hash{Symbol => Proc}] User-defined methods
	# @raise [ArgumentError] invalid row
	def initialize(row, attr_types, methods)
		# @type [Hash{Symbol => DataType::Data}]
		@attributes = {}
		row.headers.each do |attribute|
			@attributes[attribute] = attr_types[attribute].data(
				rule.rule_name,
				row[:id].to_i,
				attribute,
				row[attribute]
			)
		end
		@attributes.freeze
		methods.each do |symbol, method|
			define_singleton_method(symbol, method)
		end
		init
	end

	# @private
	def initialize_copy(source)
		restore_state(source)
	end

	# Returns the entity's id.
	# @note It is strongly recommended to not override this method, as the
	#  +id+ attribute must always return the id as it is in the context.
	# @return [Integer] entity's id, as in the CSV file
	def id
		@attributes[:id].value(context)
	end

	alias :rule :class

	# Override this method to add a specific behaviour when initializing the
	# entity or resetting the context.
	# Does nothing by default.
	def init
	end

	# Decides whether the entity must be picked in a random picking according
	# to given arguments.
	# Returns +true+ by default.
	# @param [Array<String>] args arguments (never empty when called from an
	#  expansion node, if no arguments are explecitly given, an empty string is
	#  given by default; can be empty if called from ruby code)
	# @return [true, false] +true+ if the entity must be picked, +false+
	#  otherwise
	def pick?(*args)
		true
	end

	# Tests if two objects are entities of the same rule (even if they are
	# different instances of this entity).
	# @param [Object] o object to compare
	# @return [true, false] +true+ if +o+ is a entity of the same rule, +false+
	#  otherwise
	def ==(o)
		self.class == o.class && self.id == o.id
	end

	alias :eql? :==

	# Returns a hash code of the entity.
	# Different instances of the same entity return the same code.
	# @return [Integer] hash code
	def hash
		hash = 45
		f = 32
		hash = hash * f + self.class.hash
		hash = hash * f + self.id.hash
		hash
	end

	# Returns a human-readable representation of the entity, listing its
	# attributes.
	# The attributes are printed as they are stored, ignoring their redefinition
	# by the user.
	# @return [String] representation of the entities and its attributes
	# @example
	#  # my_rule.csv:
	#  # id,value,weight
	#  # 1,aaa,10
	#  # 2,bbb,20
	#  
	#  class MyRule < Rosace::Entity
	#      self.file = 'my_rule.csv'
	#  end
	#  
	#  MyRule[1].inspect	#=> '#<MyRule id=1, value="aaa", weight=10>'
	def inspect
		"#<#{self.class.rule_name} #{@attributes.map do |k, v|
			"#{k}=#{v.inspect}"
		end.join(', ')}>"
	end

	alias :to_s :inspect

	private

	# Verifies the entity, i.e. searches for and lists anomalies.
	# @return [Array<Message>] generated messages
	def verify
		@attributes.keys.inject([]) do |messages, attribute|
			messages + @attributes[attribute].verify(context)
		end
	end

	# Copies +source+’s state into this one.
	# @param source [Entity] Entity whose state will be copied into this one
	# @return [self]
	def restore_state(source)
		unless source.equal?(self)
			instance_variables.each do |symbol|
				remove_instance_variable(symbol)
			end
			singleton_methods.each do |symbol|
				singleton_class.remove_method(symbol)
			end
			if source.instance_variable_defined?(:@context)
				@context = source.instance_variable_get(:@context)
			end
			if source.instance_variable_defined?(:@attributes)
				@attributes = source.instance_variable_get(:@attributes).
					each_with_object({}) do |(name, data), dest|
						dest[name] = data.clone
					end.freeze
			end
			source.instance_variables.each do |symbol|
				src_var = source.instance_variable_get(symbol)
				unless [:@context, :@attributes].include?(symbol)
					same_var = source.instance_variables.find do |src_sym|
						source.instance_variable_get(src_sym).equal?(src_var) &&
							instance_variables.any? do |self_sym|
								self_sym == src_sym
							end
					end
					if src_var.kind_of?(Rosace::Entity)
						instance_variable_set(symbol, @context.entity(
							src_var.rule.rule_name,
							src_var.id
						))
					elsif same_var
						instance_variable_set(
							symbol,
							instance_variable_get(same_var)
						)
					else
						instance_variable_set(symbol, src_var.clone)
					end
				end
			end
			source.singleton_methods.each do |symbol|
				define_singleton_method(
					symbol,
					source.singleton_method(symbol).to_proc
				)
			end
		end
		self
	end

	# Set this entity’s context.
	# @param context [Context] Context to set
	# @return [void]
	def context=(context)
		@context = context
		instance_variables.map do |symbol|
			[symbol, instance_variable_get(symbol)]
		end.each do |symbol, value|
			if value.is_a?(Rosace::Entity)
				instance_variable_set(
					symbol,
					context.entity(value.rule.rule_name, value.id)
				)
			end
		end
		nil
	end

end
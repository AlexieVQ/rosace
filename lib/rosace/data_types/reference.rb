require_relative '../data_types'
require_relative '../utils'
require_relative 'integer_type'

# Type for an attribute referencing another rule.
#
# @author AlexieVQ
class Rosace::DataTypes::Reference < Rosace::DataTypes::IntegerType

	class Data < Rosace::DataTypes::IntegerType::Data
		
		def initialize(*args)
			super(*args)
			# @type [Integer]
			@id = @value
		end

		def inspect
			"#{type.target}[#{@id}]"
		end

		def verify(context)
			messages = super(context)
			if type.type == :required && @id <= 0
				messages << Rosace::ErrorMessage.new(
					"required reference to rule #{type.target} cannot be" +
						" null or negative",
					rule_name,
					entity_id,
					attribute
				)
			elsif @id != 0 &&
				context.generator.rules.key?(type.target) &&
				context.entity(type.target, @id).nil?
					message_class = type.type == :required ?
						Rosace::ErrorMessage :
						Rosace::WarningMessage
					messages << message_class.new(
						"no entity of id #{@id} in rule #{type.target}",
						rule_name,
						entity_id,
						attribute
					)
			end
			messages
		end

		def value(context)
			context.entity(type.target, @id)
		end

	end

	public_class_method :new

	# @see Reference#initialize
	def self.[](target, type)
		self.new(target, type)
	end

	# @return [Symbol] referenced rule
	attr_reader :target

	# @return [:required, :optional] type of the reference
	attr_reader :type

	# Creates a type for an attribute referencing given rule.
	# @param [#to_sym] target name of referenced rule
	# @param [:required, :optional] type +:required+ for a required reference,
	#  +:optional+ for an optional one
	# @raise [TypeError] no implicit conversion of target into Symbol
	# @raise [ArgumentError] wrong type given
	def initialize(target, type)
		@target = Rosace::Utils.sym(target)
		unless [:required, :optional].include?(type)
			raise ArgumentError,
				"wrong reference type (:required or :optional expected, " +
				"#{type} given)"
		end
		@type = type
	end

	# Testing if another object is a Reference type referencing the same
	# rule with the same type of requirement.
	# @param [Object] o the object to compare
	# @return [true, false] +true+ if +o+ is a Reference type referencing
	#  the same rule with the same type of requirement, +false+ otherwise
	def ==(o)
		o.kind_of?(Rosace::DataTypes::Reference) &&
			o.target == self.target &&
			o.type == self.type
	end

	# Returns a string in the format +"Reference<rule_name, type>"+.
	# @return [String] string representing the type
	# @example
	#  p Rosace::Entity::Reference[:MyRule, :optional]
	#  # Reference<MyRule, optional>
	def inspect
		super + "<#{target}, #{type}>"
	end

	alias :to_s :inspect

	# Verify this type’s definition for anomalies.
	# @param [Context] context context used
	# @param [Class, nil] rule rule calling this method
	# @param [Symbol, nil] attribute concerned attribute
	# @return [Array<Message>] generated messages
	def verify(context, rule = nil, attribute = nil)
		unless context.generator.rules.key?(self.target)
			[Rosace::ErrorMessage.new(
				"no rule named #{self.target}",
				rule ? rule.rule_name : nil,
				nil,
				attribute
			)]
		else
			[]
		end
	end
	
end
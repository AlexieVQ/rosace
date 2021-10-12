require_relative '../data_types'
require_relative '../utils'

# Type for an attribute with a set of accepted values.
#
# @author AlexieVQ
class Rosace::DataTypes::Enum < Rosace::DataTypes::DataType

	# An attribute with a value from a set of accepted value.
	#
	# @author AlexieVQ
	class Data < Rosace::DataTypes::DataType::Data

		def initialize(*args)
			super(*args)
			# @type [Symbol] converted value
			@value = plain_value.strip.to_sym
		end

		def inspect
			value.inspect
		end

		def verify(context)
			messages = super(context)
			unless type.values.any? { |v| v == value }
				messages << Rosace::ErrorMessage.new(
					"invalid value \"#{value}\" (expected " +
						"#{type.values.map { |v| v.id2name }.join(', ')})",
					context.generator.rules[rule_name],
					context.entity(rule_name, entity_id),
					attribute
				)
			end
			messages
		end

		# Return the value of this piece of data.
		# @param context [Context, nil] Evaluation context
		# @return [Symbol] Stored value
		def value(context = nil)
			@value
		end
		
	end

	# @see Enum#initialize
	def self.[](*values)
		self.new(*values)
	end

	# @return [Array<Symbol>] set of accepted values (frozen)
	attr_reader :values

	# Creates a type for an attribute with a set of accepted values.
	# @param [Array<#to_sym>] values values accepted by the attribute
	# @raise [TypeError] no implicit conversion of value into Symbol
	def initialize(*values)
		@values = values.map do |value|
			Rosace::Utils.sym(value)
		end.uniq.sort.freeze
	end

	# Testing if another object is an Enum type with the same set of values.
	# @param [Object] o the object to compare
	# @return [true, false] +true+ if +o+ is an Enum type with the same set
	#  of referenced values, +false+ otherwise
	def ==(o)
		o.kind_of?(Rosace::DataTypes::Enum) && o.values == self.values
	end

	# Returns a string in the format +"Enum<:value1, :value2, :value3>"+.
	# @return [String] a string representing the type and its accepted
	#  values
	def inspect
		super + "<#{self.values.map { |v| v.inspect }.join(', ')}>"
	end

	alias :to_s :inspect
	
end
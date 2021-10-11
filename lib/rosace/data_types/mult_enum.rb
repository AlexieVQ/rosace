require_relative '../data_types'
require_relative 'enum'

# Type for an attribute that can specify a list of values from a set of accepted
# values.
#
# @author AlexieVQ
class Rosace::DataTypes::MultEnum < Rosace::DataTypes::DataType

	# A piece of data storing a list of values from a set of accepted values.
	#
	# @author AlexieVQ
	class Data < Rosace::DataTypes::DataType::Data

		def initialize(*args)
			super(*args)
			# @type [Array<Enum::Data>] converted values
			@data = plain_value.split(
				type.class.const_get(:SEPARATOR)
			).map do |value|
				type.send(:enum).data(rule_name, entity_id, attribute, value)
			end
		end

		def inspect
			value.inspect
		end

		def value(context = nil)
			@data.map { |data| data.value(context) }
		end

		def verify(context)
			@data.reduce(super(context)) do |messages, data|
				messages + data.verify(context)
			end
		end
		
	end

	SEPARATOR = /\s+/
	private_constant :SEPARATOR

	# @see MultEnum#initialize
	def self.[](*values)
		self.new(*values)
	end

	# Creates a type for an attribute that specifies a list of accepted values.
	# @param [Array<#to_sym>] values values accepted by the attribute
	# @raise [TypeError] no implicit conversion of value into Symbol
	def initialize(*values)
		@enum = Rosace::DataTypes::Enum[*values]
	end

	# @return [Array<Symbol>] set of accepted values (frozen)
	def values
		@enum.values
	end

	# Testing if another object is a MultEnum type with the same set of values.
	# @param [Object] o the object to compare
	# @return [true, false] +true+ if +o+ is a MultEnum type with the same set
	#  of referenced values, +false+ otherwise
	def ==(o)
		o.kind_of?(Rosace::DataTypes::MultEnum) && o.values == self.values
	end

	# Returns a string in the format +"MultEnum<:value1, :value2, :value3>"+.
	# @return [String] a string representing the type and its accepted
	#  values
	def inspect
		"Mult" + @enum.inspect
	end

	alias :to_s :inspect

	private

	# @return [Enum] Enum type holding the values
	attr_reader :enum
	
end
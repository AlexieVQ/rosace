require_relative '../rosace'
require_relative 'utils'
require_relative 'messages'

# Module storing classes representing data types for the attributes.
#
# @author AlexieVQ
module Rosace::DataTypes

	# Superclass for classes representing attribute types.
	#
	# @author AlexieVQ
	class DataType

		# A piece of data stored in an entity’s attribute.
		#
		# @author AlexieVQ
		class Data

			# @return [DataType] Type of this piece of data.
			attr_reader :type

			# @return [Symbol] Name of the rule in which this piece of data is
			#  stored.
			attr_reader :rule_name

			# @return [Integer] Id of the entity in which this piece of data is
			#  stored.
			attr_reader :entity_id

			# @return [Symbol] Name of the attribute in which this piece of
			#  data is stored.
			attr_reader :attribute

			# @return [String] Value of this piece of data, as it is defined in
			#  the CSV file.
			attr_reader :plain_value

			# Creates a piece of data of given value (representing a plain text
			# by default).
			# @param type [DataType] Type of this piece of data.
			# @param rule_name [Symbol] Name of the rule in which this piece of
			#  data is stored.
			# @param entity_id [Integer] Id of the entity in which this piece of
			#  data is stored.
			# @param attribute [Symbol] Name of the attribute in which this
			#  piece of data is stored.
			# @param plain_value [String] Value of this piece of data as it is
			#  defined in the CSV file.
			def initialize(type, rule_name, entity_id, attribute, plain_value)
				@type = type
				@rule_name = rule_name
				@entity_id = entity_id
				@attribute = attribute
				@plain_value = plain_value ? plain_value.freeze : nil
			end

			# Returns the value of this piece of data in the target type.
			# @param context [Context] Context to use to evaluate this piece of
			#  data
			# @returns Value of this piece of data in the target type
			# @raise [RTCException] Exception thrown during its evaluation that
			#  has not been rescued.
			def value(context)
				@plain_value
			end

			# Inspect this piece of data.
			# @return [String] String representing this piece of data
			def inspect
				value.inspect
			end

			# @see #inspect
			def to_s
				inspect
			end

			# Verifies if this pieced of data contains anomalies.
			# @param context [Context] Context to use to verify
			# @return [Array<Message>] List of anomalies found in this piece of
			#  data
			def verify(context)
				if plain_value.nil?
					[
						Rosace::ErrorMessage.new(
							"Missing #{attribute} attribute",
							context.rule(rule_name),
							context.entity(rule_name, entity_id),
							attribute
						)
					]
				else
					[]
				end
			end
		end

		private_class_method :new

		# Returns the name of the type
		# @return [String] name of the type
		def inspect
			self.class.name.split('::').last
		end

		alias :to_s :inspect

		# Verify this type’s definition for anomalies.
		# @param [Context] context context used
		# @param [Class, nil] rule rule calling this method
		# @param [Symbol, nil] attribute concerned attribute
		# @return [Array<Message>] generated messages
		def verify(context, rule = nil, attribute = nil)
			[]
		end

		# Creates an object storing a piece of data of this type.
		# @param rule_name [#to_sym] Name of the rule in which this piece of
		#  data is defined.
		# @param entity_id [#to_int] Id of the entity in which this piece of
		#  data is defined.
		# @param attribute [#to_sym] Name of the attribute in which this piece
		#  of data is defined.
		# @param plain_value [#to_str] Piece of data, as it is defined in the
		#  CSV file.
		# @return [Data] Object representing this piece of data
		def data(rule_name, entity_id, attribute, plain_value)
			self.class::Data.new(
				self,
				Rosace::Utils.sym(rule_name),
				Rosace::Utils.int(entity_id),
				Rosace::Utils.sym(attribute),
				plain_value ? Rosace::Utils.str(plain_value) : nil
			)
		end
		
	end

end

require_relative 'data_types/identifier'
require_relative 'data_types/weight'
require_relative 'data_types/reference'
require_relative 'data_types/text'
require_relative 'data_types/enum'
require_relative 'data_types/mult_enum'
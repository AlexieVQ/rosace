require_relative '../data_types'
require_relative '../messages'

# Super type for types storing integer values.
#
# @author AlexieVQ
class Rosace::DataTypes::IntegerType < Rosace::DataTypes::DataType

	# An integer value.
	#
	# @author AlexieVQ
	class Data < Rosace::DataTypes::DataType::Data

		def initialize(*args)
			super(*args)
			# @type [Integer] integer value
			@value = plain_value.to_i
		end

		def value(context = nil)
			@value
		end

		def inspect
			@value.inspect
		end

		def verify(context)
			messages = super(context)
			unless plain_value.match?(/\A\s*(-?\d+)?\s*\z/)
				messages << Rosace::WarningMessage.new(
					"\"#{plain_value}\" is confusing for an integer " +
						"(#{value} inferred)",
					context.generator.rules[rule_name],
					context.entity(rule_name, entity_id),
					attribute
				)
			end
			messages
		end
	end

end
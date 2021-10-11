require_relative '../data_types'
require_relative 'integer_type'


# Type for the 'weight' attribute.
#
# @author AlexieVQ
class Rosace::DataTypes::Weight < Rosace::DataTypes::IntegerType

	class Data < Rosace::DataTypes::IntegerType::Data

		def verify(context)
			messages = super(context)
			if value < 0
				messages << Rosace::ErrorMessage.new(
					"weight cannot ben negative",
					context.rule(rule_name),
					context.entity(rule_name, entity_id),
					attribute
				)
			end
			messages
		end

	end

	# Returns an instance representing the Weight type.
	# @return [Weight] instance representing the type
	def self.type
		@instance ||= self.new
		@instance
	end

end
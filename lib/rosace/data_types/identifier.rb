require_relative '../data_types'
require_relative 'integer_type'

# Type for the 'id' attribute.
#
# @author AlexieVQ
class Rosace::DataTypes::Identifier < Rosace::DataTypes::IntegerType

	class Data < Rosace::DataTypes::IntegerType::Data

		def verify(context)
			messages = super(context)
			if value <= 0
				messages << Rosace::ErrorMessage.new(
					"id cannot be null or negative",
					context.rule(rule_name),
					context.entity(rule_name, entity_id),
					attribute
				)
			end
			messages
		end

	end

	# Returns an instance representing the Identifier type.
	# @return [Identifier] instance representing the type
	def self.type
		@instance ||= self.new
		@instance
	end

end
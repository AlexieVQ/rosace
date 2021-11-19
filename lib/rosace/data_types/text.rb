require 'rattler'
require_relative '../data_types'
require_relative '../parser'
require_relative '../messages'

# Type for an attribute with string values.
#
# @author AlexieVQ
class Rosace::DataTypes::Text < Rosace::DataTypes::DataType

	# A text attribute.
	#
	# @author AlexieVQ
	class Data < Rosace::DataTypes::DataType::Data

		def initialize(*args)
			super(*args)
			begin
				# @type [ASD::Node]
				@ast = Rosace::Parser.parse!(plain_value ? plain_value : "")
				@ast.set_location(rule_name, entity_id, attribute)
			rescue Rattler::Runtime::SyntaxError => e
				# @type [String, nil]
				@failed_message = e.message
			end
		end

		def verify(context)
			messages = super(context)
			if @failed_message
				messages << Rosace::ErrorMessage.new(
					@failed_message,
					context.generator.rules[rule_name],
					context.entity(rule_name, entity_id),
					attribute
				)
			else
				messages += @ast.verify(context)
			end
			messages
		end

		def inspect
			plain_value.inspect
		end

		# Evaluates this text.
		# @param context [Context] Evaluation context
		# @return [String] Evaluated text
		# @raise [EvaluationException] Exception during evaluation that has not been
		#  rescued.
		def value(context)
			parent = context
			begin
				context = parent.send(:child)
				# @type [String] Last evaluation, in case of failure if the
				#  method is called again
				@last_eval = @ast.eval(context)
				context.send(:write_to_parent, local: false)
				@last_eval
			rescue Rosace::EvaluationException => e
				if @last_eval
					@last_eval
				else
					raise e
				end
			end
		end
	end

	# Returns an instance representing the Text type
	# @return [Text] instance representing the Text
	#  type
	def self.type
		@instance ||= self.new
		@instance
	end

end
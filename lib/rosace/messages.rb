require_relative '../rosace'

# Object storing a message when analyzing a rule.
#
# @author AlexieVQ
class Rosace::Message

	private_class_method :new

	# @return [String] message
	attr_reader :message

	# @return [String] level (usually +'ERROR'+, +'WARNING'+)
	attr_reader :level

	# @return [Class, nil] concerned rule (or +nil+ if none)
	attr_reader :rule

	# @return [Entity, nil] concerned entity (or +nil+ if none)
	attr_reader :entity

	# @return [Symbol, nil] concerned attribute (or +nil+ if none)
	attr_reader :attribute

	# Creates a message.
	# @param [#to_str] message message
	# @param [Class] rule concerned rule
	# @param [Entity] entity concerned entity of the rule
	# @param [Symbol] attribute concerned attribute
	def initialize(message, rule = nil, entity = nil, attribute = nil)
		@message = message.to_str
		@rule = rule
		@entity = entity
		@attribute = attribute
	end

	# Returns the message, with its level, concerned rule and entity.
	# @return [String] message, with its level, concerned rule and entity
	def to_s
		"#{
			if self.rule
				"Rule #{self.rule.rule_name} (#{self.rule.file})#{
					if self.entity
						", entity #{self.entity.inspect}"
					else
						""
					end
				}#{
					if self.attribute
						", attribute \"#{self.attribute}\": "
					else
						": "
					end
				}"
			else
				""
			end
		}#{self.level}: #{self.message}"
	end

end

# Class for message of warning level.
#
# @author AlexieVQ
class Rosace::WarningMessage < Rosace::Message

	public_class_method :new

	# @see Message#initialize
	def initialize(*args)
		@level = 'WARNING'
		super(*args)
	end

end

# Class for message of error level.
#
# @author AlexieVQ
class Rosace::ErrorMessage < Rosace::Message

	public_class_method :new

	# @see Message#initialize
	def initialize(*args)
		@level = 'ERROR'
		super(*args)
	end

end
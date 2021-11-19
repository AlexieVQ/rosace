require_relative '../rosace'
require_relative 'messages'

# Object storing a message when analyzing a rule.
#
# @author AlexieVQ
class Rosace::Message

	private_class_method :new

	# @return [String] message
	attr_reader :message

	# @return [String] level (usually +'ERROR'+, +'WARNING'+)
	attr_reader :level

	# @return [Symbol, nil] concerned rule (or +nil+ if none)
	attr_reader :rule

	# @return [Integer, nil] concerned entity (or +nil+ if none)
	attr_reader :entity

	# @return [Symbol, nil] concerned attribute (or +nil+ if none)
	attr_reader :attribute

	# Creates a message.
	# @param [#to_str] message message
	# @param [#to_sym, nil] rule concerned rule
	# @param [#to_int, nil] entity concerned entity of the rule
	# @param [#to_sym, nil] attribute concerned attribute
	def initialize(message, rule = nil, entity = nil, attribute = nil)
		@message = message.to_str
		@rule = rule ? Rosace::Utils.sym(rule) : nil
		@entity = entity ? Rosace::Utils.int(entity) : nil
		@attribute = attribute ? Rosace::Utils.sym(attribute) : nil
	end

	# Returns the message, with its level, concerned rule and entity.
	# @return [String] message, with its level, concerned rule and entity
	def to_s
		"#{
			if self.rule
				"#{self.rule}#{
					if self.entity
						"[#{self.entity}]"
					else
						""
					end
				}#{
					if self.attribute
						"#\"#{self.attribute}\": "
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